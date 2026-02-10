-- core_state migration 0001: character_state table
CREATE TABLE IF NOT EXISTS character_state (
    citizenid VARCHAR(20) NOT NULL PRIMARY KEY,
    position_json TEXT DEFAULT NULL COMMENT 'JSON {x,y,z}',
    heading FLOAT DEFAULT 0.0,
    health INT UNSIGNED DEFAULT 200,
    armor INT UNSIGNED DEFAULT 0,
    metadata_json LONGTEXT DEFAULT NULL COMMENT 'Arbitrary key-value metadata',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_state_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
