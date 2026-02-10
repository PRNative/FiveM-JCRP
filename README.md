# FiveM JCRP - Database-First Modular Framework

A complete, production-ready FiveM roleplay server framework built with a database-first, modular architecture. All systems are API-first with proper exports and no direct cross-resource database access.

## 🏗️ Architecture Overview

### Design Principles

- **Database-First**: All state persists to MySQL/MariaDB via oxmysql
- **API-First**: Modules expose functionality via exports, never direct DB access
- **Restart-Safe**: All player data automatically saves and restores
- **Modular**: Resources are independent and communicate via documented APIs
- **Secure**: Server-authoritative for money, inventory, jobs, and properties

### Tech Stack

- **FiveM**: Cerulean runtime
- **Database**: MySQL/MariaDB via oxmysql
- **UI Framework**: ox_lib for callbacks
- **NUI**: Custom interfaces for character selection, HUD, loading screen
- **Language**: Lua (can be migrated to TypeScript)

## 📁 Repository Structure

```
/workspace/
├── server.cfg                      # Server configuration
├── config/
│   └── server_config.json          # Global server configuration
├── resources/
│   ├── core/                       # P0: Platform Foundation
│   │   ├── core_boot/              # Boot system, migrations, config
│   │   ├── core_identity/          # Account management, ban system
│   │   ├── core_characters/        # 3-slot character system
│   │   ├── core_state/             # Character state persistence
│   │   ├── core_session/           # Login flow, session management
│   │   └── core_spawn/             # Spawn selection system
│   ├── systems/                    # P1: Core Gameplay & P2: Lifestyle
│   │   ├── system_money/           # Money management with ledger
│   │   ├── system_inventory/       # Inventory system
│   │   ├── system_jobs/            # Job assignments
│   │   ├── system_status/          # Hunger/thirst/stress
│   │   ├── system_permissions/     # Admin & roles
│   │   ├── system_apartments/      # Apartment ownership
│   │   └── system_vehicles/        # Vehicle ownership & garages
│   └── ui/                         # UI Resources
│       ├── ui_loading/             # Loading screen
│       └── ui_hud/                 # Player HUD
└── sql/                            # (Auto-generated migrations)
```

## 🚀 Installation & Setup

### Prerequisites

- FiveM Server (latest artifact)
- MySQL 8.0+ or MariaDB 10.5+
- oxmysql resource
- ox_lib resource

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/PRNative/FiveM-JCRP.git
   cd FiveM-JCRP
   ```

2. **Configure database**
   
   Edit `server.cfg`:
   ```cfg
   set mysql_connection_string "mysql://user:password@localhost/jcrp?charset=utf8mb4"
   ```

3. **Configure server**
   
   Edit `config/server_config.json` to customize:
   - Server branding
   - Default money amounts
   - Spawn locations
   - Decay rates for status

4. **Set license key**
   
   In `server.cfg`:
   ```cfg
   sv_licenseKey "YOUR_CFXRE_LICENSE_KEY"
   ```

5. **Start the server**
   
   The database will auto-initialize on first boot with all required migrations.

## 📦 Module Documentation

### P0: Platform Foundation

#### core_boot
- **Purpose**: Database connectivity, schema migrations, config loader
- **Exports**:
  - `RunMigrations()`: Execute pending migrations
  - `GetConfig(path)`: Get configuration value
  - `HealthCheck()`: Verify database connection
- **Critical**: Must start before all other resources

#### core_identity
- **Purpose**: Account resolution, ban system
- **Database**: `accounts`, `account_audit`
- **Exports**:
  - `ResolveAccount(src)`: Get/create account ID from player
  - `IsBanned(accountId)`: Check ban status
  - `BanAccount(accountId, reason, duration)`
  - `UnbanAccount(accountId)`
- **Features**: 
  - Auto-creates accounts on first connection
  - Supports license and Discord identifiers
  - Temporary and permanent bans

#### core_characters
- **Purpose**: 3-slot character system
- **Database**: `characters` (max 3 per account)
- **Exports**:
  - `ListCharacters(accountId)`: Get all characters
  - `CreateCharacter(accountId, slot, data)`: Create new character
  - `DeleteCharacter(accountId, slot)`: Delete character
  - `LoadCharacter(citizenid)`: Load full character data
  - `UpdateLastPlayed(citizenid)`
- **Features**:
  - Enforced 3-slot limit
  - Unique citizenid generation (CIDxxxxxxx)
  - Character deletion triggers cleanup in all systems

#### core_state
- **Purpose**: Generic character state persistence
- **Database**: `character_state` (position, health, armor, metadata)
- **Exports**:
  - `GetState(citizenid)`: Get full state
  - `SetState(citizenid, partial)`: Update state
  - `SetPosition(citizenid, coords, heading)`
  - `SetHealthArmor(citizenid, health, armor)`
  - `GetMetadata(citizenid, key)`
  - `SetMetadata(citizenid, key, value)`

#### core_session
- **Purpose**: Login flow and session management
- **Exports**:
  - `GetCitizenId(src)`: Get logged-in player's citizenid
  - `GetAccountId(src)`: Get player's account ID
  - `GetPlayerData(src)`: Get hydrated player data
- **Flow**: Deferrals → Account check → Character selection → Data hydration → Spawn
- **Auto-save**: Every 2 minutes + on disconnect

#### core_spawn
- **Purpose**: Spawn selection system
- **Exports**:
  - `GetSpawnOptions(citizenid)`: Get available spawns
  - `SetLastPosition(citizenid, coords, heading)`
  - `SpawnPlayer(src, coords, heading)`
- **Spawn Types**:
  - Last location (if exists)
  - Predefined spawns (configured in config.json)
  - Apartment spawns (if owned)
  - New character default spawn

### P1: Core Gameplay

#### system_money
- **Purpose**: Authoritative money management with transaction ledger
- **Database**: `character_money`, `money_ledger`
- **Accounts**: cash, bank, dirty
- **Exports**:
  - `GetBalances(citizenid)`: Get all account balances
  - `AddMoney(citizenid, account, amount, reason, ref)`
  - `RemoveMoney(citizenid, account, amount, reason, ref)`
  - `TransferMoney(fromCitizenId, toCitizenId, account, amount, reason, ref)`
  - `GetTransactionHistory(citizenid, limit)`
- **Features**:
  - All transactions logged
  - Anti-negative enforcement
  - Atomic transfers with database transactions

#### system_inventory
- **Purpose**: Server-authoritative inventory management
- **Database**: `character_inventory`, `item_defs`
- **Exports**:
  - `GetInventory(citizenid)`: Get all items
  - `AddItem(citizenid, itemName, amount, metadata)`
  - `RemoveItem(citizenid, itemName, amount, slot)`
  - `UseItem(src, citizenid, slot)`
  - `GetItemCount(citizenid, itemName)`
  - `HasItem(citizenid, itemName, amount)`
- **Features**:
  - Stackable and unique items
  - 40-slot inventory (configurable)
  - Item metadata support
  - Usable items with hooks
  - Auto-initializes with starter items

#### system_jobs
- **Purpose**: Job assignment and management
- **Database**: `character_jobs`, `job_defs`
- **Exports**:
  - `GetJob(citizenid)`: Get current job
  - `SetJob(citizenid, jobName, grade)`
  - `SetDuty(citizenid, onDuty)`
  - `ToggleDuty(citizenid)`
  - `HasPermission(citizenid, permission)`
  - `GetOnlinePlayersWithJob(jobName)`
  - `GetOnlinePlayersOnDuty(jobName)`
- **Jobs Included**:
  - Police (7 grades)
  - EMS (5 grades)
  - Mechanic (4 grades)
  - Real Estate (3 grades)
  - Taxi, Bus, Trucker
- **Features**:
  - Grade-based permissions
  - Salary system
  - Duty toggle for applicable jobs

#### system_status
- **Purpose**: Hunger, thirst, and stress management
- **Database**: `character_status`
- **Exports**:
  - `GetStatus(citizenid)`
  - `SetStatus(citizenid, partial)`
  - `ModifyStatus(citizenid, type, amount)`
  - `ApplyDecay(citizenid)`
- **Features**:
  - Auto-decay system (configurable rates)
  - Critical status applies damage
  - Visual effects on client

#### system_permissions
- **Purpose**: Admin and role management
- **Database**: `account_roles`, `admin_audit`
- **Exports**:
  - `GetRoles(accountId)`: Get all roles
  - `HasRole(accountId, role)`
  - `AddRole(accountId, role, grantedBy)`
  - `RemoveRole(accountId, role)`
  - `RequireRole(src, role)`: Check permission
  - `AuditLog(accountId, action, targetId, payload)`
  - `ExportCharacter(citizenid)`: Export full character data
- **Roles**: user, moderator, admin, superadmin, owner

#### ui_hud
- **Purpose**: Player HUD display
- **Features**:
  - Money display (cash/bank)
  - Job and duty status
  - Hunger/thirst/stress bars
  - Health and armor vitals
  - Real-time location display
- **Commands**: `/hud` to toggle

### P2: Lifestyle Systems

#### system_apartments
- **Purpose**: Apartment ownership and management
- **Database**: `properties`, `property_units`, `property_ownership`, `property_stash`
- **Exports**:
  - `GetOwnedProperties(citizenid)`
  - `EnterProperty(src, unitId)`
  - `ExitProperty(src, unitId)`
  - `GetStash(unitId)`: Get property storage
  - `AddToStash(unitId, itemName, amount, metadata)`
  - `RemoveFromStash(unitId, slot, amount)`
- **Features**:
  - Auto-assign starter apartment
  - Property stash (100 slots)
  - Interior system
  - Spawn integration

#### system_vehicles
- **Purpose**: Vehicle ownership and garage system
- **Database**: `owned_vehicles`, `garages`
- **Exports**:
  - `GetVehicles(citizenid)`: Get all owned vehicles
  - `GetVehiclesInGarage(citizenid, garageId)`
  - `AddVehicle(citizenid, model, props, garageId)`
  - `StoreVehicle(plate, garageId, props)`
  - `SpawnVehicle(src, plate)`
  - `DeleteVehicle(plate, citizenid)`
- **Garages**:
  - Legion Square, Pillbox Hill, Airport
  - Sandy Shores, Paleto Bay
- **Features**:
  - Vehicle state tracking (in/out/impounded)
  - Fuel and damage persistence
  - Auto plate generation

## 🎮 Player Flow

### First Connection

1. **Loading Screen** (ui_loading)
   - Beautiful animated loading screen
   - Tips rotation

2. **Account Resolution** (core_identity)
   - Auto-creates account from license
   - Ban check at deferrals

3. **Character Selection** (core_session)
   - Shows up to 3 character slots
   - Create new character with:
     - First/Last name
     - Date of birth
     - Gender

4. **Character Hydration** (core_session)
   - Loads all character data from all systems
   - Money, job, inventory, status, etc.

5. **Spawn Selection** (core_spawn)
   - Choose from available spawns
   - Last location, apartments, or defaults

6. **In-Game** (ui_hud, all systems active)
   - HUD displays all info
   - Systems auto-save periodically

### Disconnect/Restart

- All data auto-saved to database
- Next login restores exact state
- **Zero data loss** on proper shutdown

## 🔧 Configuration

### Global Config (`config/server_config.json`)

```json
{
  "server": {
    "name": "JCRP",
    "brand": "Just City Roleplay"
  },
  "characters": {
    "max_slots": 3,
    "default_money": {
      "cash": 5000,
      "bank": 25000
    },
    "starting_job": {
      "name": "unemployed",
      "grade": 0
    }
  },
  "spawn": {
    "new_character_spawn": {...},
    "predefined_spawns": [...]
  },
  "status": {
    "decay_rate": {
      "hunger": 0.1,
      "thirst": 0.15,
      "stress": 0.05
    },
    "decay_interval": 60000
  }
}
```

## 🛠️ Admin Commands

### Identity & Bans
- `ban <player_id> <reason> [duration_seconds]`
- `unban <license>`

### Money
- `givemoney <player_id> <account> <amount> [reason]`
- `removemoney <player_id> <account> <amount> [reason]`

### Jobs
- `setjob <player_id> <job_name> <grade>`

### Permissions
- `addrole <player_id> <role>`
- `removerole <player_id> <role>`

### Vehicles
- `givevehicle <player_id> <model> [garage_id]`

### Data Export
- `exportchar <citizenid>` - Exports full character data to JSON

## 🔐 Security

### Server-Authoritative Design
- All mutations validated server-side
- No trust of client input
- Citizen ID resolution via core_session prevents impersonation

### Database Security
- Foreign key constraints enforce referential integrity
- CHECK constraints prevent invalid states
- Transaction support for atomic operations
- Prepared statements prevent SQL injection

### Permission System
- Role-based access control
- Audit logging for admin actions
- ACE permissions integrated

## 📊 Database Schema

### Key Tables

**accounts**: Player accounts (1 per license)
- Primary key: `id`
- Unique: `license`

**characters**: Player characters (max 3 per account)
- Primary key: `id`
- Unique: `citizenid`, `(account_id, slot)`
- Foreign key: `account_id` → `accounts(id)`

**character_state**: Generic state (position, health, metadata)
- Primary key: `citizenid`

**character_money**: Money balances
- Primary key: `citizenid`

**money_ledger**: Transaction history
- All money changes logged

**character_inventory**: Player inventory
- Unique: `(citizenid, slot)`

**character_jobs**: Job assignments
- Primary key: `citizenid`

**owned_vehicles**: Vehicle ownership
- Primary key: `plate`

**property_ownership**: Property ownership
- Unique: `unit_id` (one owner per unit)

### Migration System

Migrations are auto-applied on server start in version order. Each resource registers its migrations with `core_boot`:

```lua
exports.core_boot:RegisterMigrations('resource_name', {
    {version = 1, description = "...", sql = "..."},
    {version = 2, description = "...", sql = "..."}
})
```

## 🧪 Testing

### Restart Safety Test

1. Create character
2. Spawn in game
3. Add money: `/givemoney [id] cash 10000`
4. Change job: `/setjob [id] police 3`
5. Move around map
6. Restart server
7. Reconnect - verify:
   - Money preserved
   - Job preserved
   - Last position restored
   - Inventory intact

### Multi-Character Test

1. Create 3 characters
2. Switch between them
3. Verify each has independent:
   - Money
   - Inventory
   - Job
   - Position
   - Status

## 🚧 Future Expansion (P3+)

### P3: Content Expansion
- Gangs and territories
- Heist systems
- Crafting trees
- Drug systems
- Skills and progression

### P4: Quality of Life
- Clothing shops
- Emote system
- Minigames
- Seasonal events

All future systems follow the same modular, API-first design.

## 📝 Development Guidelines

### Adding New Systems

1. **Create migrations**
   ```lua
   migrations = {
       {version = X, description = "...", sql = "..."}
   }
   exports.core_boot:RegisterMigrations('my_resource', migrations)
   ```

2. **Export functions, never tables**
   ```lua
   exports('MyFunction', MyModule.MyFunction)
   ```

3. **Use callbacks for client → server**
   ```lua
   lib.callback.register('resource:action', function(source, ...)
       return result
   end)
   ```

4. **Listen for character events**
   ```lua
   AddEventHandler('core_characters:created', function(citizenid, accountId)
       InitializeMyData(citizenid)
   end)
   
   AddEventHandler('core_characters:beforeDelete', function(citizenid)
       CleanupMyData(citizenid)
   end)
   ```

5. **Never query other resources' tables**
   - Always use exports
   - Document your API

## 🤝 Contributing

This is a complete, production-ready framework. Contributions should maintain:

1. Database-first design
2. API-first exports
3. Restart safety
4. No cross-resource DB access
5. Proper migration versioning

## 📄 License

MIT License - see LICENSE file

## 🙏 Credits

Built with:
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_lib](https://github.com/overextended/ox_lib)
- FiveM platform

---

**Status**: ✅ P0 + P1 + P2 (Core) Complete

**Production Ready**: Yes

**Restart Safe**: Yes

**Database Migrations**: Auto-applied

**Documentation**: Complete
