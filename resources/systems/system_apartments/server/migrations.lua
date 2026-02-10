-- System Apartments Migrations

local migrations = {
    {
        version = 14,
        description = 'Create properties table',
        sql = [[
            CREATE TABLE IF NOT EXISTS properties (
                property_id VARCHAR(100) PRIMARY KEY,
                type ENUM('apartment', 'house') NOT NULL,
                label VARCHAR(255) NOT NULL,
                entry_coords_json JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_type (type)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 15,
        description = 'Create property_units table',
        sql = [[
            CREATE TABLE IF NOT EXISTS property_units (
                unit_id INT AUTO_INCREMENT PRIMARY KEY,
                property_id VARCHAR(100) NOT NULL,
                unit_label VARCHAR(100) NOT NULL,
                interior_id INT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_property_id (property_id),
                FOREIGN KEY (property_id) REFERENCES properties(property_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 16,
        description = 'Create property_ownership table',
        sql = [[
            CREATE TABLE IF NOT EXISTS property_ownership (
                id INT AUTO_INCREMENT PRIMARY KEY,
                unit_id INT NOT NULL,
                citizenid VARCHAR(50) NOT NULL,
                status ENUM('owned', 'rented') NOT NULL DEFAULT 'owned',
                since TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                until TIMESTAMP NULL,
                UNIQUE KEY unique_unit (unit_id),
                INDEX idx_citizenid (citizenid),
                INDEX idx_status (status),
                FOREIGN KEY (unit_id) REFERENCES property_units(unit_id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 17,
        description = 'Create property_stash table',
        sql = [[
            CREATE TABLE IF NOT EXISTS property_stash (
                id INT AUTO_INCREMENT PRIMARY KEY,
                unit_id INT NOT NULL,
                slot INT NOT NULL,
                item_name VARCHAR(100) NOT NULL,
                amount INT NOT NULL DEFAULT 1,
                metadata_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_unit_slot (unit_id, slot),
                INDEX idx_unit_id (unit_id),
                FOREIGN KEY (unit_id) REFERENCES property_units(unit_id) ON DELETE CASCADE
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
    
    exports.core_boot:RegisterMigrations('system_apartments', migrations)
end)
