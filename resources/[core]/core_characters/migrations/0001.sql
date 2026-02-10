-- core_characters migration 0001: characters table
CREATE TABLE IF NOT EXISTS characters (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT UNSIGNED NOT NULL,
    slot TINYINT UNSIGNED NOT NULL CHECK (slot BETWEEN 1 AND 3),
    citizenid VARCHAR(20) NOT NULL UNIQUE,
    firstname VARCHAR(64) NOT NULL,
    lastname VARCHAR(64) NOT NULL,
    dob VARCHAR(16) DEFAULT '1990-01-01',
    gender TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '0=male, 1=female',
    model VARCHAR(64) NOT NULL DEFAULT 'mp_m_freemode_01',
    skin_json LONGTEXT DEFAULT NULL,
    backstory TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_played TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_account_slot (account_id, slot),
    INDEX idx_characters_citizenid (citizenid),
    INDEX idx_characters_account (account_id),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
