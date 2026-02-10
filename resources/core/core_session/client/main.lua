-- Core Session Client
local isLoggedIn = false
local playerData = nil

-- Wait for player to spawn
CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsPlayerActive(PlayerId()) then
            break
        end
    end
    
    -- Trigger character selection
    TriggerEvent('core_session:showCharacterSelector')
end)

-- Show character selector
RegisterNetEvent('core_session:showCharacterSelector', function()
    -- Fetch characters
    local characters = lib.callback.await('core_characters:getCharacters', false)
    
    if not characters then
        characters = {}
    end
    
    -- Show character selector UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showCharacterSelector',
        characters = characters,
        maxSlots = 3
    })
end)

-- Handle character selection from NUI
RegisterNUICallback('selectCharacter', function(data, cb)
    local citizenid = data.citizenid
    
    -- Request character selection
    local result = lib.callback.await('core_session:selectCharacter', false, citizenid)
    
    if result.success then
        playerData = result.data
        isLoggedIn = true
        
        -- Hide UI
        SetNuiFocus(false, false)
        SendNUIMessage({action = 'hide'})
        
        -- Notify client character is set
        TriggerEvent('core_characters:setCurrentCharacter', result.data.character)
        
        -- Trigger spawn selection
        TriggerEvent('core_spawn:showSpawnSelector')
        
        cb({success = true})
    else
        cb({success = false, message = result.message})
    end
end)

-- Handle character creation from NUI
RegisterNUICallback('createCharacter', function(data, cb)
    local result = lib.callback.await('core_characters:createCharacter', false, data.slot, data.charData)
    
    if result.success then
        -- Refresh character list
        local characters = lib.callback.await('core_characters:getCharacters', false)
        
        SendNUIMessage({
            action = 'refreshCharacters',
            characters = characters
        })
        
        cb({success = true})
    else
        cb({success = false, message = result.message})
    end
end)

-- Handle character deletion from NUI
RegisterNUICallback('deleteCharacter', function(data, cb)
    local result = lib.callback.await('core_characters:deleteCharacter', false, data.slot)
    
    if result.success then
        -- Refresh character list
        local characters = lib.callback.await('core_characters:getCharacters', false)
        
        SendNUIMessage({
            action = 'refreshCharacters',
            characters = characters
        })
        
        cb({success = true})
    else
        cb({success = false, message = result.message})
    end
end)

-- Close NUI callback
RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb({success = true})
end)

-- Get player data
function GetPlayerData()
    return playerData
end

function IsLoggedIn()
    return isLoggedIn
end

-- Exports
exports('GetPlayerData', GetPlayerData)
exports('IsLoggedIn', IsLoggedIn)
