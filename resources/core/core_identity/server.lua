--[[
  core_identity - P0 Platform Foundation
  Responsibilities:
  - Resolve account from player identifiers (license, discord optional)
  - Enforce bans/flags at deferrals
  - Track last_seen
  - Provide account audit logging

  DB: accounts, account_audit
  Exports: ResolveAccount(src), IsBanned(account_id), Audit(account_id, event, payload)
]]

local IdentityMigrations = {
  { version = 'core_identity_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_identity.sql') },
}

--- Run migrations on start
CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), IdentityMigrations)
  if not ok then
    print('^1[core_identity] Migrations failed^0')
    return
  end
  print('^2[core_identity] Ready^0')
end)

--- Get license from player identifiers
---@param src number
---@return string|nil
local function GetLicense(src)
  local ids = GetPlayerIdentifiers(src)
  if not ids then return nil end
  for _, id in ipairs(ids) do
    if id:sub(1, 8) == 'license:' then
      return id
    end
  end
  return nil
end

--- Get discord from player identifiers
---@param src number
---@return string|nil
local function GetDiscord(src)
  local ids = GetPlayerIdentifiers(src)
  if not ids then return nil end
  for _, id in ipairs(ids) do
    if id:sub(1, 8) == 'discord:' then
      return id:sub(9)
    end
  end
  return nil
end

--- Resolve or create account from source
---@param src number
---@return number|nil account_id
function ResolveAccount(src)
  local license = GetLicense(src)
  if not license then
    print('^1[core_identity] No license for source ' .. tostring(src) .. '^0')
    return nil
  end

  local row = MySQL.single.await('SELECT id FROM accounts WHERE license = ?', { license })
  if row then
    -- Update last_seen
    MySQL.update.await('UPDATE accounts SET last_seen = CURRENT_TIMESTAMP WHERE id = ?', { row.id })
    return row.id
  end

  local discord = GetDiscord(src)
  local insertId = MySQL.insert.await(
    'INSERT INTO accounts (license, discord) VALUES (?, ?)',
    { license, discord or nil }
  )
  return insertId
end

--- Check if account is banned
---@param account_id number
---@return boolean banned, string|nil reason
function IsBanned(account_id)
  local row = MySQL.single.await('SELECT banned, ban_reason FROM accounts WHERE id = ?', { account_id })
  if not row then return false, nil end
  return row.banned == 1, row.ban_reason
end

--- Audit log entry
---@param account_id number
---@param event string
---@param payload table|nil
function Audit(account_id, event, payload)
  local jsonStr = payload and json.encode(payload) or nil
  MySQL.insert.await('INSERT INTO account_audit (account_id, event, payload_json) VALUES (?, ?, ?)', {
    account_id,
    event,
    jsonStr,
  })
end

exports('ResolveAccount', ResolveAccount)
exports('IsBanned', IsBanned)
exports('Audit', Audit)
