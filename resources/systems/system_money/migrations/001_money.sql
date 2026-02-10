-- system_money: wallet, bank, dirty, ledger

CREATE TABLE IF NOT EXISTS character_money (
  citizenid VARCHAR(32) PRIMARY KEY,
  cash INT DEFAULT 0,
  bank INT DEFAULT 0,
  dirty INT DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT chk_cash_nonneg CHECK (cash >= 0),
  CONSTRAINT chk_bank_nonneg CHECK (bank >= 0),
  CONSTRAINT chk_dirty_nonneg CHECK (dirty >= 0)
);

CREATE TABLE IF NOT EXISTS money_ledger (
  id INT AUTO_INCREMENT PRIMARY KEY,
  citizenid VARCHAR(32) NOT NULL,
  type ENUM('cash', 'bank', 'dirty') NOT NULL,
  amount INT NOT NULL,
  balance_after_json JSON DEFAULT NULL,
  reason VARCHAR(255) DEFAULT NULL,
  ref VARCHAR(64) DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_citizenid (citizenid),
  INDEX idx_created (created_at)
);
