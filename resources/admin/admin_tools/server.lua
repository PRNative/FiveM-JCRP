--[[
  admin_tools - Import/Export, admin utilities
  ExportCharacter(citizenid) -> JSON
  ImportCharacter(json) -> citizenid
  Require admin role
]]

--- Export full character to JSON
---@param citizenid string
---@return string|nil json
function ExportCharacter(citizenid)
  if not citizenid then return nil end
  local data = {
    citizenid = citizenid,
    char = exports.core_characters:LoadCharacter(citizenid),
    state = exports.core_state:GetState(citizenid),
    money = exports.system_money:GetBalances(citizenid),
    inventory = exports.system_inventory:GetInventory(citizenid),
    job = exports.system_jobs:GetJob(citizenid),
    status = exports.system_status:GetStatus(citizenid),
  }
  if not data.char then return nil end
  return json.encode(data)
end

--- Import character from JSON (creates new or overwrites with mapping)
---@param jsonStr string
---@param options table|nil { overwrite = citizenid, account_id = number }
---@return string|nil new citizenid
function ImportCharacter(jsonStr, options)
  if not jsonStr or #jsonStr == 0 then return nil end
  local ok, data = pcall(json.decode, jsonStr)
  if not ok or not data or not data.char then return nil end

  options = options or {}
  local accountId = options.account_id
  local targetCitizenid = options.overwrite

  if targetCitizenid then
    -- Overwrite existing
    local existing = exports.core_characters:LoadCharacter(targetCitizenid)
    if not existing then return nil end
    accountId = accountId or existing.account_id
    -- Update char, state, money, inventory, job, status
    -- For simplicity: update in place
    exports.core_state:SetState(targetCitizenid, data.state or {})
    if data.money then
      MySQL.insert.await([[
        INSERT INTO character_money (citizenid, cash, bank, dirty) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE cash = VALUES(cash), bank = VALUES(bank), dirty = VALUES(dirty)
      ]], { targetCitizenid, data.money.cash or 0, data.money.bank or 0, data.money.dirty or 0 })
    end
    if data.job then
      exports.system_jobs:SetJob(targetCitizenid, data.job.job_name, data.job.grade)
    end
    if data.status then
      exports.system_status:SetStatus(targetCitizenid, data.status)
    end
    -- Inventory: clear and re-add
    MySQL.update.await('DELETE FROM character_inventory WHERE citizenid = ?', { targetCitizenid })
    for _, item in ipairs(data.inventory or {}) do
      exports.system_inventory:AddItem(targetCitizenid, item.item_name, item.amount or 1, item.metadata_json and json.decode(item.metadata_json) or nil)
    end
    return targetCitizenid
  end

  -- Create new character
  if not accountId then return nil end
  local slot = 1
  for i = 1, 3 do
    local exists = MySQL.single.await('SELECT 1 FROM characters WHERE account_id = ? AND slot = ?', { accountId, i })
    if not exists then slot = i break end
  end
  local citizenid = exports.core_characters:CreateCharacter(accountId, slot, {
    firstname = data.char.firstname,
    lastname = data.char.lastname,
    dob = data.char.dob,
    gender = data.char.gender,
    model = data.char.model,
    skin_json = data.char.skin_json,
  })
  if not citizenid then return nil end

  exports.core_state:SetState(citizenid, data.state or {})
  if data.money and (data.money.cash or 0) > 0 then
    exports.system_money:AddMoney(citizenid, 'cash', data.money.cash, 'import', nil)
  end
  if data.money and (data.money.bank or 0) > 0 then
    exports.system_money:AddMoney(citizenid, 'bank', data.money.bank, 'import', nil)
  end
  if data.job then
    exports.system_jobs:SetJob(citizenid, data.job.job_name, data.job.grade)
  end
  if data.status then
    exports.system_status:SetStatus(citizenid, data.status)
  end
  for _, item in ipairs(data.inventory or {}) do
    exports.system_inventory:AddItem(citizenid, item.item_name, item.amount or 1, item.metadata_json and json.decode(item.metadata_json) or nil)
  end
  return citizenid
end

exports('ExportCharacter', ExportCharacter)
exports('ImportCharacter', ImportCharacter)
