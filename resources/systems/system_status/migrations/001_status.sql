-- system_status: hunger, thirst, stress

CREATE TABLE IF NOT EXISTS character_status (
  citizenid VARCHAR(32) PRIMARY KEY,
  hunger INT DEFAULT 100,
  thirst INT DEFAULT 100,
  stress INT DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_hunger CHECK (hunger >= 0 AND hunger <= 100),
  CONSTRAINT chk_thirst CHECK (thirst >= 0 AND thirst <= 100),
  CONSTRAINT chk_stress CHECK (stress >= 0 AND stress <= 100)
);
