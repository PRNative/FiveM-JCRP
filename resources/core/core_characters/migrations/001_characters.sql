-- core_characters: 3-slot character system

CREATE TABLE IF NOT EXISTS characters (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  slot INT NOT NULL CHECK (slot >= 1 AND slot <= 3),
  citizenid VARCHAR(32) NOT NULL UNIQUE,
  firstname VARCHAR(64) NOT NULL,
  lastname VARCHAR(64) NOT NULL,
  dob DATE DEFAULT NULL,
  gender TINYINT DEFAULT 0,
  model VARCHAR(64) DEFAULT 'mp_m_freemode_01',
  skin_json JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_played TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_account_slot (account_id, slot),
  INDEX idx_account (account_id),
  INDEX idx_citizenid (citizenid),
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
