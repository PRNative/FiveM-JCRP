-- System Vehicles Migrations

local migrations = {
    {
        version = 18,
        description = 'Create garages table',
        sql = [[
            CREATE TABLE IF NOT EXISTS garages (
                garage_id VARCHAR(100) PRIMARY KEY,
                label VARCHAR(255) NOT NULL,
                type ENUM('public', 'private', 'depot') NOT NULL,
                coords_json JSON,
                spawn_coords_json JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_type (type)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 19,
        description = 'Create owned_vehicles table',
        sql = [[
            CREATE TABLE IF NOT EXISTS owned_vehicles (
                plate VARCHAR(8) PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                model VARCHAR(50) NOT NULL,
                props_json LONGTEXT,
                garage_id VARCHAR(100) NOT NULL,
                state ENUM('in', 'out', 'impounded') NOT NULL DEFAULT 'in',
                fuel FLOAT DEFAULT 100.0,
                engine_health FLOAT DEFAULT 1000.0,
                body_health FLOAT DEFAULT 1000.0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_citizenid (citizenid),
                INDEX idx_garage_id (garage_id),
                INDEX idx_state (state)
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
    
    exports.core_boot:RegisterMigrations('system_vehicles', migrations)
end)
