-- System Apartments Main
SystemApartments = SystemApartments or {}

-- Initialize apartments data on resource start
CreateThread(function()
    if GetResourceState('core_boot') ~= 'started' then
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:WaitForBoot(function()
        Wait(2000)
        
        -- Sync apartment definitions to database
        for _, apartment in ipairs(Apartments) do
            local exists = MySQL.scalar.await('SELECT property_id FROM properties WHERE property_id = ?', {apartment.property_id})
            
            if not exists then
                -- Insert property
                MySQL.insert.await('INSERT INTO properties (property_id, type, label, entry_coords_json) VALUES (?, ?, ?, ?)', {
                    apartment.property_id,
                    apartment.type,
                    apartment.label,
                    json.encode(apartment.entry_coords)
                })
                
                -- Insert units
                for _, unit in ipairs(apartment.units) do
                    MySQL.insert.await('INSERT INTO property_units (property_id, unit_label, interior_id) VALUES (?, ?, ?)', {
                        apartment.property_id,
                        unit.unit_label,
                        unit.interior_id
                    })
                end
            end
        end
        
        print('[^2SYSTEM_APARTMENTS^7] Apartment data synced')
    end)
end)

-- Assign starter apartment to new character
local function AssignStarterApartment(citizenid)
    local autoAssign = exports.core_boot:GetConfig('apartments.auto_assign_on_first_character')
    
    if not autoAssign then
        return
    end
    
    -- Find first available unit
    local units = MySQL.query.await([[
        SELECT pu.unit_id, pu.unit_label, p.label as property_label
        FROM property_units pu
        JOIN properties p ON pu.property_id = p.property_id
        LEFT JOIN property_ownership po ON pu.unit_id = po.unit_id
        WHERE po.id IS NULL
        AND p.type = 'apartment'
        LIMIT 1
    ]])
    
    if units and #units > 0 then
        local unit = units[1]
        
        MySQL.insert.await('INSERT INTO property_ownership (unit_id, citizenid, status) VALUES (?, ?, ?)', {
            unit.unit_id,
            citizenid,
            'owned'
        })
        
        print(string.format('[^2SYSTEM_APARTMENTS^7] Assigned starter apartment to %s: %s %s', citizenid, unit.property_label, unit.unit_label))
    else
        print(string.format('[^3SYSTEM_APARTMENTS^7] No available apartments for %s', citizenid))
    end
end

-- Get owned properties
function SystemApartments.GetOwnedProperties(citizenid)
    local properties = MySQL.query.await([[
        SELECT po.id, po.unit_id, po.status, po.since, po.until,
               pu.unit_label, pu.interior_id,
               p.property_id, p.type, p.label, p.entry_coords_json
        FROM property_ownership po
        JOIN property_units pu ON po.unit_id = pu.unit_id
        JOIN properties p ON pu.property_id = p.property_id
        WHERE po.citizenid = ?
    ]], {citizenid})
    
    if properties then
        for _, property in ipairs(properties) do
            if property.entry_coords_json then
                if type(property.entry_coords_json) == "string" then
                    property.entry_coords = json.decode(property.entry_coords_json)
                else
                    property.entry_coords = property.entry_coords_json
                end
                property.entry_coords_json = nil
            end
        end
    end
    
    return properties or {}
end

-- Enter property
function SystemApartments.EnterProperty(src, unitId)
    if GetResourceState('core_session') ~= 'started' then
        return false, "Session not ready"
    end
    
    local citizenid = exports.core_session:GetCitizenId(src)
    if not citizenid then
        return false, "Not logged in"
    end
    
    -- Check ownership
    local ownership = MySQL.single.await('SELECT id FROM property_ownership WHERE unit_id = ? AND citizenid = ?', {
        unitId,
        citizenid
    })
    
    if not ownership then
        return false, "You don't own this property"
    end
    
    -- Get interior info
    local unit = MySQL.single.await('SELECT interior_id FROM property_units WHERE unit_id = ?', {unitId})
    
    if not unit then
        return false, "Property not found"
    end
    
    local interior = Interiors[unit.interior_id]
    
    if not interior then
        return false, "Interior not configured"
    end
    
    -- Teleport player to interior
    TriggerClientEvent('system_apartments:enterInterior', src, interior.spawn, unitId)
    
    return true
end

-- Exit property
function SystemApartments.ExitProperty(src, unitId)
    -- Get property entry coords
    local property = MySQL.single.await([[
        SELECT p.entry_coords_json
        FROM property_units pu
        JOIN properties p ON pu.property_id = p.property_id
        WHERE pu.unit_id = ?
    ]], {unitId})
    
    if not property then
        return false, "Property not found"
    end
    
    local entryCoords = json.decode(property.entry_coords_json)
    
    -- Teleport player back to entry
    TriggerClientEvent('system_apartments:exitInterior', src, entryCoords)
    
    return true
end

-- Get stash
function SystemApartments.GetStash(unitId)
    local items = MySQL.query.await([[
        SELECT id, slot, item_name, amount, metadata_json
        FROM property_stash
        WHERE unit_id = ?
        ORDER BY slot ASC
    ]], {unitId})
    
    if items then
        for _, item in ipairs(items) do
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

-- Add to stash
function SystemApartments.AddToStash(unitId, itemName, amount, metadata)
    if not unitId or not itemName or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    local itemDef = GetItemDefinition(itemName)
    if not itemDef then
        return false, "Item does not exist"
    end
    
    metadata = metadata or {}
    
    -- Find next available slot (simplified, can be improved)
    local maxSlot = MySQL.scalar.await('SELECT COALESCE(MAX(slot), 0) FROM property_stash WHERE unit_id = ?', {unitId})
    local nextSlot = (maxSlot or 0) + 1
    
    if nextSlot > 100 then -- Max 100 slots for stash
        return false, "Stash is full"
    end
    
    MySQL.insert('INSERT INTO property_stash (unit_id, slot, item_name, amount, metadata_json) VALUES (?, ?, ?, ?, ?)', {
        unitId,
        nextSlot,
        itemName,
        amount,
        json.encode(metadata)
    })
    
    return true, "Item added to stash"
end

-- Remove from stash
function SystemApartments.RemoveFromStash(unitId, slot, amount)
    local item = MySQL.single.await('SELECT id, amount, item_name FROM property_stash WHERE unit_id = ? AND slot = ?', {
        unitId,
        slot
    })
    
    if not item then
        return false, "Item not found"
    end
    
    if item.amount < amount then
        return false, "Not enough items"
    end
    
    if item.amount == amount then
        -- Remove entire stack
        MySQL.update('DELETE FROM property_stash WHERE id = ?', {item.id})
    else
        -- Reduce amount
        MySQL.update('UPDATE property_stash SET amount = amount - ? WHERE id = ?', {
            amount,
            item.id
        })
    end
    
    return true, item.item_name
end

-- Listen to character creation
AddEventHandler('core_characters:created', function(citizenid, accountId)
    AssignStarterApartment(citizenid)
end)

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    -- Get owned properties
    local properties = SystemApartments.GetOwnedProperties(citizenid)
    
    for _, property in ipairs(properties) do
        -- Clear stash
        MySQL.update('DELETE FROM property_stash WHERE unit_id = ?', {property.unit_id})
        
        -- Remove ownership
        MySQL.update('DELETE FROM property_ownership WHERE citizenid = ?', {citizenid})
    end
    
    print(string.format('[^2SYSTEM_APARTMENTS^7] Cleaned up properties for character: %s', citizenid))
end)

-- Callbacks
lib.callback.register('system_apartments:getOwnedProperties', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    return SystemApartments.GetOwnedProperties(citizenid)
end)

lib.callback.register('system_apartments:enterProperty', function(source, unitId)
    return SystemApartments.EnterProperty(source, unitId)
end)

lib.callback.register('system_apartments:exitProperty', function(source, unitId)
    return SystemApartments.ExitProperty(source, unitId)
end)

lib.callback.register('system_apartments:getStash', function(source, unitId)
    -- Verify ownership
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    local ownership = MySQL.scalar.await('SELECT id FROM property_ownership WHERE unit_id = ? AND citizenid = ?', {
        unitId,
        citizenid
    })
    
    if not ownership then
        return {}
    end
    
    return SystemApartments.GetStash(unitId)
end)

-- Exports
exports('GetOwnedProperties', SystemApartments.GetOwnedProperties)
exports('EnterProperty', SystemApartments.EnterProperty)
exports('ExitProperty', SystemApartments.ExitProperty)
exports('GetStash', SystemApartments.GetStash)
exports('AddToStash', SystemApartments.AddToStash)
exports('RemoveFromStash', SystemApartments.RemoveFromStash)

print('[^2SYSTEM_APARTMENTS^7] Initialized')
