-- Item Definitions
Items = {
    -- Consumables
    water = {
        label = "Water",
        weight = 500,
        stackable = true,
        max_stack = 5,
        usable = true,
        description = "A refreshing bottle of water"
    },
    
    sandwich = {
        label = "Sandwich",
        weight = 300,
        stackable = true,
        max_stack = 5,
        usable = true,
        description = "A delicious sandwich"
    },
    
    burger = {
        label = "Burger",
        weight = 400,
        stackable = true,
        max_stack = 5,
        usable = true,
        description = "A tasty burger"
    },
    
    -- Tools
    lockpick = {
        label = "Lockpick",
        weight = 100,
        stackable = true,
        max_stack = 10,
        usable = true,
        description = "Used to pick locks"
    },
    
    phone = {
        label = "Phone",
        weight = 200,
        stackable = false,
        usable = true,
        description = "A smartphone"
    },
    
    -- Weapons (examples)
    weapon_pistol = {
        label = "Pistol",
        weight = 1500,
        stackable = false,
        usable = true,
        description = "A standard pistol"
    },
    
    -- Items
    id_card = {
        label = "ID Card",
        weight = 10,
        stackable = false,
        usable = true,
        description = "Your identification card"
    },
    
    driver_license = {
        label = "Driver License",
        weight = 10,
        stackable = false,
        usable = true,
        description = "Your driver's license"
    },
    
    -- Resources
    wood = {
        label = "Wood",
        weight = 1000,
        stackable = true,
        max_stack = 50,
        usable = false,
        description = "A piece of wood"
    },
    
    iron = {
        label = "Iron",
        weight = 2000,
        stackable = true,
        max_stack = 50,
        usable = false,
        description = "A chunk of iron"
    },
    
    -- Money items
    cash_roll = {
        label = "Cash Roll",
        weight = 100,
        stackable = true,
        max_stack = 100,
        usable = false,
        description = "A roll of cash"
    }
}

-- Get item definition
function GetItemDefinition(itemName)
    return Items[itemName]
end

-- Check if item is stackable
function IsItemStackable(itemName)
    local item = Items[itemName]
    return item and item.stackable or false
end

-- Get max stack for item
function GetMaxStack(itemName)
    local item = Items[itemName]
    if item and item.stackable then
        return item.max_stack or 1
    end
    return 1
end
