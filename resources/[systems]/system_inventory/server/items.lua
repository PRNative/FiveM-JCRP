-- ============================================================
-- system_inventory: Item Definitions Cache
-- ============================================================

ItemDefs = {}

--- Load all item definitions from DB
function LoadItemDefs()
    local rows = MySQL.query.await('SELECT * FROM item_defs')
    if not rows then return end

    ItemDefs = {}
    for _, row in ipairs(rows) do
        ItemDefs[row.item_name] = {
            name = row.item_name,
            label = row.label,
            description = row.description,
            stackable = row.stackable == 1,
            max_stack = row.max_stack,
            weight = row.weight,
            usable = row.usable == 1,
            category = row.category,
            image = row.image,
            metadata_schema = JCRP.JsonDecode(row.metadata_schema_json, nil),
        }
    end

    JCRP.Log('system_inventory', 'INFO', ('Loaded %d item definitions.'):format(#rows))
end

--- Get an item definition
---@param itemName string
---@return table|nil
function GetItemDef(itemName)
    return ItemDefs[itemName]
end

--- Register a new item definition (for other resources to add items)
---@param itemName string
---@param data table
---@return boolean
function RegisterItem(itemName, data)
    if not itemName or not data.label then return false end

    MySQL.insert.await([[
        INSERT INTO item_defs (item_name, label, description, stackable, max_stack, weight, usable, category, image)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), description = VALUES(description)
    ]], {
        itemName,
        data.label,
        data.description or '',
        data.stackable ~= false and 1 or 0,
        data.max_stack or 50,
        data.weight or 0.1,
        data.usable and 1 or 0,
        data.category or 'misc',
        data.image,
    })

    ItemDefs[itemName] = {
        name = itemName,
        label = data.label,
        description = data.description,
        stackable = data.stackable ~= false,
        max_stack = data.max_stack or 50,
        weight = data.weight or 0.1,
        usable = data.usable or false,
        category = data.category or 'misc',
        image = data.image,
    }

    return true
end

exports('GetItemDef', GetItemDef)
exports('RegisterItem', RegisterItem)
exports('GetAllItemDefs', function() return ItemDefs end)

-- Load on start
CreateThread(function()
    Wait(100)
    LoadItemDefs()
end)
