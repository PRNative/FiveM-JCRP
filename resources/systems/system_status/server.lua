--[[
  system_status - P1
  Hunger/thirst/stress, tick-based decay
  Exports: GetStatus, SetStatus, ApplyDecay
]]

local StatusMigrations = {
  { version = 'system_status_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_status.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), StatusMigrations)
  if not ok then
    print('^1[system_status] Migrations failed^0')
    return
  end
  print('^2[system_status] Ready^0')
end)

--- Get status
---@param citizenid string
---@return table { hunger, thirst, stress }
function GetStatus(citizenid)
  if not citizenid then return { hunger = 100, thirst = 100, stress = 0 } end
  local row = MySQL.single.await('SELECT hunger, thirst, stress FROM character_status WHERE citizenid = ?', { citizenid })
  if not row then
    MySQL.insert.await('INSERT IGNORE INTO character_status (citizenid) VALUES (?)', { citizenid })
    return { hunger = 100, thirst = 100, stress = 0 }
  end
  return { hunger = row.hunger or 100, thirst = row.thirst or 100, stress = row.stress or 0 }
end

--- Set partial status
---@param citizenid string
---@param partial table { hunger?, thirst?, stress? }
function SetStatus(citizenid, partial)
  if not citizenid or not partial then return end
  local current = GetStatus(citizenid)
  local hunger = partial.hunger ~= nil and math.max(0, math.min(100, tonumber(partial.hunger) or current.hunger)) or current.hunger
  local thirst = partial.thirst ~= nil and math.max(0, math.min(100, tonumber(partial.thirst) or current.thirst)) or current.thirst
  local stress = partial.stress ~= nil and math.max(0, math.min(100, tonumber(partial.stress) or current.stress)) or current.stress
  MySQL.insert.await([[
    INSERT INTO character_status (citizenid, hunger, thirst, stress) VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE hunger = VALUES(hunger), thirst = VALUES(thirst), stress = VALUES(stress)
  ]], { citizenid, hunger, thirst, stress })
end

--- Apply decay (call periodically, e.g. every 60s)
---@param citizenid string
---@param amounts table|nil { hunger = -1, thirst = -1, stress = 0 } defaults
function ApplyDecay(citizenid, amounts)
  if not citizenid then return end
  amounts = amounts or { hunger = -1, thirst = -1, stress = 0 }
  local s = GetStatus(citizenid)
  SetStatus(citizenid, {
    hunger = math.max(0, s.hunger + (amounts.hunger or 0)),
    thirst = math.max(0, s.thirst + (amounts.thirst or 0)),
    stress = math.max(0, math.min(100, s.stress + (amounts.stress or 0))),
  })
end

RegisterNetEvent('system_status:applyDecay', function()
  local src = source
  local citizenid = exports.core_session:GetCitizenId(src)
  if citizenid then
    ApplyDecay(citizenid, { hunger = -1, thirst = -1, stress = 0 })
  end
end)

exports('GetStatus', GetStatus)
exports('SetStatus', SetStatus)
exports('ApplyDecay', ApplyDecay)
