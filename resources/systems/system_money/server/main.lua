-- System Money Main
SystemMoney = SystemMoney or {}

-- Initialize money for new character
local function InitializeMoney(citizenid)
    local existing = MySQL.scalar.await('SELECT citizenid FROM character_money WHERE citizenid = ?', {citizenid})
    
    if not existing then
        local defaultMoney = exports.core_boot:GetConfig('characters.default_money') or {
            cash = 5000,
            bank = 25000,
            dirty = 0
        }
        
        MySQL.insert.await([[
            INSERT INTO character_money (citizenid, cash, bank, dirty)
            VALUES (?, ?, ?, ?)
        ]], {
            citizenid,
            defaultMoney.cash,
            defaultMoney.bank,
            defaultMoney.dirty
        })
        
        print(string.format('[^2SYSTEM_MONEY^7] Initialized money for character: %s', citizenid))
    end
end

-- Get balances
function SystemMoney.GetBalances(citizenid)
    local money = MySQL.single.await('SELECT cash, bank, dirty FROM character_money WHERE citizenid = ?', {citizenid})
    
    if not money then
        InitializeMoney(citizenid)
        money = MySQL.single.await('SELECT cash, bank, dirty FROM character_money WHERE citizenid = ?', {citizenid})
    end
    
    return money or {cash = 0, bank = 0, dirty = 0}
end

-- Log transaction to ledger
local function LogTransaction(citizenid, transactionType, account, amount, balances, reason, ref)
    MySQL.insert('INSERT INTO money_ledger (citizenid, transaction_type, account, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        citizenid,
        transactionType,
        account,
        amount,
        json.encode(balances),
        reason or 'No reason provided',
        ref
    })
end

-- Add money
function SystemMoney.AddMoney(citizenid, account, amount, reason, ref)
    if not citizenid or not account or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    if account ~= 'cash' and account ~= 'bank' and account ~= 'dirty' then
        return false, "Invalid account type"
    end
    
    -- Use transaction for atomic update
    local success = pcall(function()
        MySQL.transaction.await({
            {
                query = string.format('UPDATE character_money SET %s = %s + ? WHERE citizenid = ?', account, account),
                values = {amount, citizenid}
            }
        })
    end)
    
    if not success then
        return false, "Database error"
    end
    
    -- Get updated balances
    local balances = SystemMoney.GetBalances(citizenid)
    
    -- Log transaction
    LogTransaction(citizenid, 'add', account, amount, balances, reason, ref)
    
    -- Notify player if online
    local src = SystemMoney.GetPlayerByCitizenId(citizenid)
    if src then
        TriggerClientEvent('system_money:updateBalances', src, balances)
    end
    
    return true, balances
end

-- Remove money
function SystemMoney.RemoveMoney(citizenid, account, amount, reason, ref)
    if not citizenid or not account or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    if account ~= 'cash' and account ~= 'bank' and account ~= 'dirty' then
        return false, "Invalid account type"
    end
    
    -- Check if player has enough money
    local balances = SystemMoney.GetBalances(citizenid)
    if balances[account] < amount then
        return false, "Insufficient funds"
    end
    
    -- Use transaction for atomic update
    local success = pcall(function()
        MySQL.transaction.await({
            {
                query = string.format('UPDATE character_money SET %s = %s - ? WHERE citizenid = ? AND %s >= ?', account, account, account),
                values = {amount, citizenid, amount}
            }
        })
    end)
    
    if not success then
        return false, "Database error"
    end
    
    -- Get updated balances
    balances = SystemMoney.GetBalances(citizenid)
    
    -- Log transaction
    LogTransaction(citizenid, 'remove', account, amount, balances, reason, ref)
    
    -- Notify player if online
    local src = SystemMoney.GetPlayerByCitizenId(citizenid)
    if src then
        TriggerClientEvent('system_money:updateBalances', src, balances)
    end
    
    return true, balances
end

-- Transfer money between players
function SystemMoney.TransferMoney(fromCitizenId, toCitizenId, account, amount, reason, ref)
    if not fromCitizenId or not toCitizenId or not account or not amount or amount <= 0 then
        return false, "Invalid parameters"
    end
    
    if account ~= 'cash' and account ~= 'bank' and account ~= 'dirty' then
        return false, "Invalid account type"
    end
    
    -- Check if sender has enough money
    local fromBalances = SystemMoney.GetBalances(fromCitizenId)
    if fromBalances[account] < amount then
        return false, "Insufficient funds"
    end
    
    -- Perform transfer using transaction
    local success = pcall(function()
        MySQL.transaction.await({
            {
                query = string.format('UPDATE character_money SET %s = %s - ? WHERE citizenid = ? AND %s >= ?', account, account, account),
                values = {amount, fromCitizenId, amount}
            },
            {
                query = string.format('UPDATE character_money SET %s = %s + ? WHERE citizenid = ?', account, account),
                values = {amount, toCitizenId}
            }
        })
    end)
    
    if not success then
        return false, "Transfer failed"
    end
    
    -- Get updated balances
    fromBalances = SystemMoney.GetBalances(fromCitizenId)
    local toBalances = SystemMoney.GetBalances(toCitizenId)
    
    -- Log transactions
    LogTransaction(fromCitizenId, 'transfer_out', account, amount, fromBalances, reason, ref)
    LogTransaction(toCitizenId, 'transfer_in', account, amount, toBalances, reason, ref)
    
    -- Notify players if online
    local fromSrc = SystemMoney.GetPlayerByCitizenId(fromCitizenId)
    if fromSrc then
        TriggerClientEvent('system_money:updateBalances', fromSrc, fromBalances)
    end
    
    local toSrc = SystemMoney.GetPlayerByCitizenId(toCitizenId)
    if toSrc then
        TriggerClientEvent('system_money:updateBalances', toSrc, toBalances)
    end
    
    return true, {from = fromBalances, to = toBalances}
end

-- Get transaction history
function SystemMoney.GetTransactionHistory(citizenid, limit)
    limit = limit or 50
    
    local transactions = MySQL.query.await([[
        SELECT transaction_type, account, amount, balance_after_json, reason, ref, created_at
        FROM money_ledger
        WHERE citizenid = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], {citizenid, limit})
    
    -- Parse JSON
    if transactions then
        for _, tx in ipairs(transactions) do
            if tx.balance_after_json then
                if type(tx.balance_after_json) == "string" then
                    tx.balance_after = json.decode(tx.balance_after_json)
                else
                    tx.balance_after = tx.balance_after_json
                end
                tx.balance_after_json = nil
            end
        end
    end
    
    return transactions or {}
end

-- Helper to get player source by citizenid
function SystemMoney.GetPlayerByCitizenId(citizenid)
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        if GetResourceState('core_session') == 'started' then
            local playerCitizenId = exports.core_session:GetCitizenId(src)
            if playerCitizenId == citizenid then
                return src
            end
        end
    end
    
    return nil
end

-- Listen to character creation
AddEventHandler('core_characters:created', function(citizenid, accountId)
    InitializeMoney(citizenid)
end)

-- Listen to character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM character_money WHERE citizenid = ?', {citizenid})
    MySQL.update('DELETE FROM money_ledger WHERE citizenid = ?', {citizenid})
    print(string.format('[^2SYSTEM_MONEY^7] Cleaned up money for character: %s', citizenid))
end)

-- Callbacks
lib.callback.register('system_money:getBalances', function(source)
    if GetResourceState('core_session') ~= 'started' then
        return {cash = 0, bank = 0, dirty = 0}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {cash = 0, bank = 0, dirty = 0}
    end
    
    return SystemMoney.GetBalances(citizenid)
end)

lib.callback.register('system_money:getTransactionHistory', function(source, limit)
    if GetResourceState('core_session') ~= 'started' then
        return {}
    end
    
    local citizenid = exports.core_session:GetCitizenId(source)
    if not citizenid then
        return {}
    end
    
    return SystemMoney.GetTransactionHistory(citizenid, limit)
end)

-- Exports
exports('GetBalances', SystemMoney.GetBalances)
exports('AddMoney', SystemMoney.AddMoney)
exports('RemoveMoney', SystemMoney.RemoveMoney)
exports('TransferMoney', SystemMoney.TransferMoney)
exports('GetTransactionHistory', SystemMoney.GetTransactionHistory)

-- Admin commands
RegisterCommand('givemoney', function(source, args)
    if source > 0 then
        local hasPermission = IsPlayerAceAllowed(source, 'command.givemoney')
        if not hasPermission then
            return
        end
    end
    
    if #args < 3 then
        print('Usage: givemoney <player_id> <account> <amount> [reason]')
        return
    end
    
    local targetId = tonumber(args[1])
    local account = args[2]
    local amount = tonumber(args[3])
    local reason = args[4] or 'Admin give money'
    
    if GetResourceState('core_session') ~= 'started' then
        print('core_session not started')
        return
    end
    
    local citizenid = exports.core_session:GetCitizenId(targetId)
    if citizenid then
        local success = SystemMoney.AddMoney(citizenid, account, amount, reason, 'admin_give')
        if success then
            print(string.format('Added $%d to %s account for player %d', amount, account, targetId))
        else
            print('Failed to add money')
        end
    else
        print('Player not found')
    end
end, true)

RegisterCommand('removemoney', function(source, args)
    if source > 0 then
        local hasPermission = IsPlayerAceAllowed(source, 'command.removemoney')
        if not hasPermission then
            return
        end
    end
    
    if #args < 3 then
        print('Usage: removemoney <player_id> <account> <amount> [reason]')
        return
    end
    
    local targetId = tonumber(args[1])
    local account = args[2]
    local amount = tonumber(args[3])
    local reason = args[4] or 'Admin remove money'
    
    if GetResourceState('core_session') ~= 'started' then
        print('core_session not started')
        return
    end
    
    local citizenid = exports.core_session:GetCitizenId(targetId)
    if citizenid then
        local success = SystemMoney.RemoveMoney(citizenid, account, amount, reason, 'admin_remove')
        if success then
            print(string.format('Removed $%d from %s account for player %d', amount, account, targetId))
        else
            print('Failed to remove money')
        end
    else
        print('Player not found')
    end
end, true)

print('[^2SYSTEM_MONEY^7] Initialized')
