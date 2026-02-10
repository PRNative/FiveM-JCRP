-- UI HUD Client
local hudData = {
    money = {cash = 0, bank = 0},
    job = {label = 'Unemployed', grade_label = '', duty = false},
    status = {hunger = 100, thirst = 100, stress = 0},
    location = {street = '', area = ''},
    voice = {talking = false, level = 2}
}

local isHudVisible = true

-- Show HUD
function ShowHUD()
    isHudVisible = true
    SendNUIMessage({action = 'show'})
end

-- Hide HUD
function HideHUD()
    isHudVisible = false
    SendNUIMessage({action = 'hide'})
end

-- Toggle HUD
function ToggleHUD()
    if isHudVisible then
        HideHUD()
    else
        ShowHUD()
    end
end

-- Update HUD data
function UpdateHUD()
    SendNUIMessage({
        action = 'update',
        data = hudData
    })
end

-- Listen for money updates
RegisterNetEvent('system_money:updateBalances', function(balances)
    hudData.money = balances
    UpdateHUD()
end)

-- Listen for job updates
RegisterNetEvent('system_jobs:updateJob', function(job)
    hudData.job = job
    UpdateHUD()
end)

-- Listen for status updates
RegisterNetEvent('ui_hud:updateStatus', function(status)
    hudData.status = status
    UpdateHUD()
end)

-- Update location thread
CreateThread(function()
    while true do
        Wait(1000)
        
        if isHudVisible then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local area = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            
            local streetName = GetStreetNameFromHashKey(street1)
            if street2 ~= 0 then
                local streetName2 = GetStreetNameFromHashKey(street2)
                streetName = streetName .. ' / ' .. streetName2
            end
            
            hudData.location = {
                street = streetName,
                area = area
            }
            
            UpdateHUD()
        end
    end
end)

-- Update health/armor thread
CreateThread(function()
    while true do
        Wait(100)
        
        if isHudVisible then
            local ped = PlayerPedId()
            local health = GetEntityHealth(ped) - 100
            local armor = GetPedArmour(ped)
            
            SendNUIMessage({
                action = 'updateVitals',
                health = math.max(0, math.min(100, health)),
                armor = armor
            })
        end
    end
end)

-- Initial load on spawn
RegisterNetEvent('core_spawn:spawned', function()
    Wait(2000)
    
    -- Fetch initial data
    if GetResourceState('system_money') == 'started' then
        local balances = lib.callback.await('system_money:getBalances', false)
        if balances then
            hudData.money = balances
        end
    end
    
    if GetResourceState('system_jobs') == 'started' then
        local job = lib.callback.await('system_jobs:getJob', false)
        if job then
            hudData.job = job
        end
    end
    
    if GetResourceState('system_status') == 'started' then
        local status = lib.callback.await('system_status:getStatus', false)
        if status then
            hudData.status = status
        end
    end
    
    UpdateHUD()
    ShowHUD()
end)

-- Hide default HUD components
CreateThread(function()
    while true do
        Wait(0)
        
        -- Hide default HUD elements
        HideHudComponentThisFrame(1) -- Wanted stars
        HideHudComponentThisFrame(2) -- Weapon icon
        HideHudComponentThisFrame(3) -- Cash
        HideHudComponentThisFrame(4) -- MP Cash
        HideHudComponentThisFrame(6) -- Vehicle name
        HideHudComponentThisFrame(7) -- Area name
        HideHudComponentThisFrame(8) -- Vehicle class
        HideHudComponentThisFrame(9) -- Street name
        HideHudComponentThisFrame(13) -- Cash change
        HideHudComponentThisFrame(19) -- Weapon wheel
    end
end)

-- Command to toggle HUD
RegisterCommand('hud', function()
    ToggleHUD()
end)

-- Exports
exports('ShowHUD', ShowHUD)
exports('HideHUD', HideHUD)
exports('ToggleHUD', ToggleHUD)
exports('UpdateHUD', UpdateHUD)
