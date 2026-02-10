-- Core Characters Client
-- This file provides client-side utilities for character management

-- Client-side character data cache
local currentCharacter = nil

-- Get current character data
function GetCurrentCharacter()
    return currentCharacter
end

-- Set current character (used by core_session)
RegisterNetEvent('core_characters:setCurrentCharacter', function(characterData)
    currentCharacter = characterData
end)

-- Clear character on logout
RegisterNetEvent('core_characters:clearCharacter', function()
    currentCharacter = nil
end)

-- Export
exports('GetCurrentCharacter', GetCurrentCharacter)
