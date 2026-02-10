-- Core Identity Main
CoreIdentity = CoreIdentity or {}

-- Get player identifiers
local function GetPlayerIdentifiers(src)
    local identifiers = {
        license = nil,
        discord = nil,
        steam = nil,
        ip = nil
    }
    
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        
        if string.sub(identifier, 1, string.len("license:")) == "license:" then
            identifiers.license = identifier
        elseif string.sub(identifier, 1, string.len("discord:")) == "discord:" then
            identifiers.discord = identifier
        elseif string.sub(identifier, 1, string.len("steam:")) == "steam:" then
            identifiers.steam = identifier
        elseif string.sub(identifier, 1, string.len("ip:")) == "ip:" then
            identifiers.ip = identifier
        end
    end
    
    return identifiers
end

-- Resolve or create account from identifiers
function CoreIdentity.ResolveAccount(src)
    local identifiers = GetPlayerIdentifiers(src)
    
    if not identifiers.license then
        print(string.format('[^1CORE_IDENTITY^7] Player %d has no license identifier', src))
        return nil
    end
    
    -- Check if account exists
    local account = MySQL.single.await('SELECT * FROM accounts WHERE license = ?', {identifiers.license})
    
    if account then
        -- Update last seen and discord if changed
        MySQL.update.await('UPDATE accounts SET last_seen = NOW(), discord = ? WHERE id = ?', {
            identifiers.discord,
            account.id
        })
        
        -- Audit login
        CoreIdentity.Audit(account.id, 'login', {
            source = src,
            identifiers = identifiers
        })
        
        print(string.format('[^2CORE_IDENTITY^7] Account %d resolved for player %d', account.id, src))
        return account.id
    else
        -- Create new account
        local result = MySQL.insert.await('INSERT INTO accounts (license, discord) VALUES (?, ?)', {
            identifiers.license,
            identifiers.discord
        })
        
        if result then
            print(string.format('[^2CORE_IDENTITY^7] New account %d created for player %d', result, src))
            
            -- Audit account creation
            CoreIdentity.Audit(result, 'account_created', {
                source = src,
                identifiers = identifiers
            })
            
            return result
        else
            print(string.format('[^1CORE_IDENTITY^7] Failed to create account for player %d', src))
            return nil
        end
    end
end

-- Check if account is banned
function CoreIdentity.IsBanned(accountId)
    local account = MySQL.single.await('SELECT banned, ban_reason, ban_expires FROM accounts WHERE id = ?', {accountId})
    
    if not account then
        return false, nil
    end
    
    if account.banned == 1 then
        -- Check if ban has expired
        if account.ban_expires then
            local expiresTimestamp = os.time({
                year = tonumber(string.sub(account.ban_expires, 1, 4)),
                month = tonumber(string.sub(account.ban_expires, 6, 7)),
                day = tonumber(string.sub(account.ban_expires, 9, 10)),
                hour = tonumber(string.sub(account.ban_expires, 12, 13)),
                min = tonumber(string.sub(account.ban_expires, 15, 16)),
                sec = tonumber(string.sub(account.ban_expires, 18, 19))
            })
            
            if os.time() >= expiresTimestamp then
                -- Ban expired, unban
                MySQL.update.await('UPDATE accounts SET banned = 0, ban_reason = NULL, ban_expires = NULL WHERE id = ?', {accountId})
                CoreIdentity.Audit(accountId, 'ban_expired', {})
                return false, nil
            end
        end
        
        return true, account.ban_reason or "No reason provided"
    end
    
    return false, nil
end

-- Ban account
function CoreIdentity.BanAccount(accountId, reason, expiresIn)
    local expires = nil
    if expiresIn then
        expires = os.date('%Y-%m-%d %H:%M:%S', os.time() + expiresIn)
    end
    
    MySQL.update.await('UPDATE accounts SET banned = 1, ban_reason = ?, ban_expires = ? WHERE id = ?', {
        reason,
        expires,
        accountId
    })
    
    CoreIdentity.Audit(accountId, 'banned', {
        reason = reason,
        expires = expires
    })
    
    print(string.format('[^2CORE_IDENTITY^7] Account %d has been banned', accountId))
end

-- Unban account
function CoreIdentity.UnbanAccount(accountId)
    MySQL.update.await('UPDATE accounts SET banned = 0, ban_reason = NULL, ban_expires = NULL WHERE id = ?', {accountId})
    
    CoreIdentity.Audit(accountId, 'unbanned', {})
    
    print(string.format('[^2CORE_IDENTITY^7] Account %d has been unbanned', accountId))
end

-- Audit log
function CoreIdentity.Audit(accountId, event, payload)
    local payloadJson = json.encode(payload or {})
    
    MySQL.insert('INSERT INTO account_audit (account_id, event, payload_json) VALUES (?, ?, ?)', {
        accountId,
        event,
        payloadJson
    })
end

-- Get account by license
function CoreIdentity.GetAccountByLicense(license)
    return MySQL.single.await('SELECT * FROM accounts WHERE license = ?', {license})
end

-- Get account by ID
function CoreIdentity.GetAccountById(accountId)
    return MySQL.single.await('SELECT * FROM accounts WHERE id = ?', {accountId})
end

-- Player connecting event with ban check
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    deferrals.defer()
    local src = source
    
    Wait(0)
    deferrals.update('Checking account...')
    
    -- Wait for core_boot to be ready
    local bootReady = exports.core_boot:IsReady()
    local attempts = 0
    while not bootReady and attempts < 100 do
        Wait(100)
        bootReady = exports.core_boot:IsReady()
        attempts = attempts + 1
    end
    
    if not bootReady then
        deferrals.done('Server is still booting. Please try again in a moment.')
        return
    end
    
    -- Resolve account
    local accountId = CoreIdentity.ResolveAccount(src)
    
    if not accountId then
        deferrals.done('Failed to resolve account. Please contact server administration.')
        return
    end
    
    -- Check ban status
    local isBanned, banReason = CoreIdentity.IsBanned(accountId)
    
    if isBanned then
        deferrals.done(string.format('You are banned from this server.\nReason: %s', banReason))
        return
    end
    
    deferrals.update('Account verified')
    Wait(500)
    deferrals.done()
end)

-- Exports
exports('ResolveAccount', CoreIdentity.ResolveAccount)
exports('IsBanned', CoreIdentity.IsBanned)
exports('BanAccount', CoreIdentity.BanAccount)
exports('UnbanAccount', CoreIdentity.UnbanAccount)
exports('Audit', CoreIdentity.Audit)
exports('GetAccountByLicense', CoreIdentity.GetAccountByLicense)
exports('GetAccountById', CoreIdentity.GetAccountById)

-- Admin commands
RegisterCommand('ban', function(source, args)
    if source > 0 then
        -- Check if player has admin permission (we'll implement this properly in system_permissions)
        local hasPermission = IsPlayerAceAllowed(source, 'command.ban')
        if not hasPermission then
            return
        end
    end
    
    if #args < 2 then
        print('Usage: ban <player_id> <reason> [duration_seconds]')
        return
    end
    
    local targetId = tonumber(args[1])
    local reason = args[2]
    local duration = args[3] and tonumber(args[3]) or nil
    
    local accountId = CoreIdentity.ResolveAccount(targetId)
    if accountId then
        CoreIdentity.BanAccount(accountId, reason, duration)
        DropPlayer(targetId, string.format('You have been banned.\nReason: %s', reason))
        print(string.format('Player %d (Account %d) has been banned', targetId, accountId))
    else
        print('Failed to resolve account for target player')
    end
end, true)

RegisterCommand('unban', function(source, args)
    if source > 0 then
        local hasPermission = IsPlayerAceAllowed(source, 'command.unban')
        if not hasPermission then
            return
        end
    end
    
    if #args < 1 then
        print('Usage: unban <license>')
        return
    end
    
    local license = args[1]
    local account = CoreIdentity.GetAccountByLicense(license)
    
    if account then
        CoreIdentity.UnbanAccount(account.id)
        print(string.format('Account %d has been unbanned', account.id))
    else
        print('Account not found with that license')
    end
end, true)

print('[^2CORE_IDENTITY^7] Initialized')
