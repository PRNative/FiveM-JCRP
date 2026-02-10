-- ============================================================
-- ui_hud: Client — Feeds data to NUI HUD
-- ============================================================

local hudVisible = false
local hudData = {
    money = { cash = 0, bank = 0 },
    job = { label = 'None', grade_label = '', duty = false },
    status = { hunger = 100, thirst = 100, stress = 0 },
    location = { street = '', area = '' },
    health = 200,
    armor = 0,
}

--- Show HUD
RegisterNetEvent('jcrp:hud:show', function()
    hudVisible = true
    SendNUIMessage({ action = 'show' })
end)

--- Hide HUD
RegisterNetEvent('jcrp:hud:hide', function()
    hudVisible = false
    SendNUIMessage({ action = 'hide' })
end)

--- Money update
AddEventHandler('jcrp:hud:updateMoney', function(money)
    hudData.money = money
    SendHudUpdate()
end)

--- Job update
AddEventHandler('jcrp:hud:updateJob', function(job)
    hudData.job = job
    SendHudUpdate()
end)

--- Status update
AddEventHandler('jcrp:hud:updateStatus', function(status)
    hudData.status = status
    SendHudUpdate()
end)

--- Inventory update (badge count)
AddEventHandler('jcrp:hud:updateInventory', function(inventory)
    -- Could show item count or weight
end)

--- Notification system
RegisterNetEvent('jcrp:notification', function(msg, notifType)
    SendNUIMessage({
        action = 'notification',
        message = msg,
        type = notifType or 'info',
    })
end)

--- Send full HUD update to NUI
function SendHudUpdate()
    if not hudVisible then return end
    SendNUIMessage({
        action = 'update',
        data = hudData,
    })
end

-- ============================================================
-- Location + Health/Armor tick (every 1 second)
-- ============================================================
CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if hudVisible then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            -- Street name
            local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash) or ''
            local cross = GetStreetNameFromHashKey(crossHash) or ''

            -- Zone
            local zone = GetNameOfZone(coords.x, coords.y, coords.z)
            local zoneName = GetLabelText(zone) or zone

            hudData.location = {
                street = street,
                cross = cross,
                area = zoneName,
            }

            -- Health & Armor
            hudData.health = GetEntityHealth(ped) - 100 -- Normalize (100 = dead, 200 = full)
            hudData.armor = GetPedArmour(ped)

            -- Speed (if in vehicle)
            hudData.speed = 0
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                hudData.speed = math.floor(GetEntitySpeed(vehicle) * 3.6) -- km/h
            end

            SendHudUpdate()
        end
    end
end)

-- ============================================================
-- Minimap control
-- ============================================================
CreateThread(function()
    while true do
        Citizen.Wait(0)
        if hudVisible then
            -- Keep minimap visible
            DisplayRadar(true)
        end
    end
end)
