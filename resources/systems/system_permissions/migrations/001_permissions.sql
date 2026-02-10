-- system_permissions: account roles, admin audit

CREATE TABLE IF NOT EXISTS account_roles (
  account_id INT NOT NULL,
  role VARCHAR(64) NOT NULL,
  PRIMARY KEY (account_id, role),
  INDEX idx_role (role),
  FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_audit (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT NOT NULL,
  action VARCHAR(128) NOT NULL,
  payload_json JSON DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_account (account_id),
  INDEX idx_action (action)
);
