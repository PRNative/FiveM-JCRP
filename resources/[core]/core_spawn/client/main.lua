-- ============================================================
-- core_spawn: Spawn System (Client)
-- NUI spawn selector + spawn execution
-- ============================================================

local isSpawnUIOpen = false
local spawnOptions = {}
local hasSpawned = false

--- Open spawn selector NUI
local function OpenSpawnUI()
    isSpawnUIOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

--- Close spawn selector NUI
local function CloseSpawnUI()
    isSpawnUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

-- ============================================================
-- Triggered after character selection from core_session
-- ============================================================
RegisterNetEvent('jcrp:spawn:showSelector', function(payload)
    -- Check if this is a brand new character (no previous position)
    local state = payload and payload.state
    local isNewCharacter = not state or not state.position or (state.position.x == 0 and state.position.y == 0 and state.position.z == 0)

    if isNewCharacter then
        -- New character — just spawn at default, no selector needed
        TriggerServerEvent('jcrp:spawn:newCharacter')
    else
        -- Existing character — request spawn options from server
        TriggerServerEvent('jcrp:spawn:requestOptions')
    end
end)

--- Receive spawn options from server
RegisterNetEvent('jcrp:spawn:options', function(options)
    spawnOptions = options

    if #options == 1 then
        -- Only one option, auto-select it
        TriggerServerEvent('jcrp:spawn:selectOption', options[1].id)
    else
        -- Show spawn selector UI
        OpenSpawnUI()
        SendNUIMessage({
            action = 'updateOptions',
            options = options,
        })
    end
end)

--- Execute spawn (from server)
RegisterNetEvent('jcrp:spawn:execute', function(spawnData)
    CloseSpawnUI()

    local ped = PlayerPedId()
    local coords = spawnData.coords
    local heading = spawnData.heading or 0

    -- Fade out
    DoScreenFadeOut(500)
    Citizen.Wait(600)

    -- Set model (from character data)
    -- The model should already be set by the session system

    -- Teleport
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    -- Restore health/armor from state
    local playerData = nil
    pcall(function()
        -- The player data was passed during character selection
    end)

    -- Fade back in
    Citizen.Wait(500)
    DoScreenFadeIn(1000)

    hasSpawned = true

    -- Notify other client-side systems
    TriggerEvent('jcrp:playerSpawned')

    -- Notify HUD to show
    TriggerEvent('jcrp:hud:show')
end)

-- ============================================================
-- NUI Callbacks
-- ============================================================

--- NUI: Select spawn option
RegisterNUICallback('selectSpawn', function(data, cb)
    if data.id then
        TriggerServerEvent('jcrp:spawn:selectOption', data.id)
    end
    cb('ok')
end)

--- NUI: Close (fallback — auto select first option)
RegisterNUICallback('closeSpawnUI', function(_, cb)
    if spawnOptions and #spawnOptions > 0 then
        TriggerServerEvent('jcrp:spawn:selectOption', spawnOptions[1].id)
    end
    cb('ok')
end)
