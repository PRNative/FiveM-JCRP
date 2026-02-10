-- System Apartments Client

-- Enter interior
RegisterNetEvent('system_apartments:enterInterior', function(spawnCoords, unitId)
    DoScreenFadeOut(500)
    Wait(500)
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
    SetEntityHeading(ped, spawnCoords.heading or 0.0)
    
    Wait(500)
    DoScreenFadeIn(500)
end)

-- Exit interior
RegisterNetEvent('system_apartments:exitInterior', function(exitCoords)
    DoScreenFadeOut(500)
    Wait(500)
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
    SetEntityHeading(ped, exitCoords.heading or 0.0)
    
    Wait(500)
    DoScreenFadeIn(500)
end)

print('[^2SYSTEM_APARTMENTS^7] Client initialized')
