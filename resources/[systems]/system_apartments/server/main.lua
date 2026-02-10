-- ============================================================
-- system_apartments: Property & Apartment System (Server)
-- ============================================================

--- Get all properties owned by a citizen
---@param citizenid string
---@return table
local function GetOwnedProperties(citizenid)
    local rows = MySQL.query.await([[
        SELECT po.*, pu.unit_label, pu.property_id, p.label, p.type, p.entry_coords_json, p.interior_coords_json
        FROM property_ownership po
        JOIN property_units pu ON pu.unit_id = po.unit_id
        JOIN properties p ON p.property_id = pu.property_id
        WHERE po.citizenid = ? AND po.status IN ('owned','rented')
    ]], { citizenid })
    return rows or {}
end

--- Assign a starter apartment unit to a citizen
---@param citizenid string
---@return boolean success
---@return number|nil unitId
local function AssignStarterApartment(citizenid)
    local config = exports['core_boot']:GetConfig()
    local starterPropertyId = config.apartments and config.apartments.starter_apartment_id or 1

    -- Check if already has a property
    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM property_ownership WHERE citizenid = ? AND status IN (\'owned\',\'rented\')',
        { citizenid }
    )
    if existing and existing > 0 then
        return false, nil -- Already has a property
    end

    -- Create a new unit in the starter property
    local unitLabel = ('Apt #%s'):format(citizenid:sub(-4))
    local unitId = MySQL.insert.await(
        'INSERT INTO property_units (property_id, unit_label) VALUES (?, ?)',
        { starterPropertyId, unitLabel }
    )

    if not unitId then return false, nil end

    -- Assign ownership
    MySQL.insert.await(
        'INSERT INTO property_ownership (unit_id, citizenid, status) VALUES (?, ?, \'owned\')',
        { unitId, citizenid }
    )

    JCRP.Log('system_apartments', 'INFO', ('Starter apartment assigned to %s: unit %d'):format(citizenid, unitId))
    return true, unitId
end

--- Enter a property (teleport to interior)
---@param src number
---@param unitId number
local function EnterProperty(src, unitId)
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    -- Verify ownership/access
    local ownership = MySQL.single.await([[
        SELECT po.*, p.interior_coords_json, p.label
        FROM property_ownership po
        JOIN property_units pu ON pu.unit_id = po.unit_id
        JOIN properties p ON p.property_id = pu.property_id
        WHERE po.unit_id = ? AND po.citizenid = ? AND po.status IN ('owned','rented')
    ]], { unitId, citizenid })

    if not ownership then
        TriggerClientEvent('jcrp:notification', src, 'You don\'t have access to this property.', 'error')
        return
    end

    local interiorCoords = JCRP.JsonDecode(ownership.interior_coords_json, nil)
    if not interiorCoords then
        TriggerClientEvent('jcrp:notification', src, 'Interior not configured.', 'error')
        return
    end

    TriggerClientEvent('jcrp:apartments:enter', src, {
        unit_id = unitId,
        coords = interiorCoords,
        label = ownership.label,
    })
end

--- Exit a property
---@param src number
local function ExitProperty(src)
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    -- Get the property they're in (client tracks this)
    TriggerClientEvent('jcrp:apartments:exit', src)
end

--- Get stash contents for a property unit
---@param unitId number
---@return table
local function GetStash(unitId)
    local rows = MySQL.query.await(
        'SELECT * FROM property_stash WHERE unit_id = ? ORDER BY slot ASC',
        { unitId }
    )

    local stash = {}
    if rows then
        for _, row in ipairs(rows) do
            stash[row.slot] = {
                slot = row.slot,
                item_name = row.item_name,
                amount = row.amount,
                metadata = JCRP.JsonDecode(row.metadata_json, {}),
            }
        end
    end
    return stash
end

--- Add item to property stash
---@param unitId number
---@param slot number
---@param itemName string
---@param amount number
---@param metadata table|nil
---@return boolean
local function AddToStash(unitId, slot, itemName, amount, metadata)
    MySQL.query.await([[
        INSERT INTO property_stash (unit_id, slot, item_name, amount, metadata_json)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), amount = VALUES(amount),
        metadata_json = VALUES(metadata_json), updated_at = NOW()
    ]], {
        unitId, slot, itemName, amount,
        metadata and JCRP.JsonEncode(metadata) or '{}',
    })
    return true
end

--- Remove item from property stash
---@param unitId number
---@param slot number
---@return boolean
local function RemoveFromStash(unitId, slot)
    MySQL.query.await(
        'DELETE FROM property_stash WHERE unit_id = ? AND slot = ?',
        { unitId, slot }
    )
    return true
end

--- Purchase a property
---@param citizenid string
---@param propertyId number
---@return boolean success
---@return string|nil error
local function PurchaseProperty(citizenid, propertyId)
    local property = MySQL.single.await(
        'SELECT * FROM properties WHERE property_id = ?',
        { propertyId }
    )
    if not property then return false, 'Property not found' end

    -- Check if can afford
    local balances = exports['system_money']:GetBalances(citizenid)
    if not balances or balances.bank < property.price then
        return false, 'Insufficient funds'
    end

    -- Count existing units
    local unitCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM property_units WHERE property_id = ?',
        { propertyId }
    )
    if unitCount >= property.max_units then
        return false, 'No units available'
    end

    -- Create unit
    local unitLabel = ('Unit #%s'):format(citizenid:sub(-4))
    local unitId = MySQL.insert.await(
        'INSERT INTO property_units (property_id, unit_label) VALUES (?, ?)',
        { propertyId, unitLabel }
    )

    if not unitId then return false, 'Failed to create unit' end

    -- Assign ownership
    MySQL.insert.await(
        'INSERT INTO property_ownership (unit_id, citizenid, status) VALUES (?, ?, \'owned\')',
        { unitId, citizenid }
    )

    -- Charge money
    exports['system_money']:RemoveMoney(citizenid, 'bank', property.price, 'Property purchase: ' .. property.label, 'PROPERTY')

    JCRP.Log('system_apartments', 'INFO', ('Property purchased: %s bought %s (unit %d)'):format(citizenid, property.label, unitId))
    return true, nil
end

-- ============================================================
-- Server Events
-- ============================================================

RegisterNetEvent('jcrp:apartments:requestEnter', function(unitId)
    local src = source
    EnterProperty(src, tonumber(unitId))
end)

RegisterNetEvent('jcrp:apartments:requestExit', function()
    local src = source
    ExitProperty(src)
end)

RegisterNetEvent('jcrp:apartments:requestStash', function(unitId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    -- Verify access
    local ownership = MySQL.single.await(
        'SELECT id FROM property_ownership WHERE unit_id = ? AND citizenid = ?',
        { unitId, citizenid }
    )
    if not ownership then return end

    local stash = GetStash(unitId)
    TriggerClientEvent('jcrp:apartments:stashData', src, stash, unitId)
end)

-- Auto-assign starter apartment on new character creation
AddEventHandler('jcrp:playerLoaded', function(src, payload)
    local citizenid = payload and payload.character and payload.character.citizenid
    if not citizenid then return end

    local config = exports['core_boot']:GetConfig()
    if config.apartments and config.apartments.auto_assign_on_create then
        -- Check if they already have one
        local props = GetOwnedProperties(citizenid)
        if #props == 0 then
            AssignStarterApartment(citizenid)
        end
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GetOwnedProperties', GetOwnedProperties)
exports('AssignStarterApartment', AssignStarterApartment)
exports('EnterProperty', EnterProperty)
exports('ExitProperty', ExitProperty)
exports('GetStash', GetStash)
exports('AddToStash', AddToStash)
exports('RemoveFromStash', RemoveFromStash)
exports('PurchaseProperty', PurchaseProperty)

JCRP.Log('system_apartments', 'INFO', 'system_apartments loaded.')
