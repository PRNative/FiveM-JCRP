-- ============================================================
-- system_money: Authoritative Money System (Server)
-- Cash, Bank, Dirty — all mutations ledgered
-- ============================================================

-- In-memory cache: citizenid -> {cash, bank, dirty}
local MoneyCache = {}

--- Initialize money for a new character (with defaults from config)
---@param citizenid string
---@return boolean
local function InitMoney(citizenid)
    local config = exports['core_boot']:GetConfig()
    local defaultCash = config.money and config.money.default_cash or 5000
    local defaultBank = config.money and config.money.default_bank or 25000

    MySQL.insert.await([[
        INSERT INTO character_money (citizenid, cash, bank, dirty)
        VALUES (?, ?, ?, 0)
        ON DUPLICATE KEY UPDATE updated_at = NOW()
    ]], { citizenid, defaultCash, defaultBank })

    MoneyCache[citizenid] = {
        cash = defaultCash,
        bank = defaultBank,
        dirty = 0,
    }

    -- Initial ledger entries
    WriteLedger(citizenid, 'cash', defaultCash, MoneyCache[citizenid], 'Character created — starting cash', 'INIT')
    WriteLedger(citizenid, 'bank', defaultBank, MoneyCache[citizenid], 'Character created — starting bank', 'INIT')

    JCRP.Log('system_money', 'INFO', ('Initialized money for %s: cash=%d bank=%d'):format(citizenid, defaultCash, defaultBank))
    return true
end

--- Write a ledger entry
---@param citizenid string
---@param moneyType string "cash"|"bank"|"dirty"
---@param amount number
---@param balanceAfter table
---@param reason string
---@param ref string|nil
function WriteLedger(citizenid, moneyType, amount, balanceAfter, reason, ref)
    MySQL.insert('INSERT INTO money_ledger (citizenid, type, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid, moneyType, amount,
        JCRP.JsonEncode(balanceAfter),
        reason or 'No reason',
        ref,
    })
end

--- Load money from DB into cache
---@param citizenid string
---@return table|nil balances
local function LoadMoney(citizenid)
    if MoneyCache[citizenid] then
        return MoneyCache[citizenid]
    end

    local row = MySQL.single.await(
        'SELECT cash, bank, dirty FROM character_money WHERE citizenid = ?',
        { citizenid }
    )

    if not row then
        -- Character has no money record — initialize with defaults
        InitMoney(citizenid)
        return MoneyCache[citizenid]
    end

    MoneyCache[citizenid] = {
        cash = row.cash or 0,
        bank = row.bank or 0,
        dirty = row.dirty or 0,
    }

    return MoneyCache[citizenid]
end

--- Get balances for a character
---@param citizenid string
---@return table {cash, bank, dirty}
local function GetBalances(citizenid)
    local money = LoadMoney(citizenid)
    if not money then return { cash = 0, bank = 0, dirty = 0 } end
    -- Return a copy
    return {
        cash = money.cash,
        bank = money.bank,
        dirty = money.dirty,
    }
end

--- Add money to an account type
---@param citizenid string
---@param account string "cash"|"bank"|"dirty"
---@param amount number (must be positive)
---@param reason string
---@param ref string|nil
---@return boolean success
---@return string|nil error
local function AddMoney(citizenid, account, amount, reason, ref)
    if not citizenid or not account or not amount then
        return false, 'Missing parameters'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false, 'Amount must be positive'
    end

    if account ~= 'cash' and account ~= 'bank' and account ~= 'dirty' then
        return false, 'Invalid account type: ' .. tostring(account)
    end

    local money = LoadMoney(citizenid)
    if not money then
        return false, 'Character money not found'
    end

    money[account] = money[account] + amount
    MoneyCache[citizenid] = money

    -- Write to DB
    MySQL.update.await(
        ('UPDATE character_money SET %s = ?, updated_at = NOW() WHERE citizenid = ?'):format(account),
        { money[account], citizenid }
    )

    -- Ledger
    WriteLedger(citizenid, account, amount, money, reason or 'Add money', ref)

    -- Notify client
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:money:update', src, GetBalances(citizenid))
    end

    JCRP.Log('system_money', 'DEBUG', ('+%d %s for %s (%s)'):format(amount, account, citizenid, reason or ''))
    return true, nil
end

--- Remove money from an account type
---@param citizenid string
---@param account string "cash"|"bank"|"dirty"
---@param amount number (must be positive)
---@param reason string
---@param ref string|nil
---@return boolean success
---@return string|nil error
local function RemoveMoney(citizenid, account, amount, reason, ref)
    if not citizenid or not account or not amount then
        return false, 'Missing parameters'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false, 'Amount must be positive'
    end

    if account ~= 'cash' and account ~= 'bank' and account ~= 'dirty' then
        return false, 'Invalid account type: ' .. tostring(account)
    end

    local config = exports['core_boot']:GetConfig()
    local allowNegative = false
    if account == 'cash' then
        allowNegative = config.money and config.money.allow_negative_cash or false
    elseif account == 'bank' then
        allowNegative = config.money and config.money.allow_negative_bank or false
    end

    local money = LoadMoney(citizenid)
    if not money then
        return false, 'Character money not found'
    end

    if not allowNegative and money[account] < amount then
        return false, 'Insufficient funds'
    end

    money[account] = money[account] - amount
    MoneyCache[citizenid] = money

    -- Write to DB
    MySQL.update.await(
        ('UPDATE character_money SET %s = ?, updated_at = NOW() WHERE citizenid = ?'):format(account),
        { money[account], citizenid }
    )

    -- Ledger
    WriteLedger(citizenid, account, -amount, money, reason or 'Remove money', ref)

    -- Notify client
    local src = exports['core_session']:GetSourceByCitizenId(citizenid)
    if src then
        TriggerClientEvent('jcrp:money:update', src, GetBalances(citizenid))
    end

    JCRP.Log('system_money', 'DEBUG', ('-%d %s for %s (%s)'):format(amount, account, citizenid, reason or ''))
    return true, nil
end

--- Transfer money between two characters
---@param fromCitizenId string
---@param toCitizenId string
---@param account string "cash"|"bank"
---@param amount number
---@param reason string
---@param ref string|nil
---@return boolean success
---@return string|nil error
local function TransferMoney(fromCitizenId, toCitizenId, account, amount, reason, ref)
    if not fromCitizenId or not toCitizenId or not account or not amount then
        return false, 'Missing parameters'
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return false, 'Amount must be positive'
    end

    if fromCitizenId == toCitizenId then
        return false, 'Cannot transfer to yourself'
    end

    -- Remove from sender
    local ok, err = RemoveMoney(fromCitizenId, account, amount, ('Transfer to %s: %s'):format(toCitizenId, reason or ''), ref)
    if not ok then
        return false, 'Sender: ' .. (err or 'Unknown error')
    end

    -- Add to receiver
    local ok2, err2 = AddMoney(toCitizenId, account, amount, ('Transfer from %s: %s'):format(fromCitizenId, reason or ''), ref)
    if not ok2 then
        -- Rollback: give money back to sender
        AddMoney(fromCitizenId, account, amount, 'Transfer rollback', ref)
        return false, 'Receiver: ' .. (err2 or 'Unknown error')
    end

    JCRP.Log('system_money', 'INFO', ('Transfer: %s -> %s | %d %s (%s)'):format(fromCitizenId, toCitizenId, amount, account, reason or ''))
    return true, nil
end

--- Flush money to DB (for disconnect/restart safety)
---@param citizenid string
local function FlushMoney(citizenid)
    local money = MoneyCache[citizenid]
    if not money then return end

    MySQL.update.await([[
        UPDATE character_money SET cash = ?, bank = ?, dirty = ?, updated_at = NOW()
        WHERE citizenid = ?
    ]], { money.cash, money.bank, money.dirty, citizenid })
end

--- Unload money from cache
---@param citizenid string
local function UnloadMoney(citizenid)
    FlushMoney(citizenid)
    MoneyCache[citizenid] = nil
end

--- Get ledger history for a character
---@param citizenid string
---@param limit number|nil
---@param offset number|nil
---@return table
local function GetLedger(citizenid, limit, offset)
    limit = limit or 50
    offset = offset or 0
    return MySQL.query.await(
        'SELECT * FROM money_ledger WHERE citizenid = ? ORDER BY created_at DESC LIMIT ? OFFSET ?',
        { citizenid, limit, offset }
    )
end

-- ============================================================
-- Resource Stop — flush all
-- ============================================================
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        JCRP.Log('system_money', 'INFO', 'Flushing all money caches...')
        for citizenid, _ in pairs(MoneyCache) do
            FlushMoney(citizenid)
        end
    end
end)

-- ============================================================
-- Exports
-- ============================================================
exports('InitMoney', InitMoney)
exports('GetBalances', GetBalances)
exports('AddMoney', AddMoney)
exports('RemoveMoney', RemoveMoney)
exports('TransferMoney', TransferMoney)
exports('FlushMoney', FlushMoney)
exports('UnloadMoney', UnloadMoney)
exports('GetLedger', GetLedger)

JCRP.Log('system_money', 'INFO', 'system_money loaded.')
