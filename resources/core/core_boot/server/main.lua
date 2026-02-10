-- Core Boot Main
CoreBoot = CoreBoot or {}

local bootComplete = false
local bootFailed = false

-- Boot sequence
CreateThread(function()
    print('┌────────────────────────────────────────┐')
    print('│  ^2JCRP Core Boot^7 - Starting Server   │')
    print('└────────────────────────────────────────┘')
    
    -- Wait for database to be ready
    Wait(1000)
    
    -- Step 1: Load configuration
    print('[^2CORE_BOOT^7] [1/3] Loading configuration...')
    if not CoreBoot.LoadConfig() then
        print('[^1CORE_BOOT^7] ^1FATAL: Failed to load configuration^7')
        bootFailed = true
        return
    end
    
    -- Step 2: Database health check
    print('[^2CORE_BOOT^7] [2/3] Checking database connectivity...')
    Wait(500)
    if not CoreBoot.Migrations.HealthCheck() then
        print('[^1CORE_BOOT^7] ^1FATAL: Database connection failed^7')
        bootFailed = true
        return
    end
    
    -- Step 3: Run migrations
    print('[^2CORE_BOOT^7] [3/3] Running database migrations...')
    Wait(500)
    
    -- Give other resources time to register their migrations
    local maxWait = 50 -- 5 seconds
    local waited = 0
    while waited < maxWait do
        local registryCount = 0
        for _ in pairs(CoreBoot.Migrations.Registry) do
            registryCount = registryCount + 1
        end
        
        if registryCount > 0 then
            break
        end
        
        Wait(100)
        waited = waited + 1
    end
    
    if not CoreBoot.Migrations.RunAll() then
        print('[^1CORE_BOOT^7] ^1FATAL: Database migrations failed^7')
        bootFailed = true
        return
    end
    
    -- Boot complete
    bootComplete = true
    print('┌────────────────────────────────────────┐')
    print('│  ^2✓ JCRP Core Boot Complete^7          │')
    print('│  Server is ready for players          │')
    print('└────────────────────────────────────────┘')
    
    -- Trigger boot complete event
    TriggerEvent('core_boot:ready')
end)

-- Check if boot is complete
function CoreBoot.IsReady()
    return bootComplete
end

function CoreBoot.HasFailed()
    return bootFailed
end

-- Wait for boot to complete
function CoreBoot.WaitForBoot(callback)
    CreateThread(function()
        local timeout = 0
        while not bootComplete and not bootFailed and timeout < 300 do
            Wait(100)
            timeout = timeout + 1
        end
        
        if bootFailed then
            print('[^1CORE_BOOT^7] Boot failed, callback not executed')
            return
        end
        
        if bootComplete and callback then
            callback()
        end
    end)
end

-- Exports
exports('IsReady', CoreBoot.IsReady)
exports('HasFailed', CoreBoot.HasFailed)
exports('WaitForBoot', CoreBoot.WaitForBoot)

-- Command to check boot status
RegisterCommand('bootstatus', function(source, args)
    if source > 0 then return end -- Server console only
    
    if bootComplete then
        print('[^2CORE_BOOT^7] Status: ^2READY^7')
    elseif bootFailed then
        print('[^1CORE_BOOT^7] Status: ^1FAILED^7')
    else
        print('[^3CORE_BOOT^7] Status: ^3BOOTING^7')
    end
end)
