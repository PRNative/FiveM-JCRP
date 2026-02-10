--[[
  system_money - P1
  Authoritative wallet + bank + dirty money
  All transactions ledgered, anti-negative, atomic
  Exports: GetBalances, AddMoney, RemoveMoney, TransferMoney
]]

local MoneyMigrations = {
  { version = 'system_money_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_money.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), MoneyMigrations)
  if not ok then
    print('^1[system_money] Migrations failed^0')
    return
  end
  print('^2[system_money] Ready^0')
end)

local ACCOUNTS = { cash = 'cash', bank = 'bank', dirty = 'dirty' }

--- Ensure money row exists
local function EnsureRow(citizenid)
  MySQL.insert.await(
    'INSERT IGNORE INTO character_money (citizenid) VALUES (?)',
    { citizenid }
  )
end

--- Get balances
---@param citizenid string
---@return table { cash, bank, dirty }
function GetBalances(citizenid)
  if not citizenid then return { cash = 0, bank = 0, dirty = 0 } end
  EnsureRow(citizenid)
  local row = MySQL.single.await('SELECT cash, bank, dirty FROM character_money WHERE citizenid = ?', { citizenid })
  return {
    cash = row and row.cash or 0,
    bank = row and row.bank or 0,
    dirty = row and row.dirty or 0,
  }
end

--- Add money
---@param citizenid string
---@param account string 'cash'|'bank'|'dirty'
---@param amount number
---@param reason string|nil
---@param ref string|nil
---@return boolean ok
function AddMoney(citizenid, account, amount, reason, ref)
  if not citizenid or not ACCOUNTS[account] or type(amount) ~= 'number' or amount <= 0 then return false end
  EnsureRow(citizenid)
  local col = account
  MySQL.update.await('UPDATE character_money SET ' .. col .. ' = ' .. col .. ' + ? WHERE citizenid = ?', { amount, citizenid })
  local balances = GetBalances(citizenid)
  MySQL.insert.await(
    'INSERT INTO money_ledger (citizenid, type, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?)',
    { citizenid, account, amount, json.encode({ [account] = balances[account] }), reason or 'add', ref or nil }
  )
  return true
end

--- Remove money
---@param citizenid string
---@param account string
---@param amount number
---@param reason string|nil
---@param ref string|nil
---@return boolean ok false if insufficient
function RemoveMoney(citizenid, account, amount, reason, ref)
  if not citizenid or not ACCOUNTS[account] or type(amount) ~= 'number' or amount <= 0 then return false end
  local balances = GetBalances(citizenid)
  if balances[account] < amount then return false end
  MySQL.update.await('UPDATE character_money SET ' .. account .. ' = ' .. account .. ' - ? WHERE citizenid = ?', { amount, citizenid })
  local newBal = GetBalances(citizenid)
  MySQL.insert.await(
    'INSERT INTO money_ledger (citizenid, type, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?)',
    { citizenid, account, -amount, json.encode({ [account] = newBal[account] }), reason or 'remove', ref or nil }
  )
  return true
end

--- Transfer between characters
---@param fromCitizenid string
---@param toCitizenid string
---@param account string
---@param amount number
---@param reason string|nil
---@param ref string|nil
---@return boolean ok
function TransferMoney(fromCitizenid, toCitizenid, account, amount, reason, ref)
  if not fromCitizenid or not toCitizenid or not ACCOUNTS[account] or type(amount) ~= 'number' or amount <= 0 then return false end
  if fromCitizenid == toCitizenid then return false end
  local fromBal = GetBalances(fromCitizenid)
  if fromBal[account] < amount then return false end
  EnsureRow(toCitizenid)
  local ok, err = pcall(function()
    MySQL.transaction.await(function()
      MySQL.update.await('UPDATE character_money SET ' .. account .. ' = ' .. account .. ' - ? WHERE citizenid = ?', { amount, fromCitizenid })
      MySQL.update.await('UPDATE character_money SET ' .. account .. ' = ' .. account .. ' + ? WHERE citizenid = ?', { amount, toCitizenid })
      local fromNew = GetBalances(fromCitizenid)
      local toNew = GetBalances(toCitizenid)
      MySQL.insert.await(
        'INSERT INTO money_ledger (citizenid, type, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?)',
        { fromCitizenid, account, -amount, json.encode({ [account] = fromNew[account] }), reason or 'transfer_out', ref or nil }
      )
      MySQL.insert.await(
        'INSERT INTO money_ledger (citizenid, type, amount, balance_after_json, reason, ref) VALUES (?, ?, ?, ?, ?, ?)',
        { toCitizenid, account, amount, json.encode({ [account] = toNew[account] }), reason or 'transfer_in', ref or toCitizenid }
      )
    end)
  end)
  return ok
end

--- Give starter cash to new character (called from core_session hydration)
---@param citizenid string
---@param amount number
function GiveStarterCash(citizenid, amount)
  if not citizenid or not amount or amount <= 0 then return end
  AddMoney(citizenid, 'cash', amount, 'starter', 'new_character')
end

exports('GetBalances', GetBalances)
exports('AddMoney', AddMoney)
exports('RemoveMoney', RemoveMoney)
exports('TransferMoney', TransferMoney)
exports('GiveStarterCash', GiveStarterCash)
