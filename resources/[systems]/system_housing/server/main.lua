-- ============================================================
-- system_housing: Housing System (Server)
-- Houses with keys, doorlocks, furniture, shared access
-- Extends the property system from system_apartments
-- ============================================================

--- Grant a key to another player
---@param unitId number
---@param citizenid string who gets the key
---@param grantedBy string who gives the key
---@return boolean
local function GrantKey(unitId, citizenid, grantedBy)
    -- Verify grantor has ownership
    local ownership = MySQL.single.await(
        'SELECT id FROM property_ownership WHERE unit_id = ? AND citizenid = ? AND status IN (\'owned\',\'rented\')',
        { unitId, grantedBy }
    )
    if not ownership then return false end

    MySQL.insert.await([[
        INSERT IGNORE INTO house_keys (unit_id, citizenid, granted_by) VALUES (?, ?, ?)
    ]], { unitId, citizenid, grantedBy })

    JCRP.Log('system_housing', 'INFO', ('Key granted: unit %d -> %s (by %s)'):format(unitId, citizenid, grantedBy))
    return true
end

--- Revoke a key
---@param unitId number
---@param citizenid string
---@param revokedBy string
---@return boolean
local function RevokeKey(unitId, citizenid, revokedBy)
    MySQL.update.await(
        'DELETE FROM house_keys WHERE unit_id = ? AND citizenid = ?',
        { unitId, citizenid }
    )
    return true
end

--- Check if someone has a key to a unit
---@param unitId number
---@param citizenid string
---@return boolean
local function HasKey(unitId, citizenid)
    -- Owner always has access
    local ownership = MySQL.scalar.await(
        'SELECT COUNT(*) FROM property_ownership WHERE unit_id = ? AND citizenid = ? AND status IN (\'owned\',\'rented\')',
        { unitId, citizenid }
    )
    if ownership and ownership > 0 then return true end

    -- Check key
    local key = MySQL.scalar.await(
        'SELECT COUNT(*) FROM house_keys WHERE unit_id = ? AND citizenid = ?',
        { unitId, citizenid }
    )
    return key and key > 0
end

--- Get all keyholders for a unit
---@param unitId number
---@return table
local function GetKeyholders(unitId)
    return MySQL.query.await(
        'SELECT * FROM house_keys WHERE unit_id = ? ORDER BY created_at ASC',
        { unitId }
    ) or {}
end

--- Toggle door lock
---@param unitId number
---@param doorHash string
---@param citizenid string
---@return boolean newState (true = locked)
local function ToggleDoorLock(unitId, doorHash, citizenid)
    if not HasKey(unitId, citizenid) then return false end

    -- Get current state
    local door = MySQL.single.await(
        'SELECT locked FROM house_doorlocks WHERE unit_id = ? AND door_hash = ?',
        { unitId, doorHash }
    )

    local newState = 1
    if door then
        newState = door.locked == 1 and 0 or 1
        MySQL.update.await(
            'UPDATE house_doorlocks SET locked = ? WHERE unit_id = ? AND door_hash = ?',
            { newState, unitId, doorHash }
        )
    else
        MySQL.insert.await(
            'INSERT INTO house_doorlocks (unit_id, door_hash, locked) VALUES (?, ?, ?)',
            { unitId, doorHash, newState }
        )
    end

    return newState == 1
end

--- Place furniture
---@param unitId number
---@param model string
---@param position table {x,y,z,rx,ry,rz}
---@param citizenid string
---@return number|nil furnitureId
local function PlaceFurniture(unitId, model, position, citizenid)
    if not HasKey(unitId, citizenid) then return nil end

    local id = MySQL.insert.await(
        'INSERT INTO house_furniture (unit_id, model, position_json, placed_by) VALUES (?, ?, ?, ?)',
        { unitId, model, JCRP.JsonEncode(position), citizenid }
    )
    return id
end

--- Get all furniture in a unit
---@param unitId number
---@return table
local function GetFurniture(unitId)
    local rows = MySQL.query.await(
        'SELECT * FROM house_furniture WHERE unit_id = ?',
        { unitId }
    )
    if not rows then return {} end
    for i, row in ipairs(rows) do
        rows[i].position = JCRP.JsonDecode(row.position_json, {})
    end
    return rows
end

--- Remove furniture
---@param furnitureId number
---@param citizenid string
---@return boolean
local function RemoveFurniture(furnitureId, citizenid)
    -- Only placer or owner can remove
    local item = MySQL.single.await('SELECT * FROM house_furniture WHERE id = ?', { furnitureId })
    if not item then return false end

    if item.placed_by ~= citizenid then
        -- Check if owner
        local isOwner = MySQL.scalar.await(
            'SELECT COUNT(*) FROM property_ownership WHERE unit_id = ? AND citizenid = ? AND status = \'owned\'',
            { item.unit_id, citizenid }
        )
        if not isOwner or isOwner == 0 then return false end
    end

    MySQL.update.await('DELETE FROM house_furniture WHERE id = ?', { furnitureId })
    return true
end

-- ============================================================
-- Events
-- ============================================================

RegisterNetEvent('jcrp:housing:grantKey', function(unitId, targetCitizenId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    local ok = GrantKey(unitId, targetCitizenId, citizenid)
    TriggerClientEvent('jcrp:notification', src, ok and 'Key granted.' or 'Failed to grant key.', ok and 'success' or 'error')
end)

RegisterNetEvent('jcrp:housing:toggleLock', function(unitId, doorHash)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    local locked = ToggleDoorLock(unitId, doorHash, citizenid)
    TriggerClientEvent('jcrp:notification', src, locked and 'Door locked.' or 'Door unlocked.', 'info')
end)

-- ============================================================
-- Exports
-- ============================================================
exports('GrantKey', GrantKey)
exports('RevokeKey', RevokeKey)
exports('HasKey', HasKey)
exports('GetKeyholders', GetKeyholders)
exports('ToggleDoorLock', ToggleDoorLock)
exports('PlaceFurniture', PlaceFurniture)
exports('GetFurniture', GetFurniture)
exports('RemoveFurniture', RemoveFurniture)

JCRP.Log('system_housing', 'INFO', 'system_housing loaded.')
