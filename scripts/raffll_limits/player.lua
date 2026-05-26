local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local ui = require('openmw.ui')
local storage = require('openmw.storage')
local interfaces = require('openmw.interfaces')
local compat = require('scripts.raffll_limits.compat')

-- Module-level state table
local state = {}

-- Set of potion record IDs excluded from counting (registered by other mods via interface)
local excludedPotions = {}

-- Initialize all state variables to their defaults
local function initState()
    state.active = false              -- knockout state flag
    state.drinkCount = 0              -- potions consumed in current window
    state.timer = 0                   -- seconds elapsed since last drink
    state.drinkHour = 0               -- GameHour when last potion was consumed
    state.potionsOnly = false         -- setting: only enforce potion limits
    state.progressivePotions = false  -- setting: scale potion cap with level
    state.progressiveStats = false    -- setting: scale stat caps with level
    state.ignoreSunsDusk = true       -- setting: ignore Sun's Dusk food/drinks in potion count
    state.ignoreBMSLuck = true        -- setting: skip luck check when BMS is modifying it
    state.oldValueAttribute = 0       -- last notified attribute cap (change detection)
    state.oldValueSkill = 0           -- last notified skill cap (change detection)
    state.oldCount = 0                -- last notified potion count (change detection)
    state.maxCount = 3                -- current max allowed potions
    state.drinkOverdose = false       -- whether at overdose threshold (drinkCount >= maxCount)
    state.limitPotion = false         -- potion limit exceeded flag (overdose triggered)
    state.lastPotionEffectCount = nil -- active potion effect count tracking for drink detection
    state.peakPotionEffectCount = 0  -- high-water mark for potion effect detection
end

-- Compute the attribute cap based on player level and progressive mode
local function computeAttributeCap(level, progressive)
    if not progressive then
        return 300
    end
    return math.min(300, 100 + level * 5)
end

-- Compute the skill cap based on player level and progressive mode
local function computeSkillCap(level, progressive)
    if not progressive then
        return 150
    end
    return math.min(150, 100 + level)
end

-- Compute the maximum allowed potions based on player level and progressive mode
local function computeMaxPotions(level, progressive)
    if not progressive then
        return 3
    end
    return math.max(3, math.min(math.floor(level / 10) + 3, 8))
end

-- Check if any of the 8 player attributes exceeds the given cap
-- Check if any of the 8 player attributes exceeds the given cap
-- skipLuck: if true, skip the luck check (BMS compatibility)
-- Returns true if ANY attribute's .modified value > cap, false otherwise
local function checkAttributes(cap, skipLuck)
    local attrs = types.Actor.stats.attributes
    if attrs.strength(self).modified > cap then return true end
    if attrs.intelligence(self).modified > cap then return true end
    if attrs.willpower(self).modified > cap then return true end
    if attrs.agility(self).modified > cap then return true end
    if attrs.speed(self).modified > cap then return true end
    if attrs.endurance(self).modified > cap then return true end
    if attrs.personality(self).modified > cap then return true end
    if not skipLuck and attrs.luck(self).modified > cap then return true end
    return false
end

-- Check if any of the 27 player skills exceeds the given cap
-- skipAcrobatics: if true, skip the acrobatics check (Icarian Flight exception)
-- Returns true if ANY skill's .modified value > cap, false otherwise
local function checkSkills(cap, skipAcrobatics)
    local skills = types.NPC.stats.skills
    if skills.alchemy(self).modified > cap then return true end
    if skills.longblade(self).modified > cap then return true end
    if not skipAcrobatics and skills.acrobatics(self).modified > cap then return true end
    if skills.bluntweapon(self).modified > cap then return true end
    if skills.enchant(self).modified > cap then return true end
    if skills.security(self).modified > cap then return true end
    if skills.axe(self).modified > cap then return true end
    if skills.conjuration(self).modified > cap then return true end
    if skills.sneak(self).modified > cap then return true end
    if skills.armorer(self).modified > cap then return true end
    if skills.alteration(self).modified > cap then return true end
    if skills.lightarmor(self).modified > cap then return true end
    if skills.mediumarmor(self).modified > cap then return true end
    if skills.destruction(self).modified > cap then return true end
    if skills.marksman(self).modified > cap then return true end
    if skills.heavyarmor(self).modified > cap then return true end
    if skills.mysticism(self).modified > cap then return true end
    if skills.shortblade(self).modified > cap then return true end
    if skills.spear(self).modified > cap then return true end
    if skills.restoration(self).modified > cap then return true end
    if skills.handtohand(self).modified > cap then return true end
    if skills.block(self).modified > cap then return true end
    if skills.illusion(self).modified > cap then return true end
    if skills.mercantile(self).modified > cap then return true end
    if skills.athletics(self).modified > cap then return true end
    if skills.unarmored(self).modified > cap then return true end
    if skills.speechcraft(self).modified > cap then return true end
    return false
end

-- Check if the Icarian Flight spell is currently active on the player
-- Returns true if active, false otherwise
local function isIcarianFlightActive()
    local activeSpells = types.Actor.activeSpells(self)
    return activeSpells:isSpellActive('sc_icarianflight_en') == true
end

-- Handle knockout/recovery state machine transitions
-- limitAttribute: boolean, true if any attribute exceeds its cap
-- limitSkill: boolean, true if any skill exceeds its cap
local function handleKnockoutRecovery(limitAttribute, limitSkill)
    local anyLimit = limitAttribute or limitSkill or state.limitPotion

    if not state.active and anyLimit then
        -- Transition to knockout: set active, drop max fatigue to 0
        state.active = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
        -- Close any open menu (if UI mode API is available)
        if interfaces.UI and interfaces.UI.setMode then
            interfaces.UI.setMode()
        end
    elseif state.active and anyLimit then
        -- Maintain knockout: keep max fatigue at 0 and current negative to stay collapsed
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
    elseif state.active and not anyLimit then
        -- Recovery: all limits cleared while in knockout
        ui.showMessage("You have fully recovered!")
        -- Restore fatigue base to Str + Wil + Agi + End
        local attrs = types.Actor.stats.attributes
        local baseMax = attrs.strength(self).modified
                      + attrs.willpower(self).modified
                      + attrs.agility(self).modified
                      + attrs.endurance(self).modified
        types.Actor.stats.dynamic.fatigue(self).base = baseMax
        -- Set current to 0 so player wakes up with empty fatigue bar
        types.Actor.stats.dynamic.fatigue(self).current = 0
        state.active = false
        -- Reset potion effect count to ignore any buffered hotkey drinks
        state.lastPotionEffectCount = nil
        state.peakPotionEffectCount = 0
    end
    -- If not active and no limit, do nothing
end

-- Update the potion cooldown timer, handling hour-skip detection and expiry
-- dt: elapsed frame time in seconds
local function updatePotionTimer(dt)
    if state.drinkCount == 0 then
        return
    end

    local currentHour = core.getGameTime() / 3600

    -- Hour-skip detection: if game hour advanced by more than 1 hour since last drink, force expiry
    if (currentHour - state.drinkHour) > 1 then
        state.drinkCount = 0
        state.timer = 0
        state.limitPotion = false
        state.drinkOverdose = false
        return
    end

    -- Accumulate elapsed frame time
    state.timer = state.timer + dt

    -- Timer expiry at 20 seconds
    if state.timer >= 20 then
        state.drinkCount = 0
        state.timer = 0
        state.limitPotion = false
        state.drinkOverdose = false
    end
end

-- Handle a potion drink detection:
-- Detected via active potion effect count increase.
-- drinkCount tracks drinks within the cooldown window.
-- When drinkCount reaches maxCount, next drink = overdose (collapse).
-- One more drink after overdose = death.
local function handleDrinkDetected()
    state.timer = 0
    state.drinkHour = core.getGameTime() / 3600
    state.drinkCount = state.drinkCount + 1

    if state.drinkCount >= state.maxCount + 2 then
        -- Death: drink while already in overdose
        ui.showMessage("You have died from the potion overdose!")
        types.Actor.stats.dynamic.health(self).current = 0
    elseif state.drinkCount >= state.maxCount + 1 then
        -- Overdose: first drink past the limit → collapse immediately
        ui.showMessage("You have overdosed potions!")
        state.limitPotion = true
        state.active = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
    end
end

return {
    engineHandlers = {
        onInit = function()
            initState()
        end,
        onLoad = function(data)
            -- 1. Set all state to defaults first
            initState()

            -- 2. Restore saved fields (guard against nil/first load)
            if data then
                state.active = data.active or false
                state.drinkCount = data.drinkCount or 0
                state.timer = data.timer or 0
                state.drinkHour = data.drinkHour or 0
                state.limitPotion = data.limitPotion or false
                state.oldValueAttribute = data.oldValueAttribute or 0
                state.oldValueSkill = data.oldValueSkill or 0
                state.oldCount = data.oldCount or 0
                state.maxCount = data.maxCount or 3
                state.potionsOnly = data.potionsOnly or false
                state.progressivePotions = data.progressivePotions or false
                state.progressiveStats = data.progressiveStats or false
                state.ignoreSunsDusk = data.ignoreSunsDusk ~= false
                state.ignoreBMSLuck = data.ignoreBMSLuck ~= false
            end

            -- Read current settings from global storage (overrides saved values)
            local settingsSection = storage.globalSection('raffll_limits')
            local compatSection = storage.globalSection('raffll_limits_compat')
            local v = settingsSection:get('potionsOnly')
            if v ~= nil then state.potionsOnly = v end
            v = settingsSection:get('progressivePotions')
            if v ~= nil then state.progressivePotions = v end
            v = settingsSection:get('progressiveStats')
            if v ~= nil then state.progressiveStats = v end
            v = compatSection:get('ignoreSunsDusk')
            if v ~= nil then state.ignoreSunsDusk = v else state.ignoreSunsDusk = true end
            v = compatSection:get('ignoreBMSLuck')
            if v ~= nil then state.ignoreBMSLuck = v else state.ignoreBMSLuck = true end

            -- Recompute derived state
            state.drinkOverdose = (state.drinkCount >= state.maxCount)
        end,
        onSave = function()
            return {
                active = state.active,
                drinkCount = state.drinkCount,
                timer = state.timer,
                drinkHour = state.drinkHour,
                limitPotion = state.limitPotion,
                oldValueAttribute = state.oldValueAttribute,
                oldValueSkill = state.oldValueSkill,
                oldCount = state.oldCount,
                maxCount = state.maxCount,
                potionsOnly = state.potionsOnly,
                progressivePotions = state.progressivePotions,
                progressiveStats = state.progressiveStats,
                ignoreSunsDusk = state.ignoreSunsDusk,
                ignoreBMSLuck = state.ignoreBMSLuck,
            }
        end,
        onUpdate = function(dt)
            -- 1. CharGen check: if character generation is not finished, return early
            if not types.Player.isCharGenFinished(self) then return end

            -- 2. Get player level
            local level = types.Actor.stats.level(self).current

            -- 3. Compute caps based on current settings and player level
            local attrCap = computeAttributeCap(level, state.progressiveStats)
            local skillCap = computeSkillCap(level, state.progressiveStats)
            state.maxCount = computeMaxPotions(level, state.progressivePotions)

            -- 4. Notify cap changes (only when NOT in knockout state AND cap differs from last notified value)
            if attrCap ~= state.oldValueAttribute and not state.active then
                ui.showMessage(string.format("Your attribute cap is now %G.", attrCap))
                state.oldValueAttribute = attrCap
            end
            if skillCap ~= state.oldValueSkill and not state.active then
                ui.showMessage(string.format("Your skill cap is now %G.", skillCap))
                state.oldValueSkill = skillCap
            end
            if state.maxCount ~= state.oldCount and not state.active then
                ui.showMessage(string.format("You can drink up to %G potions.", state.maxCount))
                state.oldCount = state.maxCount
            end

            -- 5. Check attributes (if not potionsOnly and not active)
            local limitAttribute = false
            if not state.potionsOnly then
                local skipLuck = compat.shouldSkipLuck(interfaces, state)
                limitAttribute = checkAttributes(attrCap, skipLuck)
            end
            if limitAttribute and not state.active then
                ui.showMessage("You have reached your attribute limit!")
            end

            -- 6. Check skills (if not potionsOnly and not active)
            local limitSkill = false
            if not state.potionsOnly then
                local skipAcro = isIcarianFlightActive()
                limitSkill = checkSkills(skillCap, skipAcro)
            end
            if limitSkill and not state.active then
                ui.showMessage("You have reached your skill limit!")
            end

            -- 7. Detect potion drink by counting active potion effects
            -- Use a high-water-mark approach: track the max effect count seen.
            -- Any increase above the peak means new potions were consumed,
            -- even if an old effect expired on the same frame.
            local potionEffectCount = 0
            local ok, activeSpells = pcall(types.Actor.activeSpells, self)
            if ok and activeSpells then
                for _, spell in pairs(activeSpells) do
                    local rok, rec = pcall(types.Potion.record, spell.id)
                    if rok and rec then
                        if not excludedPotions[spell.id] and not compat.shouldIgnorePotion(spell.id, state) then
                            potionEffectCount = potionEffectCount + 1
                        end
                    end
                end
            end
            if state.lastPotionEffectCount == nil then
                state.lastPotionEffectCount = potionEffectCount
                state.peakPotionEffectCount = potionEffectCount
            else
                if potionEffectCount > state.peakPotionEffectCount then
                    local newDrinks = potionEffectCount - state.peakPotionEffectCount
                    for i = 1, newDrinks do
                        handleDrinkDetected()
                    end
                    state.peakPotionEffectCount = potionEffectCount
                end
                -- When all effects have expired, reset the peak so future drinks are detected fresh
                if potionEffectCount == 0 then
                    state.peakPotionEffectCount = 0
                end
            end
            state.lastPotionEffectCount = potionEffectCount

            -- 8. Update potion timer
            updatePotionTimer(dt)

            -- 9. Update drinkOverdose
            state.drinkOverdose = (state.drinkCount >= state.maxCount)

            -- 10. Handle knockout/recovery
            handleKnockoutRecovery(limitAttribute, limitSkill)

            -- 11. Write state to player storage for menu scripts to read
            local section = storage.playerSection('raffll_limits_state')
            section:set('active', state.active)
            section:set('drinkCount', state.drinkCount)
            section:set('maxCount', state.maxCount)
            section:set('countdown', state.drinkCount > 0 and math.max(0, 20 - state.timer) or 0)
            section:set('drinkOverdose', state.drinkOverdose)

            -- 12. Send state to global script for item blocking
            core.sendGlobalEvent('raffll_limits_stateUpdate', {
                active = state.active,
                drinkOverdose = state.drinkOverdose,
            })
        end,
    },
    eventHandlers = {
        raffll_limits_settingChanged = function(data)
            if data.key == 'potionsOnly' then
                state.potionsOnly = data.value
            elseif data.key == 'progressivePotions' then
                state.progressivePotions = data.value
            elseif data.key == 'progressiveStats' then
                state.progressiveStats = data.value
            elseif data.key == 'ignoreSunsDusk' then
                state.ignoreSunsDusk = data.value
            elseif data.key == 'ignoreBMSLuck' then
                state.ignoreBMSLuck = data.value
            end
        end,
        raffll_limits_showMessage = function(data)
            if data and data.text then
                ui.showMessage(data.text)
            end
        end,
    },
    interfaceName = "StatsAndPotionsLimit",
    interface = {
        version = 1,
        --- Returns true if the player is currently knocked out (overdose/stat limit).
        isActive = function() return state.active end,
        --- Returns the number of potions consumed in the current cooldown window.
        getDrinkCount = function() return state.drinkCount end,
        --- Returns the maximum allowed potions before overdose.
        getMaxCount = function() return state.maxCount end,
        --- Returns true if the player has reached or exceeded the potion limit.
        isOverdosed = function() return state.drinkOverdose end,
        --- Returns the current attribute cap.
        getAttributeCap = function() return state.oldValueAttribute end,
        --- Returns the current skill cap.
        getSkillCap = function() return state.oldValueSkill end,
        --- Exclude a potion record ID from being counted toward the limit.
        --- Other mods can call this to whitelist their custom potions.
        --- @param recordId string the potion record ID to exclude
        excludePotion = function(recordId)
            if recordId then
                excludedPotions[recordId] = true
            end
        end,
        --- Remove a previously excluded potion record ID.
        --- @param recordId string the potion record ID to stop excluding
        includePotion = function(recordId)
            if recordId then
                excludedPotions[recordId] = nil
            end
        end,
        --- Check if a potion record ID is currently excluded.
        --- @param recordId string
        --- @return boolean
        isPotionExcluded = function(recordId)
            return excludedPotions[recordId] == true
        end,
    },
}
