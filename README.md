# FiveM Platform Foundation

A complete, database-first, modular FiveM codebase. All player/character state is persisted in MySQL/MariaDB via oxmysql.

## Structure

```
resources/
├── core/           # P0 Platform
│   ├── core_boot       # DB migrations, config, health
│   ├── core_identity   # Accounts, bans, audit
│   ├── core_characters # 3-slot character system
│   ├── core_state      # Position, metadata persistence
│   ├── core_session    # Login flow, character select NUI
│   ├── core_spawn      # Spawn selection (last, predefined)
│   └── ui_loading      # NUI loading screen
├── systems/        # P1 Core Gameplay
│   ├── system_money     # Wallet, bank, ledger
│   ├── system_inventory # Items, slots, metadata
│   ├── system_jobs      # Job, grade, duty
│   ├── system_status    # Hunger, thirst, stress
│   └── system_permissions # Roles, admin audit
├── ui/             # P1 UI
│   └── ui_hud          # Cash, bank, job, status HUD
└── admin/          # Admin tooling
    └── admin_tools      # ExportCharacter, ImportCharacter
```

## Requirements

- FiveM server (OneSync recommended)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- MySQL 8+ or MariaDB 10.3+

## Setup

1. **Database**

   Create a database and configure the connection in `server.cfg`:

   ```cfg
   set mysql_connection_string "mysql://user:password@localhost:3306/fivem_platform?charset=utf8mb4"
   ```

2. **Schema**

   Migrations run automatically on first boot. The `core_boot` resource creates `schema_migrations` and applies all module migrations in dependency order.

3. **Config**

   Edit `resources/core/core_boot/config.json` for spawn locations, brand, etc. Or set `set platform_config_path "C:/path/to/config.json"` to override.

## Load Order

Resources must start in this order (handled by `server.cfg`):

1. oxmysql, ox_lib
2. core_boot → core_identity → core_characters → core_state → core_spawn → core_session → ui_loading
3. system_money, system_inventory, system_jobs, system_status, system_permissions, ui_hud
4. admin_tools (optional)

## Data Contracts

- **account_id**: Internal numeric ID for accounts
- **license**: FiveM license identifier (account key)
- **citizenid**: Character key (globally unique, e.g. `ABC1234`)
- All character-related tables reference `citizenid`, not `license`

## Key Exports

| Resource | Exports |
|----------|---------|
| core_boot | RunMigrations, GetConfig, HealthCheck |
| core_identity | ResolveAccount, IsBanned, Audit |
| core_characters | ListCharacters, CreateCharacter, DeleteCharacter, LoadCharacter |
| core_state | GetState, SetState, MarkDirty, FlushState |
| core_session | GetCitizenId, GetAccountId, GetPlayerData |
| core_spawn | GetSpawnOptions, SetLastPosition, SpawnPlayer |
| system_money | GetBalances, AddMoney, RemoveMoney, TransferMoney |
| system_inventory | GetInventory, AddItem, RemoveItem, SetSlot, UseItem |
| system_jobs | GetJob, SetJob, SetDuty |
| system_status | GetStatus, SetStatus, ApplyDecay |
| system_permissions | HasRole, RequireRole, AddRole, RemoveRole |
| admin_tools | ExportCharacter, ImportCharacter |

## Restart Safety

- All state is persisted to DB
- Position saved every 30s and on disconnect
- Migrations are versioned; server refuses to start if migrations fail

## P2+ (Planned)

- system_apartments, system_housing
- system_vehicles, garages
- system_banking_ui, system_phone
- P3: gangs, heists, crafting, drugs, skills
- P4: cosmetics, emotes, minigames

## License

MIT
