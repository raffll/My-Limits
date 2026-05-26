-- Compatibility layer for third-party mod integration.
-- Each function checks whether a potion active spell should be ignored
-- (i.e. not counted toward the potion limit), or whether certain stat checks
-- should be skipped due to other mods temporarily modifying stats.

local interfaces = require('openmw.interfaces')

local compat = {}

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ Sun's Dusk Survival and Needs                                        │
-- ╰──────────────────────────────────────────────────────────────────────╯

--- Check if a potion record ID is a Sun's Dusk consumable (food/drink).
--- Uses the SunsDusk interface if available.
--- @param recordId string
--- @return boolean true if the potion should be ignored
function compat.isSunsDuskConsumable(recordId)
    if not interfaces.SunsDusk then return false end
    local entry, typ = interfaces.SunsDusk.isConsumable(recordId)
    return typ ~= nil
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ Better Merchants Skills (BMS)                                        │
-- ╰──────────────────────────────────────────────────────────────────────╯

-- BMS temporarily boosts the player's luck modifier during merchant interactions.
-- We detect its presence by checking for its settings page registration.
local bmsDetected = nil

--- Returns true if BMS is installed.
function compat.isBMSLoaded()
    if bmsDetected == nil then
        -- BMS registers a settings page with key "BMS"
        -- We can detect it by checking if its global storage section exists
        local ok, storage = pcall(require, 'openmw.storage')
        if ok then
            local section = storage.globalSection('SettingsBMS')
            bmsDetected = section ~= nil
        else
            bmsDetected = false
        end
    end
    return bmsDetected
end

--- Returns true if the luck attribute check should be skipped.
--- BMS modifies luck during dialogue/barter; skip luck check when in a UI mode.
--- @param uiInterfaces table the openmw.interfaces module
--- @param settings table current state with toggle flags
--- @return boolean
function compat.shouldSkipLuck(uiInterfaces, settings)
    if not settings or not settings.ignoreBMSLuck then return false end
    if not compat.isBMSLoaded() then return false end
    -- BMS only modifies luck while in dialogue-related UI modes
    if uiInterfaces and uiInterfaces.UI then
        local mode = uiInterfaces.UI.getMode()
        if mode then
            -- Any UI mode active while BMS is loaded means luck may be modified
            return true
        end
    end
    return false
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ Master Filters                                                       │
-- ╰──────────────────────────────────────────────────────────────────────╯

--- Master filter: returns true if the given potion spell should be excluded
--- from the drink counter. Add future mod checks here.
--- @param recordId string
--- @param settings table  current state/settings with toggle flags
--- @return boolean
function compat.shouldIgnorePotion(recordId, settings)
    if settings.ignoreSunsDusk and compat.isSunsDuskConsumable(recordId) then
        return true
    end
    -- Add more mod checks here in the future:
    -- if settings.ignoreFooMod and compat.isFooModConsumable(recordId) then return true end
    return false
end

return compat
