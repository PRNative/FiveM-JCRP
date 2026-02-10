<!-- Truncated for brevity - this is a comprehensive API documentation file -->
# 📚 API Documentation - JCRP Framework

Complete API reference for all exported functions and events.

## Table of Contents

- [Core Boot](#core-boot)
- [Core Identity](#core-identity)
- [Core Characters](#core-characters)
- [Core State](#core-state)
- [Core Session](#core-session)
- [Core Spawn](#core-spawn)
- [System Money](#system-money)
- [System Inventory](#system-inventory)
- [System Jobs](#system-jobs)
- [System Status](#system-status)
- [System Permissions](#system-permissions)
- [System Apartments](#system-apartments)
- [System Vehicles](#system-vehicles)

---

## Core Boot

**Resource**: `core_boot`

### Exports

#### `GetConfig(path)`
Get configuration value from server_config.json

**Parameters:**
- `path` (string, optional): Dot-notation path to config value

**Returns:** Configuration value or entire config object

**Example:**
```lua
local serverName = exports.core_boot:GetConfig('server.name')
local defaultMoney = exports.core_boot:GetConfig('characters.default_money')
```

#### `RunMigrations()`
Execute all pending database migrations

**Returns:** boolean - success status

#### `HealthCheck()`
Check database connectivity

**Returns:** boolean - connection status

#### `WaitForBoot(callback)`
Execute callback after boot completes

**Parameters:**
- `callback` (function): Function to execute

**Example:**
```lua
exports.core_boot:WaitForBoot(function()
    print('Server is ready!')
end)
```

---

## Core Identity

**Resource**: `core_identity`

### Exports

#### `ResolveAccount(source)`
Get or create account ID for player

**Parameters:**
- `source` (number): Player server ID

**Returns:** number - account_id or nil

**Example:**
```lua
local accountId = exports.core_identity:ResolveAccount(source)
```

#### `IsBanned(accountId)`
Check if account is banned

**Parameters:**
- `accountId` (number): Account ID

**Returns:** 
- boolean - is banned
- string - ban reason (if banned)

**Example:**
```lua
local isBanned, reason = exports.core_identity:IsBanned(accountId)
if isBanned then
    print('Banned:', reason)
end
```

#### `BanAccount(accountId, reason, duration)`
Ban an account

**Parameters:**
- `accountId` (number): Account ID
- `reason` (string): Ban reason
- `duration` (number, optional): Duration in seconds (nil = permanent)

**Example:**
```lua
-- Permanent ban
exports.core_identity:BanAccount(accountId, 'Cheating')

-- Temporary ban (24 hours)
exports.core_identity:BanAccount(accountId, 'Toxic behavior', 86400)
```

#### `UnbanAccount(accountId)`
Remove ban from account

#### `Audit(accountId, event, payload)`
Log account event

**Parameters:**
- `accountId` (number): Account ID
- `event` (string): Event name
- `payload` (table): Event data

---

## Core Characters

**Resource**: `core_characters`

### Exports

#### `ListCharacters(accountId)`
Get all characters for an account

**Parameters:**
- `accountId` (number): Account ID

**Returns:** table - array of characters

**Example:**
```lua
local characters = exports.core_characters:ListCharacters(accountId)
for _, char in ipairs(characters) do
    print(char.firstname, char.lastname, char.citizenid)
end
```

#### `CreateCharacter(accountId, slot, charData)`
Create new character

**Parameters:**
- `accountId` (number): Account ID
- `slot` (number): Slot number (1-3)
- `charData` (table): Character data
  - `firstname` (string, required)
  - `lastname` (string, required)
  - `dob` (string, required): Date of birth (YYYY-MM-DD)
  - `gender` (string, required): 'male' or 'female'
  - `model` (string, optional): Ped model
  - `skin` (table, optional): Skin data

**Returns:** string - citizenid or nil

**Example:**
```lua
local citizenid = exports.core_characters:CreateCharacter(accountId, 1, {
    firstname = 'John',
    lastname = 'Doe',
    dob = '1990-01-01',
    gender = 'male'
})
```

#### `DeleteCharacter(accountId, slot)`
Delete character

**Parameters:**
- `accountId` (number): Account ID
- `slot` (number): Slot number

**Returns:** 
- boolean - success
- string - error message (if failed)

#### `LoadCharacter(citizenid)`
Load full character data

**Parameters:**
- `citizenid` (string): Citizen ID

**Returns:** table - character data

#### `GetCharacter(citizenid)`
Alias for LoadCharacter

#### `UpdateLastPlayed(citizenid)`
Update last played timestamp

---

## Core State

**Resource**: `core_state`

### Exports

#### `GetState(citizenid)`
Get character state

**Parameters:**
- `citizenid` (string): Citizen ID

**Returns:** table - state data
- `position` (table): {x, y, z}
- `heading` (number)
- `health` (number)
- `armor` (number)
- `metadata` (table)

**Example:**
```lua
local state = exports.core_state:GetState(citizenid)
print('Position:', state.position.x, state.position.y, state.position.z)
print('Health:', state.health)
```

#### `SetState(citizenid, partialState)`
Update character state

**Parameters:**
- `citizenid` (string): Citizen ID
- `partialState` (table): State updates

**Example:**
```lua
exports.core_state:SetState(citizenid, {
    health = 150,
    armor = 50
})
```

#### `SetPosition(citizenid, coords, heading)`
Update character position

**Parameters:**
- `citizenid` (string): Citizen ID
- `coords` (table): {x, y, z}
- `heading` (number)

#### `SetHealthArmor(citizenid, health, armor)`
Update health and armor

#### `GetMetadata(citizenid, key)`
Get metadata value

**Parameters:**
- `citizenid` (string): Citizen ID
- `key` (string): Metadata key

**Returns:** any - metadata value

#### `SetMetadata(citizenid, key, value)`
Set metadata value

**Parameters:**
- `citizenid` (string): Citizen ID
- `key` (string): Metadata key
- `value` (any): Value to store

**Example:**
```lua
exports.core_state:SetMetadata(citizenid, 'last_job_switch', os.time())
local lastSwitch = exports.core_state:GetMetadata(citizenid, 'last_job_switch')
```

---

## Core Session

**Resource**: `core_session`

### Exports

#### `GetCitizenId(source)`
Get citizen ID for online player

**Parameters:**
- `source` (number): Player server ID

**Returns:** string - citizenid or nil

**Example:**
```lua
local citizenid = exports.core_session:GetCitizenId(source)
if citizenid then
    print('Player is logged in as:', citizenid)
end
```

#### `GetAccountId(source)`
Get account ID for online player

#### `GetPlayerData(source)`
Get full hydrated player data

**Returns:** table - player data
- `source` (number)
- `account_id` (number)
- `citizenid` (string)
- `character` (table)
- `state` (table)
- `money` (table)
- `job` (table)
- `inventory` (table)
- `status` (table)

---

## System Money

**Resource**: `system_money`

### Exports

#### `GetBalances(citizenid)`
Get all account balances

**Parameters:**
- `citizenid` (string): Citizen ID

**Returns:** table - balances
- `cash` (number)
- `bank` (number)
- `dirty` (number)

**Example:**
```lua
local balances = exports.system_money:GetBalances(citizenid)
print('Cash:', balances.cash)
print('Bank:', balances.bank)
```

#### `AddMoney(citizenid, account, amount, reason, ref)`
Add money to account

**Parameters:**
- `citizenid` (string): Citizen ID
- `account` (string): 'cash', 'bank', or 'dirty'
- `amount` (number): Amount to add
- `reason` (string): Transaction reason
- `ref` (string, optional): Reference ID

**Returns:**
- boolean - success
- table/string - updated balances or error message

**Example:**
```lua
local success, balances = exports.system_money:AddMoney(
    citizenid,
    'cash',
    1000,
    'Job payment',
    'job_taxi_001'
)
```

#### `RemoveMoney(citizenid, account, amount, reason, ref)`
Remove money from account

**Returns:**
- boolean - success
- table/string - updated balances or error message

#### `TransferMoney(fromCitizenId, toCitizenId, account, amount, reason, ref)`
Transfer money between players

**Parameters:**
- `fromCitizenId` (string): Sender citizen ID
- `toCitizenId` (string): Receiver citizen ID
- `account` (string): Account type
- `amount` (number): Amount to transfer
- `reason` (string): Transaction reason
- `ref` (string, optional): Reference ID

**Returns:**
- boolean - success
- table/string - {from: balances, to: balances} or error

**Example:**
```lua
local success, result = exports.system_money:TransferMoney(
    senderCitizenId,
    receiverCitizenId,
    'cash',
    500,
    'Payment for services'
)
```

#### `GetTransactionHistory(citizenid, limit)`
Get transaction ledger

**Parameters:**
- `citizenid` (string): Citizen ID
- `limit` (number, optional): Max records (default 50)

**Returns:** table - array of transactions

---

## System Inventory

**Resource**: `system_inventory`

### Exports

#### `GetInventory(citizenid)`
Get all inventory items

**Parameters:**
- `citizenid` (string): Citizen ID

**Returns:** table - array of items

**Example:**
```lua
local inventory = exports.system_inventory:GetInventory(citizenid)
for _, item in ipairs(inventory) do
    print(item.item_name, item.amount, item.slot)
end
```

#### `AddItem(citizenid, itemName, amount, metadata)`
Add item to inventory

**Parameters:**
- `citizenid` (string): Citizen ID
- `itemName` (string): Item name
- `amount` (number): Quantity
- `metadata` (table, optional): Item metadata

**Returns:**
- boolean - success
- string - message

**Example:**
```lua
local success, msg = exports.system_inventory:AddItem(
    citizenid,
    'water',
    5,
    {temperature = 'cold'}
)
```

#### `RemoveItem(citizenid, itemName, amount, slot)`
Remove item from inventory

**Parameters:**
- `citizenid` (string): Citizen ID
- `itemName` (string): Item name
- `amount` (number): Quantity
- `slot` (number, optional): Specific slot to remove from

**Returns:**
- boolean - success
- string - message

#### `GetItemCount(citizenid, itemName)`
Count total of specific item

**Returns:** number - count

#### `HasItem(citizenid, itemName, amount)`
Check if player has item

**Parameters:**
- `citizenid` (string): Citizen ID
- `itemName` (string): Item name
- `amount` (number, optional): Required amount (default 1)

**Returns:** boolean

**Example:**
```lua
if exports.system_inventory:HasItem(citizenid, 'lockpick', 1) then
    -- Player has lockpick
end
```

---

## System Jobs

**Resource**: `system_jobs`

### Exports

#### `GetJob(citizenid)`
Get player's current job

**Parameters:**
- `citizenid` (string): Citizen ID

**Returns:** table - job data
- `name` (string): Job name
- `label` (string): Display name
- `grade` (number): Grade level
- `grade_label` (string): Grade display name
- `salary` (number): Hourly salary
- `permissions` (table): Array of permissions
- `duty` (boolean): On duty status

**Example:**
```lua
local job = exports.system_jobs:GetJob(citizenid)
print(job.label, job.grade_label)
print('Salary:', job.salary)
print('On duty:', job.duty)
```

#### `SetJob(citizenid, jobName, grade)`
Set player's job

**Parameters:**
- `citizenid` (string): Citizen ID
- `jobName` (string): Job name
- `grade` (number): Grade level

**Returns:**
- boolean - success
- string - message

**Example:**
```lua
exports.system_jobs:SetJob(citizenid, 'police', 3)
```

#### `SetDuty(citizenid, onDuty)`
Set duty status

**Parameters:**
- `citizenid` (string): Citizen ID
- `onDuty` (boolean): Duty status

#### `ToggleDuty(citizenid)`
Toggle duty status

#### `HasPermission(citizenid, permission)`
Check if player has job permission

**Parameters:**
- `citizenid` (string): Citizen ID
- `permission` (string): Permission name

**Returns:** boolean

**Example:**
```lua
if exports.system_jobs:HasPermission(citizenid, 'arrest') then
    -- Player can arrest
end
```

#### `GetOnlinePlayersWithJob(jobName)`
Get all online players with specific job

**Returns:** table - array of players
- `source` (number)
- `citizenid` (string)
- `job` (table)

#### `GetOnlinePlayersOnDuty(jobName)`
Get all online players on duty with specific job

---

## System Status

**Resource**: `system_status`

### Exports

#### `GetStatus(citizenid)`
Get player status

**Returns:** table
- `hunger` (number): 0-100
- `thirst` (number): 0-100
- `stress` (number): 0-100

#### `SetStatus(citizenid, partial)`
Update status values

**Example:**
```lua
exports.system_status:SetStatus(citizenid, {
    hunger = 80,
    thirst = 90
})
```

#### `ModifyStatus(citizenid, statusType, amount)`
Add or subtract from status

**Parameters:**
- `citizenid` (string): Citizen ID
- `statusType` (string): 'hunger', 'thirst', or 'stress'
- `amount` (number): Amount to modify (positive or negative)

**Example:**
```lua
-- Restore thirst
exports.system_status:ModifyStatus(citizenid, 'thirst', 30)

-- Increase stress
exports.system_status:ModifyStatus(citizenid, 'stress', 10)
```

---

## System Permissions

**Resource**: `system_permissions`

### Exports

#### `GetRoles(accountId)`
Get all roles for account

**Returns:** table - array of role names

#### `HasRole(accountId, role)`
Check if account has role

**Returns:** boolean

#### `AddRole(accountId, role, grantedBy)`
Grant role to account

**Example:**
```lua
exports.system_permissions:AddRole(accountId, 'admin', adminAccountId)
```

#### `RemoveRole(accountId, role)`
Revoke role from account

#### `RequireRole(source, role)`
Check if online player has role

**Returns:** boolean

#### `RequireAnyRole(source, roles)`
Check if online player has any of the specified roles

**Parameters:**
- `source` (number): Player server ID
- `roles` (table): Array of role names

**Example:**
```lua
if exports.system_permissions:RequireAnyRole(source, {'admin', 'moderator'}) then
    -- Player is admin or moderator
end
```

#### `ExportCharacter(citizenid)`
Export full character data

**Returns:** table - complete character data from all systems

---

## System Apartments

**Resource**: `system_apartments`

### Exports

#### `GetOwnedProperties(citizenid)`
Get all owned/rented properties

**Returns:** table - array of properties

#### `EnterProperty(source, unitId)`
Teleport player into property

**Parameters:**
- `source` (number): Player server ID
- `unitId` (number): Property unit ID

**Returns:**
- boolean - success
- string - error message (if failed)

#### `ExitProperty(source, unitId)`
Teleport player out of property

#### `GetStash(unitId)`
Get property stash contents

**Returns:** table - array of items

#### `AddToStash(unitId, itemName, amount, metadata)`
Add item to property stash

#### `RemoveFromStash(unitId, slot, amount)`
Remove item from property stash

**Returns:**
- boolean - success
- string - item name or error

---

## System Vehicles

**Resource**: `system_vehicles`

### Exports

#### `GetVehicles(citizenid)`
Get all owned vehicles

**Returns:** table - array of vehicles

#### `GetVehiclesInGarage(citizenid, garageId)`
Get vehicles in specific garage

**Returns:** table - array of vehicles

#### `AddVehicle(citizenid, model, props, garageId)`
Give vehicle to player

**Parameters:**
- `citizenid` (string): Citizen ID
- `model` (string): Vehicle model
- `props` (table): Vehicle properties
- `garageId` (string, optional): Garage ID (default: legion_garage)

**Returns:** string - plate

**Example:**
```lua
local plate = exports.system_vehicles:AddVehicle(
    citizenid,
    'adder',
    {},
    'legion_garage'
)
```

#### `StoreVehicle(plate, garageId, props)`
Store vehicle in garage

**Parameters:**
- `plate` (string): Vehicle plate
- `garageId` (string): Garage ID
- `props` (table): Vehicle properties
  - `vehicleProps` (table)
  - `fuel` (number)
  - `engineHealth` (number)
  - `bodyHealth` (number)

#### `SpawnVehicle(source, plate)`
Spawn vehicle from garage

**Returns:**
- boolean - success
- table/string - vehicle data or error message

#### `DeleteVehicle(plate, citizenid)`
Remove vehicle from database

---

## Events

### Character Events

Triggered by core_characters:

```lua
-- When character is created
AddEventHandler('core_characters:created', function(citizenid, accountId)
    -- Initialize your data for new character
end)

-- Before character is deleted
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    -- Cleanup your data for character
end)
```

### Session Events

```lua
-- When player session is created
AddEventHandler('core_session:created', function(source, citizenid)
    -- Player logged in
end)

-- Before session is destroyed
AddEventHandler('core_session:beforeDestroy', function(source, citizenid)
    -- Player about to disconnect
end)
```

### Client Events

```lua
-- Spawn completed
RegisterNetEvent('core_spawn:spawned', function()
    -- Player finished spawning
end)

-- Money update
RegisterNetEvent('system_money:updateBalances', function(balances)
    -- balances = {cash, bank, dirty}
end)

-- Job update
RegisterNetEvent('system_jobs:updateJob', function(job)
    -- job = {name, label, grade, ...}
end)

-- Status update
RegisterNetEvent('system_status:updateStatus', function(status)
    -- status = {hunger, thirst, stress}
end)
```

---

## Callbacks

Using ox_lib callbacks:

### Server → Client

```lua
-- Get player data
local data = lib.callback.await('resource:getData', false, arg1, arg2)
```

### Client → Server

```lua
-- Request action
lib.callback.register('resource:action', function(source, arg1, arg2)
    -- Process request
    return result
end)
```

---

## Best Practices

### 1. Always Check Resource State

```lua
if GetResourceState('core_session') == 'started' then
    local citizenid = exports.core_session:GetCitizenId(source)
end
```

### 2. Use Citizenid, Not Source

```lua
-- Good - uses citizenid
exports.system_money:AddMoney(citizenid, 'cash', 1000, 'Reward')

-- Bad - uses source (session-dependent)
-- Don't store source, it changes on reconnect
```

### 3. Always Provide Transaction Reasons

```lua
-- Good
exports.system_money:AddMoney(citizenid, 'cash', 1000, 'Job completion: Taxi #42')

-- Bad
exports.system_money:AddMoney(citizenid, 'cash', 1000, '')
```

### 4. Validate Before Mutations

```lua
-- Check if player has enough money
local balances = exports.system_money:GetBalances(citizenid)
if balances.cash >= price then
    exports.system_money:RemoveMoney(citizenid, 'cash', price, 'Purchase')
else
    -- Not enough money
end
```

### 5. Handle Character Events

```lua
-- Always cleanup on character deletion
AddEventHandler('core_characters:beforeDelete', function(citizenid)
    MySQL.update('DELETE FROM my_table WHERE citizenid = ?', {citizenid})
end)
```

---

**API Version**: 1.0

**Last Updated**: 2026-02-10

**Compatibility**: FiveM Server 6683+
