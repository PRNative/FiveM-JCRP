--[[
  core_characters - P0 Platform Foundation
  Responsibilities:
  - 3-slot character system (create, list, delete, select)
  - Character identity storage and base state
  - Hydration pipeline: returns full character payload

  DB: characters
  Exports: ListCharacters, CreateCharacter, DeleteCharacter, LoadCharacter, UpdateLastPlayed
]]

local IdentityMigrations = {
  { version = 'core_characters_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_characters.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), IdentityMigrations)
  if not ok then
    print('^1[core_characters] Migrations failed^0')
    return
  end
  print('^2[core_characters] Ready^0')
end)

local MAX_SLOTS = 3

--- Generate unique citizenid
---@return string
local function GenerateCitizenId()
  local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
  local id = ''
  for _ = 1, 7 do
    id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
  end
  local exists = MySQL.single.await('SELECT 1 FROM characters WHERE citizenid = ?', { id })
  if exists then return GenerateCitizenId() end
  return id
end

--- List characters for account
---@param account_id number
---@return table
function ListCharacters(account_id)
  local rows = MySQL.query.await(
    'SELECT id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json, created_at, last_played FROM characters WHERE account_id = ? ORDER BY slot ASC',
    { account_id }
  ) or {}
  return rows
end

--- Create character
---@param account_id number
---@param slot number 1-3
---@param charData table { firstname, lastname, dob?, gender?, model?, skin_json? }
---@return string|nil citizenid
function CreateCharacter(account_id, slot, charData)
  if type(slot) ~= 'number' or slot < 1 or slot > MAX_SLOTS then
    return nil
  end

  local firstname = charData.firstname and tostring(charData.firstname):sub(1, 64) or 'Unknown'
  local lastname = charData.lastname and tostring(charData.lastname):sub(1, 64) or 'Unknown'
  local dob = charData.dob or nil
  local gender = tonumber(charData.gender) or 0
  local model = charData.model and tostring(charData.model):sub(1, 64) or 'mp_m_freemode_01'
  local skin_json = charData.skin_json
  if type(skin_json) == 'table' then
    skin_json = json.encode(skin_json)
  elseif type(skin_json) ~= 'string' then
    skin_json = nil
  end

  local existing = MySQL.single.await('SELECT 1 FROM characters WHERE account_id = ? AND slot = ?', { account_id, slot })
  if existing then return nil end

  local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE account_id = ?', { account_id }) or 0
  if count >= MAX_SLOTS then return nil end

  local citizenid = GenerateCitizenId()
  MySQL.insert.await(
    'INSERT INTO characters (account_id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    { account_id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json }
  )
  return citizenid
end

--- Delete character
---@param account_id number
---@param slot number
---@return boolean ok
function DeleteCharacter(account_id, slot)
  if type(slot) ~= 'number' or slot < 1 or slot > MAX_SLOTS then return false end
  local result = MySQL.update.await('DELETE FROM characters WHERE account_id = ? AND slot = ?', { account_id, slot })
  return result and result > 0
end

--- Load character payload (identity + metadata)
---@param citizenid string
---@return table|nil
function LoadCharacter(citizenid)
  if not citizenid or type(citizenid) ~= 'string' then return nil end
  local row = MySQL.single.await(
    'SELECT id, account_id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json, created_at, last_played FROM characters WHERE citizenid = ?',
    { citizenid }
  )
  if not row then return nil end
  return {
    id = row.id,
    account_id = row.account_id,
    slot = row.slot,
    citizenid = row.citizenid,
    firstname = row.firstname,
    lastname = row.lastname,
    dob = row.dob,
    gender = row.gender,
    model = row.model,
    skin_json = row.skin_json,
    created_at = row.created_at,
    last_played = row.last_played,
  }
end

--- Update last played timestamp
---@param citizenid string
function UpdateLastPlayed(citizenid)
  if not citizenid then return end
  MySQL.update.await('UPDATE characters SET last_played = CURRENT_TIMESTAMP WHERE citizenid = ?', { citizenid })
end

exports('ListCharacters', ListCharacters)
exports('CreateCharacter', CreateCharacter)
exports('DeleteCharacter', DeleteCharacter)
exports('LoadCharacter', LoadCharacter)
exports('UpdateLastPlayed', UpdateLastPlayed)
