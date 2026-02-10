--[[
  core_session - Client
  Character selector + spawn flow
]]

local characterList = nil
local maxSlots = 3
local isUiVisible = false
local spawnOptions = nil
local selectedCitizenid = nil

--- Show character selector NUI
local function ShowCharacterUI()
  if isUiVisible then return end
  isUiVisible = true
  SetNuiFocus(true, true)
  SendNUIMessage({ action = 'showCharacterSelect', characters = characterList or {}, maxSlots = maxSlots })
end

--- Hide NUI
local function HideUI()
  isUiVisible = false
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'hide' })
end

--- Request character list from server
local function RequestCharacterList()
  characterList = nil
  TriggerServerEvent('core_session:requestCharacterList')
end

--- Receive character list from server
RegisterNetEvent('core_session:receiveCharacterList', function(chars, err, slots)
  characterList = chars or {}
  maxSlots = slots or 3
  if err then
    print('^1[core_session] Character list error: ' .. tostring(err) .. '^0')
  end
  ShowCharacterUI()
end)

--- Select character result
RegisterNetEvent('core_session:selectResult', function(success, data)
  if success then
    selectedCitizenid = data
    HideUI()
    TriggerServerEvent('core_session:requestSpawnOptions', false)
  else
    SendNUIMessage({ action = 'selectError', error = data or 'unknown' })
  end
end)

--- Create character result
RegisterNetEvent('core_session:createResult', function(citizenid, err)
  if citizenid then
    selectedCitizenid = citizenid
    HideUI()
    TriggerServerEvent('core_session:requestSpawnOptions', true)
  else
    SendNUIMessage({ action = 'createError', error = err or 'unknown' })
  end
end)

--- Delete result
RegisterNetEvent('core_session:deleteResult', function(ok)
  if ok then
    RequestCharacterList()
  end
end)

--- Receive spawn options
RegisterNetEvent('core_session:receiveSpawnOptions', function(options)
  spawnOptions = options or {}
  if #spawnOptions == 0 then
    TriggerServerEvent('core_session:spawnReady', 'default')
    return
  end
  SetNuiFocus(true, true)
  isUiVisible = true
  SendNUIMessage({ action = 'showSpawnSelect', options = spawnOptions })
end)

--- NUI callbacks
RegisterNUICallback('selectCharacter', function(data, cb)
  local cid = data and data.citizenid
  if not cid then cb({ ok = false }) return end
  TriggerServerEvent('core_session:selectCharacter', cid)
  cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
  local slot = data and data.slot
  local charData = data and data.charData
  if not slot then cb({ ok = false }) return end
  TriggerServerEvent('core_session:createCharacter', slot, charData)
  cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
  local slot = data and data.slot
  if not slot then cb({ ok = false }) return end
  TriggerServerEvent('core_session:deleteCharacter', slot)
  cb({ ok = true })
end)

RegisterNUICallback('selectSpawn', function(data, cb)
  local optionId = data and data.optionId
  if not optionId then optionId = spawnOptions and spawnOptions[1] and spawnOptions[1].id end
  HideUI()
  TriggerServerEvent('core_session:spawnReady', optionId or 'default')
  cb({ ok = true })
end)

RegisterNUICallback('closeUI', function(_, cb)
  -- Only allow close if not in critical flow
  cb({ ok = true })
end)

-- On player spawn (first spawn after connect)
CreateThread(function()
  -- Wait for game to be loaded
  while not NetworkIsPlayerActive(PlayerId()) do
    Wait(100)
  end
  Wait(1000)
  -- Freeze player until they select character
  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)
  SetEntityVisible(ped, false, false)
  SetEntityCoords(ped, -1037.0, -2737.0, 20.17, false, false, false, false)
  RequestCharacterList()
end)

-- Position update for last location (every 30 seconds when loaded)
CreateThread(function()
  while true do
    Wait(30000)
    if selectedCitizenid and not isUiVisible then
      local ped = PlayerPedId()
      if DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        TriggerServerEvent('core_session:updatePosition', coords.x, coords.y, coords.z, heading)
      end
    end
  end
end)

-- Export for other resources
exports('IsCharacterSelected', function()
  return selectedCitizenid ~= nil
end)
