-- Core State Main
CoreState = CoreState or {}

-- In-memory dirty state tracking
local dirtyStates = {}

-- Initialize state for new character
local function InitializeState(citizenid)
    local existing = MySQL.single.await('SELECT citizenid FROM character_state WHERE citizenid = ?', {citizenid})
    
    if not existing then
        MySQL.insert.await([[
            INSERT INTO character_state (citizenid, position_json, heading, health, armor, metadata_json)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            citizenid,
            json.encode({x = 0, y = 0, z = 0}),
            0.0,
            200,
            0,
            json.encode({})
        })
        print(string.format('[^2CORE_STATE^7] Initialized state for character: %s', citizenid))
    end
end

-- Get character state
function CoreState.GetState(citizenid)
    local state = MySQL.single.await('SELECT * FROM character_state WHERE citizenid = ?', {citizenid})
    
    if not state then
        -- Initialize if doesn't exist
        InitializeState(citizenid)
        state = MySQL.single.await('SELECT * FROM character_state WHERE citizenid = ?', {citizenid})
    end
    
    if state then
        -- Parse JSON fields
        if state.position_json then
            if type(state.position_json) == "string" then
                state.position = json.decode(state.position_json)
            else
                state.position = state.position_json
            end
            state.position_json = nil
        end
        
        if state.metadata_json then
            if type(state.metadata_json) == "string" then
                state.metadata = json.decode(state.metadata_json)
            else
                state.metadata = state.metadata_json
            end
            state.metadata_json = nil
        end
    end
    
    return state
end

-- Set character state (partial update)
function CoreState.SetState(citizenid, partialState)
    if not citizenid then return false end
    
    local updates = {}
    local values = {}
    
    if partialState.position then
        table.insert(updates, 'position_json = ?')
        table.insert(values, json.encode(partialState.position))
    end
    
    if partialState.heading then
        table.insert(updates, 'heading = ?')
        table.insert(values, partialState.heading)
    end
    
    if partialState.health then
        table.insert(updates, 'health = ?')
        table.insert(values, partialState.health)
    end
    
    if partialState.armor then
        table.insert(updates, 'armor = ?')
        table.insert(values, partialState.armor)
    end
    
    if partialState.metadata then
        -- Merge with existing metadata
        local currentState = CoreState.GetState(citizenid)
        local metadata = currentState and currentState.metadata or {}
        
        for k, v in pairs(partialState.metadata) do
            metadata[k] = v
        end
        
        table.insert(updates, 'metadata_json = ?')
        table.insert(values, json.encode(metadata))
    end
    
    if #updates == 0 then
        return true
    end
    
    table.insert(values, citizenid)
    
    local query = string.format('UPDATE character_state SET %s, updated_at = NOW() WHERE citizenid = ?', table.concat(updates, ', '))
    MySQL.update(query, values)
    
    return true
end

-- Mark state as dirty (needs flush)
function CoreState.MarkDirty(citizenid, key)
    if not dirtyStates[citizenid] then
        dirtyStates[citizenid] = {}
    end
    
    dirtyStates[citizenid][key] = true
end

-- Flush dirty state to database
function CoreState.FlushState(citizenid)
    if not dirtyStates[citizenid] then
        return true
    end
    
    -- State is already being saved by SetState calls
    -- This just clears the dirty flag
    dirtyStates[citizenid] = nil
    
    return true
end

-- Set player position (convenience function)
function CoreState.SetPosition(citizenid, coords, heading)
    return CoreState.SetState(citizenid, {
        position = {x = coords.x, y = coords.y, z = coords.z},
        heading = heading or 0.0
    })
end

-- Set player health and armor
function CoreState.SetHealthArmor(citizenid, health, armor)
    return CoreState.SetState(citizenid, {
        health = health,
        armor = armor
    })
end

-- Get metadata value
function CoreState.GetMetadata(citizenid, key)
    local state = CoreState.GetState(citizenid)
    if state and state.metadata then
        return state.metadata[key]
    end
    return nil
end

-- Set metadata value
function CoreState.SetMetadata(citizenid, key, value)
    return CoreState.SetState(citizenid, {
        metadata = {[key] = value}
    })
end

-- Listen to character creation to initialize state
AddEventHandler('core_characters:created', function(citizenid, accountId)
    InitializeState(citizenid)
end)

-- Listen to character deletion to clean up state
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM character_state WHERE citizenid = ?', {citizenid})
    dirtyStates[citizenid] = nil
    print(string.format('[^2CORE_STATE^7] Cleaned up state for character: %s', citizenid))
end)

-- Auto-save dirty states every 5 minutes
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        
        local count = 0
        for citizenid, _ in pairs(dirtyStates) do
            CoreState.FlushState(citizenid)
            count = count + 1
        end
        
        if count > 0 then
            print(string.format('[^2CORE_STATE^7] Auto-flushed %d dirty states', count))
        end
    end
end)

-- Exports
exports('GetState', CoreState.GetState)
exports('SetState', CoreState.SetState)
exports('MarkDirty', CoreState.MarkDirty)
exports('FlushState', CoreState.FlushState)
exports('SetPosition', CoreState.SetPosition)
exports('SetHealthArmor', CoreState.SetHealthArmor)
exports('GetMetadata', CoreState.GetMetadata)
exports('SetMetadata', CoreState.SetMetadata)

print('[^2CORE_STATE^7] Initialized')
