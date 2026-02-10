--[[
  core_spawn - P0 Platform Foundation
  Responsibilities:
  - Spawn selection: last location, predefined spawns, new character default
  - Writes last location to character_state

  Uses: character_state.position_json
  Exports: GetSpawnOptions, SetLastPosition, SpawnPlayer
]]

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  print('^2[core_spawn] Ready^0')
end)

--- Get spawn options for character
---@param citizenid string
---@param isNewCharacter boolean
---@return table options
function GetSpawnOptions(citizenid, isNewCharacter)
  local config = exports.core_boot:GetConfig()
  local serverCfg = config.server or {}
  local locations = serverCfg.spawnLocations or {}
  local defaultSpawn = serverCfg.defaultSpawn or { x = -1037.0, y = -2737.0, z = 20.17, heading = 0.0 }

  local options = {}

  if not isNewCharacter then
    local state = exports.core_state:GetState(citizenid)
    local pos = state.position_json
    if pos and (type(pos) == 'table' and (pos.x or pos[1])) then
      local x = pos.x or pos[1] or 0
      local y = pos.y or pos[2] or 0
      local z = pos.z or pos[3] or 20.0
      local heading = state.heading or 0
      options[#options + 1] = {
        id = 'last',
        label = 'Last Location',
        coords = { x = x, y = y, z = z, heading = heading },
      }
    end
  end

  for _, loc in ipairs(locations) do
    options[#options + 1] = {
      id = loc.id or ('spawn_' .. #options),
      label = loc.label or 'Spawn',
      coords = loc.coords or defaultSpawn,
    }
  end

  if #options == 0 then
    options[#options + 1] = {
      id = 'default',
      label = 'Default Spawn',
      coords = defaultSpawn,
    }
  end

  return options
end

--- Set last position for character
---@param citizenid string
---@param coords table { x, y, z, heading? }
function SetLastPosition(citizenid, coords)
  if not citizenid or not coords then return end
  exports.core_state:SetState(citizenid, {
    position_json = coords,
    heading = coords.heading or 0.0,
  })
end

--- Resolve spawn coords for option
---@param option table
---@return vector4
local function GetSpawnCoords(option)
  local c = option.coords
  if not c then return vector4(-1037.0, -2737.0, 20.17, 0.0) end
  return vector4(
    tonumber(c.x) or c[1] or -1037.0,
    tonumber(c.y) or c[2] or -2737.0,
    tonumber(c.z) or c[3] or 20.17,
    tonumber(c.heading) or c[4] or 0.0
  )
end

--- SpawnPlayer: triggers client spawn
---@param src number
---@param option table spawn option from GetSpawnOptions
function SpawnPlayer(src, option)
  if not src or not option then return end
  local coords = GetSpawnCoords(option)
  TriggerClientEvent('core_spawn:doSpawn', src, coords)
end

exports('GetSpawnOptions', GetSpawnOptions)
exports('SetLastPosition', SetLastPosition)
exports('SpawnPlayer', SpawnPlayer)
