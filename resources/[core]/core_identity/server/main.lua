-- ============================================================
-- core_identity: Account Resolution, Bans & Audit
-- ============================================================

--- Extract a specific identifier from a player source
---@param src number player server id
---@param idType string e.g. "license", "discord", "steam"
---@return string|nil
local function GetIdentifier(src, idType)
    local identifiers = GetPlayerIdentifiers(src)
    for _, id in ipairs(identifiers) do
        if string.find(id, idType .. ':') then
            return id
        end
    end
    return nil
end

--- Resolve (or create) an account for the connecting player.
--- Returns account_id or nil + error string.
---@param src number
---@return number|nil account_id
---@return string|nil error
local function ResolveAccount(src)
    local license = GetIdentifier(src, 'license')
    if not license then
        return nil, 'No license identifier found. Cannot connect.'
    end

    local discord = GetIdentifier(src, 'discord')

    -- Try to find existing account
    local row = MySQL.single.await('SELECT * FROM accounts WHERE license = ?', { license })

    if row then
        -- Update last_seen and discord
        MySQL.update.await(
            'UPDATE accounts SET last_seen = NOW(), discord = COALESCE(?, discord) WHERE id = ?',
            { discord, row.id }
        )
        JCRP.Log('core_identity', 'INFO', ('Account resolved: id=%d license=%s'):format(row.id, license))
        return row.id, nil
    end

    -- Create new account
    local newId = MySQL.insert.await(
        'INSERT INTO accounts (license, discord) VALUES (?, ?)',
        { license, discord }
    )

    if not newId then
        return nil, 'Failed to create account in database.'
    end

    JCRP.Log('core_identity', 'INFO', ('New account created: id=%d license=%s'):format(newId, license))
    Audit(newId, 'account_created', { license = license, discord = discord })
    return newId, nil
end

--- Check if an account is banned
---@param accountId number
---@return boolean banned
---@return string|nil reason
local function IsBanned(accountId)
    local row = MySQL.single.await(
        'SELECT banned, ban_reason FROM accounts WHERE id = ?',
        { accountId }
    )
    if not row then return false, nil end
    if row.banned == 1 then
        return true, row.ban_reason or 'No reason provided.'
    end
    return false, nil
end

--- Ban an account
---@param accountId number
---@param reason string
---@return boolean
local function BanAccount(accountId, reason)
    local affected = MySQL.update.await(
        'UPDATE accounts SET banned = 1, ban_reason = ? WHERE id = ?',
        { reason, accountId }
    )
    if affected and affected > 0 then
        Audit(accountId, 'account_banned', { reason = reason })
        return true
    end
    return false
end

--- Unban an account
---@param accountId number
---@return boolean
local function UnbanAccount(accountId)
    local affected = MySQL.update.await(
        'UPDATE accounts SET banned = 0, ban_reason = NULL WHERE id = ?',
        { accountId }
    )
    if affected and affected > 0 then
        Audit(accountId, 'account_unbanned', {})
        return true
    end
    return false
end

--- Get account data by id
---@param accountId number
---@return table|nil
local function GetAccount(accountId)
    return MySQL.single.await('SELECT * FROM accounts WHERE id = ?', { accountId })
end

--- Get account by license
---@param license string
---@return table|nil
local function GetAccountByLicense(license)
    return MySQL.single.await('SELECT * FROM accounts WHERE license = ?', { license })
end

--- Write an audit log entry
---@param accountId number
---@param event string
---@param payload table|nil
function Audit(accountId, event, payload)
    local payloadJson = payload and JCRP.JsonEncode(payload) or nil
    MySQL.insert('INSERT INTO account_audit (account_id, event, payload_json) VALUES (?, ?, ?)', {
        accountId, event, payloadJson
    })
end

--- Get audit log for an account
---@param accountId number
---@param limit number|nil
---@return table
local function GetAuditLog(accountId, limit)
    limit = limit or 50
    return MySQL.query.await(
        'SELECT * FROM account_audit WHERE account_id = ? ORDER BY created_at DESC LIMIT ?',
        { accountId, limit }
    )
end

-- ============================================================
-- Exports
-- ============================================================
exports('ResolveAccount', ResolveAccount)
exports('IsBanned', IsBanned)
exports('BanAccount', BanAccount)
exports('UnbanAccount', UnbanAccount)
exports('GetAccount', GetAccount)
exports('GetAccountByLicense', GetAccountByLicense)
exports('Audit', Audit)
exports('GetAuditLog', GetAuditLog)
exports('GetIdentifier', GetIdentifier)

JCRP.Log('core_identity', 'INFO', 'core_identity loaded.')
