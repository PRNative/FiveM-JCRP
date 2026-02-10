-- ============================================================
-- core_session: Session Manager (Server)
-- Manages login flow, session map, hydration pipeline
-- ============================================================

-- In-memory session map: source -> session data
local Sessions = {}

-- Reverse map: citizenid -> source
local CitizenToSource = {}

--- Get citizen ID for a player source
---@param src number
---@return string|nil
local function GetCitizenId(src)
    local session = Sessions[src]
    return session and session.citizenid or nil
end

--- Get account ID for a player source
---@param src number
---@return number|nil
local function GetAccountId(src)
    local session = Sessions[src]
    return session and session.account_id or nil
end

--- Get the full hydrated player data snapshot
---@param src number
---@return table|nil
local function GetPlayerData(src)
    local session = Sessions[src]
    return session and session.data or nil
end

--- Get source from citizenid
---@param citizenid string
---@return number|nil
local function GetSourceByCitizenId(citizenid)
    return CitizenToSource[citizenid]
end

--- Check if a source is fully loaded
---@param src number
---@return boolean
local function IsPlayerLoaded(src)
    local session = Sessions[src]
    return session and session.loaded or false
end

--- Hydrate character: load full payload from all modules
---@param citizenid string
---@return table payload
local function HydrateCharacter(citizenid)
    local payload = {}

    -- Base character identity
    payload.character = exports['core_characters']:LoadCharacter(citizenid)

    -- State (position, health, metadata)
    payload.state = exports['core_state']:GetState(citizenid)

    -- Money (P1 — safe call)
    pcall(function()
        payload.money = exports['system_money']:GetBalances(citizenid)
    end)

    -- Inventory (P1 — safe call)
    pcall(function()
        payload.inventory = exports['system_inventory']:GetInventory(citizenid)
    end)

    -- Job (P1 — safe call)
    pcall(function()
        payload.job = exports['system_jobs']:GetJob(citizenid)
    end)

    -- Status (P1 — safe call)
    pcall(function()
        payload.status = exports['system_status']:GetStatus(citizenid)
    end)

    return payload
end

--- Complete the character selection and spawn the player
---@param src number
---@param citizenid string
local function SelectCharacter(src, citizenid)
    local session = Sessions[src]
    if not session then
        JCRP.Log('core_session', 'ERROR', ('No session for source %d'):format(src))
        return
    end

    -- Verify this character belongs to this account
    local char = exports['core_characters']:LoadCharacter(citizenid)
    if not char or char.account_id ~= session.account_id then
        JCRP.Log('core_session', 'WARN', ('Source %d tried to select character %s that doesn\'t belong to them'):format(src, citizenid))
        TriggerClientEvent('jcrp:session:error', src, 'Invalid character selection.')
        return
    end

    -- Hydrate full payload
    local payload = HydrateCharacter(citizenid)

    -- Store in session
    session.citizenid = citizenid
    session.data = payload
    session.loaded = true
    Sessions[src] = session
    CitizenToSource[citizenid] = src

    -- Update last played
    exports['core_characters']:UpdateLastPlayed(citizenid)

    JCRP.Log('core_session', 'INFO', ('Player %d selected character %s (%s %s)'):format(
        src, citizenid, char.firstname, char.lastname
    ))

    -- Tell client to close NUI and proceed to spawn
    TriggerClientEvent('jcrp:session:characterSelected', src, payload)

    -- Notify other resources
    TriggerEvent('jcrp:playerLoaded', src, payload)
end

-- ============================================================
-- Connection Handler (Deferrals)
-- ============================================================
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    deferrals.update(('Welcome %s! Verifying your account...'):format(name))
    Wait(500)

    -- Resolve account
    local accountId, err = exports['core_identity']:ResolveAccount(src)
    if not accountId then
        deferrals.done(err or 'Account resolution failed.')
        return
    end

    -- Ban check
    local banned, banReason = exports['core_identity']:IsBanned(accountId)
    if banned then
        deferrals.done(('You are banned from this server. Reason: %s'):format(banReason or 'No reason provided.'))
        return
    end

    -- Store initial session
    Sessions[src] = {
        account_id = accountId,
        citizenid = nil,
        data = nil,
        loaded = false,
        name = name,
    }

    deferrals.update('Account verified! Loading...')
    Wait(500)
    deferrals.done()

    JCRP.Log('core_session', 'INFO', ('Player %s (src=%d, account=%d) connecting.'):format(name, src, accountId))
end)

-- ============================================================
-- Client Callbacks (NUI -> Client -> Server)
-- ============================================================

--- Client requests character list
RegisterNetEvent('jcrp:session:requestCharacters', function()
    local src = source
    local session = Sessions[src]
    if not session then
        TriggerClientEvent('jcrp:session:error', src, 'No session found.')
        return
    end

    local characters = exports['core_characters']:ListCharacters(session.account_id)

    -- Enrich with parsed data
    for i, char in ipairs(characters) do
        characters[i].skin = JCRP.JsonDecode(char.skin_json, {})
        characters[i].skin_json = nil
    end

    TriggerClientEvent('jcrp:session:characterList', src, characters)
end)

--- Client wants to select a character
RegisterNetEvent('jcrp:session:selectCharacter', function(citizenid)
    local src = source
    if not citizenid or citizenid == '' then return end
    SelectCharacter(src, citizenid)
end)

--- Client wants to create a character
RegisterNetEvent('jcrp:session:createCharacter', function(charData)
    local src = source
    local session = Sessions[src]
    if not session then return end

    if type(charData) ~= 'table' then return end

    local citizenid, err = exports['core_characters']:CreateCharacter(
        session.account_id,
        charData.slot,
        charData
    )

    if not citizenid then
        TriggerClientEvent('jcrp:session:createResult', src, false, err)
        return
    end

    -- Initialize state for the new character
    local config = exports['core_boot']:GetConfig()
    local defaultSpawn = config.characters and config.characters.new_character_spawn or { x = -1035.71, y = -2731.87, z = 13.76 }
    exports['core_state']:InitState(citizenid, defaultSpawn, 326.0)

    -- Initialize money (P1 — safe call)
    pcall(function()
        exports['system_money']:InitMoney(citizenid)
    end)

    -- Initialize job (P1 — safe call)
    pcall(function()
        exports['system_jobs']:InitJob(citizenid)
    end)

    -- Initialize status (P1 — safe call)
    pcall(function()
        exports['system_status']:InitStatus(citizenid)
    end)

    TriggerClientEvent('jcrp:session:createResult', src, true, citizenid)

    -- Refresh character list
    local characters = exports['core_characters']:ListCharacters(session.account_id)
    for i, char in ipairs(characters) do
        characters[i].skin = JCRP.JsonDecode(char.skin_json, {})
        characters[i].skin_json = nil
    end
    TriggerClientEvent('jcrp:session:characterList', src, characters)
end)

--- Client wants to delete a character
RegisterNetEvent('jcrp:session:deleteCharacter', function(slot)
    local src = source
    local session = Sessions[src]
    if not session then return end

    if type(slot) ~= 'number' then return end

    local ok, err = exports['core_characters']:DeleteCharacter(session.account_id, slot)
    TriggerClientEvent('jcrp:session:deleteResult', src, ok, err)

    if ok then
        -- Refresh character list
        local characters = exports['core_characters']:ListCharacters(session.account_id)
        for i, char in ipairs(characters) do
            characters[i].skin = JCRP.JsonDecode(char.skin_json, {})
            characters[i].skin_json = nil
        end
        TriggerClientEvent('jcrp:session:characterList', src, characters)
    end
end)

-- ============================================================
-- Disconnect Handler
-- ============================================================
AddEventHandler('playerDropped', function(reason)
    local src = source
    local session = Sessions[src]

    if session and session.citizenid then
        JCRP.Log('core_session', 'INFO', ('Player %d (%s) dropped: %s'):format(src, session.citizenid, reason))

        -- Save last position and state
        exports['core_state']:FlushState(session.citizenid)
        exports['core_state']:UnloadState(session.citizenid)

        -- Flush money/status if loaded (P1 — safe call)
        pcall(function() exports['system_money']:FlushMoney(session.citizenid) end)
        pcall(function() exports['system_status']:FlushStatus(session.citizenid) end)

        -- Notify other resources
        TriggerEvent('jcrp:playerUnloaded', src, session.citizenid)

        -- Clean up reverse map
        CitizenToSource[session.citizenid] = nil
    end

    Sessions[src] = nil
end)

-- ============================================================
-- Resource Stop — flush all sessions
-- ============================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        JCRP.Log('core_session', 'INFO', 'Resource stopping — saving all sessions...')
        for src, session in pairs(Sessions) do
            if session.citizenid then
                pcall(function() exports['core_state']:FlushState(session.citizenid) end)
                pcall(function() exports['system_money']:FlushMoney(session.citizenid) end)
                pcall(function() exports['system_status']:FlushStatus(session.citizenid) end)
            end
        end
        JCRP.Log('core_session', 'INFO', 'All sessions saved.')
    end
end)

-- ============================================================
-- Position Saving (client periodically sends position)
-- ============================================================
RegisterNetEvent('jcrp:session:updatePosition', function(coords, heading)
    local src = source
    local session = Sessions[src]
    if not session or not session.citizenid then return end

    if type(coords) ~= 'table' then return end

    exports['core_state']:SetPosition(session.citizenid, {
        x = tonumber(coords.x) or 0,
        y = tonumber(coords.y) or 0,
        z = tonumber(coords.z) or 0,
    }, tonumber(heading) or 0)
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetCitizenId', GetCitizenId)
exports('GetAccountId', GetAccountId)
exports('GetPlayerData', GetPlayerData)
exports('GetSourceByCitizenId', GetSourceByCitizenId)
exports('IsPlayerLoaded', IsPlayerLoaded)

JCRP.Log('core_session', 'INFO', 'core_session loaded.')
