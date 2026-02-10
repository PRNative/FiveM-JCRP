--[[
  core_spawn - Client
  Handles actual teleport and spawn on client
]]

RegisterNetEvent('core_spawn:doSpawn', function(coords)
  local ped = PlayerPedId()
  SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
  SetEntityHeading(ped, coords.w or 0.0)
  FreezeEntityPosition(ped, false)
  SetEntityVisible(ped, true, false)
  SetPlayerInvincible(PlayerId(), false)
  NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.w or 0.0, true, false)
  ClearPedTasksImmediately(ped)
end)
