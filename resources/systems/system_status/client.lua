--[[
  system_status - Client
  Requests decay from server periodically (server applies it)
]]

CreateThread(function()
  while true do
    Wait(60000)
    TriggerServerEvent('system_status:applyDecay')
  end
end)
