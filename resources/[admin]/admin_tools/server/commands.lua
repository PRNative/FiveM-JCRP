-- ============================================================
-- admin_tools: Admin Commands for Import/Export
-- ============================================================

--- /exportchar [citizenid] — exports character JSON to console
RegisterCommand('exportchar', function(source, args, rawCommand)
    local src = source

    -- Permission check (console always allowed)
    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId then return end
        local hasRole = pcall(function()
            return exports['system_permissions']:HasRoleLevel(accountId, 'admin')
        end)
        if not hasRole then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 1 then
        local usage = 'Usage: /exportchar [citizenid]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local citizenid = args[1]
    local data, err = ExportCharacter(citizenid)

    if not data then
        local msg = 'Export failed: ' .. (err or 'unknown')
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local jsonStr = JCRP.JsonEncode(data)

    -- Save to file
    SaveResourceFile(GetCurrentResourceName(), ('exports/%s_%s.json'):format(citizenid, os.date('%Y%m%d_%H%M%S')), jsonStr, -1)

    local msg = ('Character %s exported successfully. Check admin_tools/exports/ folder.'):format(citizenid)
    if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'success')
    else print(msg) end

    -- Also print to console
    print('=== CHARACTER EXPORT: ' .. citizenid .. ' ===')
    print(jsonStr)
    print('=== END EXPORT ===')
end, false)

--- /importchar [account_id] [slot] [filename] — imports from JSON file
RegisterCommand('importchar', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId then return end
        local hasRole = pcall(function()
            return exports['system_permissions']:HasRoleLevel(accountId, 'superadmin')
        end)
        if not hasRole then
            TriggerClientEvent('jcrp:notification', src, 'No permission. Requires superadmin.', 'error')
            return
        end
    end

    if #args < 3 then
        local usage = 'Usage: /importchar [account_id] [slot] [filename]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local accountId = tonumber(args[1])
    local slot = tonumber(args[2])
    local filename = args[3]

    if not accountId or not slot then
        print('Invalid account_id or slot')
        return
    end

    -- Load the JSON file
    local jsonStr = LoadResourceFile(GetCurrentResourceName(), 'exports/' .. filename)
    if not jsonStr then
        local msg = 'File not found: exports/' .. filename
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local importData = JCRP.JsonDecode(jsonStr, nil)
    if not importData then
        local msg = 'Invalid JSON in file'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local newCid, err = ImportCharacter(accountId, slot, importData, false)
    if newCid then
        local msg = ('Character imported as %s into account %d slot %d'):format(newCid, accountId, slot)
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'success')
        else print(msg) end
    else
        local msg = 'Import failed: ' .. (err or 'unknown')
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
    end
end, false)

--- /playerinfo [server_id] — show player session info
RegisterCommand('playerinfo', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId then return end
        local hasRole = pcall(function()
            return exports['system_permissions']:HasRoleLevel(accountId, 'moderator')
        end)
        if not hasRole then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 1 then
        local usage = 'Usage: /playerinfo [server_id]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then return end

    local citizenid = exports['core_session']:GetCitizenId(targetId)
    local accountId = exports['core_session']:GetAccountId(targetId)

    if not citizenid then
        local msg = 'Player not loaded.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local char = exports['core_characters']:LoadCharacter(citizenid)
    local money = nil
    pcall(function() money = exports['system_money']:GetBalances(citizenid) end)
    local job = nil
    pcall(function() job = exports['system_jobs']:GetJob(citizenid) end)

    local info = {
        ('Server ID: %d'):format(targetId),
        ('Account ID: %s'):format(tostring(accountId)),
        ('Citizen ID: %s'):format(citizenid),
        ('Name: %s %s'):format(char and char.firstname or '?', char and char.lastname or '?'),
    }

    if money then
        info[#info + 1] = ('Cash: $%d | Bank: $%d'):format(money.cash, money.bank)
    end
    if job then
        info[#info + 1] = ('Job: %s (%s) %s'):format(job.label or job.name, job.grade_label or '', job.duty and '[ON DUTY]' or '')
    end

    local output = table.concat(info, '\n')
    if src > 0 then
        -- Send each line as notification
        for _, line in ipairs(info) do
            TriggerClientEvent('jcrp:notification', src, line, 'info')
        end
    else
        print('=== PLAYER INFO ===')
        print(output)
        print('===================')
    end
end, false)

--- /givevehicle [server_id] [model]
RegisterCommand('givevehicle', function(source, args, rawCommand)
    local src = source

    if src > 0 then
        local accountId = exports['core_session']:GetAccountId(src)
        if not accountId then return end
        local ok = pcall(function()
            return exports['system_permissions']:HasRoleLevel(accountId, 'admin')
        end)
        if not ok then
            TriggerClientEvent('jcrp:notification', src, 'No permission.', 'error')
            return
        end
    end

    if #args < 2 then
        local usage = 'Usage: /givevehicle [server_id] [model]'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, usage, 'error')
        else print(usage) end
        return
    end

    local targetId = tonumber(args[1])
    local model = args[2]

    if not targetId then return end

    local citizenid = exports['core_session']:GetCitizenId(targetId)
    if not citizenid then
        local msg = 'Player not loaded.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
        return
    end

    local plate = exports['system_vehicles']:RegisterVehicle(citizenid, model, model, 1, nil)
    if plate then
        local msg = ('Vehicle %s (%s) registered to player %d'):format(model, plate, targetId)
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'success')
        else print(msg) end
    else
        local msg = 'Failed to register vehicle.'
        if src > 0 then TriggerClientEvent('jcrp:notification', src, msg, 'error')
        else print(msg) end
    end
end, false)

JCRP.Log('admin_tools', 'INFO', 'Admin tools commands registered.')
