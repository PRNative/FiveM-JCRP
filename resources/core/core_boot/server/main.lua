local Config = require 'server/config'
local Log = require 'server/log'
local Migrations = require 'server/migrations'

local cfg = nil
local logger = nil
local healthy = false

local function quitServer(reason)
  print(('[core_boot][FATAL] %s'):format(reason))
  -- best-effort: quit command + os.exit fallback
  pcall(function()
    ExecuteCommand('quit')
  end)
  pcall(function()
    os.exit()
  end)
end

local function dbHealthCheck()
  local ok, err = pcall(function()
    return MySQL.scalar.await('SELECT 1', {})
  end)
  if not ok then return false, err end
  return true
end

CreateThread(function()
  cfg = Config.Load()
  logger = Log.Make(cfg)

  logger.info(('Boot env=%s'):format(cfg._env or 'unknown'))

  local dbOk, dbErr = dbHealthCheck()
  if not dbOk then
    quitServer(('DB connectivity failed (check mysql_connection_string): %s'):format(dbErr))
    return
  end

  local order = (((cfg or {}).migrations or {}).order) or {}
  local migOk, migErr = Migrations.Run(order, logger)
  if not migOk then
    quitServer(('Migrations failed: %s'):format(migErr))
    return
  end

  healthy = true
  GlobalState['core_boot:ready'] = true
  GlobalState['core_boot:booted_at'] = os.time()
  logger.info('Boot complete; schema OK')
end)

exports('RunMigrations', function()
  if not cfg then cfg = Config.Load() end
  if not logger then logger = Log.Make(cfg) end
  local order = (((cfg or {}).migrations or {}).order) or {}
  return Migrations.Run(order, logger)
end)

exports('GetConfig', function()
  if not cfg then cfg = Config.Load() end
  return cfg
end)

exports('HealthCheck', function()
  return healthy == true
end)

