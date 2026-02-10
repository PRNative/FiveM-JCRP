-- System Inventory Migrations

local migrations = {
    {
        version = 7,
        description = 'Create character_inventory table',
        sql = [[
            CREATE TABLE IF NOT EXISTS character_inventory (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                slot INT NOT NULL,
                item_name VARCHAR(100) NOT NULL,
                amount INT NOT NULL DEFAULT 1,
                metadata_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_citizenid_slot (citizenid, slot),
                INDEX idx_citizenid (citizenid),
                INDEX idx_item_name (item_name),
                CHECK (slot >= 1),
                CHECK (amount > 0)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 8,
        description = 'Create item_defs table',
        sql = [[
            CREATE TABLE IF NOT EXISTS item_defs (
                item_name VARCHAR(100) PRIMARY KEY,
                label VARCHAR(100) NOT NULL,
                description TEXT,
                weight INT NOT NULL DEFAULT 0,
                stackable TINYINT(1) DEFAULT 0,
                max_stack INT DEFAULT 1,
                usable TINYINT(1) DEFAULT 0,
                metadata_schema_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
    
    exports.core_boot:RegisterMigrations('system_inventory', migrations)
end)
