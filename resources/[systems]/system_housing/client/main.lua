-- ============================================================
-- system_housing: Client
-- Doorlock interaction, furniture placement
-- ============================================================

--- Request to toggle a door lock
---@param unitId number
---@param doorHash string
function ToggleDoorLock(unitId, doorHash)
    TriggerServerEvent('jcrp:housing:toggleLock', unitId, doorHash)
end

--- Request to grant a key
---@param unitId number
---@param targetCitizenId string
function GrantKey(unitId, targetCitizenId)
    TriggerServerEvent('jcrp:housing:grantKey', unitId, targetCitizenId)
end

exports('ToggleDoorLock', ToggleDoorLock)
exports('GrantKey', GrantKey)
