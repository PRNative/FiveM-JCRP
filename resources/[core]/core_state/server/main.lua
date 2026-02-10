-- ============================================================
-- core_state: Per-Character Persistent State
-- Position, health, armor, arbitrary metadata
-- Dirty tracking for efficient DB flushes
-- ============================================================

-- In-memory state cache: citizenid -> stateData
local StateCache = {}

-- Dirty tracking: citizenid -> true
local DirtySet = {}

--- Initialize default state for a new character
---@param citizenid string
---@param position table|nil {x, y, z}
---@param heading number|nil
---@return table state
local function InitState(citizenid, position, heading)
    local config = exports['core_boot']:GetConfig()
    local defaultSpawn = config.characters and config.characters.default_spawn or { x = -1035.71, y = -2731.87, z = 13.76 }
    local defaultHeading = config.characters and config.characters.default_spawn and config.characters.default_spawn.heading or 326.0

    local state = {
        citizenid = citizenid,
        position = position or defaultSpawn,
        heading = heading or defaultHeading,
        health = 200,
        armor = 0,
        metadata = {},
    }

    -- Insert into DB
    MySQL.insert.await([[
        INSERT INTO character_state (citizenid, position_json, heading, health, armor, metadata_json)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE updated_at = NOW()
    ]], {
        citizenid,
        JCRP.JsonEncode(state.position),
        state.heading,
        state.health,
        state.armor,
        JCRP.JsonEncode(state.metadata),
    })

    StateCache[citizenid] = state
    JCRP.Log('core_state', 'DEBUG', ('Initialized state for %s'):format(citizenid))
    return state
end

--- Get state from cache or DB
---@param citizenid string
---@return table|nil state
local function GetState(citizenid)
    -- Check cache first
    if StateCache[citizenid] then
        return StateCache[citizenid]
    end

    -- Load from DB
    local row = MySQL.single.await(
        'SELECT * FROM character_state WHERE citizenid = ?',
        { citizenid }
    )

    if not row then
        -- No state exists, initialize with defaults
        return InitState(citizenid)
    end

    local state = {
        citizenid = citizenid,
        position = JCRP.JsonDecode(row.position_json, { x = 0, y = 0, z = 0 }),
        heading = row.heading or 0.0,
        health = row.health or 200,
        armor = row.armor or 0,
        metadata = JCRP.JsonDecode(row.metadata_json, {}),
    }

    StateCache[citizenid] = state
    return state
end

--- Set state (partial merge)
---@param citizenid string
---@param partialState table
---@return boolean ok
local function SetState(citizenid, partialState)
    local state = GetState(citizenid)
    if not state then return false end

    -- Merge partial state
    if partialState.position then state.position = partialState.position end
    if partialState.heading then state.heading = partialState.heading end
    if partialState.health then state.health = partialState.health end
    if partialState.armor ~= nil then state.armor = partialState.armor end
    if partialState.metadata then
        for k, v in pairs(partialState.metadata) do
            state.metadata[k] = v
        end
    end

    StateCache[citizenid] = state
    DirtySet[citizenid] = true
    return true
end

--- Mark a specific state key as dirty (forces flush)
---@param citizenid string
---@param key string (unused but kept for API contract)
local function MarkDirty(citizenid, key)
    DirtySet[citizenid] = true
end

--- Flush state to DB
---@param citizenid string
---@return boolean ok
local function FlushState(citizenid)
    local state = StateCache[citizenid]
    if not state then return false end

    MySQL.update.await([[
        UPDATE character_state SET
            position_json = ?,
            heading = ?,
            health = ?,
            armor = ?,
            metadata_json = ?,
            updated_at = NOW()
        WHERE citizenid = ?
    ]], {
        JCRP.JsonEncode(state.position),
        state.heading,
        state.health,
        state.armor,
        JCRP.JsonEncode(state.metadata),
        citizenid,
    })

    DirtySet[citizenid] = nil
    JCRP.Log('core_state', 'DEBUG', ('Flushed state for %s'):format(citizenid))
    return true
end

--- Flush all dirty states
local function FlushAllDirty()
    local count = 0
    for citizenid, _ in pairs(DirtySet) do
        FlushState(citizenid)
        count = count + 1
    end
    if count > 0 then
        JCRP.Log('core_state', 'INFO', ('Flushed %d dirty state(s).'):format(count))
    end
end

--- Remove a character from cache (on disconnect)
---@param citizenid string
local function UnloadState(citizenid)
    if DirtySet[citizenid] then
        FlushState(citizenid)
    end
    StateCache[citizenid] = nil
    DirtySet[citizenid] = nil
end

--- Set position specifically
---@param citizenid string
---@param coords table {x, y, z}
---@param heading number|nil
local function SetPosition(citizenid, coords, heading)
    local state = GetState(citizenid)
    if not state then return end
    state.position = coords
    if heading then state.heading = heading end
    StateCache[citizenid] = state
    DirtySet[citizenid] = true
end

--- Get metadata value
---@param citizenid string
---@param key string
---@return any
local function GetMetadata(citizenid, key)
    local state = GetState(citizenid)
    if not state or not state.metadata then return nil end
    return state.metadata[key]
end

--- Set metadata value
---@param citizenid string
---@param key string
---@param value any
local function SetMetadata(citizenid, key, value)
    local state = GetState(citizenid)
    if not state then return end
    state.metadata[key] = value
    StateCache[citizenid] = state
    DirtySet[citizenid] = true
end

-- ============================================================
-- Periodic flush (every 5 minutes)
-- ============================================================
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        FlushAllDirty()
    end
end)

-- ============================================================
-- Flush all on resource stop (server restart safety)
-- ============================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        JCRP.Log('core_state', 'INFO', 'Resource stopping — flushing all state...')
        for citizenid, _ in pairs(StateCache) do
            FlushState(citizenid)
        end
        JCRP.Log('core_state', 'INFO', 'All state flushed.')
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetState', GetState)
exports('SetState', SetState)
exports('MarkDirty', MarkDirty)
exports('FlushState', FlushState)
exports('FlushAllDirty', FlushAllDirty)
exports('UnloadState', UnloadState)
exports('InitState', InitState)
exports('SetPosition', SetPosition)
exports('GetMetadata', GetMetadata)
exports('SetMetadata', SetMetadata)

JCRP.Log('core_state', 'INFO', 'core_state loaded.')
