-- system_permissions migration 0001: roles and admin audit
CREATE TABLE IF NOT EXISTS account_roles (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT UNSIGNED NOT NULL,
    role VARCHAR(64) NOT NULL,
    granted_by INT UNSIGNED DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_account_role (account_id, role),
    INDEX idx_roles_account (account_id),
    INDEX idx_roles_role (role),
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admin_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT UNSIGNED NOT NULL,
    action VARCHAR(128) NOT NULL,
    target_info TEXT DEFAULT NULL,
    payload_json TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin_audit_account (account_id),
    INDEX idx_admin_audit_action (action),
    INDEX idx_admin_audit_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
