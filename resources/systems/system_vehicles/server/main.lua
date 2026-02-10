-- System Vehicles Main
SystemVehicles = SystemVehicles or {}

-- Initialize garages data on resource start
CreateThread(function()
    if GetResourceState('core_boot') ~= 'started' then
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:WaitForBoot(function()
        Wait(2000)
        
        -- Sync garage definitions to database
        for _, garage in ipairs(Garages) do
            local exists = MySQL.scalar.await('SELECT garage_id FROM garages WHERE garage_id = ?', {garage.garage_id})
            
            if not exists then
                MySQL.insert.await('INSERT INTO garages (garage_id, label, type, coords_json, spawn_coords_json) VALUES (?, ?, ?, ?, ?)', {
                    garage.garage_id,
                    garage.label,
                    garage.type,
                    json.encode(garage.coords),
                    json.encode(garage.spawn_coords)
                })
            end
        end
        
        print('[^2SYSTEM_VEHICLES^7] Garage data synced')
    end)
end)

-- Generate random plate
local function GeneratePlate()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local plate = ""
    
    for i = 1, 8 do
        local rand = math.random(1, #charset)
        plate = plate .. string.sub(charset, rand, rand)
    end
    
    -- Check if plate exists
    local exists = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ?', {plate})
    
    if exists then
        return GeneratePlate()
    end
    
    return plate
end

-- Get vehicles owned by player
function SystemVehicles.GetVehicles(citizenid)
    local vehicles = MySQL.query.await([[
        SELECT plate, model, props_json, garage_id, state, fuel, engine_health, body_health, created_at
        FROM owned_vehicles
        WHERE citizenid = ?
        ORDER BY created_at DESC
    ]], {citizenid})
    
    if vehicles then
        for _, vehicle in ipairs(vehicles) do
            if vehicle.props_json then
                if type(vehicle.props_json) == "string" then
                    vehicle.props = json.decode(vehicle.props_json)
                else
                    vehicle.props = vehicle.props_json
                end
                vehicle.props_json = nil
            end
        end
    end
    
    return vehicles or {}
end

-- Get vehicles in garage
function SystemVehicles.GetVehiclesInGarage(citizenid, garageId)
    local vehicles = MySQL.query.await([[
        SELECT plate, model, props_json, fuel, engine_health, body_health
        FROM owned_vehicles
        WHERE citizenid = ? AND garage_id = ? AND state = 'in'
        ORDER BY created_at DESC
    ]], {citizenid, garageId})
    
    if vehicles then
        for _, vehicle in ipairs(vehicles) do
            if vehicle.props_json then
                if type(vehicle.props_json) == "string" then
                    vehicle.props = json.decode(vehicle.props_json)
                else
                    vehicle.props = vehicle.props_json
                end
                vehicle.props_json = nil
            end
        end
    end
    
    return vehicles or {}
end

-- Add vehicle
function SystemVehicles.AddVehicle(citizenid, model, props, garageId)
    local plate = props.plate or GeneratePlate()
    
    MySQL.insert.await([[
        INSERT INTO owned_vehicles (plate, citizenid, model, props_json, garage_id, state)
        VALUES (?, ?, ?, ?, ?, 'in')
    ]], {
        plate,
        citizenid,
        model,
        json.encode(props),
        garageId or 'legion_garage'
    })
    
    print(string.format('[^2SYSTEM_VEHICLES^7] Added vehicle %s (plate: %s) for %s', model, plate, citizenid))
    
    return plate
end

-- Store vehicle in garage
function SystemVehicles.StoreVehicle(plate, garageId, props)
    -- Update vehicle properties and set to 'in' state
    MySQL.update.await([[
        UPDATE owned_vehicles
        SET garage_id = ?, state = 'in', props_json = ?, fuel = ?, engine_health = ?, body_health = ?
        WHERE plate = ?
    ]], {
        garageId,
        json.encode(props.vehicleProps or {}),
        props.fuel or 100.0,
        props.engineHealth or 1000.0,
        props.bodyHealth or 1000.0,
        plate
    })
    
    return true
end

-- Spawn vehicle from garage
function SystemVehicles.SpawnVehicle(src, plate)
    if GetResourceState('core_session') ~= 'started' then
        return false, "Session not ready"
    end
    
    local citizenid = exports.core_session:GetCitizenId(src)
    if not citizenid then
        return false, "Not logged in"
    end
    
    -- Get vehicle
    local vehicle = MySQL.single.await([[
        SELECT plate, model, props_json, garage_id, fuel, engine_health, body_health
        FROM owned_vehicles
        WHERE plate = ? AND citizenid = ? AND state = 'in'
    ]], {plate, citizenid})
    
    if not vehicle then
        return false, "Vehicle not found or already out"
    end
    
    -- Parse props
    if vehicle.props_json then
        if type(vehicle.props_json) == "string" then
            vehicle.props = json.decode(vehicle.props_json)
        else
            vehicle.props = vehicle.props_json
        end
        vehicle.props_json = nil
    else
        vehicle.props = {}
    end
    
    -- Set vehicle to 'out' state
    MySQL.update('UPDATE owned_vehicles SET state = "out" WHERE plate = ?', {plate})
    
    -- Find spawn point for garage
    local garage = nil
    for _, g in ipairs(Garages) do
        if g.garage_id == vehicle.garage_id then
            garage = g
            break
        end
    end
    
    if not garage then
        return false, "Garage not found"
    end
    
    -- Get first available spawn point
    local spawnPoint = garage.spawn_coords[1]
    
    -- Return vehicle data for client to spawn
    return true, {
        model = vehicle.model,
        plate = vehicle.plate,
        props = vehicle.props,
        fuel = vehicle.fuel,
        engineHealth = vehicle.engine_health,
        bodyHealth = vehicle.body_health,
        coords = spawnPoint
    }
end

-- Delete vehicle
function SystemVehicles.DeleteVehicle(plate, citizenid)
    local deleted = MySQL.update.await('DELETE FROM owned_vehicles WHERE plate = ? AND citizenid = ?', {
        plate,
        citizenid
    })
    
    return deleted > 0
end

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM owned_vehicles WHERE citizenid = ?', {citizenid})
    print(string.format('[^2SYSTEM_VEHICLES^7] Cleaned up vehicles for character: %s', citizenid))
end)

-- Callbacks
lib.callback.register('system_vehicles:getVehicles', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    return SystemVehicles.GetVehicles(citizenid)
end)

lib.callback.register('system_vehicles:getVehiclesInGarage', function(source, garageId)
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    return SystemVehicles.GetVehiclesInGarage(citizenid, garageId)
end)

lib.callback.register('system_vehicles:spawnVehicle', function(source, plate)
    local success, data = SystemVehicles.SpawnVehicle(source, plate)
    
    if success then
        return {success = true, data = data}
    else
        return {success = false, message = data}
    end
end)

lib.callback.register('system_vehicles:storeVehicle', function(source, plate, garageId, props)
    if GetResourceState('core_session') ~= 'started' then
        return {success = false, message = "Session not ready"}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {success = false, message = "Not logged in"}
    end
    
    -- Verify ownership
    local vehicle = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ? AND citizenid = ?', {
        plate,
        citizenid
    })
    
    if not vehicle then
        return {success = false, message = "You don't own this vehicle"}
    end
    
    local success = SystemVehicles.StoreVehicle(plate, garageId, props)
    
    if success then
        return {success = true, message = "Vehicle stored"}
    else
        return {success = false, message = "Failed to store vehicle"}
    end
end)

-- Exports
exports('GetVehicles', SystemVehicles.GetVehicles)
exports('GetVehiclesInGarage', SystemVehicles.GetVehiclesInGarage)
exports('AddVehicle', SystemVehicles.AddVehicle)
exports('StoreVehicle', SystemVehicles.StoreVehicle)
exports('SpawnVehicle', SystemVehicles.SpawnVehicle)
exports('DeleteVehicle', SystemVehicles.DeleteVehicle)

-- Admin command to give vehicle
RegisterCommand('givevehicle', function(source, args)
    if source > 0 then
        local hasPermission = IsPlayerAceAllowed(source, 'command.givevehicle')
        if not hasPermission then
            return
        end
    end
    
    if #args < 2 then
        print('Usage: givevehicle <player_id> <model> [garage_id]')
        return
    end
    
    local targetId = tonumber(args[1])
    local model = args[2]
    local garageId = args[3] or 'legion_garage'
    
    if GetResourceState('core_session') ~= 'started' then
        print('core_session not started')
        return
    end
    
    local citizenid = exports.core_session:GetCitizenId(targetId)
    if citizenid then
        local plate = SystemVehicles.AddVehicle(citizenid, model, {}, garageId)
        print(string.format('Gave vehicle %s to player %d (plate: %s)', model, targetId, plate))
    else
        print('Player not found')
    end
end, true)

print('[^2SYSTEM_VEHICLES^7] Initialized')
