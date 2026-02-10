-- ============================================================
-- system_jobs: Job System (Server)
-- Assignment, grades, duty, paychecks
-- ============================================================

-- Cache: citizenid -> job data
local JobCache = {}

-- Job definitions cache
local JobDefs = {}

--- Load job definitions from DB
local function LoadJobDefs()
    local rows = MySQL.query.await('SELECT * FROM job_defs')
    if not rows then return end

    JobDefs = {}
    for _, row in ipairs(rows) do
        JobDefs[row.job_name] = {
            name = row.job_name,
            label = row.label,
            category = row.category,
            grades = JCRP.JsonDecode(row.grades_json, {}),
            permissions = JCRP.JsonDecode(row.permissions_json, {}),
        }
    end

    JCRP.Log('system_jobs', 'INFO', ('Loaded %d job definitions.'):format(#rows))
end

--- Get a grade's data from a job definition
---@param jobName string
---@param grade number
---@return table|nil
local function GetGradeData(jobName, grade)
    local def = JobDefs[jobName]
    if not def then return nil end

    for _, g in ipairs(def.grades) do
        if g.grade == grade then
            return g
        end
    end
    return nil
end

--- Initialize job for a new character
---@param citizenid string
---@return boolean
local function InitJob(citizenid)
    local config = exports['core_boot']:GetConfig()
    local defaultJob = config.jobs and config.jobs.default_job or 'unemployed'
    local defaultGrade = config.jobs and config.jobs.default_grade or 0

    MySQL.insert.await([[
        INSERT INTO character_jobs (citizenid, job_name, grade, duty)
        VALUES (?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE updated_at = NOW()
    ]], { citizenid, defaultJob, defaultGrade })

    local gradeData = GetGradeData(defaultJob, defaultGrade) or {}
    JobCache[citizenid] = {
        name = defaultJob,
        label = JobDefs[defaultJob] and JobDefs[defaultJob].label or 'Unemployed',
        grade = defaultGrade,
        grade_label = gradeData.label or 'None',
        salary = gradeData.salary or 0,
        duty = false,
        permissions = gradeData.permissions or {},
    }

    return true
end

--- Get job data for a character
---@param citizenid string
---@return table
local function GetJob(citizenid)
    if JobCache[citizenid] then
        return JobCache[citizenid]
    end

    local row = MySQL.single.await(
        'SELECT * FROM character_jobs WHERE citizenid = ?',
        { citizenid }
    )

    if not row then
        InitJob(citizenid)
        return JobCache[citizenid]
    end

    local def = JobDefs[row.job_name]
    local gradeData = GetGradeData(row.job_name, row.grade) or {}

    local job = {
        name = row.job_name,
        label = def and def.label or row.job_name,
        grade = row.grade,
        grade_label = gradeData.label or 'Grade ' .. row.grade,
        salary = gradeData.salary or 0,
        duty = row.duty == 1,
        permissions = gradeData.permissions or {},
    }

    JobCache[citizenid] = job
    return job
end

--- Set job for a character
---@param citizenid string
---@param jobName string
---@param grade number
---@return boolean success
---@return string|nil error
local function SetJob(citizenid, jobName, grade)
    if not citizenid or not jobName then
        return false, 'Missing parameters'
    end

    local def = JobDefs[jobName]
    if not def then
        return false, 'Unknown job: ' .. tostring(jobName)
    end

    grade = tonumber(grade) or 0
    local gradeData = GetGradeData(jobName, grade)
    if not gradeData then
        return false, ('Invalid grade %d for job %s'):format(grade, jobName)
    end

    MySQL.update.await(
        'UPDATE character_jobs SET job_name = ?, grade = ?, duty = 0, updated_at = NOW() WHERE citizenid = ?',
        { jobName, grade, citizenid }
    )

    -- If no row was updated, insert
    MySQL.insert.await([[
        INSERT INTO character_jobs (citizenid, job_name, grade, duty)
        VALUES (?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE job_name = VALUES(job_name), grade = VALUES(grade), duty = 0, updated_at = NOW()
    ]], { citizenid, jobName, grade })

    local job = {
        name = jobName,
        label = def.label,
        grade = grade,
        grade_label = gradeData.label,
        salary = gradeData.salary or 0,
        duty = false,
        permissions = gradeData.permissions or {},
    }

    JobCache[citizenid] = job

    -- Notify client
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:jobs:update', src, job)
    end

    JCRP.Log('system_jobs', 'INFO', ('Set job for %s: %s grade %d'):format(citizenid, jobName, grade))
    return true, nil
end

--- Set duty status
---@param citizenid string
---@param onDuty boolean
---@return boolean
local function SetDuty(citizenid, onDuty)
    local job = GetJob(citizenid)
    if not job then return false end

    job.duty = onDuty and true or false
    JobCache[citizenid] = job

    MySQL.update('UPDATE character_jobs SET duty = ? WHERE citizenid = ?', {
        onDuty and 1 or 0, citizenid
    })

    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:jobs:dutyUpdate', src, job.duty)
    end

    return true
end

--- Check if a character has a specific job permission
---@param citizenid string
---@param permission string
---@return boolean
local function HasJobPermission(citizenid, permission)
    local job = GetJob(citizenid)
    if not job or not job.permissions then return false end

    for _, perm in ipairs(job.permissions) do
        if perm == permission then
            return true
        end
    end
    return false
end

--- Get all job definitions
---@return table
local function GetAllJobs()
    return JobDefs
end

--- Unload job from cache
---@param citizenid string
local function UnloadJob(citizenid)
    JobCache[citizenid] = nil
end

-- ============================================================
-- Paycheck system (periodic)
-- ============================================================
CreateThread(function()
    Wait(1000)
    LoadJobDefs()

    local config = exports['core_boot']:GetConfig()
    local paycheckInterval = (config.jobs and config.jobs.paycheck_interval_minutes or 30) * 60000

    while true do
        Wait(paycheckInterval)

        -- Issue paychecks to all online players on duty
        for citizenid, job in pairs(JobCache) do
            if job.duty and job.salary and job.salary > 0 then
                local ok, err = pcall(function()
                    exports['system_money']:AddMoney(citizenid, 'bank', job.salary, 'Paycheck: ' .. job.label, 'PAYCHECK')
                end)
                if ok then
                    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
                    if src then
                        TriggerClientEvent('jcrp:jobs:paycheck', src, job.salary, job.label)
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- Server Events
-- ============================================================

--- Toggle duty
RegisterNetEvent('jcrp:jobs:toggleDuty', function()
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    local job = GetJob(citizenid)
    if not job or job.name == 'unemployed' then return end

    SetDuty(citizenid, not job.duty)
end)

-- ============================================================
-- Exports
-- ============================================================
exports('InitJob', InitJob)
exports('GetJob', GetJob)
exports('SetJob', SetJob)
exports('SetDuty', SetDuty)
exports('HasJobPermission', HasJobPermission)
exports('GetAllJobs', GetAllJobs)
exports('UnloadJob', UnloadJob)

JCRP.Log('system_jobs', 'INFO', 'system_jobs loaded.')
