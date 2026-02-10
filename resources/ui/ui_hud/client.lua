--[[
  ui_hud - P1
  HUD reads from server snapshot, does NOT own truth
  Subscribes to OnMoneyUpdate, OnJobUpdate, OnStateUpdate
]]

local streetNames = {}
local lastStreet = nil

--- Format street name
local function GetStreetName()
  local coords = GetEntityCoords(PlayerPedId())
  local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
  local street = GetStreetNameFromHashKey(streetHash)
  local crossing = GetStreetNameFromHashKey(crossingHash)
  if crossing and crossing ~= '' then
    return street .. ' / ' .. crossing
  end
  return street or 'Unknown'
end

--- Update street periodically
CreateThread(function()
  while true do
    Wait(2000)
    local street = GetStreetName()
    if street ~= lastStreet then
      lastStreet = street
      SendNUIMessage({ action = 'update', street = street })
    end
  end
end)

--- Money update from server
RegisterNetEvent('ui_hud:moneyUpdate', function(cash, bank)
  SendNUIMessage({ action = 'update', cash = cash, bank = bank })
end)

--- Job update from server
RegisterNetEvent('ui_hud:jobUpdate', function(job)
  SendNUIMessage({ action = 'update', job = job })
end)

--- Status update from server
RegisterNetEvent('ui_hud:statusUpdate', function(hunger, thirst, stress)
  SendNUIMessage({ action = 'update', hunger = hunger, thirst = thirst, stress = stress })
end)

--- Show HUD when character selected
local function ShowHud()
  SendNUIMessage({ action = 'show' })
  TriggerServerEvent('ui_hud:requestSnapshot')
end

RegisterNetEvent('core_session:selectResult', function(success)
  if success then ShowHud() end
end)

RegisterNetEvent('core_session:createResult', function(citizenid)
  if citizenid then ShowHud() end
end)
