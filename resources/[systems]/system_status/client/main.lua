-- ============================================================
-- system_status: Client
-- Receives status updates, handles critical states
-- ============================================================

local currentStatus = { hunger = 100, thirst = 100, stress = 0 }

--- Receive status update from server
RegisterNetEvent('jcrp:status:update', function(status)
    if type(status) ~= 'table' then return end
    currentStatus = status
    TriggerEvent('jcrp:hud:updateStatus', currentStatus)
end)

--- Critical status — take health damage
RegisterNetEvent('jcrp:status:critical', function(critical)
    local ped = PlayerPedId()
    if critical.hunger then
        local health = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(100, health - 5))
    end
    if critical.thirst then
        local health = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(100, health - 3))
    end
end)

--- Eat handler (called from inventory item use)
RegisterNetEvent('jcrp:status:eat', function()
    -- Request server to add hunger
    TriggerServerEvent('jcrp:status:modify', 'hunger', 25)
end)

--- Drink handler
RegisterNetEvent('jcrp:status:drink', function()
    TriggerServerEvent('jcrp:status:modify', 'thirst', 30)
end)

--- Heal handler
RegisterNetEvent('jcrp:status:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
end)

--- Server event for status modifications from client actions
RegisterNetEvent('jcrp:status:modify')

exports('GetCurrentStatus', function() return currentStatus end)
