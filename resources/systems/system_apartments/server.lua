--[[
  system_apartments - P2 (Schema + API stubs)
  Starter apartments, instanced interiors, stash
  Exports: GetOwnedProperties, AssignStarterApartment, EnterProperty, GetStash, AddToStash, RemoveFromStash
]]

local AptMigrations = {
  { version = 'system_apartments_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_apartments.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), AptMigrations)
  if not ok then
    print('^1[system_apartments] Migrations failed^0')
    return
  end
  print('^2[system_apartments] Ready (schema only, full implementation P2)^0')
end)

function GetOwnedProperties(citizenid)
  if not citizenid then return {} end
  return MySQL.query.await([[
    SELECT po.*, pu.unit_label, p.label as property_label
    FROM property_ownership po
    JOIN property_units pu ON pu.unit_id = po.unit_id
    JOIN properties p ON p.property_id = pu.property_id
    WHERE po.citizenid = ?
  ]], { citizenid }) or {}
end

function AssignStarterApartment(citizenid)
  if not citizenid then return nil end
  -- Stub: create default property + unit, assign to citizen
  local prop = MySQL.single.await('SELECT property_id FROM properties LIMIT 1')
  if not prop then return nil end
  local unit = MySQL.single.await('SELECT unit_id FROM property_units WHERE property_id = ? LIMIT 1', { prop.property_id })
  if not unit then return nil end
  MySQL.insert.await('INSERT IGNORE INTO property_ownership (unit_id, citizenid, status) VALUES (?, ?, ?)', { unit.unit_id, citizenid, 'rented' })
  return unit.unit_id
end

function EnterProperty(src, unit_id)
  -- Stub: teleport to interior
  if not src or not unit_id then return false end
  return true
end

function GetStash(unit_id)
  if not unit_id then return {} end
  return MySQL.query.await('SELECT slot, item_name, amount, metadata_json FROM property_stash WHERE unit_id = ? ORDER BY slot', { unit_id }) or {}
end

function AddToStash(unit_id, item_name, amount, metadata)
  if not unit_id or not item_name or not amount or amount <= 0 then return false end
  local metaJson = metadata and json.encode(metadata) or nil
  local existing = MySQL.single.await('SELECT slot, amount FROM property_stash WHERE unit_id = ? AND item_name = ? LIMIT 1', { unit_id, item_name })
  if existing then
    MySQL.update.await('UPDATE property_stash SET amount = amount + ?, metadata_json = ? WHERE unit_id = ? AND slot = ?', { amount, metaJson, unit_id, existing.slot })
  else
    local maxSlot = MySQL.scalar.await('SELECT COALESCE(MAX(slot), 0) + 1 FROM property_stash WHERE unit_id = ?', { unit_id }) or 1
    MySQL.insert.await('INSERT INTO property_stash (unit_id, slot, item_name, amount, metadata_json) VALUES (?, ?, ?, ?, ?)', { unit_id, maxSlot, item_name, amount, metaJson })
  end
  return true
end

function RemoveFromStash(unit_id, slot, amount)
  if not unit_id or not slot or not amount or amount <= 0 then return false end
  local row = MySQL.single.await('SELECT amount FROM property_stash WHERE unit_id = ? AND slot = ?', { unit_id, slot })
  if not row or row.amount < amount then return false end
  if row.amount == amount then
    MySQL.update.await('DELETE FROM property_stash WHERE unit_id = ? AND slot = ?', { unit_id, slot })
  else
    MySQL.update.await('UPDATE property_stash SET amount = amount - ? WHERE unit_id = ? AND slot = ?', { amount, unit_id, slot })
  end
  return true
end

exports('GetOwnedProperties', GetOwnedProperties)
exports('AssignStarterApartment', AssignStarterApartment)
exports('EnterProperty', EnterProperty)
exports('GetStash', GetStash)
exports('AddToStash', AddToStash)
exports('RemoveFromStash', RemoveFromStash)
