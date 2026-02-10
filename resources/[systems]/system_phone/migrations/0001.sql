-- system_phone migration 0001: phone tables
CREATE TABLE IF NOT EXISTS phone_contacts (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    owner_citizenid VARCHAR(20) NOT NULL,
    name VARCHAR(64) NOT NULL,
    number VARCHAR(20) NOT NULL,
    avatar VARCHAR(255) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_contacts_owner (owner_citizenid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS phone_messages (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    sender_citizenid VARCHAR(20) NOT NULL,
    receiver_citizenid VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    is_read TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_msg_sender (sender_citizenid),
    INDEX idx_msg_receiver (receiver_citizenid),
    INDEX idx_msg_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS phone_settings (
    citizenid VARCHAR(20) NOT NULL PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    wallpaper VARCHAR(255) DEFAULT NULL,
    ringtone VARCHAR(64) DEFAULT 'default',
    silent_mode TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_phone_number (phone_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
