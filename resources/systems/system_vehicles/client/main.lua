-- System Vehicles Client

-- Currently driven vehicle
local currentVehicle = nil
local currentPlate = nil

-- Spawn vehicle
RegisterNetEvent('system_vehicles:spawnVehicle', function(vehicleData)
    local model = GetHashKey(vehicleData.model)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    
    local coords = vehicleData.coords
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.heading, true, false)
    
    -- Set vehicle properties
    if vehicleData.props then
        -- Apply vehicle props (simplified, can use a proper vehicle props library)
        SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    end
    
    -- Set fuel and health
    SetVehicleFuelLevel(vehicle, vehicleData.fuel or 100.0)
    SetVehicleEngineHealth(vehicle, vehicleData.engineHealth or 1000.0)
    SetVehicleBodyHealth(vehicle, vehicleData.bodyHealth or 1000.0)
    
    -- Put player in vehicle
    local ped = PlayerPedId()
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    
    SetModelAsNoLongerNeeded(model)
    
    currentVehicle = vehicle
    currentPlate = vehicleData.plate
end)

-- Get current vehicle properties
function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then
        return {}
    end
    
    return {
        plate = GetVehicleNumberPlateText(vehicle),
        fuel = GetVehicleFuelLevel(vehicle),
        engineHealth = GetVehicleEngineHealth(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle),
        vehicleProps = {} -- Simplified, can be expanded
    }
end

-- Export
exports('GetVehicleProperties', GetVehicleProperties)

print('[^2SYSTEM_VEHICLES^7] Client initialized')
