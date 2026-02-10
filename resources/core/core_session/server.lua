--[[
  core_session - P0 Platform Foundation
  Responsibilities:
  - End-to-end login: deferrals -> resolve account -> character UI -> select -> hydrate -> spawn
  - In-memory session map (src -> account_id, citizenid)
  - Hydrated player data snapshot
  - Secure callback validation
]]

-- Session store: src -> { account_id, citizenid, playerData }
local Sessions = {}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  print('^2[core_session] Ready^0')
end)

--- PlayerConnecting: deferrals, ban check, account resolve
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
  local src = source
  deferrals.defer()
  Wait(0)
  deferrals.update('Checking identity...')

  while not exports.core_boot:IsReady() do
    Wait(100)
  end

  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then
    deferrals.done('Unable to identify your account. Please ensure your license is valid.')
    return
  end

  local banned, reason = exports.core_identity:IsBanned(accountId)
  if banned then
    deferrals.done(reason or 'You are banned from this server.')
    return
  end

  exports.core_identity:Audit(accountId, 'connect_attempt', { name = name })
  deferrals.done()
end)

--- Get citizenid for source (only when logged in)
---@param src number
---@return string|nil
function GetCitizenId(src)
  local s = Sessions[src]
  return s and s.citizenid or nil
end

--- Get account_id for source
---@param src number
---@return number|nil
function GetAccountId(src)
  local s = Sessions[src]
  if s then return s.account_id end
  return exports.core_identity:ResolveAccount(src)
end

--- Get full hydrated player data
---@param src number
---@return table|nil
function GetPlayerData(src)
  local s = Sessions[src]
  return s and s.playerData or nil
end

--- Hydrate full payload for character
---@param citizenid string
---@return table
local function HydratePlayerData(citizenid)
  local char = exports.core_characters:LoadCharacter(citizenid)
  if not char then return nil end

  local state = exports.core_state:GetState(citizenid)
  local data = {
    citizenid = citizenid,
    char = char,
    state = state,
  }

  if GetResourceState('system_money') == 'started' then
    data.money = exports.system_money:GetBalances(citizenid)
  end
  if GetResourceState('system_inventory') == 'started' then
    data.inventory = exports.system_inventory:GetInventory(citizenid)
  end
  if GetResourceState('system_jobs') == 'started' then
    data.job = exports.system_jobs:GetJob(citizenid)
  end
  if GetResourceState('system_status') == 'started' then
    data.status = exports.system_status:GetStatus(citizenid)
  end

  return data
end

--- Start session for player (called after character select)
---@param src number
---@param citizenid string
local function StartSession(src, citizenid)
  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then return false end

  local char = exports.core_characters:LoadCharacter(citizenid)
  if not char or char.account_id ~= accountId then
    return false
  end

  exports.core_characters:UpdateLastPlayed(citizenid)
  local playerData = HydratePlayerData(citizenid)
  if not playerData then return false end

  Sessions[src] = {
    account_id = accountId,
    citizenid = citizenid,
    playerData = playerData,
  }
  -- Give starter cash if system_money is available
  if GetResourceState('system_money') == 'started' then
    exports.system_money:GiveStarterCash(citizenid, 500)
  end
  TriggerEvent('core_session:sessionStarted', src)
  return true
end

--- End session and flush state
---@param src number
---@param citizenid string|nil if nil, get from session
local function EndSession(src, citizenid)
  citizenid = citizenid or (Sessions[src] and Sessions[src].citizenid)
  if citizenid then
    -- Flush position from client if we have it
    exports.core_state:FlushState(citizenid)
  end
  Sessions[src] = nil
end

RegisterNetEvent('core_session:requestCharacterList', function()
  local src = source
  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then
    TriggerClientEvent('core_session:receiveCharacterList', src, nil, 'identity_failed')
    return
  end

  local chars = exports.core_characters:ListCharacters(accountId)
  local maxSlots = 3
  local config = exports.core_boot:GetConfig()
  if config and config.server then
    maxSlots = config.server.maxCharactersPerAccount or 3
  end
  TriggerClientEvent('core_session:receiveCharacterList', src, chars, nil, maxSlots)
end)

RegisterNetEvent('core_session:selectCharacter', function(citizenid)
  local src = source
  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then return end

  local char = exports.core_characters:LoadCharacter(citizenid)
  if not char or char.account_id ~= accountId then
    TriggerClientEvent('core_session:selectResult', src, false, 'invalid_character')
    return
  end

  if not StartSession(src, citizenid) then
    TriggerClientEvent('core_session:selectResult', src, false, 'hydrate_failed')
    return
  end

  TriggerClientEvent('core_session:selectResult', src, true, citizenid)
end)

RegisterNetEvent('core_session:createCharacter', function(slot, charData)
  local src = source
  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then
    TriggerClientEvent('core_session:createResult', src, nil, 'identity_failed')
    return
  end

  local citizenid = exports.core_characters:CreateCharacter(accountId, slot, charData or {})
  if not citizenid then
    TriggerClientEvent('core_session:createResult', src, nil, 'create_failed')
    return
  end

  if not StartSession(src, citizenid) then
    TriggerClientEvent('core_session:createResult', src, nil, 'hydrate_failed')
    return
  end

  exports.core_identity:Audit(accountId, 'character_created', { citizenid = citizenid, slot = slot })
  TriggerClientEvent('core_session:createResult', src, citizenid, nil)
end)

RegisterNetEvent('core_session:deleteCharacter', function(slot)
  local src = source
  local accountId = exports.core_identity:ResolveAccount(src)
  if not accountId then return end

  local ok = exports.core_characters:DeleteCharacter(accountId, slot)
  if ok then
    TriggerClientEvent('core_session:deleteResult', src, true)
    TriggerClientEvent('core_session:requestCharacterList', src)
  else
    TriggerClientEvent('core_session:deleteResult', src, false)
  end
end)

--- Provide spawn options to client
RegisterNetEvent('core_session:requestSpawnOptions', function(isNewCharacter)
  local src = source
  local citizenid = GetCitizenId(src)
  if not citizenid then return end
  local options = exports.core_spawn:GetSpawnOptions(citizenid, isNewCharacter == true)
  TriggerClientEvent('core_session:receiveSpawnOptions', src, options)
end)

--- Called when player chooses spawn and is ready
RegisterNetEvent('core_session:spawnReady', function(spawnOptionId)
  local src = source
  local citizenid = GetCitizenId(src)
  if not citizenid then return end

  local options = exports.core_spawn:GetSpawnOptions(citizenid, false)
  local chosen
  for _, opt in ipairs(options) do
    if opt.id == spawnOptionId then chosen = opt break end
  end
  if not chosen then chosen = options[1] end

  exports.core_spawn:SpawnPlayer(src, chosen)
end)

--- Client sends position update (for last location persistence)
RegisterNetEvent('core_session:updatePosition', function(x, y, z, heading)
  local src = source
  local citizenid = GetCitizenId(src)
  if not citizenid then return end
  exports.core_spawn:SetLastPosition(citizenid, { x = x, y = y, z = z, heading = heading })
end)

--- Player dropped: flush and clear session
AddEventHandler('playerDropped', function()
  local src = source
  local citizenid = GetCitizenId(src)
  EndSession(src, citizenid)
end)

exports('GetCitizenId', GetCitizenId)
exports('GetAccountId', GetAccountId)
exports('GetPlayerData', GetPlayerData)
exports('HydratePlayerData', HydratePlayerData)
