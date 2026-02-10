# `core_boot` (P0)

## Responsibilities

- DB connectivity check (`oxmysql`)
- Config loader (JSON) with environment overrides
- Schema migrations runner (dependency order)
- Startup gating: **refuses to run** if migrations fail

## Owned tables

- `schema_migrations`

## Exports

- `RunMigrations() -> boolean, err?`
- `GetConfig() -> table`
- `HealthCheck() -> boolean`

## Notes

- Migration discovery uses `migrations/migrations.json` in each resource.
- Keep migration SQL simple (no stored procedures) to avoid splitter edge-cases.

