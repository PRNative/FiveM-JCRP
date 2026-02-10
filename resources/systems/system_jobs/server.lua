--[[
  system_jobs - P1
  Job assignment, grade, duty, permission flags
  Exports: GetJob, SetJob, SetDuty
]]

local JobMigrations = {
  { version = 'system_jobs_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_jobs.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), JobMigrations)
  if not ok then
    print('^1[system_jobs] Migrations failed^0')
    return
  end
  print('^2[system_jobs] Ready^0')
end)

--- Get job for character
---@param citizenid string
---@return table { job_name, grade, duty }
function GetJob(citizenid)
  if not citizenid then return { job_name = 'unemployed', grade = 0, duty = 0 } end
  local row = MySQL.single.await('SELECT job_name, grade, duty FROM character_jobs WHERE citizenid = ?', { citizenid })
  if not row then
    MySQL.insert.await('INSERT IGNORE INTO character_jobs (citizenid) VALUES (?)', { citizenid })
    return { job_name = 'unemployed', grade = 0, duty = 0 }
  end
  return { job_name = row.job_name or 'unemployed', grade = row.grade or 0, duty = row.duty or 0 }
end

--- Set job
---@param citizenid string
---@param job string
---@param grade number
---@return boolean ok
function SetJob(citizenid, job, grade)
  if not citizenid then return false end
  job = job or 'unemployed'
  grade = grade or 0
  MySQL.insert.await([[
    INSERT INTO character_jobs (citizenid, job_name, grade) VALUES (?, ?, ?)
    ON DUPLICATE KEY UPDATE job_name = VALUES(job_name), grade = VALUES(grade)
  ]], { citizenid, job, grade })
  return true
end

--- Set duty
---@param citizenid string
---@param onoff boolean
function SetDuty(citizenid, onoff)
  if not citizenid then return end
  MySQL.update.await('UPDATE character_jobs SET duty = ? WHERE citizenid = ?', { onoff and 1 or 0, citizenid })
  MySQL.insert.await('INSERT IGNORE INTO character_jobs (citizenid, duty) VALUES (?, ?)', { citizenid, onoff and 1 or 0 })
end

exports('GetJob', GetJob)
exports('SetJob', SetJob)
exports('SetDuty', SetDuty)
