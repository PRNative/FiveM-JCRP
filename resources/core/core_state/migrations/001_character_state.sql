-- core_state: per-character persistent state

CREATE TABLE IF NOT EXISTS character_state (
  citizenid VARCHAR(32) PRIMARY KEY,
  position_json JSON DEFAULT NULL,
  heading FLOAT DEFAULT 0.0,
  health INT DEFAULT 200,
  armor INT DEFAULT 0,
  metadata_json JSON DEFAULT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_updated (updated_at)
);
