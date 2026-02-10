-- ============================================================
-- system_vehicles: Vehicle & Garage System (Server)
-- ============================================================

--- Generate a random plate
---@return string
local function GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    local plate = ''

    for i = 1, 3 do
        local idx = math.random(1, #chars)
        plate = plate .. chars:sub(idx, idx)
    end
    plate = plate .. ' '
    for i = 1, 4 do
        local idx = math.random(1, #nums)
        plate = plate .. nums:sub(idx, idx)
    end

    return plate
end

--- Generate a unique plate
---@return string
local function GenerateUniquePlate()
    for _ = 1, 100 do
        local plate = GeneratePlate()
        local exists = MySQL.scalar.await(
            'SELECT COUNT(*) FROM owned_vehicles WHERE plate = ?',
            { plate }
        )
        if exists == 0 then return plate end
    end
    return GeneratePlate() -- fallback
end

--- Get all vehicles for a citizen
---@param citizenid string
---@return table
local function GetVehicles(citizenid)
    local rows = MySQL.query.await([[
        SELECT ov.*, g.label as garage_label, g.coords_json as garage_coords
        FROM owned_vehicles ov
        LEFT JOIN garages g ON g.garage_id = ov.garage_id
        WHERE ov.citizenid = ?
        ORDER BY ov.updated_at DESC
    ]], { citizenid })
    return rows or {}
end

--- Get vehicles in a specific garage for a citizen
---@param citizenid string
---@param garageId number
---@return table
local function GetGarageVehicles(citizenid, garageId)
    local rows = MySQL.query.await([[
        SELECT * FROM owned_vehicles
        WHERE citizenid = ? AND garage_id = ? AND state = 'garaged'
        ORDER BY model_name ASC
    ]], { citizenid, garageId })
    return rows or {}
end

--- Store a vehicle in a garage
---@param plate string
---@param garageId number
---@param props table|nil vehicle properties
---@param fuel number|nil
---@param engineHealth number|nil
---@param bodyHealth number|nil
---@return boolean
local function StoreVehicle(plate, garageId, props, fuel, engineHealth, bodyHealth)
    local affected = MySQL.update.await([[
        UPDATE owned_vehicles SET
            garage_id = ?,
            state = 'garaged',
            props_json = COALESCE(?, props_json),
            fuel = COALESCE(?, fuel),
            engine_health = COALESCE(?, engine_health),
            body_health = COALESCE(?, body_health),
            updated_at = NOW()
        WHERE plate = ?
    ]], {
        garageId,
        props and JCRP.JsonEncode(props) or nil,
        fuel, engineHealth, bodyHealth,
        plate,
    })

    return affected and affected > 0
end

--- Spawn a vehicle from garage
---@param plate string
---@return table|nil vehicle data
local function TakeVehicleOut(plate)
    local vehicle = MySQL.single.await(
        'SELECT * FROM owned_vehicles WHERE plate = ? AND state = \'garaged\'',
        { plate }
    )

    if not vehicle then return nil end

    MySQL.update.await(
        'UPDATE owned_vehicles SET state = \'out\', updated_at = NOW() WHERE plate = ?',
        { plate }
    )

    vehicle.props = JCRP.JsonDecode(vehicle.props_json, {})
    return vehicle
end

--- Register a new vehicle (purchase/admin)
---@param citizenid string
---@param model string
---@param modelName string|nil
---@param garageId number|nil
---@param props table|nil
---@return string|nil plate
local function RegisterVehicle(citizenid, model, modelName, garageId, props)
    local plate = GenerateUniquePlate()

    MySQL.insert.await([[
        INSERT INTO owned_vehicles (plate, citizenid, model, model_name, props_json, garage_id, state)
        VALUES (?, ?, ?, ?, ?, ?, 'garaged')
    ]], {
        plate, citizenid, model, modelName or model,
        props and JCRP.JsonEncode(props) or nil,
        garageId or 1,
    })

    JCRP.Log('system_vehicles', 'INFO', ('Vehicle registered: %s model=%s owner=%s'):format(plate, model, citizenid))
    return plate
end

--- Impound a vehicle
---@param plate string
---@param reason string|nil
---@return boolean
local function ImpoundVehicle(plate, reason)
    local affected = MySQL.update.await(
        'UPDATE owned_vehicles SET state = \'impounded\', updated_at = NOW() WHERE plate = ?',
        { plate }
    )
    return affected and affected > 0
end

--- Release a vehicle from impound
---@param plate string
---@param garageId number|nil
---@return boolean
local function ReleaseVehicle(plate, garageId)
    local affected = MySQL.update.await(
        'UPDATE owned_vehicles SET state = \'garaged\', garage_id = COALESCE(?, garage_id), updated_at = NOW() WHERE plate = ? AND state = \'impounded\'',
        { garageId, plate }
    )
    return affected and affected > 0
end

--- Transfer vehicle ownership
---@param plate string
---@param newCitizenId string
---@return boolean
local function TransferVehicle(plate, newCitizenId)
    local affected = MySQL.update.await(
        'UPDATE owned_vehicles SET citizenid = ?, updated_at = NOW() WHERE plate = ?',
        { newCitizenId, plate }
    )
    return affected and affected > 0
end

--- Delete a vehicle permanently
---@param plate string
---@return boolean
local function DeleteVehicle(plate)
    local affected = MySQL.update.await(
        'DELETE FROM owned_vehicles WHERE plate = ?',
        { plate }
    )
    return affected and affected > 0
end

--- Get all garages
---@return table
local function GetGarages()
    local rows = MySQL.query.await('SELECT * FROM garages ORDER BY label ASC')
    local garages = {}
    if rows then
        for _, row in ipairs(rows) do
            row.coords = JCRP.JsonDecode(row.coords_json, {})
            row.spawn_coords = JCRP.JsonDecode(row.spawn_coords_json, {})
            garages[row.garage_id] = row
        end
    end
    return garages
end

-- ============================================================
-- Server Events
-- ============================================================

--- Client requests garage vehicle list
RegisterNetEvent('jcrp:vehicles:requestGarage', function(garageId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    local vehicles = GetGarageVehicles(citizenid, garageId)
    TriggerClientEvent('jcrp:vehicles:garageList', src, vehicles, garageId)
end)

--- Client requests to take vehicle out
RegisterNetEvent('jcrp:vehicles:takeOut', function(plate, garageId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    -- Verify ownership
    local vehicle = MySQL.single.await(
        'SELECT * FROM owned_vehicles WHERE plate = ? AND citizenid = ?',
        { plate, citizenid }
    )
    if not vehicle then
        TriggerClientEvent('jcrp:notification', src, 'Vehicle not found or not yours.', 'error')
        return
    end

    local data = TakeVehicleOut(plate)
    if not data then
        TriggerClientEvent('jcrp:notification', src, 'Vehicle is not in the garage.', 'error')
        return
    end

    -- Get garage spawn coords
    local garage = MySQL.single.await('SELECT * FROM garages WHERE garage_id = ?', { garageId })
    local spawnCoords = garage and JCRP.JsonDecode(garage.spawn_coords_json, nil)

    TriggerClientEvent('jcrp:vehicles:spawn', src, {
        plate = data.plate,
        model = data.model,
        props = data.props,
        fuel = data.fuel,
        engine_health = data.engine_health,
        body_health = data.body_health,
        spawn_coords = spawnCoords,
    })
end)

--- Client requests to store vehicle
RegisterNetEvent('jcrp:vehicles:store', function(plate, garageId, vehicleData)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    if type(vehicleData) ~= 'table' then vehicleData = {} end

    local ok = StoreVehicle(plate, garageId, vehicleData.props, vehicleData.fuel, vehicleData.engine_health, vehicleData.body_health)
    if ok then
        TriggerClientEvent('jcrp:vehicles:stored', src, plate)
        TriggerClientEvent('jcrp:notification', src, 'Vehicle stored.', 'success')
    else
        TriggerClientEvent('jcrp:notification', src, 'Failed to store vehicle.', 'error')
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetVehicles', GetVehicles)
exports('GetGarageVehicles', GetGarageVehicles)
exports('StoreVehicle', StoreVehicle)
exports('TakeVehicleOut', TakeVehicleOut)
exports('RegisterVehicle', RegisterVehicle)
exports('ImpoundVehicle', ImpoundVehicle)
exports('ReleaseVehicle', ReleaseVehicle)
exports('TransferVehicle', TransferVehicle)
exports('DeleteVehicle', DeleteVehicle)
exports('GetGarages', GetGarages)

JCRP.Log('system_vehicles', 'INFO', 'system_vehicles loaded.')
