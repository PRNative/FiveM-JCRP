--[[
  system_inventory - P1
  Server-authoritative inventory, stackable/unique items, metadata
  Exports: GetInventory, AddItem, RemoveItem, SetSlot, UseItem
]]

local InvMigrations = {
  { version = 'system_inventory_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_inventory.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), InvMigrations)
  if not ok then
    print('^1[system_inventory] Migrations failed^0')
    return
  end
  print('^2[system_inventory] Ready^0')
end)

--- Get full inventory
---@param citizenid string
---@return table
function GetInventory(citizenid)
  if not citizenid then return {} end
  local rows = MySQL.query.await(
    'SELECT slot, item_name, amount, metadata_json FROM character_inventory WHERE citizenid = ? ORDER BY slot',
    { citizenid }
  ) or {}
  return rows
end

--- Find first empty slot
local function FindEmptySlot(citizenid)
  local used = {}
  local rows = MySQL.query.await('SELECT slot FROM character_inventory WHERE citizenid = ?', { citizenid }) or {}
  for _, r in ipairs(rows) do used[r.slot] = true end
  for i = 1, 50 do
    if not used[i] then return i end
  end
  return nil
end

--- Add item
---@param citizenid string
---@param item string
---@param amount number
---@param metadata table|nil
---@return boolean ok, number|nil slot
function AddItem(citizenid, item, amount, metadata)
  if not citizenid or not item or not amount or amount <= 0 then return false, nil end
  local def = MySQL.single.await('SELECT stackable, max_stack FROM item_defs WHERE item_name = ?', { item })
  if not def then return false, nil end
  local metaJson = metadata and json.encode(metadata) or nil
  if def.stackable == 1 then
    local existing = MySQL.single.await('SELECT slot, amount FROM character_inventory WHERE citizenid = ? AND item_name = ? AND (metadata_json IS NULL OR metadata_json = ?)', { citizenid, item, metaJson or 'null' })
    if existing then
      local newAmt = math.min(existing.amount + amount, def.max_stack)
      MySQL.update.await('UPDATE character_inventory SET amount = ?, updated_at = CURRENT_TIMESTAMP WHERE citizenid = ? AND slot = ?', { newAmt, citizenid, existing.slot })
      if newAmt < existing.amount + amount then
        return AddItem(citizenid, item, (existing.amount + amount) - newAmt, metadata)
      end
      return true, existing.slot
    end
  end
  local slot = FindEmptySlot(citizenid)
  if not slot then return false, nil end
  local amt = def.stackable == 1 and math.min(amount, def.max_stack) or 1
  MySQL.insert.await('INSERT INTO character_inventory (citizenid, slot, item_name, amount, metadata_json) VALUES (?, ?, ?, ?, ?)', { citizenid, slot, item, amt, metaJson })
  if amount > amt then return AddItem(citizenid, item, amount - amt, metadata) end
  return true, slot
end

--- Remove item
---@param citizenid string
---@param slot number|nil if nil, remove by item_name
---@param item string|nil required if slot nil
---@param amount number
---@return boolean ok
function RemoveItem(citizenid, slot, item, amount)
  amount = amount or 1
  if slot then
    local row = MySQL.single.await('SELECT amount, item_name FROM character_inventory WHERE citizenid = ? AND slot = ?', { citizenid, slot })
    if not row or row.amount < amount then return false end
    if row.amount == amount then
      MySQL.update.await('DELETE FROM character_inventory WHERE citizenid = ? AND slot = ?', { citizenid, slot })
    else
      MySQL.update.await('UPDATE character_inventory SET amount = amount - ? WHERE citizenid = ? AND slot = ?', { amount, citizenid, slot })
    end
    return true
  elseif item then
    local row = MySQL.single.await('SELECT slot, amount FROM character_inventory WHERE citizenid = ? AND item_name = ? ORDER BY slot LIMIT 1', { citizenid, item })
    if not row then return false end
    return RemoveItem(citizenid, row.slot, nil, amount)
  end
  return false
end

--- Set slot (move/swap)
---@param citizenid string
---@param fromSlot number
---@param toSlot number
---@return boolean ok
function SetSlot(citizenid, fromSlot, toSlot)
  if not citizenid or fromSlot == toSlot then return false end
  local from = MySQL.single.await('SELECT item_name, amount, metadata_json FROM character_inventory WHERE citizenid = ? AND slot = ?', { citizenid, fromSlot })
  if not from then return false end
  local to = MySQL.single.await('SELECT item_name, amount, metadata_json FROM character_inventory WHERE citizenid = ? AND slot = ?', { citizenid, toSlot })
  if to then
    MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE citizenid = ? AND slot = ?', { -fromSlot, citizenid, fromSlot })
    MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE citizenid = ? AND slot = ?', { fromSlot, citizenid, toSlot })
    MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE citizenid = ? AND slot = ?', { toSlot, citizenid, -fromSlot })
  else
    MySQL.update.await('UPDATE character_inventory SET slot = ? WHERE citizenid = ? AND slot = ?', { toSlot, citizenid, fromSlot })
  end
  return true
end

--- Use item (server validates, triggers use logic)
---@param src number
---@param citizenid string
---@param slot number
function UseItem(src, citizenid, slot)
  if not citizenid or not slot then return end
  local row = MySQL.single.await('SELECT item_name, amount, metadata_json FROM character_inventory WHERE citizenid = ? AND slot = ?', { citizenid, slot })
  if not row then return end
  local def = MySQL.single.await('SELECT usable FROM item_defs WHERE item_name = ?', { row.item_name })
  if not def or def.usable ~= 1 then return end
  RemoveItem(citizenid, slot, nil, 1)
  TriggerEvent('system_inventory:itemUsed', src, citizenid, row.item_name, row.metadata_json)
  TriggerClientEvent('system_inventory:itemUsed', src, row.item_name, row.metadata_json)
end

exports('GetInventory', GetInventory)
exports('AddItem', AddItem)
exports('RemoveItem', RemoveItem)
exports('SetSlot', SetSlot)
exports('UseItem', UseItem)
