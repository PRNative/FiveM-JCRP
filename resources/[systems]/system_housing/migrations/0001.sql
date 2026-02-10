-- system_housing migration 0001: housing-specific tables
-- Houses extend the property system from system_apartments
-- The core tables (properties, property_units, property_ownership, property_stash)
-- are already created by system_apartments.

CREATE TABLE IF NOT EXISTS house_keys (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    unit_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(20) NOT NULL COMMENT 'Who has the key',
    granted_by VARCHAR(20) NOT NULL COMMENT 'Who gave the key',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_house_key (unit_id, citizenid),
    INDEX idx_keys_unit (unit_id),
    INDEX idx_keys_citizen (citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS house_furniture (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    unit_id INT UNSIGNED NOT NULL,
    model VARCHAR(64) NOT NULL,
    position_json TEXT NOT NULL COMMENT 'JSON {x,y,z,rx,ry,rz}',
    placed_by VARCHAR(20) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_furniture_unit (unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS house_doorlocks (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    unit_id INT UNSIGNED NOT NULL,
    door_hash VARCHAR(64) NOT NULL,
    locked TINYINT(1) NOT NULL DEFAULT 1,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_door (unit_id, door_hash),
    INDEX idx_doorlock_unit (unit_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
