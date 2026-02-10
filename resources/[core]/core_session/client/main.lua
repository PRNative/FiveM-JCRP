-- ============================================================
-- core_session: Client — NUI Character Selector + Position Sync
-- ============================================================

local isNuiOpen = false
local isSpawned = false
local playerData = nil

--- Open character selection NUI
local function OpenCharacterUI()
    isNuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })

    -- Request character list from server
    TriggerServerEvent('jcrp:session:requestCharacters')
end

--- Close character selection NUI
local function CloseCharacterUI()
    isNuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================
-- Server Events
-- ============================================================

--- Receive character list from server
RegisterNetEvent('jcrp:session:characterList', function(characters)
    SendNUIMessage({
        action = 'updateCharacters',
        characters = characters,
    })
end)

--- Character selected — proceed to spawn
RegisterNetEvent('jcrp:session:characterSelected', function(payload)
    playerData = payload
    CloseCharacterUI()

    -- Notify spawn system
    TriggerEvent('jcrp:spawn:showSelector', payload)
end)

--- Character creation result
RegisterNetEvent('jcrp:session:createResult', function(success, result)
    SendNUIMessage({
        action = 'createResult',
        success = success,
        message = success and 'Character created!' or result,
    })
end)

--- Character deletion result
RegisterNetEvent('jcrp:session:deleteResult', function(success, err)
    SendNUIMessage({
        action = 'deleteResult',
        success = success,
        message = success and 'Character deleted.' or err,
    })
end)

--- Error message
RegisterNetEvent('jcrp:session:error', function(msg)
    SendNUIMessage({
        action = 'showError',
        message = msg,
    })
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

--- NUI: Select character
RegisterNUICallback('selectCharacter', function(data, cb)
    if data.citizenid then
        TriggerServerEvent('jcrp:session:selectCharacter', data.citizenid)
    end
    cb('ok')
end)

--- NUI: Create character
RegisterNUICallback('createCharacter', function(data, cb)
    if data then
        TriggerServerEvent('jcrp:session:createCharacter', {
            slot = tonumber(data.slot),
            firstname = data.firstname,
            lastname = data.lastname,
            dob = data.dob,
            gender = tonumber(data.gender) or 0,
            backstory = data.backstory or '',
        })
    end
    cb('ok')
end)

--- NUI: Delete character
RegisterNUICallback('deleteCharacter', function(data, cb)
    if data.slot then
        TriggerServerEvent('jcrp:session:deleteCharacter', tonumber(data.slot))
    end
    cb('ok')
end)

--- NUI: Close UI
RegisterNUICallback('closeUI', function(_, cb)
    CloseCharacterUI()
    cb('ok')
end)

-- ============================================================
-- Initial spawn trigger — open character selection
-- ============================================================
AddEventHandler('playerSpawned', function()
    if not isSpawned then
        isSpawned = true
        -- Freeze player initially
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)

        -- Small delay then open character selector
        Citizen.Wait(1000)
        OpenCharacterUI()
    end
end)

-- ============================================================
-- Position Sync — sends position to server every 30 seconds
-- ============================================================
CreateThread(function()
    while true do
        Citizen.Wait(30000)
        if playerData and not isNuiOpen then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            TriggerServerEvent('jcrp:session:updatePosition', {
                x = coords.x,
                y = coords.y,
                z = coords.z,
            }, heading)
        end
    end
end)

-- ============================================================
-- Health/Armor sync — sends periodically
-- ============================================================
CreateThread(function()
    while true do
        Citizen.Wait(60000) -- every 60s
        if playerData and not isNuiOpen then
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped)
            local armor = GetPedArmour(ped)
            TriggerServerEvent('jcrp:session:updateHealth', health, armor)
        end
    end
end)
