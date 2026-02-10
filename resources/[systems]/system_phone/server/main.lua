-- ============================================================
-- system_phone: Phone System (Server)
-- Contacts, messages, settings
-- ============================================================

--- Generate a random phone number
---@return string
local function GeneratePhoneNumber()
    local num = '555-'
    for i = 1, 4 do
        num = num .. tostring(math.random(0, 9))
    end
    return num
end

--- Generate a unique phone number
---@return string
local function GenerateUniquePhoneNumber()
    for _ = 1, 100 do
        local num = GeneratePhoneNumber()
        local exists = MySQL.scalar.await(
            'SELECT COUNT(*) FROM phone_settings WHERE phone_number = ?',
            { num }
        )
        if exists == 0 then return num end
    end
    return GeneratePhoneNumber()
end

--- Initialize phone for a character
---@param citizenid string
---@return string phoneNumber
local function InitPhone(citizenid)
    local existing = MySQL.single.await(
        'SELECT phone_number FROM phone_settings WHERE citizenid = ?',
        { citizenid }
    )
    if existing then return existing.phone_number end

    local phoneNumber = GenerateUniquePhoneNumber()
    MySQL.insert.await(
        'INSERT INTO phone_settings (citizenid, phone_number) VALUES (?, ?)',
        { citizenid, phoneNumber }
    )

    JCRP.Log('system_phone', 'INFO', ('Phone initialized for %s: %s'):format(citizenid, phoneNumber))
    return phoneNumber
end

--- Get phone number for a citizenid
---@param citizenid string
---@return string|nil
local function GetPhoneNumber(citizenid)
    local row = MySQL.single.await(
        'SELECT phone_number FROM phone_settings WHERE citizenid = ?',
        { citizenid }
    )
    return row and row.phone_number or nil
end

--- Get citizenid from phone number
---@param phoneNumber string
---@return string|nil
local function GetCitizenIdByPhone(phoneNumber)
    local row = MySQL.single.await(
        'SELECT citizenid FROM phone_settings WHERE phone_number = ?',
        { phoneNumber }
    )
    return row and row.citizenid or nil
end

--- Get contacts for a character
---@param citizenid string
---@return table
local function GetContacts(citizenid)
    return MySQL.query.await(
        'SELECT * FROM phone_contacts WHERE owner_citizenid = ? ORDER BY name ASC',
        { citizenid }
    ) or {}
end

--- Add a contact
---@param citizenid string
---@param name string
---@param number string
---@return boolean
local function AddContact(citizenid, name, number)
    MySQL.insert.await(
        'INSERT INTO phone_contacts (owner_citizenid, name, number) VALUES (?, ?, ?)',
        { citizenid, name, number }
    )
    return true
end

--- Delete a contact
---@param citizenid string
---@param contactId number
---@return boolean
local function DeleteContact(citizenid, contactId)
    MySQL.update.await(
        'DELETE FROM phone_contacts WHERE id = ? AND owner_citizenid = ?',
        { contactId, citizenid }
    )
    return true
end

--- Send a message
---@param senderCitizenId string
---@param receiverCitizenId string
---@param message string
---@return boolean
local function SendMessage(senderCitizenId, receiverCitizenId, message)
    MySQL.insert.await(
        'INSERT INTO phone_messages (sender_citizenid, receiver_citizenid, message) VALUES (?, ?, ?)',
        { senderCitizenId, receiverCitizenId, message }
    )

    -- Notify receiver if online
    local receiverSrc = exports['core_session']:GetSourceByCitizenId(receiverCitizenId)
    if receiverSrc then
        TriggerClientEvent('jcrp:phone:newMessage', receiverSrc, {
            from = senderCitizenId,
            message = message,
        })
    end

    return true
end

--- Get messages between two characters
---@param citizenid1 string
---@param citizenid2 string
---@param limit number|nil
---@return table
local function GetMessages(citizenid1, citizenid2, limit)
    limit = limit or 50
    return MySQL.query.await([[
        SELECT * FROM phone_messages
        WHERE (sender_citizenid = ? AND receiver_citizenid = ?)
           OR (sender_citizenid = ? AND receiver_citizenid = ?)
        ORDER BY created_at DESC LIMIT ?
    ]], { citizenid1, citizenid2, citizenid2, citizenid1, limit }) or {}
end

--- Get recent conversations
---@param citizenid string
---@return table
local function GetConversations(citizenid)
    return MySQL.query.await([[
        SELECT
            CASE WHEN sender_citizenid = ? THEN receiver_citizenid ELSE sender_citizenid END as other_citizenid,
            MAX(created_at) as last_message_at,
            SUM(CASE WHEN receiver_citizenid = ? AND is_read = 0 THEN 1 ELSE 0 END) as unread_count
        FROM phone_messages
        WHERE sender_citizenid = ? OR receiver_citizenid = ?
        GROUP BY other_citizenid
        ORDER BY last_message_at DESC
    ]], { citizenid, citizenid, citizenid, citizenid }) or {}
end

-- ============================================================
-- Events
-- ============================================================

RegisterNetEvent('jcrp:phone:getContacts', function()
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    TriggerClientEvent('jcrp:phone:contactsList', src, GetContacts(citizenid))
end)

RegisterNetEvent('jcrp:phone:addContact', function(name, number)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    AddContact(citizenid, name, number)
    TriggerClientEvent('jcrp:phone:contactsList', src, GetContacts(citizenid))
end)

RegisterNetEvent('jcrp:phone:sendMessage', function(targetCitizenId, message)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    SendMessage(citizenid, targetCitizenId, message)
end)

RegisterNetEvent('jcrp:phone:getMessages', function(otherCitizenId)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end
    TriggerClientEvent('jcrp:phone:messagesList', src, GetMessages(citizenid, otherCitizenId))
end)

-- Init phone on player load
AddEventHandler('jcrp:playerLoaded', function(src, payload)
    local citizenid = payload and payload.character and payload.character.citizenid
    if not citizenid then return end
    InitPhone(citizenid)
end)

-- ============================================================
-- Exports
-- ============================================================
exports('InitPhone', InitPhone)
exports('GetPhoneNumber', GetPhoneNumber)
exports('GetCitizenIdByPhone', GetCitizenIdByPhone)
exports('GetContacts', GetContacts)
exports('AddContact', AddContact)
exports('DeleteContact', DeleteContact)
exports('SendMessage', SendMessage)
exports('GetMessages', GetMessages)
exports('GetConversations', GetConversations)

JCRP.Log('system_phone', 'INFO', 'system_phone loaded.')
