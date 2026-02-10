-- ============================================================
-- system_jobs: Client
-- Receives job updates, duty toggles, paycheck notifications
-- ============================================================

local currentJob = nil

--- Receive job update from server
RegisterNetEvent('jcrp:jobs:update', function(job)
    if type(job) ~= 'table' then return end
    currentJob = job
    TriggerEvent('jcrp:hud:updateJob', currentJob)
end)

--- Duty status update
RegisterNetEvent('jcrp:jobs:dutyUpdate', function(onDuty)
    if currentJob then
        currentJob.duty = onDuty
        TriggerEvent('jcrp:hud:updateJob', currentJob)
    end
end)

--- Paycheck notification
RegisterNetEvent('jcrp:jobs:paycheck', function(amount, jobLabel)
    -- Show notification (simple for now)
    TriggerEvent('jcrp:notification', ('Paycheck received: $%s (%s)'):format(
        tostring(amount), jobLabel
    ), 'success')
end)

exports('GetCurrentJob', function() return currentJob end)
