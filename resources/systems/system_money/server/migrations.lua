-- System Money Migrations

local migrations = {
    {
        version = 5,
        description = 'Create character_money table',
        sql = [[
            CREATE TABLE IF NOT EXISTS character_money (
                citizenid VARCHAR(50) PRIMARY KEY,
                cash INT NOT NULL DEFAULT 0,
                bank INT NOT NULL DEFAULT 0,
                dirty INT NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_updated_at (updated_at),
                CHECK (cash >= 0),
                CHECK (bank >= 0),
                CHECK (dirty >= 0)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 6,
        description = 'Create money_ledger table',
        sql = [[
            CREATE TABLE IF NOT EXISTS money_ledger (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                transaction_type ENUM('add', 'remove', 'transfer_in', 'transfer_out') NOT NULL,
                account ENUM('cash', 'bank', 'dirty') NOT NULL,
                amount INT NOT NULL,
                balance_after_json JSON,
                reason VARCHAR(255),
                ref VARCHAR(100),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_citizenid (citizenid),
                INDEX idx_transaction_type (transaction_type),
                INDEX idx_created_at (created_at),
                INDEX idx_ref (ref)
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
    
    exports.core_boot:RegisterMigrations('system_money', migrations)
end)
