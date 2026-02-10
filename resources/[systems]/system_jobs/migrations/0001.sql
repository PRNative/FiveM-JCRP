-- system_jobs migration 0001: job tables
CREATE TABLE IF NOT EXISTS job_defs (
    job_name VARCHAR(64) NOT NULL PRIMARY KEY,
    label VARCHAR(128) NOT NULL,
    category VARCHAR(64) DEFAULT 'civilian',
    grades_json TEXT NOT NULL COMMENT 'Array of {grade, label, salary, permissions[]}',
    permissions_json TEXT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS character_jobs (
    citizenid VARCHAR(20) NOT NULL PRIMARY KEY,
    job_name VARCHAR(64) NOT NULL DEFAULT 'unemployed',
    grade INT UNSIGNED NOT NULL DEFAULT 0,
    duty TINYINT(1) NOT NULL DEFAULT 0,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_jobs_jobname (job_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default job definitions
INSERT IGNORE INTO job_defs (job_name, label, category, grades_json) VALUES
('unemployed', 'Unemployed', 'civilian', '[{"grade":0,"label":"Unemployed","salary":0,"permissions":[]}]'),
('police', 'Los Santos Police Department', 'emergency', '[{"grade":0,"label":"Cadet","salary":500,"permissions":["handcuff","search"]},{"grade":1,"label":"Officer","salary":750,"permissions":["handcuff","search","impound"]},{"grade":2,"label":"Sergeant","salary":1000,"permissions":["handcuff","search","impound","hire"]},{"grade":3,"label":"Lieutenant","salary":1250,"permissions":["handcuff","search","impound","hire","fire"]},{"grade":4,"label":"Chief","salary":1500,"permissions":["handcuff","search","impound","hire","fire","admin"]}]'),
('ems', 'Emergency Medical Services', 'emergency', '[{"grade":0,"label":"EMT","salary":500,"permissions":["heal","revive"]},{"grade":1,"label":"Paramedic","salary":700,"permissions":["heal","revive","transport"]},{"grade":2,"label":"Doctor","salary":1000,"permissions":["heal","revive","transport","surgery"]},{"grade":3,"label":"Chief of Medicine","salary":1300,"permissions":["heal","revive","transport","surgery","hire","fire"]}]'),
('mechanic', 'Los Santos Customs', 'business', '[{"grade":0,"label":"Trainee","salary":300,"permissions":["repair"]},{"grade":1,"label":"Mechanic","salary":500,"permissions":["repair","upgrade"]},{"grade":2,"label":"Senior Mechanic","salary":700,"permissions":["repair","upgrade","order"]},{"grade":3,"label":"Manager","salary":900,"permissions":["repair","upgrade","order","hire","fire"]}]'),
('taxi', 'Downtown Cab Co.', 'civilian', '[{"grade":0,"label":"Driver","salary":200,"permissions":["dispatch"]},{"grade":1,"label":"Senior Driver","salary":350,"permissions":["dispatch"]},{"grade":2,"label":"Manager","salary":500,"permissions":["dispatch","hire","fire"]}]'),
('realestate', 'Real Estate Agency', 'business', '[{"grade":0,"label":"Agent","salary":400,"permissions":["sell","show"]},{"grade":1,"label":"Senior Agent","salary":600,"permissions":["sell","show","appraise"]},{"grade":2,"label":"Broker","salary":900,"permissions":["sell","show","appraise","hire","fire"]}]'),
('reporter', 'Weazel News', 'civilian', '[{"grade":0,"label":"Intern","salary":200,"permissions":["camera"]},{"grade":1,"label":"Reporter","salary":400,"permissions":["camera","broadcast"]},{"grade":2,"label":"Editor","salary":600,"permissions":["camera","broadcast","hire","fire"]}]')
