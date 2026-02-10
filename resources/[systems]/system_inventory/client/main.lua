-- ============================================================
-- system_inventory: Client
-- Receives inventory updates, forwards to UI
-- ============================================================

local currentInventory = {}

--- Receive inventory update from server
RegisterNetEvent('jcrp:inventory:update', function(slots)
    if type(slots) ~= 'table' then return end
    currentInventory = slots
    TriggerEvent('jcrp:hud:updateInventory', currentInventory)
end)

--- Item used notification
RegisterNetEvent('jcrp:inventory:itemUsed', function(itemName, slot, metadata)
    -- Handle client-side effects of item use
    if itemName == 'water' then
        -- Example: play drinking animation
        TriggerEvent('jcrp:status:drink')
    elseif itemName == 'bread' or itemName == 'burger' then
        TriggerEvent('jcrp:status:eat')
    elseif itemName == 'bandage' or itemName == 'medkit' then
        TriggerEvent('jcrp:status:heal')
    end
end)

--- Request to use an item from UI
function UseItemInSlot(slot)
    TriggerServerEvent('jcrp:inventory:useItem', slot)
end

exports('GetCurrentInventory', function() return currentInventory end)
exports('UseItemInSlot', UseItemInSlot)
