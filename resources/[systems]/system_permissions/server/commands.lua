-- ============================================================
-- system_permissions: Admin Commands
-- ============================================================

--- /setjob [id] [job] [grade]
RegisterCommand('setjob', function(source, args, rawCommand)
    local src = source

    -- Console always has permission, players need admin role
    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'admin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 3 then
        if src > 0 then
            TriggerClientEvent('jcrp:notification', src, 'Usage: /setjob [server_id] [job] [grade]', 'error')
        else
            print('Usage: setjob [server_id] [job] [grade]')
        end
        return
    end

    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0

    if not targetId then return end

    local citizenid = exports['core_session']:GetCitizenId(targetId)
    if not citizenid then
        local msg = 'Player not found or not loaded.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local ok, err = exports['system_jobs']:SetJob(citizenid, jobName, grade)
    local msg = ok and ('Set job for %d: %s grade %d'):format(targetId, jobName, grade) or ('Failed: %s'):format(err or 'unknown')

    if src > 0 then
        TriggerClientEvent('jcrp:notification', src, msg, ok and 'success' or 'error')
        AdminAudit(exports['core_session']:GetAccountId(src), 'setjob', msg, { target = targetId, job = jobName, grade = grade })
    else
        print(msg)
    end
end, false)

--- /givemoney [id] [type] [amount]
RegisterCommand('givemoney', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'admin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 3 then
        local usage = 'Usage: /givemoney [server_id] [cash|bank|dirty] [amount]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local moneyType = args[2]
    local amount = tonumber(args[3])

    if not targetId or not amount then return end

    local citizenid = exports['core_session']:GetCitizenId(targetId)
    if not citizenid then
        local msg = 'Player not found or not loaded.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local ok, err = exports['system_money']:AddMoney(citizenid, moneyType, amount, 'Admin givemoney', 'ADMIN')
    local msg = ok and ('Gave $%d %s to %d'):format(amount, moneyType, targetId) or ('Failed: %s'):format(err or 'unknown')

    if src > 0 then
        TriggerClientEvent('jcrp:notification', src, msg, ok and 'success' or 'error')
        AdminAudit(exports['core_session']:GetAccountId(src), 'givemoney', msg, { target = targetId, type = moneyType, amount = amount })
    else
        print(msg)
    end
end, false)

--- /giveitem [id] [item] [amount]
RegisterCommand('giveitem', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'admin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 2 then
        local usage = 'Usage: /giveitem [server_id] [item_name] [amount]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1

    if not targetId then return end

    local citizenid = exports['core_session']:GetCitizenId(targetId)
    if not citizenid then
        local msg = 'Player not found or not loaded.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local ok, err = exports['system_inventory']:AddItem(citizenid, itemName, amount)
    local msg = ok and ('Gave %dx %s to %d'):format(amount, itemName, targetId) or ('Failed: %s'):format(err or 'unknown')

    if src > 0 then
        TriggerClientEvent('jcrp:notification', src, msg, ok and 'success' or 'error')
        AdminAudit(exports['core_session']:GetAccountId(src), 'giveitem', msg, { target = targetId, item = itemName, amount = amount })
    else
        print(msg)
    end
end, false)

--- /ban [id] [reason]
RegisterCommand('ban', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'admin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 2 then
        local usage = 'Usage: /ban [server_id] [reason]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local reason = table.concat(args, ' ', 2)

    if not targetId then return end

    local targetAccountId = exports['core_session']:GetAccountId(targetId)
    if not targetAccountId then
        local msg = 'Player not found.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    exports['core_identity']:BanAccount(targetAccountId, reason)
    DropPlayer(targetId, ('You have been banned. Reason: %s'):format(reason))

    local msg = ('Banned player %d: %s'):format(targetId, reason)
    if src > 0 then
        TriggerClientEvent('jcrp:notification', src, msg, 'success')
        AdminAudit(exports['core_session']:GetAccountId(src), 'ban', msg, { target = targetId, targetAccount = targetAccountId, reason = reason })
    else
        print(msg)
    end
end, false)

--- /unban [account_id]
RegisterCommand('unban', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'admin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 1 then
        local usage = 'Usage: /unban [account_id]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetAccountId = tonumber(args[1])
    if not targetAccountId then return end

    exports['core_identity']:UnbanAccount(targetAccountId)

    local msg = ('Unbanned account %d'):format(targetAccountId)
    if src > 0 then
        TriggerClientEvent('jcrp:notification', src, msg, 'success')
        AdminAudit(exports['core_session']:GetAccountId(src), 'unban', msg, { targetAccount = targetAccountId })
    else
        print(msg)
    end
end, false)

--- /grantrole [server_id] [role]
RegisterCommand('grantrole', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'superadmin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission. Requires superadmin.', 'error')
            return
        end
    end

    if #args < 2 then
        local usage = 'Usage: /grantrole [server_id] [role]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local role = args[2]

    if not targetId then return end

    local targetAccountId = exports['core_session']:GetAccountId(targetId)
    if not targetAccountId then
        local msg = 'Player not found.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local grantedBy = src > 0 and exports['core_session']:GetAccountId(src) or 0
    exports['system_permissions']:GrantRole(targetAccountId, role, grantedBy)

    local msg = ('Granted role %s to player %d (account %d)'):format(role, targetId, targetAccountId)
    if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'success')
    else print(msg) end
end, false)

--- /revokerole [server_id] [role]
RegisterCommand('revokerole', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId or not exports['system_permissions']:HasRoleLevel(accountId, 'superadmin') then
            TriggerClientEvent('jcrp:notification', src, 'No permission. Requires superadmin.', 'error')
            return
        end
    end

    if #args < 2 then
        local usage = 'Usage: /revokerole [server_id] [role]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local role = args[2]

    if not targetId then return end

    local targetAccountId = exports['core_session']:GetAccountId(targetId)
    if not targetAccountId then
        local msg = 'Player not found.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local revokedBy = src > 0 and exports['core_session']:GetAccountId(src) or 0
    exports['system_permissions']:RevokeRole(targetAccountId, role, revokedBy)

    local msg = ('Revoked role %s from player %d (account %d)'):format(role, targetId, targetAccountId)
    if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'success')
    else print(msg) end
end, false)

JCRP.Log('system_permissions', 'INFO', 'Admin commands registered.')
