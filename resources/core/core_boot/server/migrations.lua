local SqlSplit = require 'server/sql_split'

local M = {}

local function loadJsonFromResource(resourceName, path)
  local raw = LoadResourceFile(resourceName, path)
  if not raw or raw == '' then return nil, ('missing file %s'):format(path) end
  local ok, parsed = pcall(json.decode, raw)
  if not ok then return nil, ('invalid json %s'):format(path) end
  return parsed, nil
end

local function ensureSchemaMigrations()
  local sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_schema_migrations.sql')
  if not sql or sql == '' then
    return false, 'core_boot migration file missing'
  end

  for _, stmt in ipairs(SqlSplit.SplitStatements(sql)) do
    local ok, err = pcall(function()
      MySQL.update.await(stmt, {})
    end)
    if not ok then return false, err end
  end

  return true
end

local function isApplied(version)
  local row = MySQL.single.await('SELECT version FROM schema_migrations WHERE version = ? LIMIT 1', { version })
  return row ~= nil
end

local function applyMigration(resourceName, migration)
  local sqlPath = ('migrations/%s'):format(migration.file)
  local raw = LoadResourceFile(resourceName, sqlPath)
  if not raw or raw == '' then
    return false, ('%s missing migration sql %s'):format(resourceName, sqlPath)
  end

  local statements = SqlSplit.SplitStatements(raw)
  if #statements == 0 then
    return false, ('%s migration %s has no statements'):format(resourceName, migration.version)
  end

  for _, stmt in ipairs(statements) do
    local ok, err = pcall(function()
      MySQL.update.await(stmt, {})
    end)
    if not ok then
      return false, err
    end
  end

  MySQL.insert.await('INSERT INTO schema_migrations (version) VALUES (?)', { migration.version })
  return true
end

function M.Run(order, log)
  local ok, err = ensureSchemaMigrations()
  if not ok then return false, ('schema_migrations ensure failed: %s'):format(err) end

  order = order or {}
  for _, resourceName in ipairs(order) do
    local manifest, jerr = loadJsonFromResource(resourceName, 'migrations/migrations.json')
    if not manifest then
      -- resources without migrations are allowed, but P0 expects all core resources to have them
      log.warn(('No migrations manifest for %s (%s)'):format(resourceName, jerr or 'unknown'))
      goto continue
    end

    if type(manifest.migrations) ~= 'table' then
      return false, ('%s migrations.json missing migrations[]'):format(resourceName)
    end

    for _, migration in ipairs(manifest.migrations) do
      if type(migration.version) ~= 'string' or type(migration.file) ~= 'string' then
        return false, ('%s has invalid migration entry'):format(resourceName)
      end
      if not isApplied(migration.version) then
        log.info(('Applying migration %s (%s)'):format(migration.version, resourceName))
        local mok, merr = applyMigration(resourceName, migration)
        if not mok then
          return false, ('migration failed %s: %s'):format(migration.version, merr)
        end
      else
        log.debug(('Migration already applied %s'):format(migration.version))
      end
    end

    ::continue::
  end

  return true
end

return M

