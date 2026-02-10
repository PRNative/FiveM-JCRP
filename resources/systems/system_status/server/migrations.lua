-- System Status Migrations

local migrations = {
    {
        version = 11,
        description = 'Create character_status table',
        sql = [[
            CREATE TABLE IF NOT EXISTS character_status (
                citizenid VARCHAR(50) PRIMARY KEY,
                hunger INT NOT NULL DEFAULT 100,
                thirst INT NOT NULL DEFAULT 100,
                stress INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                CHECK (hunger >= 0 AND hunger <= 100),
                CHECK (thirst >= 0 AND thirst <= 100),
                CHECK (stress >= 0 AND stress <= 100)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    }
}

-- Register migrations with core_boot
CreateThread(function()
    if GetResourceState('core_boot') ~= 'started' then
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:RegisterMigrations('system_status', migrations)
end)
