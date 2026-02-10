--[[
  ui_loading - P0
  Loading screen, no DB required.
  Brand config from config.json (optional override)
]]

local config = {}
local configLoaded = false

local function LoadConfig()
  if configLoaded then return config end
  local raw = LoadResourceFile(GetCurrentResourceName(), 'config.json')
  if raw and #raw > 0 then
    local ok, data = pcall(json.decode, raw)
    if ok and data then
      config = data
    end
  end
  if not config.loading then
    config.loading = {
      brandName = 'FiveM Platform',
      brandTagline = 'DB-First Roleplay',
      backgroundColor = '#0a0a0f',
      accentColor = '#3b82f6',
    }
  end
  configLoaded = true
  return config
end

-- Pass config to NUI when loading screen is ready
AddEventHandler('onClientResourceStart', function(name)
  if name ~= GetCurrentResourceName() then return end
  LoadConfig()
  -- Loading screen is shown automatically; we shutdown manually when game is ready
end)

-- Manual shutdown when player has loaded
CreateThread(function()
  -- Wait for game to be playable
  while not NetworkIsPlayerActive(PlayerId()) do
    Wait(100)
  end
  Wait(2000)
  ShutdownLoadingScreen()
  ShutdownLoadingScreenNui()
end)
