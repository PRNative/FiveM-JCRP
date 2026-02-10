-- ============================================================
-- system_phone: Client
-- Phone open/close, message notifications
-- ============================================================

local isPhoneOpen = false

--- New message notification
RegisterNetEvent('jcrp:phone:newMessage', function(data)
    TriggerEvent('jcrp:notification', 'New message received!', 'info')
end)

--- Contact list received
RegisterNetEvent('jcrp:phone:contactsList', function(contacts)
    -- Forward to phone NUI when implemented
end)

--- Messages received
RegisterNetEvent('jcrp:phone:messagesList', function(messages)
    -- Forward to phone NUI when implemented
end)

exports('IsPhoneOpen', function() return isPhoneOpen end)
