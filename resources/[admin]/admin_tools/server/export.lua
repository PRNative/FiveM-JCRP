-- ============================================================
-- admin_tools: Character Export
-- Exports full character data as JSON for migration/backup
-- ============================================================

--- Export a complete character snapshot
---@param citizenid string
---@return table|nil exportData
---@return string|nil error
function ExportCharacter(citizenid)
    if not citizenid or citizenid == '' then
        return nil, 'citizenid is required'
    end

    local exportData = {
        _meta = {
            exported_at = os.date('%Y-%m-%d %H:%M:%S'),
            format_version = '1.0.0',
            source = 'JCRP Admin Tools',
        },
        citizenid = citizenid,
    }

    -- Identity
    local character = exports['core_characters']:LoadCharacter(citizenid)
    if not character then
        return nil, 'Character not found: ' .. citizenid
    end
    exportData.identity = {
        firstname = character.firstname,
        lastname = character.lastname,
        dob = character.dob,
        gender = character.gender,
        model = character.model,
        skin = character.skin,
        backstory = character.backstory,
    }

    -- State
    local state = exports['core_state']:GetState(citizenid)
    if state then
        exportData.state = {
            position = state.position,
            heading = state.heading,
            health = state.health,
            armor = state.armor,
            metadata = state.metadata,
        }
    end

    -- Money
    local ok1, money = pcall(function()
        return exports['system_money']:GetBalances(citizenid)
    end)
    if ok1 and money then
        exportData.money = money
    end

    -- Inventory
    local ok2, inventory = pcall(function()
        return exports['system_inventory']:GetInventory(citizenid)
    end)
    if ok2 and inventory then
        exportData.inventory = {}
        for slot, item in pairs(inventory) do
            exportData.inventory[#exportData.inventory + 1] = {
                slot = slot,
                item_name = item.item_name,
                amount = item.amount,
                metadata = item.metadata,
            }
        end
    end

    -- Job
    local ok3, job = pcall(function()
        return exports['system_jobs']:GetJob(citizenid)
    end)
    if ok3 and job then
        exportData.job = {
            name = job.name,
            grade = job.grade,
            duty = job.duty,
        }
    end

    -- Status
    local ok4, status = pcall(function()
        return exports['system_status']:GetStatus(citizenid)
    end)
    if ok4 and status then
        exportData.status = status
    end

    -- Properties
    local ok5, properties = pcall(function()
        return exports['system_apartments']:GetOwnedProperties(citizenid)
    end)
    if ok5 and properties then
        exportData.properties = properties
    end

    -- Vehicles
    local ok6, vehicles = pcall(function()
        return exports['system_vehicles']:GetVehicles(citizenid)
    end)
    if ok6 and vehicles then
        exportData.vehicles = {}
        for _, v in ipairs(vehicles) do
            exportData.vehicles[#exportData.vehicles + 1] = {
                plate = v.plate,
                model = v.model,
                model_name = v.model_name,
                props = JCRP.JsonDecode(v.props_json, {}),
                garage_id = v.garage_id,
                state = v.state,
                fuel = v.fuel,
                engine_health = v.engine_health,
                body_health = v.body_health,
            }
        end
    end

    -- Phone
    local ok7, phoneNumber = pcall(function()
        return exports['system_phone']:GetPhoneNumber(citizenid)
    end)
    if ok7 and phoneNumber then
        exportData.phone = { number = phoneNumber }
    end

    JCRP.Log('admin_tools', 'INFO', ('Exported character: %s (%s %s)'):format(
        citizenid, character.firstname, character.lastname
    ))

    return exportData, nil
end

--- Export all characters for an account
---@param accountId number
---@return table exports
function ExportAccount(accountId)
    local characters = exports['core_characters']:ListCharacters(accountId)
    local results = {}

    for _, char in ipairs(characters) do
        local data, err = ExportCharacter(char.citizenid)
        if data then
            results[#results + 1] = data
        else
            JCRP.Log('admin_tools', 'WARN', ('Failed to export %s: %s'):format(char.citizenid, err or 'unknown'))
        end
    end

    return results
end

exports('ExportCharacter', ExportCharacter)
exports('ExportAccount', ExportAccount)
