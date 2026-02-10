-- Core Session Main
CoreSession = CoreSession or {}

-- Active sessions (source -> session data)
local activeSessions = {}

-- Get citizen ID for a player
function CoreSession.GetCitizenId(src)
    local session = activeSessions[src]
    return session and session.citizenid or nil
end

-- Get account ID for a player
function CoreSession.GetAccountId(src)
    local session = activeSessions[src]
    return session and session.account_id or nil
end

-- Get full player data
function CoreSession.GetPlayerData(src)
    local session = activeSessions[src]
    if not session then return nil end
    
    return {
        source = src,
        account_id = session.account_id,
        citizenid = session.citizenid,
        character = session.character,
        state = session.state,
        money = session.money,
        job = session.job,
        inventory = session.inventory,
        status = session.status
    }
end

-- Hydrate character data from all systems
local function HydrateCharacterData(citizenid)
    local data = {}
    
    -- Load character
    data.character = exports.core_characters:LoadCharacter(citizenid)
    
    -- Load state
    data.state = exports.core_state:GetState(citizenid)
    
    -- Load money (if system_money is loaded)
    if GetResourceState('system_money') == 'started' then
        data.money = exports.system_money:GetBalances(citizenid)
    end
    
    -- Load job (if system_jobs is loaded)
    if GetResourceState('system_jobs') == 'started' then
        data.job = exports.system_jobs:GetJob(citizenid)
    end
    
    -- Load inventory (if system_inventory is loaded)
    if GetResourceState('system_inventory') == 'started' then
        data.inventory = exports.system_inventory:GetInventory(citizenid)
    end
    
    -- Load status (if system_status is loaded)
    if GetResourceState('system_status') == 'started' then
        data.status = exports.system_status:GetStatus(citizenid)
    end
    
    return data
end

-- Select character and create session
local function SelectCharacter(src, citizenid)
    local accountId = exports.core_identity:ResolveAccount(src)
    
    if not accountId then
        return false, "Account not found"
    end
    
    -- Verify character belongs to account
    local character = exports.core_characters:LoadCharacter(citizenid)
    
    if not character or character.account_id ~= accountId then
        return false, "Character not found or access denied"
    end
    
    -- Hydrate full character data
    local hydratedData = HydrateCharacterData(citizenid)
    
    -- Update last played
    exports.core_characters:UpdateLastPlayed(citizenid)
    
    -- Create session
    activeSessions[src] = {
        account_id = accountId,
        citizenid = citizenid,
        character = hydratedData.character,
        state = hydratedData.state,
        money = hydratedData.money,
        job = hydratedData.job,
        inventory = hydratedData.inventory,
        status = hydratedData.status,
        joined_at = os.time()
    }
    
    print(string.format('[^2CORE_SESSION^7] Session created for player %d (CID: %s)', src, citizenid))
    
    -- Trigger session created event
    TriggerEvent('core_session:created', src, citizenid)
    
    return true, hydratedData
end

-- Update session data (for other systems to update in memory)
function CoreSession.UpdateSessionData(src, key, value)
    if activeSessions[src] then
        activeSessions[src][key] = value
    end
end

-- Flush session data to database
local function FlushSession(src)
    local session = activeSessions[src]
    
    if not session then
        return
    end
    
    local citizenid = session.citizenid
    
    -- Flush state
    if session.state then
        exports.core_state:FlushState(citizenid)
    end
    
    -- Flush money (if loaded)
    if GetResourceState('system_money') == 'started' and session.money then
        -- Money is auto-saved on transactions
    end
    
    print(string.format('[^2CORE_SESSION^7] Session flushed for player %d (CID: %s)', src, citizenid))
end

-- Destroy session
local function DestroySession(src)
    local session = activeSessions[src]
    
    if not session then
        return
    end
    
    -- Flush data first
    FlushSession(src)
    
    -- Trigger before destroy event
    TriggerEvent('core_session:beforeDestroy', src, session.citizenid)
    
    -- Remove session
    activeSessions[src] = nil
    
    print(string.format('[^2CORE_SESSION^7] Session destroyed for player %d', src))
end

-- Callbacks
lib.callback.register('core_session:selectCharacter', function(source, citizenid)
    local success, data = SelectCharacter(source, citizenid)
    
    if success then
        return {success = true, data = data}
    else
        return {success = false, message = data}
    end
end)

-- Player drop event
AddEventHandler('playerDropped', function(reason)
    local src = source
    DestroySession(src)
end)

-- Save all sessions (used on resource stop or server restart)
local function SaveAllSessions()
    local count = 0
    for src, _ in pairs(activeSessions) do
        FlushSession(src)
        count = count + 1
    end
    print(string.format('[^2CORE_SESSION^7] Saved %d active sessions', count))
end

-- Auto-save every 2 minutes
CreateThread(function()
    while true do
        Wait(120000) -- 2 minutes
        SaveAllSessions()
    end
end)

-- Save on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SaveAllSessions()
    end
end)

-- Exports
exports('GetCitizenId', CoreSession.GetCitizenId)
exports('GetAccountId', CoreSession.GetAccountId)
exports('GetPlayerData', CoreSession.GetPlayerData)
exports('UpdateSessionData', CoreSession.UpdateSessionData)

print('[^2CORE_SESSION^7] Initialized')
