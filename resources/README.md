# Resources Monorepo

This repository is **DB-first** and **API-first**:

- **DB-first**: every persisted system stores state in MySQL/MariaDB via `oxmysql`.
- **API-first**: no resource may query another resource’s tables directly. Cross-module access must happen through **documented exports**.

## Folder structure

```
resources/
  core/       # platform foundation (P0) + shared contracts
  systems/    # gameplay systems (P1+)
  ui/         # NUI resources (HUD, loading, selectors)
  admin/      # admin tools, import/export, moderation
```

## Global identifiers (contracts)

- **account_id**: internal numeric id (DB `accounts.id`)
- **license**: FiveM license identifier (account key)
- **citizenid**: character key (globally unique); all character tables reference this

## Migrations

- Table: `schema_migrations(version PRIMARY KEY, applied_at)`
- Each resource owns a `migrations/migrations.json` manifest plus `migrations/*.sql`.
- `core_boot` applies migrations in dependency order and **refuses to start** if any migration fails.

## Security rules

- Server authoritative for money/inventory/jobs/spawn/state.
- Client can request; server validates using `core_session` citizen/account resolution.
- All server exports validate inputs; never trust client payloads.

