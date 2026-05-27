local core = require("openmw.core")
local self = require("openmw.self")
local types = require("openmw.types")
local ui = require("openmw.ui")
local storage = require("openmw.storage")
local interfaces = require("openmw.interfaces")

-- Load config
local config = require("scripts.spt_limits.config")
local L = core.l10n("spt_limits")

-- Module-level state table
local state = {}

-- Set of potion record IDs excluded from counting (from data file + registered via interface)
local excludedPotions = {}
-- List of Lua patterns converted from wildcard entries (e.g. "sd_*" -> "^sd_")
local excludedPotionPatterns = {}

for _, entry in ipairs(config.potions or {}) do
    if entry:find("%*") then
        -- Convert wildcard to Lua pattern: escape special chars, replace * with .*
        local pattern = "^" .. entry:gsub("([%.%+%-%^%$%(%)%%])", "%%%1"):gsub("%*", ".*") .. "$"
        table.insert(excludedPotionPatterns, pattern)
    else
        excludedPotions[entry] = true
    end
end

-- Check if a potion ID is excluded (exact match, Sun's Dusk consumable, or wildcard pattern)
local function isPotionExcludedByFile(id)
    if excludedPotions[id] then
        return true
    end
    if config.excludeSunsDusk and interfaces.SunsDusk and interfaces.SunsDusk.isConsumable then
        if interfaces.SunsDusk.isConsumable(id) then
            return true
        end
    end
    for _, pattern in ipairs(excludedPotionPatterns) do
        if id:match(pattern) then
            return true
        end
    end
    return false
end

-- Per-attribute spell exclusion sets
local excludedAttributeSpells = {}
for attr, spells in pairs(config.attributes or {}) do
    excludedAttributeSpells[attr] = {}
    for _, id in ipairs(spells) do
        excludedAttributeSpells[attr][id] = true
    end
end

-- Per-skill spell exclusion sets
local excludedSkillSpells = {}
for skill, spells in pairs(config.skills or {}) do
    excludedSkillSpells[skill] = {}
    for _, id in ipairs(spells) do
        excludedSkillSpells[skill][id] = true
    end
end

-- Set of attribute names temporarily excluded from limit checks (registered by other mods via interface)
local skippedAttributes = {}

-- Set of skill names temporarily excluded from limit checks (registered by other mods via interface)
local skippedSkills = {}

-- Last values sent to storage/global, used for dirty-flag optimization
local lastSent = {}

-- Initialize all state variables to their defaults
local function initState()
    state.knockedOut = false -- knockout state flag
    state.drinkCount = 0 -- potions consumed in current window
    state.timer = 0 -- seconds elapsed since last drink
    state.drinkHour = 0 -- GameHour when last potion was consumed
    state.drinkOverdose = false -- whether at overdose threshold (drinkCount >= potionLimit)
    state.overdoseCollapse = false -- potion overdose triggered collapse flag
    state.potionEffectsInitialized = false -- whether baseline has been captured
    state.baselinePotionEffects = 0 -- active potion effect count at last reset/init
    state.detectedDrinks = 0 -- cumulative drinks detected since last reset (via delta from baseline)
    state.trainCount = 0 -- training sessions used this level
    state.trainLevel = 0 -- level at which trainCount was last reset

    -- Reset dirty-flag cache so first frame always writes
    lastSent.knockedOut = nil
    lastSent.drinkCount = nil
    lastSent.countdown = nil
    lastSent.drinkOverdose = nil
    lastSent.globalKnockedOut = nil
    lastSent.globalOverdose = nil
end

-- Check if any spell in the given set is currently active on the player.
-- Returns true if any excluded spell is active, false otherwise.
local function hasExcludedSpellActive(spellSet)
    if not spellSet or not next(spellSet) then
        return false
    end
    local activeSpells = types.Actor.activeSpells(self)
    for id, _ in pairs(spellSet) do
        if activeSpells:isSpellActive(id) == true then
            return true
        end
    end
    return false
end

-- Module-scope skip helpers (avoids closure allocation per frame)
local function shouldSkipAttribute(name)
    return skippedAttributes[name] or hasExcludedSpellActive(excludedAttributeSpells[name])
end

local function shouldSkipSkill(name)
    return skippedSkills[name] or hasExcludedSpellActive(excludedSkillSpells[name])
end

-- Check if any of the 8 player attributes exceeds the given cap.
-- Skips attributes that are in the skippedAttributes set (interface) or have an excluded spell active.
-- Returns true if ANY attribute's .modified value > cap, false otherwise.
local function checkAttributes(cap)
    local attrs = types.Actor.stats.attributes
    if not shouldSkipAttribute("strength") and attrs.strength(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("intelligence") and attrs.intelligence(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("willpower") and attrs.willpower(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("agility") and attrs.agility(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("speed") and attrs.speed(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("endurance") and attrs.endurance(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("personality") and attrs.personality(self).modified > cap then
        return true
    end
    if not shouldSkipAttribute("luck") and attrs.luck(self).modified > cap then
        return true
    end
    return false
end

-- Check if any of the 27 player skills exceeds the given cap.
-- Skips skills that are in the skippedSkills set (interface) or have an excluded spell active.
-- Returns true if ANY skill's .modified value > cap, false otherwise.
local function checkSkills(cap)
    local skills = types.NPC.stats.skills
    if not shouldSkipSkill("alchemy") and skills.alchemy(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("longblade") and skills.longblade(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("acrobatics") and skills.acrobatics(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("bluntweapon") and skills.bluntweapon(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("enchant") and skills.enchant(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("security") and skills.security(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("axe") and skills.axe(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("conjuration") and skills.conjuration(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("sneak") and skills.sneak(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("armorer") and skills.armorer(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("alteration") and skills.alteration(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("lightarmor") and skills.lightarmor(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("mediumarmor") and skills.mediumarmor(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("destruction") and skills.destruction(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("marksman") and skills.marksman(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("heavyarmor") and skills.heavyarmor(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("mysticism") and skills.mysticism(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("shortblade") and skills.shortblade(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("spear") and skills.spear(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("restoration") and skills.restoration(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("handtohand") and skills.handtohand(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("block") and skills.block(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("illusion") and skills.illusion(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("mercantile") and skills.mercantile(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("athletics") and skills.athletics(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("unarmored") and skills.unarmored(self).modified > cap then
        return true
    end
    if not shouldSkipSkill("speechcraft") and skills.speechcraft(self).modified > cap then
        return true
    end
    return false
end

-- Handle knockout/recovery state machine transitions
-- limitAttribute: boolean, true if any attribute exceeds its cap
-- limitSkill: boolean, true if any skill exceeds its cap
local function handleKnockoutRecovery(limitAttribute, limitSkill)
    local anyLimit = limitAttribute or limitSkill or state.overdoseCollapse

    if not state.knockedOut and anyLimit then
        state.knockedOut = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
        if interfaces.UI and interfaces.UI.setMode then
            interfaces.UI.setMode()
        end
    elseif state.knockedOut and anyLimit then
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = 0
    elseif state.knockedOut and not anyLimit then
        ui.showMessage(L("recovered"))
        local attrs = types.Actor.stats.attributes
        local baseMax = attrs.strength(self).modified
            + attrs.willpower(self).modified
            + attrs.agility(self).modified
            + attrs.endurance(self).modified
        types.Actor.stats.dynamic.fatigue(self).base = baseMax
        types.Actor.stats.dynamic.fatigue(self).current = 0
        state.knockedOut = false
        state.potionEffectsInitialized = false
        state.baselinePotionEffects = 0
        state.detectedDrinks = 0
    end
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
        state.overdoseCollapse = false
        state.drinkOverdose = false
        -- Re-baseline potion detection for the new window
        state.potionEffectsInitialized = false
        state.detectedDrinks = 0
        return
    end

    -- Accumulate elapsed frame time
    state.timer = state.timer + dt

    -- Timer expiry
    if state.timer >= config.potionCooldown then
        state.drinkCount = 0
        state.timer = 0
        state.overdoseCollapse = false
        state.drinkOverdose = false
        -- Re-baseline potion detection for the new window
        state.potionEffectsInitialized = false
        state.detectedDrinks = 0
    end
end

-- Handle a potion drink detection:
-- Detected via active potion effect count increase.
-- drinkCount tracks drinks within the cooldown window.
-- When drinkCount reaches potionLimit, next drink = overdose (collapse).
-- One more drink after overdose = death.
local function handleDrinkDetected()
    state.timer = 0
    state.drinkHour = core.getGameTime() / 3600
    state.drinkCount = state.drinkCount + 1

    if state.drinkCount >= config.potionLimit + 2 then
        -- Death: drink while already in overdose
        ui.showMessage(L("overdose_death"))
        types.Actor.stats.dynamic.health(self).current = 0
    elseif state.drinkCount >= config.potionLimit + 1 then
        -- Overdose: first drink past the limit → collapse immediately
        ui.showMessage(L("overdose"))
        state.overdoseCollapse = true
        state.knockedOut = true
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
    if not config.trainingLimitEnabled then
        return
    end
    if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
        checkTrainingLevelReset()
        if state.trainCount >= config.trainingLimit then
            ui.showMessage(L("train_limit_reached"))
            return false
        end
        state.trainCount = state.trainCount + 1
    end
end)

return {
    engineHandlers = {
        onInit = function()
            initState()
        end,
        onLoad = function(data)
            -- Set all state to defaults first
            initState()

            -- Restore saved fields (guard against nil/first load)
            if data then
                state.knockedOut = data.knockedOut or false
                state.drinkCount = data.drinkCount or 0
                state.timer = data.timer or 0
                state.drinkHour = data.drinkHour or 0
                state.overdoseCollapse = data.overdoseCollapse or false
                state.trainCount = data.trainCount or 0
                state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
            end

            -- Recompute derived state
            state.drinkOverdose = (state.drinkCount >= config.potionLimit)

            -- Re-seed potion detection baseline from current active effects
            local potionEffectCount = 0
            local activeSpells = types.Actor.activeSpells(self)
            for _, spell in pairs(activeSpells) do
                local rok, rec = pcall(types.Potion.record, spell.id)
                if rok and rec then
                    if not isPotionExcludedByFile(spell.id) then
                        potionEffectCount = potionEffectCount + 1
                    end
                end
            end
            state.baselinePotionEffects = potionEffectCount
            state.detectedDrinks = 0
            state.potionEffectsInitialized = true
        end,
        onSave = function()
            return {
                knockedOut = state.knockedOut,
                drinkCount = state.drinkCount,
                timer = state.timer,
                drinkHour = state.drinkHour,
                overdoseCollapse = state.overdoseCollapse,
                trainCount = state.trainCount,
                trainLevel = state.trainLevel,
            }
        end,
        onUpdate = function(dt)
            if not types.Player.isCharGenFinished(self) then
                return
            end

            if not config.statLimitEnabled and not config.potionLimitEnabled then
                return
            end

            local limitAttribute = false
            local limitSkill = false

            if config.statLimitEnabled then
                limitAttribute = checkAttributes(config.attributeCap)
                if limitAttribute and not state.knockedOut then
                    ui.showMessage(L("attribute_limit"))
                end

                limitSkill = checkSkills(config.skillCap)
                if limitSkill and not state.knockedOut then
                    ui.showMessage(L("skill_limit"))
                end
            end

            if config.potionLimitEnabled then
                local potionEffectCount = 0
                local activeSpells = types.Actor.activeSpells(self)
                for _, spell in pairs(activeSpells) do
                    local rok, rec = pcall(types.Potion.record, spell.id)
                    if rok and rec then
                        if not isPotionExcludedByFile(spell.id) then
                            potionEffectCount = potionEffectCount + 1
                        end
                    end
                end
                if not state.potionEffectsInitialized then
                    state.baselinePotionEffects = potionEffectCount
                    state.detectedDrinks = 0
                    state.potionEffectsInitialized = true
                else
                    local currentDelta = potionEffectCount - state.baselinePotionEffects
                    if currentDelta > state.detectedDrinks then
                        local newDrinks = currentDelta - state.detectedDrinks
                        for i = 1, newDrinks do
                            handleDrinkDetected()
                        end
                        state.detectedDrinks = currentDelta
                    end
                end

                updatePotionTimer(dt)
                state.drinkOverdose = (state.drinkCount >= config.potionLimit)
            end

            handleKnockoutRecovery(limitAttribute, limitSkill)

            if config.potionLimitEnabled then
                local countdown = state.drinkCount > 0 and math.max(0, config.potionCooldown - state.timer) or 0
                local section = storage.playerSection("spt_limits_state")
                if lastSent.drinkCount ~= state.drinkCount then
                    section:set("drink_count", state.drinkCount)
                    lastSent.drinkCount = state.drinkCount
                end
                local countdownRounded = math.floor(countdown * 10) / 10
                if lastSent.countdown ~= countdownRounded then
                    section:set("countdown", countdown)
                    lastSent.countdown = countdownRounded
                end
            end

            if lastSent.globalKnockedOut ~= state.knockedOut or lastSent.globalOverdose ~= state.drinkOverdose then
                core.sendGlobalEvent("spt_limits_state_update", {
                    knocked_out = state.knockedOut,
                    drink_overdose = state.drinkOverdose,
                })
                lastSent.globalKnockedOut = state.knockedOut
                lastSent.globalOverdose = state.drinkOverdose
            end
        end,
    },
    eventHandlers = {
        spt_limits_show_message = function(data)
            if data and data.text then
                ui.showMessage(data.text)
            end
        end,
        UiModeChanged = function(data)
            if not data then
                return
            end
            if not config.trainingLimitEnabled then
                return
            end
            checkTrainingLevelReset()
            if state.trainCount >= config.trainingLimit and data.newMode == "Training" then
                if interfaces.UI and interfaces.UI.removeMode then
                    interfaces.UI.removeMode("Training")
                    interfaces.UI.removeMode("Dialogue")
                    interfaces.UI.removeMode("Interface")
                end
                ui.showMessage(L("train_limit_reached"))
            end
        end,
    },
    interfaceName = "spt_limits",
    interface = {
        version = 1,
        --- Returns true if the player is currently knocked out (overdose/stat limit).
        isKnockedOut = function()
            return state.knockedOut
        end,
        --- Exclude a potion record ID from being counted toward the limit.
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
        --- Temporarily skip an attribute from limit checks.
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
        --- Temporarily skip a skill from limit checks.
        --- @param skillName string one of: alchemy, longblade, acrobatics, bluntweapon, enchant, security, axe, conjuration, sneak, armorer, alteration, lightarmor, mediumarmor, destruction, marksman, heavyarmor, mysticism, shortblade, spear, restoration, handtohand, block, illusion, mercantile, athletics, unarmored, speechcraft
        skipSkill = function(skillName)
            if skillName then
                skippedSkills[skillName] = true
            end
        end,
        --- Re-enable a skill for limit checks.
        --- @param skillName string
        unskipSkill = function(skillName)
            if skillName then
                skippedSkills[skillName] = nil
            end
        end,
    },
}
