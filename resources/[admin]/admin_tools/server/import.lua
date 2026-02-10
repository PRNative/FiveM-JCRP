-- ============================================================
-- admin_tools: Character Import
-- Imports character data from JSON export
-- ============================================================

--- Import a character from export JSON
---@param accountId number target account to import into
---@param slot number target slot (1-3)
---@param importData table the exported character JSON
---@param overwrite boolean if true, overwrite existing citizenid mapping
---@return string|nil newCitizenId
---@return string|nil error
function ImportCharacter(accountId, slot, importData, overwrite)
    if not importData or type(importData) ~= 'table' then
        return nil, 'Invalid import data'
    end

    if not importData.identity then
        return nil, 'Import data missing identity section'
    end

    -- Create the character
    local charData = {
        firstname = importData.identity.firstname or 'Imported',
        lastname = importData.identity.lastname or 'Character',
        dob = importData.identity.dob or '1990-01-01',
        gender = importData.identity.gender or 0,
        model = importData.identity.model or 'mp_m_freemode_01',
        backstory = importData.identity.backstory or '',
        skin_json = importData.identity.skin,
    }

    local citizenid, err = exports['core_characters']:CreateCharacter(accountId, slot, charData)
    if not citizenid then
        return nil, 'Failed to create character: ' .. (err or 'unknown')
    end

    -- Import state
    if importData.state then
        exports['core_state']:InitState(citizenid, importData.state.position, importData.state.heading)
        exports['core_state']:SetState(citizenid, {
            health = importData.state.health,
            armor = importData.state.armor,
            metadata = importData.state.metadata,
        })
        exports['core_state']:FlushState(citizenid)
    end

    -- Import money
    if importData.money then
        pcall(function()
            exports['system_money']:InitMoney(citizenid)
            -- Set exact values by adding difference from defaults
            local config = exports['core_boot']:GetConfig()
            local defaultCash = config.money and config.money.default_cash or 5000
            local defaultBank = config.money and config.money.default_bank or 25000

            local cashDiff = (importData.money.cash or 0) - defaultCash
            local bankDiff = (importData.money.bank or 0) - defaultBank

            if cashDiff > 0 then
                exports['system_money']:AddMoney(citizenid, 'cash', cashDiff, 'Import adjustment', 'IMPORT')
            elseif cashDiff < 0 then
                exports['system_money']:RemoveMoney(citizenid, 'cash', math.abs(cashDiff), 'Import adjustment', 'IMPORT')
            end

            if bankDiff > 0 then
                exports['system_money']:AddMoney(citizenid, 'bank', bankDiff, 'Import adjustment', 'IMPORT')
            elseif bankDiff < 0 then
                exports['system_money']:RemoveMoney(citizenid, 'bank', math.abs(bankDiff), 'Import adjustment', 'IMPORT')
            end

            if importData.money.dirty and importData.money.dirty > 0 then
                exports['system_money']:AddMoney(citizenid, 'dirty', importData.money.dirty, 'Import dirty money', 'IMPORT')
            end
        end)
    end

    -- Import inventory
    if importData.inventory and type(importData.inventory) == 'table' then
        pcall(function()
            for _, item in ipairs(importData.inventory) do
                exports['system_inventory']:AddItem(citizenid, item.item_name, item.amount, item.metadata)
            end
        end)
    end

    -- Import job
    if importData.job then
        pcall(function()
            exports['system_jobs']:SetJob(citizenid, importData.job.name, importData.job.grade)
        end)
    end

    -- Import status
    if importData.status then
        pcall(function()
            exports['system_status']:InitStatus(citizenid)
            exports['system_status']:SetStatus(citizenid, importData.status)
            exports['system_status']:FlushStatus(citizenid)
        end)
    end

    -- Import vehicles
    if importData.vehicles and type(importData.vehicles) == 'table' then
        pcall(function()
            for _, v in ipairs(importData.vehicles) do
                exports['system_vehicles']:RegisterVehicle(
                    citizenid, v.model, v.model_name, v.garage_id or 1, v.props
                )
            end
        end)
    end

    JCRP.Log('admin_tools', 'INFO', ('Imported character as %s into account %d slot %d'):format(
        citizenid, accountId, slot
    ))

    return citizenid, nil
end

exports('ImportCharacter', ImportCharacter)
