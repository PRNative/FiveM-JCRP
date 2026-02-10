local M = {}

local levels = {
  error = 0,
  warn = 1,
  info = 2,
  debug = 3,
}

local function shouldLog(cfg, level)
  local cfgLevel = (cfg and cfg.logLevel) or 'info'
  return (levels[level] or 2) <= (levels[cfgLevel] or 2)
end

function M.Make(cfg)
  return {
    error = function(...)
      if shouldLog(cfg, 'error') then
        print(('[core_boot][ERROR] %s'):format(table.concat({ ... }, ' ')))
      end
    end,
    warn = function(...)
      if shouldLog(cfg, 'warn') then
        print(('[core_boot][WARN] %s'):format(table.concat({ ... }, ' ')))
      end
    end,
    info = function(...)
      if shouldLog(cfg, 'info') then
        print(('[core_boot][INFO] %s'):format(table.concat({ ... }, ' ')))
      end
    end,
    debug = function(...)
      if shouldLog(cfg, 'debug') then
        print(('[core_boot][DEBUG] %s'):format(table.concat({ ... }, ' ')))
      end
    end,
  }
end

return M

