-- ============================================================
-- system_status: Hunger/Thirst/Stress (Server)
-- Configurable tick-based decay, persistence
-- ============================================================

-- Cache: citizenid -> {hunger, thirst, stress}
local StatusCache = {}

--- Initialize status for a new character
---@param citizenid string
---@return boolean
local function InitStatus(citizenid)
    local config = exports['core_boot']:GetConfig()
    local defaultHunger = config.status and config.status.default_hunger or 100
    local defaultThirst = config.status and config.status.default_thirst or 100
    local defaultStress = config.status and config.status.default_stress or 0

    MySQL.insert.await([[
        INSERT INTO character_status (citizenid, hunger, thirst, stress)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE updated_at = NOW()
    ]], { citizenid, defaultHunger, defaultThirst, defaultStress })

    StatusCache[citizenid] = {
        hunger = defaultHunger,
        thirst = defaultThirst,
        stress = defaultStress,
    }

    return true
end

--- Load status from DB
---@param citizenid string
---@return table
local function LoadStatus(citizenid)
    if StatusCache[citizenid] then
        return StatusCache[citizenid]
    end

    local row = MySQL.single.await(
        'SELECT hunger, thirst, stress FROM character_status WHERE citizenid = ?',
        { citizenid }
    )

    if not row then
        InitStatus(citizenid)
        return StatusCache[citizenid]
    end

    StatusCache[citizenid] = {
        hunger = row.hunger or 100,
        thirst = row.thirst or 100,
        stress = row.stress or 0,
    }

    return StatusCache[citizenid]
end

--- Get status for a character
---@param citizenid string
---@return table {hunger, thirst, stress}
local function GetStatus(citizenid)
    local status = LoadStatus(citizenid)
    return {
        hunger = status.hunger,
        thirst = status.thirst,
        stress = status.stress,
    }
end

--- Set status (partial update)
---@param citizenid string
---@param partial table
---@return boolean
local function SetStatus(citizenid, partial)
    local status = LoadStatus(citizenid)
    if not status then return false end

    if partial.hunger ~= nil then status.hunger = math.max(0, math.min(100, partial.hunger)) end
    if partial.thirst ~= nil then status.thirst = math.max(0, math.min(100, partial.thirst)) end
    if partial.stress ~= nil then status.stress = math.max(0, math.min(100, partial.stress)) end

    StatusCache[citizenid] = status

    -- Notify client
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:status:update', src, GetStatus(citizenid))
    end

    return true
end

--- Apply decay tick to a character
---@param citizenid string
local function ApplyDecay(citizenid)
    local config = exports['core_boot']:GetConfig()
    local hungerDecay = config.status and config.status.hunger_decay or 0.5
    local thirstDecay = config.status and config.status.thirst_decay or 0.7
    local stressDecay = config.status and config.status.stress_decay or 0.2

    local status = LoadStatus(citizenid)
    if not status then return end

    status.hunger = math.max(0, status.hunger - hungerDecay)
    status.thirst = math.max(0, status.thirst - thirstDecay)
    status.stress = math.max(0, status.stress - stressDecay)

    StatusCache[citizenid] = status

    -- Apply health damage if hunger/thirst is 0
    if status.hunger <= 0 or status.thirst <= 0 then
        local src = exports['core_session']:GetSourceByCitizenId(citizenid)
        if src then
            TriggerClientEvent('jcrp:status:critical', src, {
                hunger = status.hunger <= 0,
                thirst = status.thirst <= 0,
            })
        end
    end

    -- Notify client
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:status:update', src, GetStatus(citizenid))
    end
end

--- Flush status to DB
---@param citizenid string
local function FlushStatus(citizenid)
    local status = StatusCache[citizenid]
    if not status then return end

    MySQL.update.await([[
        UPDATE character_status SET hunger = ?, thirst = ?, stress = ?, updated_at = NOW()
        WHERE citizenid = ?
    ]], { status.hunger, status.thirst, status.stress, citizenid })
end

--- Unload status from cache
---@param citizenid string
local function UnloadStatus(citizenid)
    FlushStatus(citizenid)
    StatusCache[citizenid] = nil
end

-- ============================================================
-- Decay tick loop
-- ============================================================
CreateThread(function()
    Wait(5000)
    local config = exports['core_boot']:GetConfig()
    local interval = config.status and config.status.decay_interval_ms or 60000

    while true do
        Wait(interval)
        for citizenid, _ in pairs(StatusCache) do
            ApplyDecay(citizenid)
        end
    end
end)

-- ============================================================
-- Periodic DB flush (every 3 minutes)
-- ============================================================
CreateThread(function()
    while true do
        Wait(180000)
        for citizenid, _ in pairs(StatusCache) do
            FlushStatus(citizenid)
        end
    end
end)

-- ============================================================
-- Resource Stop
-- ============================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        JCRP.Log('system_status', 'INFO', 'Flushing all status caches...')
        for citizenid, _ in pairs(StatusCache) do
            FlushStatus(citizenid)
        end
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('InitStatus', InitStatus)
exports('GetStatus', GetStatus)
exports('SetStatus', SetStatus)
exports('ApplyDecay', ApplyDecay)
exports('FlushStatus', FlushStatus)
exports('UnloadStatus', UnloadStatus)

JCRP.Log('system_status', 'INFO', 'system_status loaded.')
