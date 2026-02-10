--[[
  core_state - P0 Platform Foundation
  Responsibilities:
  - Owns generic per-character persistent state
  - get/set metadata and position persistence
  - Dirty state tracking + flush on drop

  DB: character_state
  Exports: GetState, SetState, MarkDirty, FlushState
]]

local StateMigrations = {
  { version = 'core_state_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_character_state.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), StateMigrations)
  if not ok then
    print('^1[core_state] Migrations failed^0')
    return
  end
  print('^2[core_state] Ready^0')
end)

local dirtyCache = {} -- citizenid -> { keys }

--- Get full state for character
---@param citizenid string
---@return table
function GetState(citizenid)
  if not citizenid then return {} end
  local row = MySQL.single.await(
    'SELECT position_json, heading, health, armor, metadata_json, updated_at FROM character_state WHERE citizenid = ?',
    { citizenid }
  )
  if not row then
    return {
      position_json = nil,
      heading = 0.0,
      health = 200,
      armor = 0,
      metadata_json = nil,
      updated_at = nil,
    }
  end
  return {
    position_json = row.position_json,
    heading = row.heading or 0.0,
    health = row.health or 200,
    armor = row.armor or 0,
    metadata_json = row.metadata_json,
    updated_at = row.updated_at,
  }
end

--- Set partial state (merge)
---@param citizenid string
---@param partialState table { position_json?, heading?, health?, armor?, metadata_json? }
---@return boolean ok
function SetState(citizenid, partialState)
  if not citizenid or not partialState then return false end

  local current = GetState(citizenid)
  local position_json = partialState.position_json ~= nil and partialState.position_json or current.position_json
  local heading = partialState.heading ~= nil and partialState.heading or current.heading
  local health = partialState.health ~= nil and partialState.health or current.health
  local armor = partialState.armor ~= nil and partialState.armor or current.armor
  local metadata_json = partialState.metadata_json ~= nil and partialState.metadata_json or current.metadata_json

  if type(position_json) == 'table' then position_json = json.encode(position_json) end
  if type(metadata_json) == 'table' then metadata_json = json.encode(metadata_json) end

  MySQL.insert.await([[
    INSERT INTO character_state (citizenid, position_json, heading, health, armor, metadata_json)
    VALUES (?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      position_json = VALUES(position_json),
      heading = VALUES(heading),
      health = VALUES(health),
      armor = VALUES(armor),
      metadata_json = VALUES(metadata_json),
      updated_at = CURRENT_TIMESTAMP
  ]], { citizenid, position_json, heading, health, armor, metadata_json })
  return true
end

--- Mark state as dirty for flush
---@param citizenid string
---@param key string
function MarkDirty(citizenid, key)
  if not citizenid then return end
  dirtyCache[citizenid] = dirtyCache[citizenid] or {}
  dirtyCache[citizenid][key] = true
end

--- Flush state to DB (called on drop)
---@param citizenid string
---@param stateSnapshot table|nil If provided, use this instead of fetching
function FlushState(citizenid, stateSnapshot)
  if not citizenid then return end
  if stateSnapshot then
    SetState(citizenid, stateSnapshot)
  end
  dirtyCache[citizenid] = nil
end

exports('GetState', GetState)
exports('SetState', SetState)
exports('MarkDirty', MarkDirty)
exports('FlushState', FlushState)
