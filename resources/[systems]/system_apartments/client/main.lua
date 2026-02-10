-- ============================================================
-- system_apartments: Client
-- Property entry/exit, stash interaction
-- ============================================================

local insideProperty = nil -- { unit_id, coords, label }
local previousCoords = nil

--- Enter a property
RegisterNetEvent('jcrp:apartments:enter', function(data)
    if not data or not data.coords then return end

    local ped = PlayerPedId()
    previousCoords = GetEntityCoords(ped)

    -- Fade out
    DoScreenFadeOut(500)
    Citizen.Wait(600)

    -- Teleport to interior
    SetEntityCoords(ped, data.coords.x, data.coords.y, data.coords.z, false, false, false, false)
    insideProperty = data

    Citizen.Wait(500)
    DoScreenFadeIn(500)

    TriggerEvent('jcrp:notification', ('Entered: %s'):format(data.label or 'Property'), 'info')
end)

--- Exit a property
RegisterNetEvent('jcrp:apartments:exit', function()
    if not insideProperty or not previousCoords then return end

    local ped = PlayerPedId()

    DoScreenFadeOut(500)
    Citizen.Wait(600)

    SetEntityCoords(ped, previousCoords.x, previousCoords.y, previousCoords.z, false, false, false, false)
    insideProperty = nil
    previousCoords = nil

    Citizen.Wait(500)
    DoScreenFadeIn(500)

    TriggerEvent('jcrp:notification', 'Left property.', 'info')
end)

--- Stash data received
RegisterNetEvent('jcrp:apartments:stashData', function(stash, unitId)
    -- Forward to inventory UI when implemented
    TriggerEvent('jcrp:inventory:openStash', stash, unitId)
end)

--- Check if inside property
function IsInsideProperty()
    return insideProperty ~= nil
end

function GetCurrentProperty()
    return insideProperty
end

exports('IsInsideProperty', IsInsideProperty)
exports('GetCurrentProperty', GetCurrentProperty)
