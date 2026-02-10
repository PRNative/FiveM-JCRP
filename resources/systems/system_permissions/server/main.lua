-- System Permissions Main
SystemPermissions = SystemPermissions or {}

-- Role hierarchy (higher number = higher permissions)
local roleHierarchy = {
    user = 0,
    moderator = 1,
    admin = 2,
    superadmin = 3,
    owner = 4
}

-- Get roles for an account
function SystemPermissions.GetRoles(accountId)
    local roles = MySQL.query.await('SELECT role FROM account_roles WHERE account_id = ?', {accountId})
    
    local result = {}
    if roles then
        for _, row in ipairs(roles) do
            table.insert(result, row.role)
        end
    end
    
    return result
end

-- Has role
function SystemPermissions.HasRole(accountId, role)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM account_roles WHERE account_id = ? AND role = ?', {
        accountId,
        role
    })
    
    return (count or 0) > 0
end

-- Has any role
function SystemPermissions.HasAnyRole(accountId, roles)
    for _, role in ipairs(roles) do
        if SystemPermissions.HasRole(accountId, role) then
            return true
        end
    end
    return false
end

-- Add role
function SystemPermissions.AddRole(accountId, role, grantedBy)
    if SystemPermissions.HasRole(accountId, role) then
        return false, "Account already has this role"
    end
    
    MySQL.insert('INSERT INTO account_roles (account_id, role, granted_by) VALUES (?, ?, ?)', {
        accountId,
        role,
        grantedBy
    })
    
    -- Audit
    SystemPermissions.AuditLog(grantedBy or 0, 'role_added', accountId, {
        role = role
    })
    
    print(string.format('[^2SYSTEM_PERMISSIONS^7] Added role "%s" to account %d', role, accountId))
    
    return true
end

-- Remove role
function SystemPermissions.RemoveRole(accountId, role)
    local deleted = MySQL.update.await('DELETE FROM account_roles WHERE account_id = ? AND role = ?', {
        accountId,
        role
    })
    
    if deleted > 0 then
        print(string.format('[^2SYSTEM_PERMISSIONS^7] Removed role "%s" from account %d', role, accountId))
        return true
    end
    
    return false, "Role not found"
end

-- Check if account has permission level
function SystemPermissions.HasPermissionLevel(accountId, requiredLevel)
    local roles = SystemPermissions.GetRoles(accountId)
    
    for _, role in ipairs(roles) do
        local level = roleHierarchy[role] or 0
        if level >= requiredLevel then
            return true
        end
    end
    
    return false
end

-- Require role (for use in commands/callbacks)
function SystemPermissions.RequireRole(src, role)
    if src == 0 then
        return true -- Console always has permission
    end
    
    if GetResourceState('core_identity') ~= 'started' then
        return false
    end
    
    local accountId = exports.core_identity:ResolveAccount(src)
    if not accountId then
        return false
    end
    
    return SystemPermissions.HasRole(accountId, role)
end

-- Require any role
function SystemPermissions.RequireAnyRole(src, roles)
    if src == 0 then
        return true -- Console always has permission
    end
    
    if GetResourceState('core_identity') ~= 'started' then
        return false
    end
    
    local accountId = exports.core_identity:ResolveAccount(src)
    if not accountId then
        return false
    end
    
    return SystemPermissions.HasAnyRole(accountId, roles)
end

-- Audit log
function SystemPermissions.AuditLog(accountId, action, targetId, payload)
    MySQL.insert('INSERT INTO admin_audit (account_id, action, target_id, payload_json) VALUES (?, ?, ?, ?)', {
        accountId,
        action,
        targetId,
        json.encode(payload or {})
    })
end

-- Get audit logs
function SystemPermissions.GetAuditLogs(accountId, limit)
    limit = limit or 100
    
    local logs = MySQL.query.await([[
        SELECT action, target_id, payload_json, created_at
        FROM admin_audit
        WHERE account_id = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], {accountId, limit})
    
    if logs then
        for _, log in ipairs(logs) do
            if log.payload_json then
                if type(log.payload_json) == "string" then
                    log.payload = json.decode(log.payload_json)
                else
                    log.payload = log.payload_json
                end
                log.payload_json = nil
            end
        end
    end
    
    return logs or {}
end

-- Export character data (for admin tools)
function SystemPermissions.ExportCharacter(citizenid)
    local data = {}
    
    -- Character info
    if GetResourceState('core_characters') == 'started' then
        data.character = exports.core_characters:GetCharacter(citizenid)
    end
    
    -- State
    if GetResourceState('core_state') == 'started' then
        data.state = exports.core_state:GetState(citizenid)
    end
    
    -- Money
    if GetResourceState('system_money') == 'started' then
        data.money = exports.system_money:GetBalances(citizenid)
    end
    
    -- Job
    if GetResourceState('system_jobs') == 'started' then
        data.job = exports.system_jobs:GetJob(citizenid)
    end
    
    -- Inventory
    if GetResourceState('system_inventory') == 'started' then
        data.inventory = exports.system_inventory:GetInventory(citizenid)
    end
    
    -- Status
    if GetResourceState('system_status') == 'started' then
        data.status = exports.system_status:GetStatus(citizenid)
    end
    
    return data
end

-- Callbacks
lib.callback.register('system_permissions:getRoles', function(source)
    if GetResourceState('core_identity') ~= 'started' then
        return {}
    end
    
    local accountId = exports.core_identity:ResolveAccount(source)
    if not accountId then
        return {}
    end
    
    return SystemPermissions.GetRoles(accountId)
end)

-- Exports
exports('GetRoles', SystemPermissions.GetRoles)
exports('HasRole', SystemPermissions.HasRole)
exports('HasAnyRole', SystemPermissions.HasAnyRole)
exports('AddRole', SystemPermissions.AddRole)
exports('RemoveRole', SystemPermissions.RemoveRole)
exports('HasPermissionLevel', SystemPermissions.HasPermissionLevel)
exports('RequireRole', SystemPermissions.RequireRole)
exports('RequireAnyRole', SystemPermissions.RequireAnyRole)
exports('AuditLog', SystemPermissions.AuditLog)
exports('GetAuditLogs', SystemPermissions.GetAuditLogs)
exports('ExportCharacter', SystemPermissions.ExportCharacter)

-- Admin commands
RegisterCommand('addrole', function(source, args)
    if source > 0 then
        if not SystemPermissions.RequireAnyRole(source, {'admin', 'superadmin', 'owner'}) then
            return
        end
    end
    
    if #args < 2 then
        print('Usage: addrole <player_id> <role>')
        return
    end
    
    local targetId = tonumber(args[1])
    local role = args[2]
    
    if GetResourceState('core_identity') ~= 'started' then
        print('core_identity not started')
        return
    end
    
    local accountId = exports.core_identity:ResolveAccount(targetId)
    if accountId then
        local grantedBy = source > 0 and exports.core_identity:ResolveAccount(source) or 0
        local success = SystemPermissions.AddRole(accountId, role, grantedBy)
        if success then
            print(string.format('Added role "%s" to player %d', role, targetId))
        else
            print('Failed to add role')
        end
    else
        print('Player not found')
    end
end, true)

RegisterCommand('removerole', function(source, args)
    if source > 0 then
        if not SystemPermissions.RequireAnyRole(source, {'admin', 'superadmin', 'owner'}) then
            return
        end
    end
    
    if #args < 2 then
        print('Usage: removerole <player_id> <role>')
        return
    end
    
    local targetId = tonumber(args[1])
    local role = args[2]
    
    if GetResourceState('core_identity') ~= 'started' then
        print('core_identity not started')
        return
    end
    
    local accountId = exports.core_identity:ResolveAccount(targetId)
    if accountId then
        local success = SystemPermissions.RemoveRole(accountId, role)
        if success then
            print(string.format('Removed role "%s" from player %d', role, targetId))
        else
            print('Failed to remove role')
        end
    else
        print('Player not found')
    end
end, true)

RegisterCommand('exportchar', function(source, args)
    if source > 0 then
        if not SystemPermissions.RequireAnyRole(source, {'admin', 'superadmin', 'owner'}) then
            return
        end
    end
    
    if #args < 1 then
        print('Usage: exportchar <citizenid>')
        return
    end
    
    local citizenid = args[1]
    local data = SystemPermissions.ExportCharacter(citizenid)
    
    -- Save to file
    local filename = string.format('character_export_%s_%s.json', citizenid, os.date('%Y%m%d_%H%M%S'))
    SaveResourceFile(GetCurrentResourceName(), filename, json.encode(data, {indent = true}), -1)
    
    print(string.format('Character data exported to: %s', filename))
end, true)

print('[^2SYSTEM_PERMISSIONS^7] Initialized')
