-- ============================================================
-- core_characters: 3-Slot Character System
-- ============================================================

local MAX_SLOTS = 3

--- List all characters for an account
---@param accountId number
---@return table characters array of character rows
local function ListCharacters(accountId)
    local rows = MySQL.query.await(
        'SELECT * FROM characters WHERE account_id = ? ORDER BY slot ASC',
        { accountId }
    )
    return rows or {}
end

--- Generate a unique citizenid that doesn't exist in DB
---@return string
local function GenerateUniqueCitizenId()
    for _ = 1, 100 do
        local cid = JCRP.GenerateCitizenId()
        local exists = MySQL.scalar.await(
            'SELECT COUNT(*) FROM characters WHERE citizenid = ?',
            { cid }
        )
        if exists == 0 then
            return cid
        end
    end
    -- Fallback: timestamp-based
    return 'JCRP-' .. tostring(os.time()):sub(-5)
end

--- Create a new character
---@param accountId number
---@param slot number 1-3
---@param charData table {firstname, lastname, dob, gender, model, backstory}
---@return string|nil citizenid
---@return string|nil error
local function CreateCharacter(accountId, slot, charData)
    -- Validate slot
    if not slot or slot < 1 or slot > MAX_SLOTS then
        return nil, 'Invalid slot. Must be 1-' .. MAX_SLOTS
    end

    -- Check existing characters count
    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM characters WHERE account_id = ?',
        { accountId }
    )
    if count >= MAX_SLOTS then
        return nil, 'Maximum character limit reached (' .. MAX_SLOTS .. ')'
    end

    -- Check if slot is taken
    local existing = MySQL.scalar.await(
        'SELECT COUNT(*) FROM characters WHERE account_id = ? AND slot = ?',
        { accountId, slot }
    )
    if existing > 0 then
        return nil, 'Slot ' .. slot .. ' is already taken.'
    end

    -- Validate required fields
    if not charData.firstname or charData.firstname == '' then
        return nil, 'First name is required.'
    end
    if not charData.lastname or charData.lastname == '' then
        return nil, 'Last name is required.'
    end

    -- Generate unique citizenid
    local citizenid = GenerateUniqueCitizenId()

    -- Defaults
    local gender = charData.gender or 0
    local model = charData.model or (gender == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01')
    local dob = charData.dob or '1990-01-01'
    local backstory = charData.backstory or ''
    local skinJson = charData.skin_json and JCRP.JsonEncode(charData.skin_json) or nil

    local insertId = MySQL.insert.await([[
        INSERT INTO characters (account_id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json, backstory)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId, slot, citizenid,
        charData.firstname, charData.lastname,
        dob, gender, model, skinJson, backstory
    })

    if not insertId then
        return nil, 'Database error creating character.'
    end

    JCRP.Log('core_characters', 'INFO', ('Character created: %s (account=%d slot=%d)'):format(citizenid, accountId, slot))

    -- Audit via core_identity
    pcall(function()
        exports['core_identity']:Audit(accountId, 'character_created', {
            citizenid = citizenid,
            slot = slot,
            firstname = charData.firstname,
            lastname = charData.lastname,
        })
    end)

    return citizenid, nil
end

--- Delete a character by account and slot
---@param accountId number
---@param slot number
---@return boolean ok
---@return string|nil error
local function DeleteCharacter(accountId, slot)
    -- Get character info before delete for audit
    local char = MySQL.single.await(
        'SELECT citizenid, firstname, lastname FROM characters WHERE account_id = ? AND slot = ?',
        { accountId, slot }
    )

    if not char then
        return false, 'No character found in slot ' .. tostring(slot)
    end

    -- Delete character (cascading will handle related data)
    local affected = MySQL.update.await(
        'DELETE FROM characters WHERE account_id = ? AND slot = ?',
        { accountId, slot }
    )

    if affected and affected > 0 then
        JCRP.Log('core_characters', 'INFO', ('Character deleted: %s (account=%d slot=%d)'):format(char.citizenid, accountId, slot))

        -- Also clean up state, money, inventory, etc.
        -- These are done via cascade or explicit cleanup
        pcall(function() MySQL.update.await('DELETE FROM character_state WHERE citizenid = ?', { char.citizenid }) end)
        pcall(function() MySQL.update.await('DELETE FROM character_money WHERE citizenid = ?', { char.citizenid }) end)
        pcall(function() MySQL.update.await('DELETE FROM character_inventory WHERE citizenid = ?', { char.citizenid }) end)
        pcall(function() MySQL.update.await('DELETE FROM character_jobs WHERE citizenid = ?', { char.citizenid }) end)
        pcall(function() MySQL.update.await('DELETE FROM character_status WHERE citizenid = ?', { char.citizenid }) end)

        pcall(function()
            exports['core_identity']:Audit(accountId, 'character_deleted', {
                citizenid = char.citizenid,
                slot = slot,
                name = char.firstname .. ' ' .. char.lastname,
            })
        end)

        return true, nil
    end

    return false, 'Failed to delete character.'
end

--- Load a character's base identity data
---@param citizenid string
---@return table|nil payload
local function LoadCharacter(citizenid)
    local char = MySQL.single.await(
        'SELECT * FROM characters WHERE citizenid = ?',
        { citizenid }
    )
    if not char then return nil end

    -- Parse skin JSON
    char.skin = JCRP.JsonDecode(char.skin_json, {})
    char.skin_json = nil -- Don't pass raw json to consumer

    return char
end

--- Update last_played timestamp
---@param citizenid string
local function UpdateLastPlayed(citizenid)
    MySQL.update('UPDATE characters SET last_played = NOW() WHERE citizenid = ?', { citizenid })
end

--- Get character by citizenid
---@param citizenid string
---@return table|nil
local function GetCharacterByCitizenId(citizenid)
    return MySQL.single.await('SELECT * FROM characters WHERE citizenid = ?', { citizenid })
end

--- Update character skin data
---@param citizenid string
---@param skinData table
local function UpdateSkin(citizenid, skinData)
    MySQL.update.await(
        'UPDATE characters SET skin_json = ? WHERE citizenid = ?',
        { JCRP.JsonEncode(skinData), citizenid }
    )
end

-- ============================================================
-- Exports
-- ============================================================
exports('ListCharacters', ListCharacters)
exports('CreateCharacter', CreateCharacter)
exports('DeleteCharacter', DeleteCharacter)
exports('LoadCharacter', LoadCharacter)
exports('UpdateLastPlayed', UpdateLastPlayed)
exports('GetCharacterByCitizenId', GetCharacterByCitizenId)
exports('UpdateSkin', UpdateSkin)

JCRP.Log('core_characters', 'INFO', 'core_characters loaded.')
