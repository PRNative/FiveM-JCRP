-- system_inventory migration 0001: inventory tables
CREATE TABLE IF NOT EXISTS item_defs (
    item_name VARCHAR(64) NOT NULL PRIMARY KEY,
    label VARCHAR(128) NOT NULL,
    description TEXT DEFAULT NULL,
    stackable TINYINT(1) NOT NULL DEFAULT 1,
    max_stack INT UNSIGNED NOT NULL DEFAULT 50,
    weight FLOAT NOT NULL DEFAULT 0.1,
    usable TINYINT(1) NOT NULL DEFAULT 0,
    metadata_schema_json TEXT DEFAULT NULL,
    category VARCHAR(64) DEFAULT 'misc',
    image VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS character_inventory (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(20) NOT NULL,
    slot INT UNSIGNED NOT NULL,
    item_name VARCHAR(64) NOT NULL,
    amount INT UNSIGNED NOT NULL DEFAULT 1,
    metadata_json TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_citizenid_slot (citizenid, slot),
    INDEX idx_inv_citizenid (citizenid),
    INDEX idx_inv_item (item_name),
    FOREIGN KEY (item_name) REFERENCES item_defs(item_name) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default item definitions
INSERT IGNORE INTO item_defs (item_name, label, description, stackable, max_stack, weight, usable, category) VALUES
('phone', 'Phone', 'A mobile phone', 0, 1, 0.5, 1, 'electronics'),
('id_card', 'ID Card', 'Personal identification card', 0, 1, 0.1, 1, 'documents'),
('water', 'Water Bottle', 'Refreshing water', 1, 20, 0.3, 1, 'food'),
('bread', 'Bread', 'Fresh bread', 1, 20, 0.2, 1, 'food'),
('bandage', 'Bandage', 'Basic medical bandage', 1, 50, 0.1, 1, 'medical'),
('lockpick', 'Lockpick', 'A tool for picking locks', 1, 10, 0.1, 1, 'tools'),
('radio', 'Radio', 'Portable radio', 0, 1, 1.0, 1, 'electronics'),
('weapon_pistol', 'Pistol', 'Standard 9mm pistol', 0, 1, 2.0, 1, 'weapons'),
('ammo_pistol', 'Pistol Ammo', '9mm ammunition', 1, 250, 0.05, 0, 'ammo'),
('cash_roll', 'Cash Roll', 'Rolled up cash', 1, 99, 0.01, 1, 'valuables'),
('repair_kit', 'Repair Kit', 'Vehicle repair kit', 1, 5, 5.0, 1, 'tools'),
('medkit', 'First Aid Kit', 'Medical first aid kit', 1, 5, 2.0, 1, 'medical'),
('burger', 'Burger', 'A delicious burger', 1, 20, 0.3, 1, 'food'),
('coffee', 'Coffee', 'Hot coffee', 1, 20, 0.3, 1, 'food')
