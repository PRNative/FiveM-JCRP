-- Core Identity Migrations

local migrations = {
    {
        version = 1,
        description = 'Create accounts table',
        sql = [[
            CREATE TABLE IF NOT EXISTS accounts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                license VARCHAR(255) UNIQUE NOT NULL,
                discord VARCHAR(255) DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                banned TINYINT(1) DEFAULT 0,
                ban_reason TEXT DEFAULT NULL,
                ban_expires TIMESTAMP NULL DEFAULT NULL,
                INDEX idx_license (license),
                INDEX idx_discord (discord),
                INDEX idx_banned (banned)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 2,
        description = 'Create account_audit table',
        sql = [[
            CREATE TABLE IF NOT EXISTS account_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                account_id INT NOT NULL,
                event VARCHAR(100) NOT NULL,
                payload_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_account_id (account_id),
                INDEX idx_event (event),
                INDEX idx_created_at (created_at),
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    }
}

-- Register migrations with core_boot
CreateThread(function()
    if GetResourceState('core_boot') ~= 'started' then
        print('[^1CORE_IDENTITY^7] Waiting for core_boot...')
        while GetResourceState('core_boot') ~= 'started' do
            Wait(100)
        end
    end
    
    exports.core_boot:RegisterMigrations('core_identity', migrations)
end)
