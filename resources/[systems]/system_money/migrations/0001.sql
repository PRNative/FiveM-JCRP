-- system_money migration 0001: money tables
CREATE TABLE IF NOT EXISTS character_money (
    citizenid VARCHAR(20) NOT NULL PRIMARY KEY,
    cash INT NOT NULL DEFAULT 0,
    bank INT NOT NULL DEFAULT 0,
    dirty INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS money_ledger (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    citizenid VARCHAR(20) NOT NULL,
    type ENUM('cash','bank','dirty') NOT NULL,
    amount INT NOT NULL COMMENT 'positive=add, negative=remove',
    balance_after_json TEXT DEFAULT NULL COMMENT 'snapshot {cash,bank,dirty}',
    reason VARCHAR(255) DEFAULT NULL,
    ref VARCHAR(128) DEFAULT NULL COMMENT 'reference id for tracing',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ledger_citizenid (citizenid),
    INDEX idx_ledger_type (type),
    INDEX idx_ledger_ref (ref),
    INDEX idx_ledger_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
