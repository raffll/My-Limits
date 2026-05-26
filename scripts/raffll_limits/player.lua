local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local ui = require('openmw.ui')
local storage = require('openmw.storage')
local interfaces = require('openmw.interfaces')

-- Load exclusion lists from data file
local exclusions = require('scripts.raffll_limits.exclude')

-- Module-level state table
local state = {}

-- Set of potion record IDs excluded from counting (from data file + registered via interface)
local excludedPotions = {}
-- List of Lua patterns converted from wildcard entries (e.g. "sd_*" -> "^sd_")
local excludedPotionPatterns = {}

for _, entry in ipairs(exclusions.potions) do
    if entry:find('%*') then
        -- Convert wildcard to Lua pattern: escape special chars, replace * with .*
        local pattern = '^' .. entry:gsub('([%.%+%-%^%$%(%)%%])', '%%%1'):gsub('%*', '.*') .. '$'
        table.insert(excludedPotionPatterns, pattern)
    else
        excludedPotions[entry] = true
    end
end

-- Check if a potion ID is excluded (exact match or wildcard pattern)
local function isPotionExcludedByFile(id)
    if excludedPotions[id] then return true end
    for _, pattern in ipairs(excludedPotionPatterns) do
        if id:match(pattern) then return true end
    end
    return false
end

-- Per-attribute spell exclusion sets
local excludedAttributeSpells = {}
for attr, spells in pairs(exclusions.attributes) do
    excludedAttributeSpells[attr] = {}
    for _, id in ipairs(spells) do
        excludedAttributeSpells[attr][id] = true
    end
end

-- Per-skill spell exclusion sets
local excludedSkillSpells = {}
for skill, spells in pairs(exclusions.skills) do
    excludedSkillSpells[skill] = {}
    for _, id in ipairs(spells) do
        excludedSkillSpells[skill][id] = true
    end
end

-- Set of attribute names temporarily excluded from limit checks (registered by other mods via interface)
local skippedAttributes = {}

-- Initialize all state variables to their defaults
local function initState()
    state.active = false              -- knockout state flag
    state.drinkCount = 0              -- potions consumed in current window
    state.timer = 0                   -- seconds elapsed since last drink
    state.drinkHour = 0               -- GameHour when last potion was consumed
    state.potionsOnly = false         -- setting: only enforce potion limits
    state.progressivePotions = false  -- setting: scale potion cap with level
    state.progressiveStats = false    -- setting: scale stat caps with level
    state.trainingLimit = true        -- setting: enforce training limit (5 per level)
    state.oldValueAttribute = 0       -- last notified attribute cap (change detection)
    state.oldValueSkill = 0           -- last notified skill cap (change detection)
    state.oldCount = 0                -- last notified potion count (change detection)
    state.maxCount = 3                -- current max allowed potions
    state.drinkOverdose = false       -- whether at overdose threshold (drinkCount >= maxCount)
    state.limitPotion = false         -- potion limit exceeded flag (overdose triggered)
    state.lastPotionEffectCount = nil -- active potion effect count tracking for drink detection
    state.peakPotionEffectCount = 0  -- high-water mark for potion effect detection
    state.trainCount = 0              -- training sessions used this level
    state.trainLevel = 0              -- level at which trainCount was last reset
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

-- Check if any of the 8 player attributes exceeds the given cap.
-- Skips attributes that are in the skippedAttributes set (interface) or have an excluded spell active.
-- Returns true if ANY attribute's .modified value > cap, false otherwise.
local function checkAttributes(cap)
    local attrs = types.Actor.stats.attributes
    local function shouldSkip(name)
        return skippedAttributes[name] or hasExcludedSpellActive(excludedAttributeSpells[name])
    end
    if not shouldSkip('strength') and attrs.strength(self).modified > cap then return true end
    if not shouldSkip('intelligence') and attrs.intelligence(self).modified > cap then return true end
    if not shouldSkip('willpower') and attrs.willpower(self).modified > cap then return true end
    if not shouldSkip('agility') and attrs.agility(self).modified > cap then return true end
    if not shouldSkip('speed') and attrs.speed(self).modified > cap then return true end
    if not shouldSkip('endurance') and attrs.endurance(self).modified > cap then return true end
    if not shouldSkip('personality') and attrs.personality(self).modified > cap then return true end
    if not shouldSkip('luck') and attrs.luck(self).modified > cap then return true end
    return false
end

-- Check if any of the 27 player skills exceeds the given cap.
-- Skips skills that have an excluded spell active.
-- Returns true if ANY skill's .modified value > cap, false otherwise.
local function checkSkills(cap)
    local skills = types.NPC.stats.skills
    local function shouldSkip(name)
        return hasExcludedSpellActive(excludedSkillSpells[name])
    end
    if not shouldSkip('alchemy') and skills.alchemy(self).modified > cap then return true end
    if not shouldSkip('longblade') and skills.longblade(self).modified > cap then return true end
    if not shouldSkip('acrobatics') and skills.acrobatics(self).modified > cap then return true end
    if not shouldSkip('bluntweapon') and skills.bluntweapon(self).modified > cap then return true end
    if not shouldSkip('enchant') and skills.enchant(self).modified > cap then return true end
    if not shouldSkip('security') and skills.security(self).modified > cap then return true end
    if not shouldSkip('axe') and skills.axe(self).modified > cap then return true end
    if not shouldSkip('conjuration') and skills.conjuration(self).modified > cap then return true end
    if not shouldSkip('sneak') and skills.sneak(self).modified > cap then return true end
    if not shouldSkip('armorer') and skills.armorer(self).modified > cap then return true end
    if not shouldSkip('alteration') and skills.alteration(self).modified > cap then return true end
    if not shouldSkip('lightarmor') and skills.lightarmor(self).modified > cap then return true end
    if not shouldSkip('mediumarmor') and skills.mediumarmor(self).modified > cap then return true end
    if not shouldSkip('destruction') and skills.destruction(self).modified > cap then return true end
    if not shouldSkip('marksman') and skills.marksman(self).modified > cap then return true end
    if not shouldSkip('heavyarmor') and skills.heavyarmor(self).modified > cap then return true end
    if not shouldSkip('mysticism') and skills.mysticism(self).modified > cap then return true end
    if not shouldSkip('shortblade') and skills.shortblade(self).modified > cap then return true end
    if not shouldSkip('spear') and skills.spear(self).modified > cap then return true end
    if not shouldSkip('restoration') and skills.restoration(self).modified > cap then return true end
    if not shouldSkip('handtohand') and skills.handtohand(self).modified > cap then return true end
    if not shouldSkip('block') and skills.block(self).modified > cap then return true end
    if not shouldSkip('illusion') and skills.illusion(self).modified > cap then return true end
    if not shouldSkip('mercantile') and skills.mercantile(self).modified > cap then return true end
    if not shouldSkip('athletics') and skills.athletics(self).modified > cap then return true end
    if not shouldSkip('unarmored') and skills.unarmored(self).modified > cap then return true end
    if not shouldSkip('speechcraft') and skills.speechcraft(self).modified > cap then return true end
    return false
end

-- Check if any spell in the given set is currently active on the player.
-- Returns true if any excluded spell is active, false otherwise.
local function hasExcludedSpellActive(spellSet)
    if not spellSet or not next(spellSet) then return false end
    local activeSpells = types.Actor.activeSpells(self)
    for id, _ in pairs(spellSet) do
        if activeSpells:isSpellActive(id) == true then
            return true
        end
    end
    return false
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

-- Training limit: reset counter when player levels up
local function checkTrainingLevelReset()
    local level = types.Actor.stats.level(self).current
    if state.trainLevel ~= level then
        state.trainCount = 0
        state.trainLevel = level
    end
end

-- Register training limit handler
interfaces.SkillProgression.addSkillLevelUpHandler(function(skillid, source, options)
    if not state.trainingLimit then return end
    if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
        checkTrainingLevelReset()
        if state.trainCount >= 5 then
            ui.showMessage("You've had enough theory. Time to practice on your own.")
            return false
        end
        state.trainCount = state.trainCount + 1
        ui.showMessage(string.format("Training sessions done: %d/5.", state.trainCount))
    end
end)

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
                state.trainingLimit = data.trainingLimit ~= false
                state.trainCount = data.trainCount or 0
                state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
            end

            -- Read current settings from global storage (overrides saved values)
            local settingsSection = storage.globalSection('raffll_limits')
            local trainingSection = storage.globalSection('raffll_limits_training')
            local v = settingsSection:get('potionsOnly')
            if v ~= nil then state.potionsOnly = v end
            v = settingsSection:get('progressivePotions')
            if v ~= nil then state.progressivePotions = v end
            v = settingsSection:get('progressiveStats')
            if v ~= nil then state.progressiveStats = v end
            v = trainingSection:get('trainingLimit')
            if v ~= nil then state.trainingLimit = v else state.trainingLimit = true end

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
                trainingLimit = state.trainingLimit,
                trainCount = state.trainCount,
                trainLevel = state.trainLevel,
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

            -- 4. Track cap values silently (messages are shown only when user changes settings)
            state.oldValueAttribute = attrCap
            state.oldValueSkill = skillCap
            state.oldCount = state.maxCount

            -- 5. Check attributes (if not potionsOnly and not active)
            local limitAttribute = false
            if not state.potionsOnly then
                limitAttribute = checkAttributes(attrCap)
            end
            if limitAttribute and not state.active then
                ui.showMessage("You have reached your attribute limit!")
            end

            -- 6. Check skills (if not potionsOnly and not active)
            local limitSkill = false
            if not state.potionsOnly then
                limitSkill = checkSkills(skillCap)
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
                        if not isPotionExcludedByFile(spell.id) then
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
            elseif data.key == 'trainingLimit' then
                state.trainingLimit = data.value
            end


        end,
        raffll_limits_showMessage = function(data)
            if data and data.text then
                ui.showMessage(data.text)
            end
        end,
        UiModeChanged = function(data)
            if not state.trainingLimit then return end
            checkTrainingLevelReset()
            if state.trainCount >= 5 and data.newMode == 'Training' then
                if interfaces.UI and interfaces.UI.removeMode then
                    interfaces.UI.removeMode('Training')
                    interfaces.UI.removeMode('Dialogue')
                    interfaces.UI.removeMode('Interface')
                end
                ui.showMessage("You've had enough theory. Time to practice on your own.")
            end
        end,
    },
    interfaceName = "StatsAndPotionsLimit",
    interface = {
        version = 2,
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
            return isPotionExcludedByFile(recordId)
        end,
        --- Temporarily skip an attribute from limit checks.
        --- Other mods can call this to prevent knockout when they modify an attribute.
        --- @param attributeName string one of: strength, intelligence, willpower, agility, speed, endurance, personality, luck
        skipAttribute = function(attributeName)
            if attributeName then
                skippedAttributes[attributeName] = true
            end
        end,
        --- Re-enable an attribute for limit checks.
        --- @param attributeName string
        unskipAttribute = function(attributeName)
            if attributeName then
                skippedAttributes[attributeName] = nil
            end
        end,
        --- Check if an attribute is currently skipped.
        --- @param attributeName string
        --- @return boolean
        isAttributeSkipped = function(attributeName)
            return skippedAttributes[attributeName] == true
        end,
    },
}
