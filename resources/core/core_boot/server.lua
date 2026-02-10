--[[
  core_boot - P0 Platform Foundation
  Responsibilities:
  - DB connectivity check
  - schema version check + migrations runner
  - environment config loader (json)
  - startup gating: do not allow other resources to run if schema invalid

  Exports: RunMigrations(), GetConfig(), HealthCheck()
]]

-- Config: (1) convar platform_config_path, (2) resource config.json
local configPath = GetConvar('platform_config_path', '') 
if configPath == '' then
  configPath = GetResourcePath(GetCurrentResourceName()) .. '/config.json'
end
local _config = nil
local _ready = false
local _migrationsApplied = {}

--- Load config from JSON file
---@return table|nil
local function LoadConfig()
  if _config then return _config end
  local f = io.open(configPath, 'r')
  if not f then
    print('^1[core_boot] FATAL: Config file not found: ' .. tostring(configPath) .. '^0')
    return nil
  end
  local content = f:read('*a')
  f:close()
  local ok, data = pcall(json.decode, content)
  if not ok or not data then
    print('^1[core_boot] FATAL: Invalid config JSON^0')
    return nil
  end
  _config = data
  print('^2[core_boot] Config loaded^0')
  return _config
end

--- Ensure schema_migrations table exists
---@return boolean
local function EnsureMigrationsTable()
  local result = MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version VARCHAR(255) PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]])
  return result ~= nil
end

--- Get list of applied migrations
---@return table
local function GetAppliedMigrations()
  local rows = MySQL.query.await('SELECT version FROM schema_migrations ORDER BY version ASC') or {}
  local set = {}
  for _, r in ipairs(rows) do
    set[r.version] = true
  end
  return set
end

--- Run all pending migrations from this resource and dependencies
--- Migrations are stored per-resource in resources/core/*/migrations/
--- core_boot runs its own first, then others via RunMigrationsFor(resourceName)
---@return boolean success
function RunMigrations()
  if not _config then
    LoadConfig()
    if not _config then return false end
  end

  if not EnsureMigrationsTable() then
    print('^1[core_boot] FATAL: Could not create schema_migrations table^0')
    return false
  end

  local applied = GetAppliedMigrations()

  -- Run core_boot migrations (schema_migrations table created by EnsureMigrationsTable)
  -- Other schema is created by dependent resources via RunMigrationsFor
  return true
end

--- Run migrations for a specific resource (called by other core resources)
---@param resourceName string
---@param migrations table Array of {version, sql}
---@return boolean
function RunMigrationsFor(resourceName, migrations)
  if not migrations or #migrations == 0 then return true end
  local applied = GetAppliedMigrations()
  for _, m in ipairs(migrations) do
    if not applied[m.version] then
      local ok, err = pcall(function()
        MySQL.query.await(m.sql)
      end)
      if not ok then
        print('^1[core_boot] Migration ' .. m.version .. ' (' .. resourceName .. ') FAILED: ' .. tostring(err) .. '^0')
        return false
      end
      MySQL.insert.await('INSERT INTO schema_migrations (version) VALUES (?)', { m.version })
      print('^2[core_boot] Applied migration: ' .. m.version .. ' (' .. resourceName .. ')^0')
    end
  end
  return true
end

--- Get config
---@return table
function GetConfig()
  if not _config then LoadConfig() end
  return _config or {}
end

--- Health check: DB connectivity + schema validity
---@return boolean healthy, string|nil error
function HealthCheck()
  if not _config then
    if not LoadConfig() then return false, 'config_load_failed' end
  end

  local ok, err = pcall(function()
    MySQL.query.await('SELECT 1')
  end)
  if not ok then
    return false, 'db_connect_failed'
  end

  local ok2, row = pcall(function()
    return MySQL.single.await('SELECT version FROM schema_migrations LIMIT 1')
  end)
  if not ok2 then
    return false, 'schema_invalid'
  end

  return true
end

--- Mark boot as complete (called after all core migrations)
function SetReady()
  _ready = true
  print('^2[core_boot] Platform ready. Schema valid.^0')
end

--- Check if boot complete
---@return boolean
function IsReady()
  return _ready
end

-- Bootstrap on resource start
CreateThread(function()
  print('^3[core_boot] Initializing...^0')

  if not LoadConfig() then
    print('^1[core_boot] CRITICAL: Config load failed. Server may not function correctly.^0')
    return
  end

  -- Wait for oxmysql to be ready
  Wait(500)
  local ok, err = pcall(MySQL.query.await, 'SELECT 1')
  if not ok then
    print('^1[core_boot] CRITICAL: Database connection failed. Check oxmysql connection string.^0')
    print('^1[core_boot] ' .. tostring(err) .. '^0')
    return
  end

  if not RunMigrations() then
    print('^1[core_boot] CRITICAL: Migrations failed. Refusing to continue.^0')
    return
  end

  SetReady()
end)

exports('RunMigrations', RunMigrations)
exports('RunMigrationsFor', RunMigrationsFor)
exports('GetConfig', GetConfig)
exports('HealthCheck', HealthCheck)
exports('IsReady', IsReady)
exports('SetReady', SetReady)
