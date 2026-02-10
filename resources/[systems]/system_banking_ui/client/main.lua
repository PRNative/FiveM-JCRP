-- ============================================================
-- system_banking_ui: Client
-- Opens/closes bank NUI, handles callbacks
-- ============================================================

local isBankOpen = false

--- Open bank UI
function OpenBank()
    isBankOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    TriggerServerEvent('jcrp:banking:requestData')
end

--- Close bank UI
function CloseBank()
    isBankOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Receive bank data
RegisterNetEvent('jcrp:banking:data', function(data)
    SendNUIMessage({
        action = 'updateData',
        balances = data.balances,
        ledger = data.ledger,
    })
end)

--- NUI Callbacks
RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('jcrp:banking:deposit', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('jcrp:banking:withdraw', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('jcrp:banking:transfer', data.target, tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('closeBank', function(_, cb)
    CloseBank()
    cb('ok')
end)

exports('OpenBank', OpenBank)
exports('CloseBank', CloseBank)
