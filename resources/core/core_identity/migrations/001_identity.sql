-- core_identity: accounts and audit

CREATE TABLE IF NOT EXISTS accounts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  license VARCHAR(128) NOT NULL UNIQUE,
  discord VARCHAR(64) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_seen TIMESTAMP NULL ON UPDATE CURRENT_TIMESTAMP,
  banned TINYINT(1) DEFAULT 0,
  ban_reason TEXT DEFAULT NULL,
  INDEX idx_license (license),
  INDEX idx_banned (banned)
);

CREATE TABLE IF NOT EXISTS account_audit (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  event VARCHAR(64) NOT NULL,
  payload_json JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_account (account_id),
  INDEX idx_event (event),
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);
