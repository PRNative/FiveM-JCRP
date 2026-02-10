-- System Jobs Migrations

local migrations = {
    {
        version = 9,
        description = 'Create character_jobs table',
        sql = [[
            CREATE TABLE IF NOT EXISTS character_jobs (
                citizenid VARCHAR(50) PRIMARY KEY,
                job_name VARCHAR(50) NOT NULL DEFAULT 'unemployed',
                grade INT NOT NULL DEFAULT 0,
                duty TINYINT(1) DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_job_name (job_name),
                INDEX idx_duty (duty)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]]
    },
    {
        version = 10,
        description = 'Create job_defs table',
        sql = [[
            CREATE TABLE IF NOT EXISTS job_defs (
                job_name VARCHAR(50) PRIMARY KEY,
                label VARCHAR(100) NOT NULL,
                default_duty TINYINT(1) DEFAULT 0,
                grades_json LONGTEXT,
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
    
    exports.core_boot:RegisterMigrations('system_jobs', migrations)
end)
