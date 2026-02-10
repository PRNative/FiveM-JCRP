-- Core Boot Config Module
CoreBoot = CoreBoot or {}
CoreBoot.Config = {}

-- Load server config from JSON
function CoreBoot.LoadConfig()
    local configFile = LoadResourceFile(GetCurrentResourceName(), '../../config/server_config.json')
    
    if not configFile then
        configFile = LoadResourceFile('core_boot', '../../../config/server_config.json')
    end
    
    if configFile then
        local success, config = pcall(json.decode, configFile)
        if success then
            CoreBoot.Config = config
            print('[^2CORE_BOOT^7] Configuration loaded successfully')
            return true
        else
            print('[^1CORE_BOOT^7] Failed to parse configuration JSON')
            return false
        end
    else
        print('[^3CORE_BOOT^7] Configuration file not found, using defaults')
        CoreBoot.Config = {
            server = { name = "JCRP", brand = "Just City Roleplay" },
            characters = { max_slots = 3 },
            database = { schema_version = 1 }
        }
        return true
    end
end

-- Get config value by path
function CoreBoot.GetConfig(path)
    if not path then return CoreBoot.Config end
    
    local keys = {}
    for key in string.gmatch(path, "[^.]+") do
        table.insert(keys, key)
    end
    
    local value = CoreBoot.Config
    for _, key in ipairs(keys) do
        if type(value) == "table" and value[key] ~= nil then
            value = value[key]
        else
            return nil
        end
    end
    
    return value
end

-- Export for other resources
exports('GetConfig', CoreBoot.GetConfig)
