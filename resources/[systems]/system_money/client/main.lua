-- ============================================================
-- system_money: Client
-- Receives money updates and forwards to HUD
-- ============================================================

local currentMoney = { cash = 0, bank = 0, dirty = 0 }

--- Receive money update from server
RegisterNetEvent('jcrp:money:update', function(balances)
    if type(balances) ~= 'table' then return end
    currentMoney = balances

    -- Forward to HUD
    TriggerEvent('jcrp:hud:updateMoney', currentMoney)
end)

--- Get current money (for other client resources)
---@return table
function GetCurrentMoney()
    return currentMoney
end

exports('GetCurrentMoney', GetCurrentMoney)
