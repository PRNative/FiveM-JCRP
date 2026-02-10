-- system_jobs: job assignment, grades, permissions

CREATE TABLE IF NOT EXISTS job_defs (
  job_name VARCHAR(64) PRIMARY KEY,
  label VARCHAR(128) NOT NULL,
  grades_json JSON DEFAULT NULL,
  permissions_json JSON DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS character_jobs (
  citizenid VARCHAR(32) PRIMARY KEY,
  job_name VARCHAR(64) DEFAULT 'unemployed',
  grade INT DEFAULT 0,
  duty TINYINT(1) DEFAULT 0,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_job (job_name)
);

INSERT IGNORE INTO job_defs (job_name, label, grades_json, permissions_json) VALUES
  ('unemployed', 'Unemployed', '["Unemployed"]', '[]'),
  ('police', 'Police', '["Cadet","Officer","Sergeant","Lieutenant","Chief"]', '["police.mdt","police.cuff"]'),
  ('ambulance', 'EMS', '["Trainee","Paramedic","Doctor","Chief"]', '["ems.revive","ems.heal"]');
