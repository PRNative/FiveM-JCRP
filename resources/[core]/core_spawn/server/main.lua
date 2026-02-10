-- ============================================================
-- core_spawn: Spawn System (Server)
-- Manages spawn options, last location, spawn execution
-- ============================================================

--- Get available spawn options for a character
---@param citizenid string
---@return table options
local function GetSpawnOptions(citizenid)
    local config = exports['core_boot']:GetConfig()
    local options = {}

    -- Option 1: Last Location (if state has valid position)
    local state = exports['core_state']:GetState(citizenid)
    if state and state.position and state.position.x and state.position.x ~= 0 then
        options[#options + 1] = {
            id = 'last_location',
            label = 'Last Location',
            description = ('Return to where you were (%.0f, %.0f, %.0f)'):format(
                state.position.x, state.position.y, state.position.z
            ),
            coords = state.position,
            heading = state.heading or 0,
            type = 'last_location',
        }
    end

    -- Option 2: Predefined spawns from config
    local predefined = config.spawns and config.spawns.predefined or {}
    for i, spawn in ipairs(predefined) do
        options[#options + 1] = {
            id = 'predefined_' .. i,
            label = spawn.label or ('Spawn ' .. i),
            description = spawn.description or '',
            coords = { x = spawn.x, y = spawn.y, z = spawn.z },
            heading = spawn.heading or 0,
            type = 'predefined',
        }
    end

    -- Option 3: Apartment spawn (P2 — safe call)
    pcall(function()
        local properties = exports['system_apartments']:GetOwnedProperties(citizenid)
        if properties and #properties > 0 then
            for _, prop in ipairs(properties) do
                options[#options + 1] = {
                    id = 'apartment_' .. prop.unit_id,
                    label = prop.label or 'Apartment',
                    description = 'Spawn in your apartment',
                    coords = JCRP.JsonDecode(prop.entry_coords_json, { x = 0, y = 0, z = 0 }),
                    heading = 0,
                    type = 'apartment',
                    unit_id = prop.unit_id,
                }
            end
        end
    end)

    -- If no options at all, provide default spawn
    if #options == 0 then
        local defaultSpawn = config.characters and config.characters.default_spawn or { x = -1035.71, y = -2731.87, z = 13.76 }
        options[#options + 1] = {
            id = 'default',
            label = 'Airport',
            description = 'Default spawn location',
            coords = defaultSpawn,
            heading = defaultSpawn.heading or 326.0,
            type = 'default',
        }
    end

    return options
end

--- Set last position for a character
---@param citizenid string
---@param coords table {x, y, z}
---@param heading number|nil
local function SetLastPosition(citizenid, coords, heading)
    exports['core_state']:SetPosition(citizenid, coords, heading)
end

--- Spawn a player at specified option
---@param src number
---@param option table spawn option with coords/heading
local function SpawnPlayer(src, option)
    if not option or not option.coords then
        JCRP.Log('core_spawn', 'ERROR', ('Invalid spawn option for source %d'):format(src))
        return
    end

    TriggerClientEvent('jcrp:spawn:execute', src, {
        coords = option.coords,
        heading = option.heading or 0,
        type = option.type or 'default',
    })

    -- Set position in state
    local citizenid = exports['core_session']:GetCitizenId(src)
    if citizenid then
        SetLastPosition(citizenid, option.coords, option.heading)
    end

    JCRP.Log('core_spawn', 'INFO', ('Spawned player %d at %s (%.1f, %.1f, %.1f)'):format(
        src, option.label or option.type or 'unknown',
        option.coords.x, option.coords.y, option.coords.z
    ))
end

-- ============================================================
-- Server Events
-- ============================================================

--- Client requests spawn options
RegisterNetEvent('jcrp:spawn:requestOptions', function()
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then
        JCRP.Log('core_spawn', 'WARN', ('No citizenid for source %d on spawn request'):format(src))
        return
    end

    local options = GetSpawnOptions(citizenid)
    TriggerClientEvent('jcrp:spawn:options', src, options)
end)

--- Client selected a spawn option
RegisterNetEvent('jcrp:spawn:selectOption', function(optionId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    local options = GetSpawnOptions(citizenid)
    local selectedOption = nil

    for _, opt in ipairs(options) do
        if opt.id == optionId then
            selectedOption = opt
            break
        end
    end

    if not selectedOption then
        -- Fallback to first option
        selectedOption = options[1]
    end

    SpawnPlayer(src, selectedOption)
end)

--- New character spawn (no options, just default)
RegisterNetEvent('jcrp:spawn:newCharacter', function()
    local src = source
    local config = exports['core_boot']:GetConfig()
    local defaultSpawn = config.characters and config.characters.new_character_spawn or { x = -1035.71, y = -2731.87, z = 13.76 }

    SpawnPlayer(src, {
        coords = defaultSpawn,
        heading = defaultSpawn.heading or 326.0,
        type = 'new_character',
        label = 'New Character Spawn',
    })
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetSpawnOptions', GetSpawnOptions)
exports('SetLastPosition', SetLastPosition)
exports('SpawnPlayer', SpawnPlayer)

JCRP.Log('core_spawn', 'INFO', 'core_spawn loaded.')
