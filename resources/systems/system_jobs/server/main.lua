-- System Jobs Main
SystemJobs = SystemJobs or {}

-- Initialize job for new character
local function InitializeJob(citizenid)
    local existing = MySQL.scalar.await('SELECT citizenid FROM character_jobs WHERE citizenid = ?', {citizenid})
    
    if not existing then
        local startingJob = exports.core_boot:GetConfig('characters.starting_job') or {
            name = 'unemployed',
            grade = 0
        }
        
        MySQL.insert.await([[
            INSERT INTO character_jobs (citizenid, job_name, grade, duty)
            VALUES (?, ?, ?, ?)
        ]], {
            citizenid,
            startingJob.name,
            startingJob.grade,
            0
        })
        
        print(string.format('[^2SYSTEM_JOBS^7] Initialized job for character: %s', citizenid))
    end
end

-- Get job
function SystemJobs.GetJob(citizenid)
    local job = MySQL.single.await('SELECT job_name, grade, duty FROM character_jobs WHERE citizenid = ?', {citizenid})
    
    if not job then
        InitializeJob(citizenid)
        job = MySQL.single.await('SELECT job_name, grade, duty FROM character_jobs WHERE citizenid = ?', {citizenid})
    end
    
    if job then
        local jobDef = GetJobDefinition(job.job_name)
        local gradeInfo = GetGradeInfo(job.job_name, job.grade)
        
        return {
            name = job.job_name,
            label = jobDef and jobDef.label or job.job_name,
            grade = job.grade,
            grade_label = gradeInfo and gradeInfo.label or 'Unknown',
            salary = gradeInfo and gradeInfo.salary or 0,
            permissions = gradeInfo and gradeInfo.permissions or {},
            duty = job.duty == 1
        }
    end
    
    return {
        name = 'unemployed',
        label = 'Unemployed',
        grade = 0,
        grade_label = 'Unemployed',
        salary = 0,
        permissions = {},
        duty = false
    }
end

-- Set job
function SystemJobs.SetJob(citizenid, jobName, grade)
    if not citizenid or not jobName then
        return false, "Invalid parameters"
    end
    
    local jobDef = GetJobDefinition(jobName)
    if not jobDef then
        return false, "Job does not exist"
    end
    
    grade = grade or 0
    
    local gradeInfo = GetGradeInfo(jobName, grade)
    if not gradeInfo then
        return false, "Invalid grade"
    end
    
    MySQL.update('UPDATE character_jobs SET job_name = ?, grade = ? WHERE citizenid = ?', {
        jobName,
        grade,
        citizenid
    })
    
    -- Notify player if online
    local src = SystemJobs.GetPlayerByCitizenId(citizenid)
    if src then
        local job = SystemJobs.GetJob(citizenid)
        TriggerClientEvent('system_jobs:updateJob', src, job)
    end
    
    print(string.format('[^2SYSTEM_JOBS^7] Set job for %s: %s (grade %d)', citizenid, jobName, grade))
    
    return true, "Job set"
end

-- Set duty
function SystemJobs.SetDuty(citizenid, onDuty)
    if not citizenid then
        return false, "Invalid parameters"
    end
    
    MySQL.update('UPDATE character_jobs SET duty = ? WHERE citizenid = ?', {
        onDuty and 1 or 0,
        citizenid
    })
    
    -- Notify player if online
    local src = SystemJobs.GetPlayerByCitizenId(citizenid)
    if src then
        local job = SystemJobs.GetJob(citizenid)
        TriggerClientEvent('system_jobs:updateJob', src, job)
    end
    
    return true, "Duty status updated"
end

-- Toggle duty
function SystemJobs.ToggleDuty(citizenid)
    local job = SystemJobs.GetJob(citizenid)
    return SystemJobs.SetDuty(citizenid, not job.duty)
end

-- Check permission
function SystemJobs.HasPermission(citizenid, permission)
    local job = SystemJobs.GetJob(citizenid)
    
    if not job or not job.permissions then
        return false
    end
    
    for _, perm in ipairs(job.permissions) do
        if perm == permission then
            return true
        end
    end
    
    return false
end

-- Get online players with job
function SystemJobs.GetOnlinePlayersWithJob(jobName)
    local players = GetPlayers()
    local result = {}
    
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        if GetResourceState('core_session') == 'started' then
            local citizenid = exports.core_session:GetCitizenId(src)
            if citizenid then
                local job = SystemJobs.GetJob(citizenid)
                if job.name == jobName then
                    table.insert(result, {
                        source = src,
                        citizenid = citizenid,
                        job = job
                    })
                end
            end
        end
    end
    
    return result
end

-- Get online players on duty
function SystemJobs.GetOnlinePlayersOnDuty(jobName)
    local players = SystemJobs.GetOnlinePlayersWithJob(jobName)
    local result = {}
    
    for _, player in ipairs(players) do
        if player.job.duty then
            table.insert(result, player)
        end
    end
    
    return result
end

-- Helper to get player source by citizenid
function SystemJobs.GetPlayerByCitizenId(citizenid)
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        if GetResourceState('core_session') == 'started' then
            local playerCitizenId = exports.core_session:GetCitizenId(src)
            if playerCitizenId == citizenid then
                return src
            end
        end
    end
    
    return nil
end

-- Listen to character creation
AddEventHandler('core_characters:created', function(citizenid, accountId)
    InitializeJob(citizenid)
end)

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM character_jobs WHERE citizenid = ?', {citizenid})
    print(string.format('[^2SYSTEM_JOBS^7] Cleaned up job for character: %s', citizenid))
end)

-- Callbacks
lib.callback.register('system_jobs:getJob', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return nil
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return nil
    end
    
    return SystemJobs.GetJob(citizenid)
end)

lib.callback.register('system_jobs:toggleDuty', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {success = false, message = "Session not ready"}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {success = false, message = "Not logged in"}
    end
    
    local success, message = SystemJobs.ToggleDuty(citizenid)
    local job = SystemJobs.GetJob(citizenid)
    
    return {success = success, message = message, duty = job.duty}
end)

-- Exports
exports('GetJob', SystemJobs.GetJob)
exports('SetJob', SystemJobs.SetJob)
exports('SetDuty', SystemJobs.SetDuty)
exports('ToggleDuty', SystemJobs.ToggleDuty)
exports('HasPermission', SystemJobs.HasPermission)
exports('GetOnlinePlayersWithJob', SystemJobs.GetOnlinePlayersWithJob)
exports('GetOnlinePlayersOnDuty', SystemJobs.GetOnlinePlayersOnDuty)

-- Admin command
RegisterCommand('setjob', function(source, args)
    if source > 0 then
        local hasPermission = IsPlayerAceAllowed(source, 'command.setjob')
        if not hasPermission then
            return
        end
    end
    
    if #args < 3 then
        print('Usage: setjob <player_id> <job_name> <grade>')
        return
    end
    
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3])
    
    if GetResourceState('core_session') ~= 'started' then
        print('core_session not started')
        return
    end
    
    local citizenid = exports.core_session:GetCitizenId(targetId)
    if citizenid then
        local success, message = SystemJobs.SetJob(citizenid, jobName, grade)
        if success then
            print(string.format('Set job for player %d: %s (grade %d)', targetId, jobName, grade))
        else
            print('Failed to set job: ' .. message)
        end
    else
        print('Player not found')
    end
end, true)

-- Sync job definitions to database on resource start
CreateThread(function()
    -- Wait for boot
    if GetResourceState('core_boot') ~= 'started' then
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:WaitForBoot(function()
        Wait(2000) -- Wait for migrations
        
        -- Sync jobs
        for jobName, jobData in pairs(Jobs) do
            local existing = MySQL.scalar.await('SELECT job_name FROM job_defs WHERE job_name = ?', {jobName})
            
            if not existing then
                MySQL.insert('INSERT INTO job_defs (job_name, label, default_duty, grades_json) VALUES (?, ?, ?, ?)', {
                    jobName,
                    jobData.label,
                    jobData.default_duty and 1 or 0,
                    json.encode(jobData.grades)
                })
            end
        end
        
        print('[^2SYSTEM_JOBS^7] Job definitions synced to database')
    end)
end)

print('[^2SYSTEM_JOBS^7] Initialized')
