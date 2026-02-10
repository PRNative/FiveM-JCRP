-- system_apartments migration 0001: property system tables
CREATE TABLE IF NOT EXISTS properties (
    property_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    type ENUM('apartment','house','business','garage') NOT NULL DEFAULT 'apartment',
    label VARCHAR(128) NOT NULL,
    description TEXT DEFAULT NULL,
    entry_coords_json TEXT NOT NULL COMMENT 'JSON {x,y,z}',
    interior_id VARCHAR(64) DEFAULT NULL,
    interior_coords_json TEXT DEFAULT NULL COMMENT 'JSON {x,y,z} inside the interior',
    price INT UNSIGNED NOT NULL DEFAULT 0,
    max_units INT UNSIGNED NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_properties_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS property_units (
    unit_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    property_id INT UNSIGNED NOT NULL,
    unit_label VARCHAR(128) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_units_property (property_id),
    FOREIGN KEY (property_id) REFERENCES properties(property_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS property_ownership (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    unit_id INT UNSIGNED NOT NULL,
    citizenid VARCHAR(20) NOT NULL,
    status ENUM('owned','rented','expired') NOT NULL DEFAULT 'owned',
    since TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    until_date TIMESTAMP DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ownership_citizen (citizenid),
    INDEX idx_ownership_unit (unit_id),
    UNIQUE KEY uk_unit_citizen (unit_id, citizenid),
    FOREIGN KEY (unit_id) REFERENCES property_units(unit_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS property_stash (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    unit_id INT UNSIGNED NOT NULL,
    slot INT UNSIGNED NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL DEFAULT 1,
    metadata_json TEXT DEFAULT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_stash_slot (unit_id, slot),
    INDEX idx_stash_unit (unit_id),
    FOREIGN KEY (unit_id) REFERENCES property_units(unit_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default starter apartments
INSERT IGNORE INTO properties (property_id, type, label, description, entry_coords_json, interior_coords_json, price, max_units) VALUES
(1, 'apartment', 'Alta Street Apartments', 'Starter apartment complex in downtown LS', '{"x":-270.0,"y":-956.0,"z":31.22}', '{"x":266.05,"y":-1007.42,"z":-101.0}', 0, 100),
(2, 'apartment', 'Integrity Way', 'Mid-range apartments near Legion Square', '{"x":-47.13,"y":-585.88,"z":37.95}', '{"x":266.05,"y":-1007.42,"z":-101.0}', 50000, 50),
(3, 'apartment', 'Del Perro Heights', 'Luxury beachfront apartments', '{"x":-1447.12,"y":-537.5,"z":34.74}', '{"x":-1452.27,"y":-540.19,"z":74.04}', 150000, 25)
