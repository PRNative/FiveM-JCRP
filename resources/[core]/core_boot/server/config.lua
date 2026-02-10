-- ============================================================
-- core_boot: Configuration Loader
-- Reads config.json from the server root
-- ============================================================

local Config = {}
local configLoaded = false

--- Load config.json from the resource root (server data folder)
local function LoadConfig()
    -- Try loading from the root config.json
    local rawJson = LoadResourceFile('core_boot', '../../../config.json')
    if not rawJson then
        -- Fallback: try resource-level config
        rawJson = LoadResourceFile('core_boot', 'config.json')
    end
    if not rawJson then
        JCRP.Log('core_boot', 'ERROR', 'config.json not found! Using defaults.')
        Config = {}
        return
    end

    local ok, parsed = pcall(json.decode, rawJson)
    if not ok or type(parsed) ~= 'table' then
        JCRP.Log('core_boot', 'ERROR', 'config.json is malformed! Using defaults.')
        Config = {}
        return
    end

    Config = parsed
    configLoaded = true
    JCRP.Log('core_boot', 'INFO', 'Configuration loaded successfully.')
end

--- Get the full config table
---@return table
function GetConfig()
    if not configLoaded then LoadConfig() end
    return Config
end

--- Get a nested config value by dot-separated path
---@param path string e.g. "characters.max_slots"
---@param default any fallback value
---@return any
function GetConfigValue(path, default)
    if not configLoaded then LoadConfig() end
    local keys = {}
    for key in path:gmatch('[^%.]+') do
        keys[#keys + 1] = key
    end
    local current = Config
    for _, key in ipairs(keys) do
        if type(current) ~= 'table' then return default end
        current = current[key]
        if current == nil then return default end
    end
    return current
end

-- Export functions
exports('GetConfig', GetConfig)
exports('GetConfigValue', GetConfigValue)

-- Load on start
LoadConfig()
