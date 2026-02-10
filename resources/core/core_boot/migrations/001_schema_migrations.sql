-- Migration 001: Ensure schema_migrations exists (bootstrap)
-- This is applied by core_boot before any other migrations.
-- The table is created in Lua if not exists; this file documents the schema.

-- schema_migrations(version PK, applied_at)
CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(255) PRIMARY KEY,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
