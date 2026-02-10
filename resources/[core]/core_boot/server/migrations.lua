-- ============================================================
-- core_boot: Migration Runner
-- Applies SQL migrations in dependency order.
-- Each migration file: NNNN_description.sql
-- ============================================================

local appliedMigrations = {}
local migrationsReady = false

--- Ensure the schema_migrations table exists
local function EnsureMigrationsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version VARCHAR(255) NOT NULL PRIMARY KEY,
            resource_name VARCHAR(128) NOT NULL,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    JCRP.Log('core_boot', 'INFO', 'schema_migrations table verified.')
end

--- Load all already-applied migration versions
local function LoadAppliedMigrations()
    local rows = MySQL.query.await('SELECT version FROM schema_migrations')
    appliedMigrations = {}
    if rows then
        for _, row in ipairs(rows) do
            appliedMigrations[row.version] = true
        end
    end
end

--- Read migration files from a resource's migrations/ folder
---@param resourceName string
---@return table migrations sorted list of {version, sql}
local function ReadMigrationFiles(resourceName)
    local migrations = {}
    -- We'll read numbered migration files 0001 through 0100
    for i = 1, 100 do
        local filename = ('migrations/%04d.sql'):format(i)
        local sql = LoadResourceFile(resourceName, filename)
        if sql and sql ~= '' then
            local version = ('%s_%04d'):format(resourceName, i)
            migrations[#migrations + 1] = {
                version = version,
                sql = sql,
                resourceName = resourceName,
                file = filename,
            }
        end
    end
    return migrations
end

--- Apply a single migration
---@param migration table {version, sql, resourceName, file}
---@return boolean success
local function ApplyMigration(migration)
    -- Split multi-statement SQL by semicolons (basic splitter)
    local statements = {}
    for stmt in migration.sql:gmatch('([^;]+)') do
        local trimmed = stmt:match('^%s*(.-)%s*$')
        if trimmed and trimmed ~= '' then
            statements[#statements + 1] = trimmed
        end
    end

    for _, stmt in ipairs(statements) do
        local ok, err = pcall(function()
            MySQL.query.await(stmt)
        end)
        if not ok then
            JCRP.Log('core_boot', 'ERROR', ('Migration %s FAILED on statement: %s'):format(migration.version, tostring(err)))
            return false
        end
    end

    -- Record migration
    MySQL.insert.await(
        'INSERT INTO schema_migrations (version, resource_name) VALUES (?, ?)',
        { migration.version, migration.resourceName }
    )

    JCRP.Log('core_boot', 'INFO', ('  ✓ Applied migration: %s'):format(migration.version))
    return true
end

--- Run all pending migrations for a specific resource
---@param resourceName string
---@return boolean success
---@return number applied count of newly applied migrations
function RunMigrations(resourceName)
    if not migrationsReady then
        EnsureMigrationsTable()
        LoadAppliedMigrations()
        migrationsReady = true
    end

    local migrations = ReadMigrationFiles(resourceName)
    local applied = 0

    JCRP.Log('core_boot', 'INFO', ('Running migrations for [%s] (%d files found)'):format(resourceName, #migrations))

    for _, migration in ipairs(migrations) do
        if not appliedMigrations[migration.version] then
            local ok = ApplyMigration(migration)
            if not ok then
                JCRP.Log('core_boot', 'ERROR', ('MIGRATION FAILURE: %s — server should not continue!'):format(migration.version))
                return false, applied
            end
            appliedMigrations[migration.version] = true
            applied = applied + 1
        end
    end

    if applied == 0 then
        JCRP.Log('core_boot', 'INFO', ('  [%s] schema is up to date.'):format(resourceName))
    else
        JCRP.Log('core_boot', 'INFO', ('  [%s] %d migration(s) applied.'):format(resourceName, applied))
    end

    return true, applied
end

--- Run migrations for all core/system resources in dependency order
---@param resourceList table ordered list of resource names
---@return boolean allOk
function RunAllMigrations(resourceList)
    EnsureMigrationsTable()
    LoadAppliedMigrations()
    migrationsReady = true

    for _, resourceName in ipairs(resourceList) do
        local ok, count = RunMigrations(resourceName)
        if not ok then
            JCRP.Log('core_boot', 'ERROR', ('Schema migration failed at resource: %s — HALTING BOOT'):format(resourceName))
            return false
        end
    end
    return true
end

--- Health check: verify schema_migrations table is accessible
---@return boolean
function HealthCheck()
    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM schema_migrations')
    end)
    return ok and result ~= nil
end

-- Exports
exports('RunMigrations', RunMigrations)
exports('RunAllMigrations', RunAllMigrations)
exports('HealthCheck', HealthCheck)
