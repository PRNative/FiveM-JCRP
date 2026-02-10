--[[
  system_permissions - P1
  Role/ACE, admin audit, HasRole, RequireRole
  Exports: HasRole, RequireRole, AddRole, RemoveRole, AdminAudit
]]

local PermMigrations = {
  { version = 'system_permissions_001', sql = LoadResourceFile(GetCurrentResourceName(), 'migrations/001_permissions.sql') },
}

CreateThread(function()
  while not exports.core_boot:IsReady() do Wait(100) end
  local ok = exports.core_boot:RunMigrationsFor(GetCurrentResourceName(), PermMigrations)
  if not ok then
    print('^1[system_permissions] Migrations failed^0')
    return
  end
  print('^2[system_permissions] Ready^0')
end)

--- Check if account has role
---@param account_id number
---@param role string
---@return boolean
function HasRole(account_id, role)
  if not account_id or not role then return false end
  local row = MySQL.single.await('SELECT 1 FROM account_roles WHERE account_id = ? AND role = ?', { account_id, role })
  return row ~= nil
end

--- Require role for source (returns false + kick if missing)
---@param src number
---@param role string
---@return boolean
function RequireRole(src, role)
  local accountId = exports.core_session:GetAccountId(src)
  if not accountId then return false end
  if HasRole(accountId, role) then return true end
  DropPlayer(src, 'Insufficient permissions.')
  return false
end

--- Add role to account
---@param account_id number
---@param role string
function AddRole(account_id, role)
  if not account_id or not role then return end
  MySQL.insert.await('INSERT IGNORE INTO account_roles (account_id, role) VALUES (?, ?)', { account_id, role })
end

--- Remove role
---@param account_id number
---@param role string
function RemoveRole(account_id, role)
  if not account_id or not role then return end
  MySQL.update.await('DELETE FROM account_roles WHERE account_id = ? AND role = ?', { account_id, role })
end

--- Admin audit log
---@param account_id number
---@param action string
---@param payload table|nil
function AdminAudit(account_id, action, payload)
  if not account_id then return end
  local jsonStr = payload and json.encode(payload) or nil
  MySQL.insert.await('INSERT INTO admin_audit (account_id, action, payload_json) VALUES (?, ?, ?)', { account_id, action, jsonStr })
end

exports('HasRole', HasRole)
exports('RequireRole', RequireRole)
exports('AddRole', AddRole)
exports('RemoveRole', RemoveRole)
exports('AdminAudit', AdminAudit)
