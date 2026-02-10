-- ============================================================
-- system_vehicles: Client
-- Vehicle spawning, storage, garage interaction
-- ============================================================

--- Spawn a vehicle
RegisterNetEvent('jcrp:vehicles:spawn', function(data)
    if not data or not data.model then return end

    local modelHash = GetHashKey(data.model)

    -- Request model
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 5000 do
        Citizen.Wait(100)
        timeout = timeout + 100
    end

    if not HasModelLoaded(modelHash) then
        TriggerEvent('jcrp:notification', 'Failed to load vehicle model.', 'error')
        return
    end

    local coords = data.spawn_coords or GetEntityCoords(PlayerPedId())
    local heading = (data.spawn_coords and data.spawn_coords.heading) or GetEntityHeading(PlayerPedId())

    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)

    -- Wait for vehicle to exist
    while not DoesEntityExist(vehicle) do
        Citizen.Wait(100)
    end

    -- Set plate
    if data.plate then
        SetVehicleNumberPlateText(vehicle, data.plate)
    end

    -- Set fuel
    if data.fuel then
        SetVehicleFuelLevel(vehicle, data.fuel + 0.0)
    end

    -- Set health
    if data.engine_health then
        SetVehicleEngineHealth(vehicle, data.engine_health + 0.0)
    end
    if data.body_health then
        SetVehicleBodyHealth(vehicle, data.body_health + 0.0)
    end

    -- Apply vehicle properties/mods if available
    if data.props and type(data.props) == 'table' then
        ApplyVehicleProps(vehicle, data.props)
    end

    -- Put player in vehicle
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)

    SetModelAsNoLongerNeeded(modelHash)

    TriggerEvent('jcrp:notification', 'Vehicle spawned.', 'success')
end)

--- Vehicle stored confirmation — delete the vehicle entity
RegisterNetEvent('jcrp:vehicles:stored', function(plate)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 0)
        Citizen.Wait(1500)
        DeleteEntity(vehicle)
    end
end)

--- Garage vehicle list received
RegisterNetEvent('jcrp:vehicles:garageList', function(vehicles, garageId)
    -- TODO: Show garage UI when implemented
    -- For now, just log it
    for _, v in ipairs(vehicles) do
        JCRP.Log('system_vehicles', 'DEBUG', ('  Plate: %s Model: %s'):format(v.plate, v.model_name or v.model))
    end
end)

--- Apply vehicle properties
---@param vehicle number entity handle
---@param props table
function ApplyVehicleProps(vehicle, props)
    if not DoesEntityExist(vehicle) then return end

    if props.color1 then
        local r, g, b = props.color1[1] or 0, props.color1[2] or 0, props.color1[3] or 0
        SetVehicleCustomPrimaryColour(vehicle, r, g, b)
    end
    if props.color2 then
        local r, g, b = props.color2[1] or 0, props.color2[2] or 0, props.color2[3] or 0
        SetVehicleCustomSecondaryColour(vehicle, r, g, b)
    end
    if props.pearlescentColor then
        SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor or 0)
    end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

    -- Mods
    SetVehicleModKit(vehicle, 0)
    if props.mods and type(props.mods) == 'table' then
        for modType, modIndex in pairs(props.mods) do
            SetVehicleMod(vehicle, tonumber(modType), tonumber(modIndex), false)
        end
    end

    -- Extras
    if props.extras and type(props.extras) == 'table' then
        for extra, enabled in pairs(props.extras) do
            SetVehicleExtra(vehicle, tonumber(extra), not enabled)
        end
    end

    -- Neon
    if props.neonEnabled then
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(vehicle, i, props.neonEnabled[i + 1] or false)
        end
    end
    if props.neonColor then
        SetVehicleNeonLightsColour(vehicle, props.neonColor[1] or 0, props.neonColor[2] or 0, props.neonColor[3] or 0)
    end
end

--- Get vehicle properties for saving
---@param vehicle number entity handle
---@return table props
function GetVehicleProps(vehicle)
    if not DoesEntityExist(vehicle) then return {} end

    local props = {}

    -- Colors
    local r1, g1, b1 = GetVehicleCustomPrimaryColour(vehicle)
    local r2, g2, b2 = GetVehicleCustomSecondaryColour(vehicle)
    props.color1 = { r1, g1, b1 }
    props.color2 = { r2, g2, b2 }

    local pearl, wheel = GetVehicleExtraColours(vehicle)
    props.pearlescentColor = pearl
    props.wheelColor = wheel
    props.wheels = GetVehicleWheelType(vehicle)
    props.windowTint = GetVehicleWindowTint(vehicle)

    -- Mods
    props.mods = {}
    for i = 0, 49 do
        local mod = GetVehicleMod(vehicle, i)
        if mod >= 0 then
            props.mods[tostring(i)] = mod
        end
    end

    return props
end

exports('GetVehicleProps', GetVehicleProps)
exports('ApplyVehicleProps', ApplyVehicleProps)
