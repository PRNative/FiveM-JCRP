-- Core Characters Main
CoreCharacters = CoreCharacters or {}

-- Generate unique citizen ID
local function GenerateCitizenId()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local citizenid = "CID"
    
    for i = 1, 7 do
        local rand = math.random(1, #charset)
        citizenid = citizenid .. string.sub(charset, rand, rand)
    end
    
    -- Check if it already exists
    local exists = MySQL.scalar.await('SELECT citizenid FROM characters WHERE citizenid = ?', {citizenid})
    
    if exists then
        return GenerateCitizenId() -- Recursively generate new one
    end
    
    return citizenid
end

-- List all characters for an account
function CoreCharacters.ListCharacters(accountId)
    local characters = MySQL.query.await([[
        SELECT id, slot, citizenid, firstname, lastname, dob, gender, model, created_at, last_played
        FROM characters
        WHERE account_id = ?
        ORDER BY slot ASC
    ]], {accountId})
    
    return characters or {}
end

-- Create a new character
function CoreCharacters.CreateCharacter(accountId, slot, charData)
    -- Validate slot
    if slot < 1 or slot > 3 then
        return nil, "Invalid slot (must be 1-3)"
    end
    
    -- Check if slot is already taken
    local existing = MySQL.scalar.await('SELECT id FROM characters WHERE account_id = ? AND slot = ?', {accountId, slot})
    
    if existing then
        return nil, "Slot already occupied"
    end
    
    -- Count existing characters
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM characters WHERE account_id = ?', {accountId})
    
    if count >= 3 then
        return nil, "Maximum 3 characters reached"
    end
    
    -- Validate character data
    if not charData.firstname or not charData.lastname or not charData.dob or not charData.gender then
        return nil, "Missing required character data"
    end
    
    -- Generate citizen ID
    local citizenid = GenerateCitizenId()
    
    -- Default values
    local model = charData.model or (charData.gender == 'male' and 'mp_m_freemode_01' or 'mp_f_freemode_01')
    local skinJson = json.encode(charData.skin or {})
    
    -- Insert character
    local result = MySQL.insert.await([[
        INSERT INTO characters (account_id, slot, citizenid, firstname, lastname, dob, gender, model, skin_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        accountId,
        slot,
        citizenid,
        charData.firstname,
        charData.lastname,
        charData.dob,
        charData.gender,
        model,
        skinJson
    })
    
    if result then
        print(string.format('[^2CORE_CHARACTERS^7] Character created: %s %s (CID: %s)', charData.firstname, charData.lastname, citizenid))
        
        -- Trigger character created event for other systems to initialize data
        TriggerEvent('core_characters:created', citizenid, accountId)
        
        return citizenid
    else
        return nil, "Failed to create character"
    end
end

-- Delete a character
function CoreCharacters.DeleteCharacter(accountId, slot)
    local character = MySQL.single.await('SELECT id, citizenid FROM characters WHERE account_id = ? AND slot = ?', {accountId, slot})
    
    if not character then
        return false, "Character not found"
    end
    
    -- Trigger before delete event (allows other systems to clean up their data)
    TriggerEvent('core_characters:beforeDelete', character.citizenid)
    
    -- Delete character
    local deleted = MySQL.update.await('DELETE FROM characters WHERE account_id = ? AND slot = ?', {accountId, slot})
    
    if deleted > 0 then
        print(string.format('[^2CORE_CHARACTERS^7] Character deleted: %s', character.citizenid))
        return true
    else
        return false, "Failed to delete character"
    end
end

-- Load character data
function CoreCharacters.LoadCharacter(citizenid)
    local character = MySQL.single.await([[
        SELECT * FROM characters WHERE citizenid = ?
    ]], {citizenid})
    
    if not character then
        return nil
    end
    
    -- Parse skin JSON
    if character.skin_json then
        character.skin = json.decode(character.skin_json)
        character.skin_json = nil
    end
    
    return character
end

-- Update last played timestamp
function CoreCharacters.UpdateLastPlayed(citizenid)
    MySQL.update('UPDATE characters SET last_played = NOW() WHERE citizenid = ?', {citizenid})
end

-- Get character by citizenid
function CoreCharacters.GetCharacter(citizenid)
    return CoreCharacters.LoadCharacter(citizenid)
end

-- Update character data
function CoreCharacters.UpdateCharacter(citizenid, data)
    local updates = {}
    local values = {}
    
    if data.firstname then
        table.insert(updates, 'firstname = ?')
        table.insert(values, data.firstname)
    end
    
    if data.lastname then
        table.insert(updates, 'lastname = ?')
        table.insert(values, data.lastname)
    end
    
    if data.dob then
        table.insert(updates, 'dob = ?')
        table.insert(values, data.dob)
    end
    
    if data.gender then
        table.insert(updates, 'gender = ?')
        table.insert(values, data.gender)
    end
    
    if data.model then
        table.insert(updates, 'model = ?')
        table.insert(values, data.model)
    end
    
    if data.skin then
        table.insert(updates, 'skin_json = ?')
        table.insert(values, json.encode(data.skin))
    end
    
    if #updates == 0 then
        return false
    end
    
    table.insert(values, citizenid)
    
    local query = string.format('UPDATE characters SET %s WHERE citizenid = ?', table.concat(updates, ', '))
    MySQL.update(query, values)
    
    return true
end

-- Callbacks
lib.callback.register('core_characters:getCharacters', function(source)
    local accountId = exports.core_identity:ResolveAccount(source)
    if not accountId then
        return {}
    end
    
    return CoreCharacters.ListCharacters(accountId)
end)

lib.callback.register('core_characters:createCharacter', function(source, slot, charData)
    local accountId = exports.core_identity:ResolveAccount(source)
    if not accountId then
        return {success = false, message = "Account not found"}
    end
    
    local citizenid, error = CoreCharacters.CreateCharacter(accountId, slot, charData)
    
    if citizenid then
        return {success = true, citizenid = citizenid}
    else
        return {success = false, message = error}
    end
end)

lib.callback.register('core_characters:deleteCharacter', function(source, slot)
    local accountId = exports.core_identity:ResolveAccount(source)
    if not accountId then
        return {success = false, message = "Account not found"}
    end
    
    local success, error = CoreCharacters.DeleteCharacter(accountId, slot)
    
    return {success = success, message = error}
end)

-- Exports
exports('ListCharacters', CoreCharacters.ListCharacters)
exports('CreateCharacter', CoreCharacters.CreateCharacter)
exports('DeleteCharacter', CoreCharacters.DeleteCharacter)
exports('LoadCharacter', CoreCharacters.LoadCharacter)
exports('GetCharacter', CoreCharacters.GetCharacter)
exports('UpdateLastPlayed', CoreCharacters.UpdateLastPlayed)
exports('UpdateCharacter', CoreCharacters.UpdateCharacter)

print('[^2CORE_CHARACTERS^7] Initialized')
