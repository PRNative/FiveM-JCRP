-- ============================================================
-- system_banking_ui: Banking Server Logic
-- ============================================================

--- Client requests bank data
RegisterNetEvent('jcrp:banking:requestData', function()
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    local balances = exports['system_money']:GetBalances(citizenid)
    local ledger = exports['system_money']:GetLedger(citizenid, 30)

    TriggerClientEvent('jcrp:banking:data', src, {
        balances = balances,
        ledger = ledger or {},
    })
end)

--- Client requests deposit
RegisterNetEvent('jcrp:banking:deposit', function(amount)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('jcrp:notification', src, 'Invalid amount.', 'error')
        return
    end

    local ok, err = exports['system_money']:RemoveMoney(citizenid, 'cash', amount, 'Bank deposit', 'BANK_DEP')
    if not ok then
        TriggerClientEvent('jcrp:notification', src, err or 'Deposit failed.', 'error')
        return
    end

    exports['system_money']:AddMoney(citizenid, 'bank', amount, 'Bank deposit', 'BANK_DEP')
    TriggerClientEvent('jcrp:notification', src, ('Deposited $%s'):format(tostring(amount)), 'success')

    -- Refresh UI
    TriggerEvent('jcrp:banking:requestData')
end)

--- Client requests withdrawal
RegisterNetEvent('jcrp:banking:withdraw', function(amount)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('jcrp:notification', src, 'Invalid amount.', 'error')
        return
    end

    local ok, err = exports['system_money']:RemoveMoney(citizenid, 'bank', amount, 'Bank withdrawal', 'BANK_WD')
    if not ok then
        TriggerClientEvent('jcrp:notification', src, err or 'Withdrawal failed.', 'error')
        return
    end

    exports['system_money']:AddMoney(citizenid, 'cash', amount, 'Bank withdrawal', 'BANK_WD')
    TriggerClientEvent('jcrp:notification', src, ('Withdrew $%s'):format(tostring(amount)), 'success')
end)

--- Client requests transfer
RegisterNetEvent('jcrp:banking:transfer', function(targetCitizenId, amount)
    local src = source
    local citizenid = exports['core_session']:GetCitizenId(src)
    if not citizenid then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        TriggerClientEvent('jcrp:notification', src, 'Invalid amount.', 'error')
        return
    end

    if not targetCitizenId or targetCitizenId == '' then
        TriggerClientEvent('jcrp:notification', src, 'Invalid recipient.', 'error')
        return
    end

    local ok, err = exports['system_money']:TransferMoney(citizenid, targetCitizenId, 'bank', amount, 'Bank transfer', 'BANK_TFR')
    if ok then
        TriggerClientEvent('jcrp:notification', src, ('Transferred $%s to %s'):format(tostring(amount), targetCitizenId), 'success')
    else
        TriggerClientEvent('jcrp:notification', src, err or 'Transfer failed.', 'error')
    end
end)

JCRP.Log('system_banking_ui', 'INFO', 'system_banking_ui loaded.')
