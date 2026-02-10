local M = {}

local function readJson(path)
  local raw = LoadResourceFile(GetCurrentResourceName(), path)
  if not raw or raw == '' then return nil end
  local ok, parsed = pcall(json.decode, raw)
  if not ok then return nil end
  return parsed
end

local function deepMerge(into, from)
  if type(into) ~= 'table' then into = {} end
  if type(from) ~= 'table' then return into end
  for k, v in pairs(from) do
    if type(v) == 'table' and type(into[k]) == 'table' then
      into[k] = deepMerge(into[k], v)
    else
      into[k] = v
    end
  end
  return into
end

function M.Load()
  local cfg = readJson('config/default.json') or {}
  local env = GetConvar('core_env', 'development')
  local envCfg = readJson(('config/%s.json'):format(env)) or {}
  cfg = deepMerge(cfg, envCfg)
  cfg._env = env
  return cfg
end

return M

