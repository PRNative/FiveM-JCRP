-- system_apartments: Schema for P2 (housing integrated from day 1)

CREATE TABLE IF NOT EXISTS properties (
  property_id INT AUTO_INCREMENT PRIMARY KEY,
  type ENUM('apartment','house') DEFAULT 'apartment',
  label VARCHAR(128) NOT NULL,
  entry_coords_json JSON DEFAULT NULL,
  interior_id INT DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS property_units (
  unit_id INT AUTO_INCREMENT PRIMARY KEY,
  property_id INT NOT NULL,
  unit_label VARCHAR(128) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_property (property_id),
  FOREIGN KEY (property_id) REFERENCES properties(property_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS property_ownership (
  id INT AUTO_INCREMENT PRIMARY KEY,
  unit_id INT NOT NULL,
  citizenid VARCHAR(32) NOT NULL,
  status ENUM('owned','rented') DEFAULT 'rented',
  since TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  until TIMESTAMP NULL,
  INDEX idx_citizen (citizenid),
  INDEX idx_unit (unit_id),
  UNIQUE KEY uk_unit_citizen (unit_id, citizenid)
);

CREATE TABLE IF NOT EXISTS property_stash (
  id INT AUTO_INCREMENT PRIMARY KEY,
  unit_id INT NOT NULL,
  slot INT NOT NULL,
  item_name VARCHAR(64) NOT NULL,
  amount INT DEFAULT 1,
  metadata_json JSON DEFAULT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_unit_slot (unit_id, slot),
  INDEX idx_unit (unit_id)
);
