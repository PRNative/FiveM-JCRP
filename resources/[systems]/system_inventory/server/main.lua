-- ============================================================
-- system_inventory: Server-Authoritative Inventory
-- ============================================================

-- In-memory cache: citizenid -> { slots = { [slot] = {item, amount, metadata} } }
local InventoryCache = {}

local MAX_SLOTS = 40
local MAX_WEIGHT = 120.0

-- ============================================================
-- Internal helpers
-- ============================================================

--- Load inventory from DB
---@param citizenid string
---@return table inventory
local function LoadInventory(citizenid)
    if InventoryCache[citizenid] then
        return InventoryCache[citizenid]
    end

    local rows = MySQL.query.await(
        'SELECT * FROM character_inventory WHERE citizenid = ? ORDER BY slot ASC',
        { citizenid }
    )

    local inventory = { slots = {}, citizenid = citizenid }

    if rows then
        for _, row in ipairs(rows) do
            inventory.slots[row.slot] = {
                item_name = row.item_name,
                amount = row.amount,
                metadata = JCRP.JsonDecode(row.metadata_json, {}),
                slot = row.slot,
                id = row.id,
            }
        end
    end

    InventoryCache[citizenid] = inventory
    return inventory
end

--- Get the total weight of an inventory
---@param inventory table
---@return number
local function CalcWeight(inventory)
    local total = 0.0
    for _, slotData in pairs(inventory.slots) do
        local def = GetItemDef(slotData.item_name)
        if def then
            total = total + (def.weight * slotData.amount)
        end
    end
    return total
end

--- Find first available slot
---@param inventory table
---@return number|nil
local function FindEmptySlot(inventory)
    for i = 1, MAX_SLOTS do
        if not inventory.slots[i] then
            return i
        end
    end
    return nil
end

--- Find slot with existing stackable item that has room
---@param inventory table
---@param itemName string
---@return number|nil slot
local function FindStackableSlot(inventory, itemName)
    local def = GetItemDef(itemName)
    if not def or not def.stackable then return nil end

    for slot, slotData in pairs(inventory.slots) do
        if slotData.item_name == itemName and slotData.amount < def.max_stack then
            return slot
        end
    end
    return nil
end

--- Save a single slot to DB
---@param citizenid string
---@param slot number
---@param slotData table|nil (nil = delete)
local function SaveSlot(citizenid, slot, slotData)
    if slotData then
        MySQL.query.await([[
            INSERT INTO character_inventory (citizenid, slot, item_name, amount, metadata_json)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), amount = VALUES(amount), metadata_json = VALUES(metadata_json), updated_at = NOW()
        ]], {
            citizenid, slot, slotData.item_name, slotData.amount,
            JCRP.JsonEncode(slotData.metadata or {}),
        })
    else
        MySQL.query.await(
            'DELETE FROM character_inventory WHERE citizenid = ? AND slot = ?',
            { citizenid, slot }
        )
    end
end

--- Notify client of inventory update
---@param citizenid string
local function NotifyClient(citizenid)
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        local inv = InventoryCache[citizenid]
        if inv then
            TriggerClientEvent('jcrp:inventory:update', src, inv.slots)
        end
    end
end

-- ============================================================
-- Public API
-- ============================================================

--- Get full inventory for a character
---@param citizenid string
---@return table slots
local function GetInventory(citizenid)
    local inv = LoadInventory(citizenid)
    -- Return enriched slots with item defs
    local result = {}
    for slot, slotData in pairs(inv.slots) do
        local def = GetItemDef(slotData.item_name)
        result[slot] = {
            slot = slot,
            item_name = slotData.item_name,
            amount = slotData.amount,
            metadata = slotData.metadata,
            label = def and def.label or slotData.item_name,
            weight = def and def.weight or 0,
            stackable = def and def.stackable or false,
            usable = def and def.usable or false,
            category = def and def.category or 'misc',
        }
    end
    return result
end

--- Add an item to inventory
---@param citizenid string
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean success
---@return string|nil error
local function AddItem(citizenid, itemName, amount, metadata)
    if not citizenid or not itemName then return false, 'Missing parameters' end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return false, 'Amount must be positive' end

    local def = GetItemDef(itemName)
    if not def then return false, 'Unknown item: ' .. tostring(itemName) end

    local inv = LoadInventory(citizenid)

    -- Check weight
    local addedWeight = def.weight * amount
    local currentWeight = CalcWeight(inv)
    if currentWeight + addedWeight > MAX_WEIGHT then
        return false, 'Inventory full (weight limit)'
    end

    local remaining = amount

    -- Try stacking first
    if def.stackable then
        while remaining > 0 do
            local stackSlot = FindStackableSlot(inv, itemName)
            if not stackSlot then break end

            local canAdd = math.min(remaining, def.max_stack - inv.slots[stackSlot].amount)
            inv.slots[stackSlot].amount = inv.slots[stackSlot].amount + canAdd
            SaveSlot(citizenid, stackSlot, inv.slots[stackSlot])
            remaining = remaining - canAdd
        end
    end

    -- Place remaining in empty slots
    while remaining > 0 do
        local emptySlot = FindEmptySlot(inv)
        if not emptySlot then
            return false, 'Inventory full (no slots)'
        end

        local placeAmount = def.stackable and math.min(remaining, def.max_stack) or 1
        inv.slots[emptySlot] = {
            item_name = itemName,
            amount = placeAmount,
            metadata = metadata or {},
            slot = emptySlot,
        }
        SaveSlot(citizenid, emptySlot, inv.slots[emptySlot])
        remaining = remaining - placeAmount
    end

    InventoryCache[citizenid] = inv
    NotifyClient(citizenid)

    JCRP.Log('system_inventory', 'DEBUG', ('+%d %s for %s'):format(amount, itemName, citizenid))
    return true, nil
end

--- Remove an item from inventory
---@param citizenid string
---@param itemName string
---@param amount number
---@return boolean success
---@return string|nil error
local function RemoveItem(citizenid, itemName, amount)
    if not citizenid or not itemName then return false, 'Missing parameters' end

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return false, 'Amount must be positive' end

    local inv = LoadInventory(citizenid)

    -- Count total of this item
    local total = 0
    local itemSlots = {}
    for slot, slotData in pairs(inv.slots) do
        if slotData.item_name == itemName then
            total = total + slotData.amount
            itemSlots[#itemSlots + 1] = slot
        end
    end

    if total < amount then
        return false, 'Not enough items (have ' .. total .. ', need ' .. amount .. ')'
    end

    -- Remove from slots (LIFO order by slot number, descending)
    table.sort(itemSlots, function(a, b) return a > b end)

    local remaining = amount
    for _, slot in ipairs(itemSlots) do
        if remaining <= 0 then break end

        local slotData = inv.slots[slot]
        local removeFromSlot = math.min(remaining, slotData.amount)
        slotData.amount = slotData.amount - removeFromSlot
        remaining = remaining - removeFromSlot

        if slotData.amount <= 0 then
            inv.slots[slot] = nil
            SaveSlot(citizenid, slot, nil)
        else
            inv.slots[slot] = slotData
            SaveSlot(citizenid, slot, slotData)
        end
    end

    InventoryCache[citizenid] = inv
    NotifyClient(citizenid)

    JCRP.Log('system_inventory', 'DEBUG', ('-%d %s for %s'):format(amount, itemName, citizenid))
    return true, nil
end

--- Set a specific slot's contents
---@param citizenid string
---@param slot number
---@param itemName string|nil (nil to clear)
---@param amount number|nil
---@param metadata table|nil
---@return boolean
local function SetSlot(citizenid, slot, itemName, amount, metadata)
    local inv = LoadInventory(citizenid)

    if not itemName then
        inv.slots[slot] = nil
        SaveSlot(citizenid, slot, nil)
    else
        inv.slots[slot] = {
            item_name = itemName,
            amount = amount or 1,
            metadata = metadata or {},
            slot = slot,
        }
        SaveSlot(citizenid, slot, inv.slots[slot])
    end

    InventoryCache[citizenid] = inv
    NotifyClient(citizenid)
    return true
end

--- Use an item (server-authoritative callback)
---@param src number
---@param citizenid string
---@param slot number
---@return boolean
local function UseItem(src, citizenid, slot)
    local inv = LoadInventory(citizenid)
    local slotData = inv.slots[slot]
    if not slotData then return false end

    local def = GetItemDef(slotData.item_name)
    if not def or not def.usable then return false end

    -- Trigger item use event for other resources to handle
    TriggerEvent('jcrp:inventory:itemUsed', src, citizenid, slotData.item_name, slot, slotData.metadata)
    TriggerClientEvent('jcrp:inventory:itemUsed', src, slotData.item_name, slot, slotData.metadata)

    JCRP.Log('system_inventory', 'DEBUG', ('Item used: %s slot %d by %s'):format(slotData.item_name, slot, citizenid))
    return true
end

--- Check if character has enough of an item
---@param citizenid string
---@param itemName string
---@param amount number|nil defaults to 1
---@return boolean
local function HasItem(citizenid, itemName, amount)
    amount = amount or 1
    local inv = LoadInventory(citizenid)
    local total = 0
    for _, slotData in pairs(inv.slots) do
        if slotData.item_name == itemName then
            total = total + slotData.amount
        end
    end
    return total >= amount
end

--- Get count of a specific item
---@param citizenid string
---@param itemName string
---@return number
local function GetItemCount(citizenid, itemName)
    local inv = LoadInventory(citizenid)
    local total = 0
    for _, slotData in pairs(inv.slots) do
        if slotData.item_name == itemName then
            total = total + slotData.amount
        end
    end
    return total
end

--- Unload inventory from cache
---@param citizenid string
local function UnloadInventory(citizenid)
    InventoryCache[citizenid] = nil
end

-- ============================================================
-- Server Events
-- ============================================================

--- Client requests to use an item
RegisterNetEvent('jcrp:inventory:useItem', function(slot)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    UseItem(src, citizenid, slot)
end)

-- ============================================================
-- Resource Stop
-- ============================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Cache is DB-synced per operation, nothing to flush
        JCRP.Log('system_inventory', 'INFO', 'system_inventory stopping.')
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetInventory', GetInventory)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('SetSlot', SetSlot)
exports('UseItem', UseItem)
exports('HasItem', HasItem)
exports('GetItemCount', GetItemCount)
exports('UnloadInventory', UnloadInventory)

JCRP.Log('system_inventory', 'INFO', 'system_inventory loaded.')
