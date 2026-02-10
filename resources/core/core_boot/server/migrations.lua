-- Core Boot Migrations Module
CoreBoot = CoreBoot or {}
CoreBoot.Migrations = {}

local appliedMigrations = {}

-- Initialize schema_migrations table
function CoreBoot.Migrations.InitMigrationsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version INT PRIMARY KEY,
            applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            description VARCHAR(255)
        )
    ]])
    print('[^2CORE_BOOT^7] Schema migrations table initialized')
end

-- Get list of applied migrations
function CoreBoot.Migrations.GetAppliedMigrations()
    local result = MySQL.query.await('SELECT version FROM schema_migrations ORDER BY version ASC')
    appliedMigrations = {}
    
    if result then
        for _, row in ipairs(result) do
            appliedMigrations[row.version] = true
        end
    end
    
    return appliedMigrations
end

-- Apply a single migration
function CoreBoot.Migrations.ApplyMigration(version, description, sql)
    if appliedMigrations[version] then
        print(string.format('[^3CORE_BOOT^7] Migration %d already applied, skipping', version))
        return true
    end
    
    print(string.format('[^2CORE_BOOT^7] Applying migration %d: %s', version, description))
    
    local success = pcall(function()
        -- Execute migration SQL
        MySQL.transaction.await({
            sql,
            {
                query = 'INSERT INTO schema_migrations (version, description) VALUES (?, ?)',
                values = {version, description}
            }
        })
    end)
    
    if success then
        appliedMigrations[version] = true
        print(string.format('[^2CORE_BOOT^7] Migration %d applied successfully', version))
        return true
    else
        print(string.format('[^1CORE_BOOT^7] Migration %d failed!', version))
        return false
    end
end

-- Register and run migrations from other resources
CoreBoot.Migrations.Registry = {}

function CoreBoot.Migrations.Register(resourceName, migrations)
    CoreBoot.Migrations.Registry[resourceName] = migrations
    print(string.format('[^2CORE_BOOT^7] Registered %d migrations from %s', #migrations, resourceName))
end

function CoreBoot.Migrations.RunAll()
    print('[^2CORE_BOOT^7] Starting database migrations...')
    
    -- Initialize migrations table
    CoreBoot.Migrations.InitMigrationsTable()
    
    -- Load applied migrations
    CoreBoot.Migrations.GetAppliedMigrations()
    
    -- Collect all migrations from registry
    local allMigrations = {}
    for resourceName, migrations in pairs(CoreBoot.Migrations.Registry) do
        for _, migration in ipairs(migrations) do
            table.insert(allMigrations, {
                resource = resourceName,
                version = migration.version,
                description = migration.description or 'No description',
                sql = migration.sql
            })
        end
    end
    
    -- Sort migrations by version
    table.sort(allMigrations, function(a, b) return a.version < b.version end)
    
    -- Apply migrations in order
    local failed = false
    for _, migration in ipairs(allMigrations) do
        if not CoreBoot.Migrations.ApplyMigration(migration.version, migration.description, migration.sql) then
            failed = true
            print(string.format('[^1CORE_BOOT^7] CRITICAL: Migration %d from %s failed!', migration.version, migration.resource))
            print('[^1CORE_BOOT^7] Server will not start until migrations are fixed.')
            break
        end
    end
    
    if failed then
        return false
    end
    
    print(string.format('[^2CORE_BOOT^7] All migrations completed successfully (%d applied)', #allMigrations))
    return true
end

-- Health check
function CoreBoot.Migrations.HealthCheck()
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT 1')
    end)
    
    if success and result == 1 then
        print('[^2CORE_BOOT^7] Database health check: ^2PASSED^7')
        return true
    else
        print('[^1CORE_BOOT^7] Database health check: ^1FAILED^7')
        return false
    end
end

-- Exports
exports('RunMigrations', CoreBoot.Migrations.RunAll)
exports('RegisterMigrations', CoreBoot.Migrations.Register)
exports('HealthCheck', CoreBoot.Migrations.HealthCheck)
