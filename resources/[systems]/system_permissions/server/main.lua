-- ============================================================
-- system_permissions: Roles & Permission System (Server)
-- ============================================================

-- Role hierarchy (higher = more powerful)
local ROLE_HIERARCHY = {
    ['user'] = 0,
    ['vip'] = 10,
    ['moderator'] = 50,
    ['admin'] = 80,
    ['superadmin'] = 100,
    ['owner'] = 999,
}

-- Cache: account_id -> set of roles
local RoleCache = {}

--- Load roles for an account
---@param accountId number
---@return table roles set of role names
local function LoadRoles(accountId)
    if RoleCache[accountId] then
        return RoleCache[accountId]
    end

    local rows = MySQL.query.await(
        'SELECT role FROM account_roles WHERE account_id = ?',
        { accountId }
    )

    local roles = {}
    if rows then
        for _, row in ipairs(rows) do
            roles[row.role] = true
        end
    end

    -- Everyone has 'user' implicitly
    roles['user'] = true

    RoleCache[accountId] = roles
    return roles
end

--- Check if an account has a specific role
---@param accountId number
---@param role string
---@return boolean
local function HasRole(accountId, role)
    local roles = LoadRoles(accountId)
    return roles[role] == true
end

--- Check if account has at least the specified role level
---@param accountId number
---@param minRole string
---@return boolean
local function HasRoleLevel(accountId, minRole)
    local minLevel = ROLE_HIERARCHY[minRole] or 0
    local roles = LoadRoles(accountId)

    for roleName, _ in pairs(roles) do
        local level = ROLE_HIERARCHY[roleName] or 0
        if level >= minLevel then
            return true
        end
    end
    return false
end

--- Require a role — kick player if they don't have it
---@param src number
---@param role string
---@return boolean hasRole
local function RequireRole(src, role)
    local accountId = exports['core_session']:GetAccountId(src)
    if not accountId then return false end

    if not HasRole(accountId, role) and not HasRoleLevel(accountId, role) then
        TriggerClientEvent('jcrp:notification', src, 'You do not have permission to do that.', 'error')
        return false
    end
    return true
end

--- Grant a role to an account
---@param accountId number
---@param role string
---@param grantedBy number|nil
---@return boolean
local function GrantRole(accountId, role, grantedBy)
    MySQL.insert.await([[
        INSERT IGNORE INTO account_roles (account_id, role, granted_by) VALUES (?, ?, ?)
    ]], { accountId, role, grantedBy })

    -- Update cache
    if RoleCache[accountId] then
        RoleCache[accountId][role] = true
    end

    AdminAudit(grantedBy or 0, 'grant_role', ('Account %d granted role: %s'):format(accountId, role), {
        target_account = accountId,
        role = role,
    })

    JCRP.Log('system_permissions', 'INFO', ('Role granted: %s -> account %d'):format(role, accountId))
    return true
end

--- Revoke a role from an account
---@param accountId number
---@param role string
---@param revokedBy number|nil
---@return boolean
local function RevokeRole(accountId, role, revokedBy)
    MySQL.update.await(
        'DELETE FROM account_roles WHERE account_id = ? AND role = ?',
        { accountId, role }
    )

    -- Update cache
    if RoleCache[accountId] then
        RoleCache[accountId][role] = nil
    end

    AdminAudit(revokedBy or 0, 'revoke_role', ('Account %d revoked role: %s'):format(accountId, role), {
        target_account = accountId,
        role = role,
    })

    JCRP.Log('system_permissions', 'INFO', ('Role revoked: %s from account %d'):format(role, accountId))
    return true
end

--- Get all roles for an account
---@param accountId number
---@return table roleNames
local function GetRoles(accountId)
    local roles = LoadRoles(accountId)
    local result = {}
    for role, _ in pairs(roles) do
        result[#result + 1] = role
    end
    return result
end

--- Write admin audit log
---@param accountId number
---@param action string
---@param targetInfo string
---@param payload table|nil
function AdminAudit(accountId, action, targetInfo, payload)
    MySQL.insert('INSERT INTO admin_audit (account_id, action, target_info, payload_json) VALUES (?, ?, ?, ?)', {
        accountId, action, targetInfo,
        payload and JCRP.JsonEncode(payload) or nil,
    })
end

--- Get admin audit log
---@param limit number|nil
---@param offset number|nil
---@return table
local function GetAdminAuditLog(limit, offset)
    limit = limit or 50
    offset = offset or 0
    return MySQL.query.await(
        'SELECT * FROM admin_audit ORDER BY created_at DESC LIMIT ? OFFSET ?',
        { limit, offset }
    )
end

--- Invalidate cache for account
---@param accountId number
local function InvalidateRoleCache(accountId)
    RoleCache[accountId] = nil
end

-- ============================================================
-- Exports
-- ============================================================
exports('HasRole', HasRole)
exports('HasRoleLevel', HasRoleLevel)
exports('RequireRole', RequireRole)
exports('GrantRole', GrantRole)
exports('RevokeRole', RevokeRole)
exports('GetRoles', GetRoles)
exports('AdminAudit', AdminAudit)
exports('GetAdminAuditLog', GetAdminAuditLog)
exports('InvalidateRoleCache', InvalidateRoleCache)

JCRP.Log('system_permissions', 'INFO', 'system_permissions loaded.')
