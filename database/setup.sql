-- FiveM Platform Foundation - Database Setup
-- Run this to create the database (migrations run automatically via oxmysql)

CREATE DATABASE IF NOT EXISTS fivem_platform
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fivem_platform;

-- schema_migrations is created by core_boot
-- All other tables are created by resource migrations on first boot
-- This file is for reference only; oxmysql + core_boot handle migrations
