-- system_inventory: items, slots, metadata

CREATE TABLE IF NOT EXISTS item_defs (
  item_name VARCHAR(64) PRIMARY KEY,
  label VARCHAR(128) NOT NULL,
  stackable TINYINT(1) DEFAULT 1,
  max_stack INT DEFAULT 1,
  weight FLOAT DEFAULT 0,
  usable TINYINT(1) DEFAULT 0,
  metadata_schema_json JSON DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS character_inventory (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(32) NOT NULL,
  slot INT NOT NULL,
  item_name VARCHAR(64) NOT NULL,
  amount INT NOT NULL DEFAULT 1,
  metadata_json JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_citizen_slot (citizenid, slot),
  INDEX idx_citizenid (citizenid),
  INDEX idx_item (item_name)
);

-- Default items
INSERT IGNORE INTO item_defs (item_name, label, stackable, max_stack, weight, usable) VALUES
  ('bread', 'Bread', 1, 10, 0.1, 1),
  ('water', 'Water', 1, 5, 0.2, 1),
  ('phone', 'Phone', 0, 1, 0.3, 1),
  ('id_card', 'ID Card', 0, 1, 0, 0);
