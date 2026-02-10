-- System Status Main
SystemStatus = SystemStatus or {}

-- Initialize status for new character
local function InitializeStatus(citizenid)
    local existing = MySQL.scalar.await('SELECT citizenid FROM character_status WHERE citizenid = ?', {citizenid})
    
    if not existing then
        MySQL.insert.await([[
            INSERT INTO character_status (citizenid, hunger, thirst, stress)
            VALUES (?, ?, ?, ?)
        ]], {
            citizenid,
            100,
            100,
            0
        })
        
        print(string.format('[^2SYSTEM_STATUS^7] Initialized status for character: %s', citizenid))
    end
end

-- Get status
function SystemStatus.GetStatus(citizenid)
    local status = MySQL.single.await('SELECT hunger, thirst, stress FROM character_status WHERE citizenid = ?', {citizenid})
    
    if not status then
        InitializeStatus(citizenid)
        status = MySQL.single.await('SELECT hunger, thirst, stress FROM character_status WHERE citizenid = ?', {citizenid})
    end
    
    return status or {hunger = 100, thirst = 100, stress = 0}
end

-- Set status (partial update)
function SystemStatus.SetStatus(citizenid, partial)
    if not citizenid or not partial then
        return false
    end
    
    local updates = {}
    local values = {}
    
    if partial.hunger then
        table.insert(updates, 'hunger = ?')
        table.insert(values, math.max(0, math.min(100, partial.hunger)))
    end
    
    if partial.thirst then
        table.insert(updates, 'thirst = ?')
        table.insert(values, math.max(0, math.min(100, partial.thirst)))
    end
    
    if partial.stress then
        table.insert(updates, 'stress = ?')
        table.insert(values, math.max(0, math.min(100, partial.stress)))
    end
    
    if #updates == 0 then
        return true
    end
    
    table.insert(values, citizenid)
    
    local query = string.format('UPDATE character_status SET %s WHERE citizenid = ?', table.concat(updates, ', '))
    MySQL.update(query, values)
    
    -- Notify player if online
    local src = SystemStatus.GetPlayerByCitizenId(citizenid)
    if src then
        local status = SystemStatus.GetStatus(citizenid)
        TriggerClientEvent('system_status:updateStatus', src, status)
    end
    
    return true
end

-- Modify status (add/subtract)
function SystemStatus.ModifyStatus(citizenid, statusType, amount)
    local status = SystemStatus.GetStatus(citizenid)
    
    if not status[statusType] then
        return false
    end
    
    local newValue = status[statusType] + amount
    
    return SystemStatus.SetStatus(citizenid, {[statusType] = newValue})
end

-- Apply decay
function SystemStatus.ApplyDecay(citizenid)
    local decayRates = exports.core_boot:GetConfig('status.decay_rate') or {
        hunger = 0.1,
        thirst = 0.15,
        stress = 0.05
    }
    
    local status = SystemStatus.GetStatus(citizenid)
    
    -- Decrease hunger and thirst, increase stress slightly
    local newHunger = math.max(0, status.hunger - decayRates.hunger)
    local newThirst = math.max(0, status.thirst - decayRates.thirst)
    local newStress = math.min(100, status.stress + decayRates.stress)
    
    SystemStatus.SetStatus(citizenid, {
        hunger = newHunger,
        thirst = newThirst,
        stress = newStress
    })
    
    -- Check critical levels and apply damage
    if newHunger <= 0 or newThirst <= 0 then
        local src = SystemStatus.GetPlayerByCitizenId(citizenid)
        if src then
            TriggerClientEvent('system_status:takeDamage', src, 5)
        end
    end
    
    return true
end

-- Helper to get player source by citizenid
function SystemStatus.GetPlayerByCitizenId(citizenid)
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
    InitializeStatus(citizenid)
end)

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM character_status WHERE citizenid = ?', {citizenid})
    print(string.format('[^2SYSTEM_STATUS^7] Cleaned up status for character: %s', citizenid))
end)

-- Auto-decay system
CreateThread(function()
    while true do
        local interval = exports.core_boot:GetConfig('status.decay_interval') or 60000
        Wait(interval)
        
        if GetResourceState('core_session') == 'started' then
            local players = GetPlayers()
            
            for _, playerId in ipairs(players) do
                local src = tonumber(playerId)
                local citizenid = exports.core_session:GetCitizenId(src)
                
                if citizenid then
                    SystemStatus.ApplyDecay(citizenid)
                end
            end
        end
    end
end)

-- Callbacks
lib.callback.register('system_status:getStatus', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {hunger = 100, thirst = 100, stress = 0}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {hunger = 100, thirst = 100, stress = 0}
    end
    
    return SystemStatus.GetStatus(citizenid)
end)

-- Exports
exports('GetStatus', SystemStatus.GetStatus)
exports('SetStatus', SystemStatus.SetStatus)
exports('ModifyStatus', SystemStatus.ModifyStatus)
exports('ApplyDecay', SystemStatus.ApplyDecay)

print('[^2SYSTEM_STATUS^7] Initialized')
