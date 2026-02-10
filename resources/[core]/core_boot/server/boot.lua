-- ============================================================
-- core_boot: Server Boot Sequence
-- Verifies DB, runs migrations, gates startup
-- ============================================================

local bootSuccess = false

--- Ordered list of all resources that have migrations
local MIGRATION_ORDER = {
    'core_boot',
    'core_identity',
    'core_characters',
    'core_state',
    'system_money',
    'system_inventory',
    'system_jobs',
    'system_status',
    'system_permissions',
    'system_apartments',
    'system_vehicles',
    'system_phone',
}

--- Boot sequence
local function Boot()
    JCRP.Log('core_boot', 'INFO', '========================================')
    JCRP.Log('core_boot', 'INFO', '  JCRP Server — Starting Boot Sequence  ')
    JCRP.Log('core_boot', 'INFO', '========================================')

    -- Step 1: DB connectivity
    JCRP.Log('core_boot', 'INFO', '[1/3] Checking database connectivity...')
    local dbOk, dbErr = pcall(function()
        MySQL.scalar.await('SELECT 1')
    end)
    if not dbOk then
        JCRP.Log('core_boot', 'ERROR', 'DATABASE CONNECTION FAILED: ' .. tostring(dbErr))
        JCRP.Log('core_boot', 'ERROR', 'Check mysql_connection_string in server.cfg')
        JCRP.Log('core_boot', 'ERROR', 'SERVER BOOT ABORTED.')
        return
    end
    JCRP.Log('core_boot', 'INFO', '  Database connection OK.')

    -- Step 2: Config
    JCRP.Log('core_boot', 'INFO', '[2/3] Loading configuration...')
    local config = GetConfig()
    local serverName = config.server and config.server.name or 'JCRP'
    local serverVersion = config.server and config.server.version or '0.0.0'
    JCRP.Log('core_boot', 'INFO', ('  Server: %s v%s'):format(serverName, serverVersion))

    -- Step 3: Migrations
    JCRP.Log('core_boot', 'INFO', '[3/3] Running database migrations...')
    local migrationOk = RunAllMigrations(MIGRATION_ORDER)
    if not migrationOk then
        JCRP.Log('core_boot', 'ERROR', 'MIGRATION FAILURE — SERVER BOOT ABORTED.')
        JCRP.Log('core_boot', 'ERROR', 'Fix the failed migration and restart.')
        return
    end

    -- Boot complete
    bootSuccess = true
    JCRP.Log('core_boot', 'INFO', '========================================')
    JCRP.Log('core_boot', 'INFO', '  JCRP Server — Boot Complete ✓         ')
    JCRP.Log('core_boot', 'INFO', '========================================')

    -- Emit event so other resources know boot is done
    TriggerEvent('jcrp:boot:complete')
end

--- Check if boot was successful
---@return boolean
function IsBootComplete()
    return bootSuccess
end

exports('IsBootComplete', IsBootComplete)

-- Run boot on resource start
CreateThread(function()
    -- Small delay to ensure oxmysql is ready
    Wait(500)
    Boot()
end)
