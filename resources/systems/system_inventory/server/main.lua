-- System Inventory Main
SystemInventory = SystemInventory or {}

local maxSlots = 40 -- Can be made configurable

-- Initialize inventory for new character
local function InitializeInventory(citizenid)
    -- Add starter items (ID card, phone, etc.)
    SystemInventory.AddItem(citizenid, 'id_card', 1, {})
    SystemInventory.AddItem(citizenid, 'phone', 1, {})
    SystemInventory.AddItem(citizenid, 'water', 2, {})
    SystemInventory.AddItem(citizenid, 'sandwich', 2, {})
    
    print(string.format('[^2SYSTEM_INVENTORY^7] Initialized inventory for character: %s', citizenid))
end

-- Get inventory
function SystemInventory.GetInventory(citizenid)
    local items = MySQL.query.await([[
        SELECT id, slot, item_name, amount, metadata_json
        FROM character_inventory
        WHERE citizenid = ?
        ORDER BY slot ASC
    ]], {citizenid})
    
    if items then
        for _, item in ipairs(items) do
            -- Parse metadata
            if item.metadata_json then
                if type(item.metadata_json) == "string" then
                    item.metadata = json.decode(item.metadata_json)
                else
                    item.metadata = item.metadata_json
                end
                item.metadata_json = nil
            else
                item.metadata = {}
            end
            
            -- Add item definition
            item.definition = GetItemDefinition(item.item_name)
        end
    end
    
    return items or {}
end

-- Find next available slot
local function FindNextSlot(citizenid)
    local inventory = SystemInventory.GetInventory(citizenid)
    local usedSlots = {}
    
    for _, item in ipairs(inventory) do
        usedSlots[item.slot] = true
    end
    
    for i = 1, maxSlots do
        if not usedSlots[i] then
            return i
        end
    end
    
    return nil -- Inventory full
end

-- Add item
function SystemInventory.AddItem(citizenid, itemName, amount, metadata)
    if not citizenid or not itemName or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    local itemDef = GetItemDefinition(itemName)
    if not itemDef then
        return false, "Item does not exist"
    end
    
    metadata = metadata or {}
    
    -- If stackable, try to add to existing stack
    if itemDef.stackable then
        local inventory = SystemInventory.GetInventory(citizenid)
        
        for _, item in ipairs(inventory) do
            if item.item_name == itemName then
                local maxStack = itemDef.max_stack or 1
                local canAdd = maxStack - item.amount
                
                if canAdd > 0 then
                    local addAmount = math.min(amount, canAdd)
                    
                    MySQL.update('UPDATE character_inventory SET amount = amount + ? WHERE id = ?', {
                        addAmount,
                        item.id
                    })
                    
                    amount = amount - addAmount
                    
                    if amount <= 0 then
                        return true, "Item added to existing stack"
                    end
                end
            end
        end
    end
    
    -- Add remaining amount to new slots
    while amount > 0 do
        local slot = FindNextSlot(citizenid)
        
        if not slot then
            return false, "Inventory full"
        end
        
        local addAmount = amount
        if itemDef.stackable then
            addAmount = math.min(amount, itemDef.max_stack or 1)
        else
            addAmount = 1
        end
        
        MySQL.insert('INSERT INTO character_inventory (citizenid, slot, item_name, amount, metadata_json) VALUES (?, ?, ?, ?, ?)', {
            citizenid,
            slot,
            itemName,
            addAmount,
            json.encode(metadata)
        })
        
        amount = amount - addAmount
    end
    
    -- Notify player if online
    local src = SystemInventory.GetPlayerByCitizenId(citizenid)
    if src then
        TriggerClientEvent('system_inventory:refresh', src)
    end
    
    return true, "Item added"
end

-- Remove item
function SystemInventory.RemoveItem(citizenid, itemName, amount, slot)
    if not citizenid or not itemName or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    local inventory = SystemInventory.GetInventory(citizenid)
    local removed = 0
    
    -- If slot specified, remove from that slot only
    if slot then
        for _, item in ipairs(inventory) do
            if item.slot == slot and item.item_name == itemName then
                local removeAmount = math.min(amount, item.amount)
                
                if item.amount <= removeAmount then
                    -- Remove entire stack
                    MySQL.update('DELETE FROM character_inventory WHERE id = ?', {item.id})
                else
                    -- Reduce amount
                    MySQL.update('UPDATE character_inventory SET amount = amount - ? WHERE id = ?', {
                        removeAmount,
                        item.id
                    })
                end
                
                removed = removed + removeAmount
                break
            end
        end
    else
        -- Remove from any slot
        for _, item in ipairs(inventory) do
            if item.item_name == itemName and removed < amount then
                local removeAmount = math.min(amount - removed, item.amount)
                
                if item.amount <= removeAmount then
                    -- Remove entire stack
                    MySQL.update('DELETE FROM character_inventory WHERE id = ?', {item.id})
                else
                    -- Reduce amount
                    MySQL.update('UPDATE character_inventory SET amount = amount - ? WHERE id = ?', {
                        removeAmount,
                        item.id
                    })
                end
                
                removed = removed + removeAmount
                
                if removed >= amount then
                    break
                end
            end
        end
    end
    
    if removed < amount then
        return false, "Not enough items"
    end
    
    -- Notify player if online
    local src = SystemInventory.GetPlayerByCitizenId(citizenid)
    if src then
        TriggerClientEvent('system_inventory:refresh', src)
    end
    
    return true, "Item removed"
end

-- Use item
function SystemInventory.UseItem(src, citizenid, slot)
    local inventory = SystemInventory.GetInventory(citizenid)
    local item = nil
    
    for _, invItem in ipairs(inventory) do
        if invItem.slot == slot then
            item = invItem
            break
        end
    end
    
    if not item then
        return false, "Item not found"
    end
    
    local itemDef = GetItemDefinition(item.item_name)
    if not itemDef or not itemDef.usable then
        return false, "Item is not usable"
    end
    
    -- Trigger item use event
    TriggerEvent('system_inventory:itemUsed', src, citizenid, item.item_name, item.metadata)
    
    -- Handle specific items
    if item.item_name == 'water' then
        -- Restore thirst
        if GetResourceState('system_status') == 'started' then
            exports.system_status:ModifyStatus(citizenid, 'thirst', 30)
        end
        SystemInventory.RemoveItem(citizenid, 'water', 1, slot)
        TriggerClientEvent('system_inventory:notify', src, 'You drank water')
    elseif item.item_name == 'sandwich' or item.item_name == 'burger' then
        -- Restore hunger
        if GetResourceState('system_status') == 'started' then
            exports.system_status:ModifyStatus(citizenid, 'hunger', 30)
        end
        SystemInventory.RemoveItem(citizenid, item.item_name, 1, slot)
        TriggerClientEvent('system_inventory:notify', src, 'You ate ' .. itemDef.label)
    elseif item.item_name == 'phone' then
        -- Open phone (would integrate with phone system)
        TriggerClientEvent('system_inventory:notify', src, 'Opening phone...')
    end
    
    return true, "Item used"
end

-- Get item count
function SystemInventory.GetItemCount(citizenid, itemName)
    local count = MySQL.scalar.await([[
        SELECT COALESCE(SUM(amount), 0)
        FROM character_inventory
        WHERE citizenid = ? AND item_name = ?
    ]], {citizenid, itemName})
    
    return count or 0
end

-- Has item
function SystemInventory.HasItem(citizenid, itemName, amount)
    amount = amount or 1
    local count = SystemInventory.GetItemCount(citizenid, itemName)
    return count >= amount
end

-- Helper to get player source by citizenid
function SystemInventory.GetPlayerByCitizenId(citizenid)
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        if GetResourceState('core_session') == 'started' then
            local playerCitizenId = exports.core_session:GetCitizenId(src)
            if playerCitizenId == citizenid then
                return src
            end
        end
    end
    
    return nil
end

-- Listen to character creation
AddEventHandler('core_characters:created', function(citizenid, accountId)
    InitializeInventory(citizenid)
end)

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM character_inventory WHERE citizenid = ?', {citizenid})
    print(string.format('[^2SYSTEM_INVENTORY^7] Cleaned up inventory for character: %s', citizenid))
end)

-- Callbacks
lib.callback.register('system_inventory:getInventory', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    return SystemInventory.GetInventory(citizenid)
end)

lib.callback.register('system_inventory:useItem', function(source, slot)
    if GetResourceState('core_session') ~= 'started' then
        return {success = false, message = "Session not ready"}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {success = false, message = "Not logged in"}
    end
    
    local success, message = SystemInventory.UseItem(source, citizenid, slot)
    return {success = success, message = message}
end)

-- Exports
exports('GetInventory', SystemInventory.GetInventory)
exports('AddItem', SystemInventory.AddItem)
exports('RemoveItem', SystemInventory.RemoveItem)
exports('UseItem', SystemInventory.UseItem)
exports('GetItemCount', SystemInventory.GetItemCount)
exports('HasItem', SystemInventory.HasItem)

-- Sync item definitions to database on resource start
CreateThread(function()
    -- Wait for boot
    if GetResourceState('core_boot') ~= 'started' then
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:WaitForBoot(function()
        Wait(2000) -- Wait for migrations
        
        -- Sync items
        for itemName, itemData in pairs(Items) do
            local existing = MySQL.scalar.await('SELECT item_name FROM item_defs WHERE item_name = ?', {itemName})
            
            if not existing then
                MySQL.insert('INSERT INTO item_defs (item_name, label, description, weight, stackable, max_stack, usable) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                    itemName,
                    itemData.label,
                    itemData.description or '',
                    itemData.weight or 0,
                    itemData.stackable and 1 or 0,
                    itemData.max_stack or 1,
                    itemData.usable and 1 or 0
                })
            end
        end
        
        print('[^2SYSTEM_INVENTORY^7] Item definitions synced to database')
    end)
end)

print('[^2SYSTEM_INVENTORY^7] Initialized')
