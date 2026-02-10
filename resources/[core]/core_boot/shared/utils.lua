-- ============================================================
-- JCRP Shared Utilities
-- ============================================================

JCRP = JCRP or {}

--- Print a formatted log message
---@param module string
---@param level string "INFO"|"WARN"|"ERROR"|"DEBUG"
---@param msg string
function JCRP.Log(module, level, msg)
    local prefix = ('[JCRP:%s][%s]'):format(module, level)
    if level == 'ERROR' then
        print('^1' .. prefix .. ' ' .. msg .. '^0')
    elseif level == 'WARN' then
        print('^3' .. prefix .. ' ' .. msg .. '^0')
    elseif level == 'DEBUG' then
        if GetConvar('jcrp_debug', 'false') == 'true' then
            print('^5' .. prefix .. ' ' .. msg .. '^0')
        end
    else
        print('^2' .. prefix .. ' ' .. msg .. '^0')
    end
end

--- Safe JSON decode with fallback
---@param str string
---@param fallback any
---@return any
function JCRP.JsonDecode(str, fallback)
    if not str or str == '' then return fallback end
    local ok, result = pcall(json.decode, str)
    if ok then return result end
    return fallback
end

--- Safe JSON encode
---@param data any
---@return string
function JCRP.JsonEncode(data)
    if data == nil then return '{}' end
    local ok, result = pcall(json.encode, data)
    if ok then return result end
    return '{}'
end

--- Generate a unique citizen ID
---@return string citizenid like "JCRP-XXXXX"
function JCRP.GenerateCitizenId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = 'JCRP-'
    for i = 1, 5 do
        local idx = math.random(1, #chars)
        id = id .. chars:sub(idx, idx)
    end
    return id
end
