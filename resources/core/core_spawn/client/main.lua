-- Core Spawn Client
local isSpawned = false
local cam = nil

-- Show spawn selector
RegisterNetEvent('core_spawn:showSpawnSelector', function()
    -- Freeze player
    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityVisible(PlayerPedId(), false, false)
    
    -- Create camera
    DoScreenFadeOut(500)
    Wait(500)
    
    local coords = vector3(-1035.71, -2731.87, 20.0)
    cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, coords.x, coords.y, coords.z + 50.0)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    
    Wait(500)
    DoScreenFadeIn(500)
    
    -- Get spawn options
    local options = lib.callback.await('core_spawn:getSpawnOptions', false)
    
    -- Show UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showSpawnSelector',
        options = options
    })
end)

-- Handle spawn selection from NUI
RegisterNUICallback('selectSpawn', function(data, cb)
    local coords = data.coords
    local heading = data.heading
    
    -- Fade out
    DoScreenFadeOut(500)
    Wait(500)
    
    -- Spawn player
    local success = lib.callback.await('core_spawn:spawnAtLocation', false, coords, heading)
    
    if success then
        -- Hide UI
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'hide'})
        
        -- Cleanup camera
        if cam then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(cam, false)
            cam = nil
        end
        
        -- Unfreeze and show player
        Wait(500)
        FreezeEntityPosition(PlayerPedId(), false)
        SetEntityVisible(PlayerPedId(), true, false)
        DoScreenFadeIn(1000)
        
        isSpawned = true
        
        -- Trigger spawned event
        TriggerEvent('core_spawn:spawned')
        
        cb({success = true})
    else
        cb({success = false, message = 'Failed to spawn'})
    end
end)

-- Set player model
RegisterNetEvent('core_spawn:setPlayerModel', function(model, skin)
    local modelHash = GetHashKey(model)
    
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end
    
    SetPlayerModel(PlayerId(), modelHash)
    SetModelAsNoLongerNeeded(modelHash)
    
    -- Apply skin (basic implementation, can be extended)
    if skin and type(skin) == 'table' then
        -- This would integrate with a clothing/appearance system
        -- For now, we just set the basic appearance
    end
end)

-- Set health and armor
RegisterNetEvent('core_spawn:setHealthArmor', function(health, armor)
    local ped = PlayerPedId()
    SetEntityHealth(ped, health)
    SetPedArmour(ped, armor)
end)

-- Save position on disconnect
AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and isSpawned then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        -- This would be sent to server to save, but server already does auto-save
    end
end)

-- Export
function IsSpawned()
    return isSpawned
end

exports('IsSpawned', IsSpawned)
