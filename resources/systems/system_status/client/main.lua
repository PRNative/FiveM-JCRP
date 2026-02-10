-- System Status Client
local currentStatus = {
    hunger = 100,
    thirst = 100,
    stress = 0
}

-- Update status
RegisterNetEvent('system_status:updateStatus', function(status)
    currentStatus = status
    
    -- Trigger HUD update if loaded
    if GetResourceState('ui_hud') == 'started' then
        TriggerEvent('ui_hud:updateStatus', status)
    end
    
    -- Apply screen effects based on status
    ApplyStatusEffects()
end)

-- Apply visual/gameplay effects based on status
function ApplyStatusEffects()
    local ped = PlayerPedId()
    
    -- Low hunger effects
    if currentStatus.hunger < 20 then
        -- Reduce max stamina
        SetPlayerHealthRechargeMultiplier(PlayerId(), 0.5)
    else
        SetPlayerHealthRechargeMultiplier(PlayerId(), 1.0)
    end
    
    -- Low thirst effects
    if currentStatus.thirst < 20 then
        -- Could add screen effects
    end
    
    -- High stress effects
    if currentStatus.stress > 80 then
        -- Could add screen shake or other effects
    end
end

-- Take damage from critical status
RegisterNetEvent('system_status:takeDamage', function(amount)
    local ped = PlayerPedId()
    local currentHealth = GetEntityHealth(ped)
    local newHealth = math.max(100, currentHealth - amount)
    
    SetEntityHealth(ped, newHealth)
end)

-- Get current status
function GetStatus()
    return currentStatus
end

-- Export
exports('GetStatus', GetStatus)

-- Fetch status on spawn
RegisterNetEvent('core_spawn:spawned', function()
    Wait(1000)
    
    local status = lib.callback.await('system_status:getStatus', false)
    if status then
        currentStatus = status
        ApplyStatusEffects()
    end
end)
