--[[
  ui_hud - P1 Server
  Pushes snapshot to clients when they have a session
]]

--- Push full snapshot to client
---@param src number
local function PushSnapshot(src)
  local citizenid = exports.core_session:GetCitizenId(src)
  if not citizenid then return end
  local balances = exports.system_money and exports.system_money:GetBalances(citizenid) or { cash = 0, bank = 0 }
  local job = exports.system_jobs and exports.system_jobs:GetJob(citizenid) or { job_name = 'unemployed' }
  local status = exports.system_status and exports.system_status:GetStatus(citizenid) or { hunger = 100, thirst = 100, stress = 0 }
  TriggerClientEvent('ui_hud:moneyUpdate', src, balances.cash, balances.bank)
  TriggerClientEvent('ui_hud:jobUpdate', src, job.job_name or 'Unemployed')
  TriggerClientEvent('ui_hud:statusUpdate', src, status.hunger, status.thirst, status.stress)
end

--- When player spawns, push initial snapshot
RegisterNetEvent('core_spawn:doSpawn', function()
  -- This fires on client; we need server-side spawn completion
  -- Use player spawned event instead
end)

--- On session start (player selected character), push snapshot
AddEventHandler('core_session:sessionStarted', function(src)
  -- Custom event we can add to core_session
  PushSnapshot(src)
end)

--- Fallback: push on spawn event from core_spawn
-- We'll have the client request snapshot when HUD shows
-- Simpler: have client request snapshot on show
RegisterNetEvent('ui_hud:requestSnapshot', function()
  local src = source
  PushSnapshot(src)
end)
