-- Core Characters Migrations

local migrations = {
    {
        version = 3,
        description = 'Create characters table',
        sql = [[
            CREATE TABLE IF NOT EXISTS characters (
                id INT AUTO_INCREMENT PRIMARY KEY,
                account_id INT NOT NULL,
                slot INT NOT NULL CHECK (slot BETWEEN 1 AND 3),
                citizenid VARCHAR(50) UNIQUE NOT NULL,
                firstname VARCHAR(50) NOT NULL,
                lastname VARCHAR(50) NOT NULL,
                dob DATE NOT NULL,
                gender VARCHAR(10) NOT NULL,
                model VARCHAR(50) DEFAULT 'mp_m_freemode_01',
                skin_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_played TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY unique_account_slot (account_id, slot),
                INDEX idx_account_id (account_id),
                INDEX idx_citizenid (citizenid),
                INDEX idx_last_played (last_played),
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
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
    
    exports.core_boot:RegisterMigrations('core_characters', migrations)
end)
