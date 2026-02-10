-- System Permissions Migrations

local migrations = {
    {
        version = 12,
        description = 'Create account_roles table',
        sql = [[
            CREATE TABLE IF NOT EXISTS account_roles (
                id INT AUTO_INCREMENT PRIMARY KEY,
                account_id INT NOT NULL,
                role VARCHAR(50) NOT NULL,
                granted_by INT,
                granted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_account_role (account_id, role),
                INDEX idx_account_id (account_id),
                INDEX idx_role (role),
                FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 13,
        description = 'Create admin_audit table',
        sql = [[
            CREATE TABLE IF NOT EXISTS admin_audit (
                id INT AUTO_INCREMENT PRIMARY KEY,
                account_id INT NOT NULL,
                action VARCHAR(100) NOT NULL,
                target_id INT,
                payload_json LONGTEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_account_id (account_id),
                INDEX idx_action (action),
                INDEX idx_created_at (created_at),
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
    
    exports.core_boot:RegisterMigrations('system_permissions', migrations)
end)
