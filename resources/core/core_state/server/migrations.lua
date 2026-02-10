-- Core State Migrations

local migrations = {
    {
        version = 4,
        description = 'Create character_state table',
        sql = [[
            CREATE TABLE IF NOT EXISTS character_state (
                citizenid VARCHAR(50) PRIMARY KEY,
                position_json JSON,
                heading FLOAT DEFAULT 0.0,
                health INT DEFAULT 200,
                armor INT DEFAULT 0,
                metadata_json LONGTEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_updated_at (updated_at)
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
    
    exports.core_boot:RegisterMigrations('core_state', migrations)
end)
