# JCRP — FiveM Roleplay Framework

A complete, database-first, modular FiveM roleplay framework built from the ground up. Every module is API-first with documented exports and no cross-module table access.

## Architecture

```
resources/
├── [core]/                     # P0 — Platform Foundation
│   ├── core_boot/              # DB connectivity, migrations, config
│   ├── core_identity/          # Account resolution, bans, audit
│   ├── core_characters/        # 3-slot character system
│   ├── core_state/             # Position/metadata persistence
│   ├── core_session/           # Login flow, NUI character selector
│   └── core_spawn/             # Spawn selection UI
├── [ui]/                       # UI Resources
│   ├── ui_loading/             # Loading screen
│   └── ui_hud/                 # In-game HUD
├── [systems]/                  # P1/P2 — Gameplay Systems
│   ├── system_money/           # Cash/bank/dirty wallets + ledger
│   ├── system_inventory/       # Server-authoritative inventory
│   ├── system_jobs/            # Jobs, grades, paychecks
│   ├── system_status/          # Hunger/thirst/stress
│   ├── system_permissions/     # Roles, admin commands
│   ├── system_apartments/      # Starter apartments, stash
│   ├── system_housing/         # Houses, keys, doorlocks
│   ├── system_vehicles/        # Vehicles, garages, impound
│   ├── system_banking_ui/      # Bank NUI
│   └── system_phone/           # Contacts, messages
└── [admin]/
    └── admin_tools/            # Import/export, admin commands
```

## Prerequisites

- **FiveM Server** (latest recommended)
- **MySQL/MariaDB** database
- **[oxmysql](https://github.com/overextended/oxmysql)** — database driver
- **[ox_lib](https://github.com/overextended/ox_lib)** — shared utilities (recommended)

## Quick Start

### 1. Database Setup

Create a MySQL database:

```sql
CREATE DATABASE jcrp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 2. Configuration

Edit `server.cfg`:

```cfg
set mysql_connection_string "mysql://user:password@localhost/jcrp?charset=utf8mb4"
```

Edit `config.json` for gameplay settings (money defaults, spawn locations, decay rates, etc.)

### 3. Start Order

Resources MUST start in this exact order (handled by `server.cfg`):

1. `oxmysql` / `ox_lib`
2. `core_boot` — verifies DB, runs all migrations
3. `core_identity` → `core_characters` → `core_state` → `core_session` → `core_spawn`
4. `ui_loading`, `ui_hud`
5. `system_money` → `system_inventory` → `system_jobs` → `system_status` → `system_permissions`
6. P2 systems (when ready)
7. `admin_tools`

### 4. Auto-Migration

On first boot, `core_boot` automatically:
- Verifies database connectivity
- Creates `schema_migrations` table
- Runs all SQL migrations for every resource in dependency order
- Refuses to start if any migration fails

**No manual SQL import needed.**

## Data Contracts

### Identifiers

| Key | Description |
|-----|-------------|
| `account_id` | Internal numeric ID (auto-increment) |
| `license` | FiveM license identifier |
| `citizenid` | Character key (e.g., `JCRP-A3X7K`), globally unique |

All character-related tables use `citizenid` as the foreign key.

### Module API Rules

- **No module may directly query another module's tables**
- All data access is through documented `exports()`
- All write operations validate inputs server-side
- Client requests are always validated against `core_session` for ownership

## Module Reference

### P0 — Platform Foundation

#### core_boot
| Export | Description |
|--------|-------------|
| `GetConfig()` | Returns full config table |
| `GetConfigValue(path, default)` | Get nested config value |
| `RunMigrations(resourceName)` | Run migrations for a resource |
| `HealthCheck()` | Verify DB connectivity |
| `IsBootComplete()` | Check if boot sequence passed |

#### core_identity
| Export | Description |
|--------|-------------|
| `ResolveAccount(src)` | Get/create account_id for player |
| `IsBanned(accountId)` | Check ban status |
| `BanAccount(accountId, reason)` | Ban an account |
| `UnbanAccount(accountId)` | Remove ban |
| `Audit(accountId, event, payload)` | Write audit log |
| `GetAccount(accountId)` | Get account data |

#### core_characters
| Export | Description |
|--------|-------------|
| `ListCharacters(accountId)` | Get all characters for account |
| `CreateCharacter(accountId, slot, data)` | Create character (max 3) |
| `DeleteCharacter(accountId, slot)` | Delete a character |
| `LoadCharacter(citizenid)` | Load full character identity |
| `UpdateLastPlayed(citizenid)` | Update timestamp |
| `UpdateSkin(citizenid, skinData)` | Update character appearance |

#### core_state
| Export | Description |
|--------|-------------|
| `GetState(citizenid)` | Get position/metadata/health/armor |
| `SetState(citizenid, partial)` | Merge partial state |
| `SetPosition(citizenid, coords, heading)` | Set position |
| `Get/SetMetadata(citizenid, key, value)` | Arbitrary metadata |
| `FlushState(citizenid)` | Force write to DB |
| `UnloadState(citizenid)` | Flush + remove from cache |

#### core_session
| Export | Description |
|--------|-------------|
| `GetCitizenId(src)` | Get citizenid for player source |
| `GetAccountId(src)` | Get account_id for player source |
| `GetPlayerData(src)` | Get full hydrated snapshot |
| `GetSourceByCitizenId(citizenid)` | Reverse lookup |
| `IsPlayerLoaded(src)` | Check if fully loaded |

#### core_spawn
| Export | Description |
|--------|-------------|
| `GetSpawnOptions(citizenid)` | Get available spawn points |
| `SetLastPosition(citizenid, coords)` | Save position |
| `SpawnPlayer(src, option)` | Execute spawn |

### P1 — Core Gameplay

#### system_money
| Export | Description |
|--------|-------------|
| `GetBalances(citizenid)` | Get cash/bank/dirty |
| `AddMoney(citizenid, account, amount, reason, ref)` | Add money + ledger |
| `RemoveMoney(citizenid, account, amount, reason, ref)` | Remove money + ledger |
| `TransferMoney(from, to, account, amount, reason, ref)` | Atomic transfer |
| `GetLedger(citizenid, limit, offset)` | Transaction history |

#### system_inventory
| Export | Description |
|--------|-------------|
| `GetInventory(citizenid)` | Get all items |
| `AddItem(citizenid, item, amount, metadata)` | Add item (auto-stack) |
| `RemoveItem(citizenid, item, amount)` | Remove item |
| `HasItem(citizenid, item, amount)` | Check if has item |
| `GetItemCount(citizenid, item)` | Count of item |
| `UseItem(src, citizenid, slot)` | Server-validated item use |
| `RegisterItem(name, data)` | Register new item def |

#### system_jobs
| Export | Description |
|--------|-------------|
| `GetJob(citizenid)` | Get current job + grade |
| `SetJob(citizenid, job, grade)` | Assign job |
| `SetDuty(citizenid, onoff)` | Toggle duty |
| `HasJobPermission(citizenid, perm)` | Check job permission |
| `GetAllJobs()` | Get all job definitions |

#### system_status
| Export | Description |
|--------|-------------|
| `GetStatus(citizenid)` | Get hunger/thirst/stress |
| `SetStatus(citizenid, partial)` | Update status values |
| `ApplyDecay(citizenid)` | Apply one tick of decay |

#### system_permissions
| Export | Description |
|--------|-------------|
| `HasRole(accountId, role)` | Check exact role |
| `HasRoleLevel(accountId, minRole)` | Check role hierarchy |
| `RequireRole(src, role)` | Gate + notify on fail |
| `GrantRole(accountId, role, grantedBy)` | Add role |
| `RevokeRole(accountId, role, revokedBy)` | Remove role |

Role hierarchy: `user(0)` → `vip(10)` → `moderator(50)` → `admin(80)` → `superadmin(100)` → `owner(999)`

### P2 — Lifestyle Systems

#### system_apartments
| Export | Description |
|--------|-------------|
| `GetOwnedProperties(citizenid)` | List owned properties |
| `AssignStarterApartment(citizenid)` | Auto-assign on character create |
| `PurchaseProperty(citizenid, propertyId)` | Buy a property |
| `EnterProperty(src, unitId)` | Enter interior |
| `Get/Add/RemoveFromStash(unitId, ...)` | Property stash CRUD |

#### system_housing
| Export | Description |
|--------|-------------|
| `GrantKey(unitId, citizenid, grantedBy)` | Share house access |
| `HasKey(unitId, citizenid)` | Check access |
| `ToggleDoorLock(unitId, doorHash, citizenid)` | Lock/unlock |
| `PlaceFurniture(unitId, model, pos, citizenid)` | Place furniture |
| `GetFurniture(unitId)` | Get all furniture |

#### system_vehicles
| Export | Description |
|--------|-------------|
| `GetVehicles(citizenid)` | All owned vehicles |
| `RegisterVehicle(citizenid, model, name, garageId)` | Register new vehicle |
| `StoreVehicle(plate, garageId, props, ...)` | Garage a vehicle |
| `TakeVehicleOut(plate)` | Spawn from garage |
| `ImpoundVehicle(plate)` / `ReleaseVehicle(plate)` | Impound system |
| `TransferVehicle(plate, newCitizenId)` | Transfer ownership |

#### system_phone
| Export | Description |
|--------|-------------|
| `GetPhoneNumber(citizenid)` | Get phone number |
| `GetContacts(citizenid)` | List contacts |
| `SendMessage(from, to, message)` | Send SMS |
| `GetMessages(cid1, cid2, limit)` | Conversation history |

## Admin Commands

| Command | Permission | Description |
|---------|-----------|-------------|
| `/setjob [id] [job] [grade]` | admin | Set player's job |
| `/givemoney [id] [type] [amount]` | admin | Give money |
| `/giveitem [id] [item] [amount]` | admin | Give inventory item |
| `/givevehicle [id] [model]` | admin | Register vehicle |
| `/ban [id] [reason]` | admin | Ban a player |
| `/unban [account_id]` | admin | Unban by account |
| `/grantrole [id] [role]` | superadmin | Grant permission role |
| `/revokerole [id] [role]` | superadmin | Remove permission role |
| `/exportchar [citizenid]` | admin | Export character to JSON |
| `/importchar [acct] [slot] [file]` | superadmin | Import character from JSON |
| `/playerinfo [id]` | moderator | View player information |

## Events

### Server Events
| Event | Payload | When |
|-------|---------|------|
| `jcrp:boot:complete` | — | Boot sequence finished |
| `jcrp:playerLoaded` | `src, payload` | Character fully loaded |
| `jcrp:playerUnloaded` | `src, citizenid` | Player disconnected |
| `jcrp:inventory:itemUsed` | `src, citizenid, item, slot, meta` | Item used |

### Client Events
| Event | Payload | When |
|-------|---------|------|
| `jcrp:playerSpawned` | — | Player spawned in world |
| `jcrp:money:update` | `{cash, bank, dirty}` | Balance changed |
| `jcrp:jobs:update` | `job data` | Job changed |
| `jcrp:status:update` | `{hunger, thirst, stress}` | Status changed |
| `jcrp:notification` | `message, type` | Show notification |
| `jcrp:hud:show` / `jcrp:hud:hide` | — | Toggle HUD |

## Restart Safety

- All state is flushed to DB on resource stop
- Position saved every 30 seconds + on disconnect
- Money/status/inventory changes are DB-synced per operation
- Periodic background flush for dirty state (every 5 minutes)
- Server restart causes zero data loss

## Acceptance Checklist

### P0 — Platform Foundation
- [ ] Server boots with all migrations applied
- [ ] Player connects, passes ban check at deferrals
- [ ] Character list shows up to 3 slots
- [ ] Can create, select, and delete characters
- [ ] Selecting character hydrates full payload from DB
- [ ] Spawn selector shows last location + predefined spawns
- [ ] Disconnect + reconnect preserves position + metadata
- [ ] Server restart: no schema drift, no data loss

### P1 — Core Gameplay
- [ ] Money persists; all transactions appear in ledger
- [ ] Inventory persists; item use is server-validated
- [ ] Jobs persist and update HUD
- [ ] Status (hunger/thirst) decays over time
- [ ] Admin commands work from console and in-game
- [ ] HUD displays money, status, job, location, speed

### P2 — Lifestyle
- [ ] Starter apartment auto-assigned on character creation
- [ ] Vehicles can be stored/retrieved from garages
- [ ] Bank UI shows balance and transaction history
- [ ] Phone system tracks contacts and messages

## License

Proprietary — JCRP Team
