-- system_vehicles migration 0001: vehicles and garages
CREATE TABLE IF NOT EXISTS garages (
    garage_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    label VARCHAR(128) NOT NULL,
    coords_json TEXT NOT NULL COMMENT 'JSON {x,y,z}',
    spawn_coords_json TEXT DEFAULT NULL COMMENT 'JSON {x,y,z,heading}',
    type ENUM('car','boat','air','all') NOT NULL DEFAULT 'car',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS owned_vehicles (
    plate VARCHAR(12) NOT NULL PRIMARY KEY,
    citizenid VARCHAR(20) NOT NULL,
    model VARCHAR(64) NOT NULL,
    model_name VARCHAR(64) DEFAULT NULL,
    props_json LONGTEXT DEFAULT NULL COMMENT 'Vehicle properties/mods JSON',
    garage_id INT UNSIGNED DEFAULT NULL,
    state ENUM('garaged','out','impounded') NOT NULL DEFAULT 'garaged',
    fuel FLOAT NOT NULL DEFAULT 100.0,
    engine_health FLOAT NOT NULL DEFAULT 1000.0,
    body_health FLOAT NOT NULL DEFAULT 1000.0,
    damage_json TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_vehicles_citizen (citizenid),
    INDEX idx_vehicles_garage (garage_id),
    INDEX idx_vehicles_state (state)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default garages
INSERT IGNORE INTO garages (garage_id, label, coords_json, spawn_coords_json, type) VALUES
(1, 'Legion Square Garage', '{"x":215.84,"y":-806.26,"z":30.78}', '{"x":218.7,"y":-800.5,"z":30.6,"heading":250.0}', 'car'),
(2, 'Pillbox Garage', '{"x":272.53,"y":-343.91,"z":44.92}', '{"x":275.0,"y":-340.0,"z":44.9,"heading":160.0}', 'car'),
(3, 'LSIA Parking', '{"x":-798.31,"y":-2450.5,"z":14.04}', '{"x":-795.0,"y":-2453.0,"z":14.0,"heading":60.0}', 'car'),
(4, 'Davis Garage', '{"x":-47.03,"y":-1756.44,"z":29.42}', '{"x":-44.0,"y":-1758.0,"z":29.4,"heading":320.0}', 'car'),
(5, 'Vespucci Marina', '{"x":-849.58,"y":-1368.12,"z":1.6}', '{"x":-851.0,"y":-1366.0,"z":1.6,"heading":108.0}', 'boat'),
(6, 'LSIA Hangar', '{"x":-1267.39,"y":-3394.38,"z":13.94}', '{"x":-1260.0,"y":-3390.0,"z":13.9,"heading":330.0}', 'air')
