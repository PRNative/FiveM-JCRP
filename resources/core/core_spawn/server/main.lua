-- Core Spawn Main
CoreSpawn = CoreSpawn or {}

-- Get spawn options for a character
function CoreSpawn.GetSpawnOptions(citizenid)
    local options = {}
    
    -- Get predefined spawns from config
    local predefinedSpawns = exports.core_boot:GetConfig('spawn.predefined_spawns') or {}
    
    for _, spawn in ipairs(predefinedSpawns) do
        table.insert(options, {
            id = spawn.id,
            label = spawn.label,
            type = 'predefined',
            coords = {x = spawn.x, y = spawn.y, z = spawn.z},
            heading = spawn.heading
        })
    end
    
    -- Get last position
    local state = exports.core_state:GetState(citizenid)
    
    if state and state.position then
        local pos = state.position
        if pos.x ~= 0 or pos.y ~= 0 or pos.z ~= 0 then
            table.insert(options, {
                id = 'last_location',
                label = 'Last Location',
                type = 'last',
                coords = pos,
                heading = state.heading or 0.0
            })
        end
    end
    
    -- Get apartment spawn (if system_apartments is loaded)
    if GetResourceState('system_apartments') == 'started' then
        local properties = exports.system_apartments:GetOwnedProperties(citizenid)
        
        if properties and #properties > 0 then
            for _, property in ipairs(properties) do
                if property.entry_coords then
                    table.insert(options, {
                        id = 'apartment_' .. property.unit_id,
                        label = property.label or 'Apartment',
                        type = 'apartment',
                        coords = property.entry_coords,
                        heading = property.heading or 0.0
                    })
                end
            end
        end
    end
    
    -- If no options, add default spawn
    if #options == 0 then
        local defaultSpawn = exports.core_boot:GetConfig('spawn.new_character_spawn')
        
        if defaultSpawn then
            table.insert(options, {
                id = 'default',
                label = defaultSpawn.label or 'Default Spawn',
                type = 'default',
                coords = {x = defaultSpawn.x, y = defaultSpawn.y, z = defaultSpawn.z},
                heading = defaultSpawn.heading or 0.0
            })
        end
    end
    
    return options
end

-- Set last position
function CoreSpawn.SetLastPosition(citizenid, coords, heading)
    return exports.core_state:SetPosition(citizenid, coords, heading)
end

-- Spawn player at location
function CoreSpawn.SpawnPlayer(src, coords, heading)
    local ped = GetPlayerPed(src)
    
    if ped > 0 then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, heading or 0.0)
        
        -- Get citizenid
        local citizenid = exports.core_session:GetCitizenId(src)
        
        if citizenid then
            -- Save position
            CoreSpawn.SetLastPosition(citizenid, coords, heading)
            
            -- Load character appearance
            local character = exports.core_characters:GetCharacter(citizenid)
            
            if character then
                -- Set model
                local model = character.model or 'mp_m_freemode_01'
                TriggerClientEvent('core_spawn:setPlayerModel', src, model, character.skin or {})
            end
            
            -- Restore health and armor
            local state = exports.core_state:GetState(citizenid)
            if state then
                TriggerClientEvent('core_spawn:setHealthArmor', src, state.health or 200, state.armor or 0)
            end
        end
        
        return true
    end
    
    return false
end

-- Callbacks
lib.callback.register('core_spawn:getSpawnOptions', function(source)
    local citizenid = exports.core_session:GetCitizenId(source)
    
    if not citizenid then
        return {}
    end
    
    return CoreSpawn.GetSpawnOptions(citizenid)
end)

lib.callback.register('core_spawn:spawnAtLocation', function(source, coords, heading)
    return CoreSpawn.SpawnPlayer(source, coords, heading)
end)

-- Save position periodically for online players
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        local players = GetPlayers()
        
        for _, playerId in ipairs(players) do
            local src = tonumber(playerId)
            local citizenid = exports.core_session:GetCitizenId(src)
            
            if citizenid then
                local ped = GetPlayerPed(src)
                if ped > 0 then
                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    
                    CoreSpawn.SetLastPosition(citizenid, {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    }, heading)
                end
            end
        end
    end
end)

-- Exports
exports('GetSpawnOptions', CoreSpawn.GetSpawnOptions)
exports('SetLastPosition', CoreSpawn.SetLastPosition)
exports('SpawnPlayer', CoreSpawn.SpawnPlayer)

print('[^2CORE_SPAWN^7] Initialized')
