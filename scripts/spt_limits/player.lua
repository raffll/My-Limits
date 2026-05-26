local core = require('openmw.core')
local self = require('openmw.self')
local types = require('openmw.types')
local ui = require('openmw.ui')
local storage = require('openmw.storage')
local interfaces = require('openmw.interfaces')

-- Load config
local exclusions = require('scripts.sptLimits.config')
local L = core.l10n('sptLimits')

-- Module-level state table
local state = {}

-- Set of potion record IDs excluded from counting (from data file + registered via interface)
local excludedPotions = {}
-- List of Lua patterns converted from wildcard entries (e.g. "sd_*" -> "^sd_")
local excludedPotionPatterns = {}

for _, entry in ipairs(exclusions.potions or {}) do
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
for attr, spells in pairs(exclusions.attributes or {}) do
    excludedAttributeSpells[attr] = {}
    for _, id in ipairs(spells) do
        excludedAttributeSpells[attr][id] = true
    end
end

-- Per-skill spell exclusion sets
local excludedSkillSpells = {}
for skill, spells in pairs(exclusions.skills or {}) do
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
    state.active = false              -- knockout state flag
    state.drinkCount = 0              -- potions consumed in current window
    state.timer = 0                   -- seconds elapsed since last drink
    state.drinkHour = 0               -- GameHour when last potion was consumed
    state.maxCount = exclusions.potionLimit -- current max allowed potions
    state.drinkOverdose = false       -- whether at overdose threshold (drinkCount > maxCount)
    state.overdoseCollapse = false    -- potion overdose triggered collapse flag
    state.potionEffectsInitialized = false -- whether baseline has been captured
    state.baselinePotionEffects = 0   -- active potion effect count at last reset/init
    state.detectedDrinks = 0          -- cumulative drinks detected since last reset (via delta from baseline)
    state.trainCount = 0              -- training sessions used this level
    state.trainLevel = 0              -- level at which trainCount was last reset

    -- Reset dirty-flag cache so first frame always writes
    lastSent.active = nil
    lastSent.drinkCount = nil
    lastSent.maxCount = nil
    lastSent.countdown = nil
    lastSent.drinkOverdose = nil
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
-- Skips skills that are in the skippedSkills set (interface) or have an excluded spell active.
-- Returns true if ANY skill's .modified value > cap, false otherwise.
local function checkSkills(cap)
    local skills = types.NPC.stats.skills
    local function shouldSkip(name)
        return skippedSkills[name] or hasExcludedSpellActive(excludedSkillSpells[name])
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

-- Handle knockout/recovery state machine transitions
-- limitAttribute: boolean, true if any attribute exceeds its cap
-- limitSkill: boolean, true if any skill exceeds its cap
local function handleKnockoutRecovery(limitAttribute, limitSkill)
    local anyLimit = limitAttribute or limitSkill or state.overdoseCollapse

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
        -- Maintain knockout: keep max fatigue at 0 and current at 0 to stay collapsed
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = 0
    elseif state.active and not anyLimit then
        -- Recovery: all limits cleared while in knockout
        ui.showMessage(L("recovered"))
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
        -- Reset potion detection to ignore any buffered hotkey drinks
        state.potionEffectsInitialized = false
        state.baselinePotionEffects = 0
        state.detectedDrinks = 0
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
    if state.timer >= exclusions.potionCooldown then
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
-- When drinkCount reaches maxCount, next drink = overdose (collapse).
-- One more drink after overdose = death.
local function handleDrinkDetected()
    state.timer = 0
    state.drinkHour = core.getGameTime() / 3600
    state.drinkCount = state.drinkCount + 1

    if state.drinkCount >= state.maxCount + 2 then
        -- Death: drink while already in overdose
        ui.showMessage(L("overdoseDeath"))
        types.Actor.stats.dynamic.health(self).current = 0
    elseif state.drinkCount >= state.maxCount + 1 then
        -- Overdose: first drink past the limit → collapse immediately
        ui.showMessage(L("overdose"))
        state.overdoseCollapse = true
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
    if not exclusions.trainingLimitEnabled then return end
    if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
        checkTrainingLevelReset()
        if state.trainCount >= exclusions.trainingLimit then
            ui.showMessage(L("trainLimitReached"))
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
            -- 1. Set all state to defaults first
            initState()

            -- 2. Restore saved fields (guard against nil/first load)
            if data then
                state.active = data.active or false
                state.drinkCount = data.drinkCount or 0
                state.timer = data.timer or 0
                state.drinkHour = data.drinkHour or 0
                state.overdoseCollapse = data.limitPotion or false
                state.trainCount = data.trainCount or 0
                state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
            end

            -- Recompute derived state (maxCount always comes from config)
            state.drinkOverdose = (state.drinkCount >= state.maxCount)

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
                active = state.active,
                drinkCount = state.drinkCount,
                timer = state.timer,
                drinkHour = state.drinkHour,
                limitPotion = state.overdoseCollapse,
                trainCount = state.trainCount,
                trainLevel = state.trainLevel,
            }
        end,
        onUpdate = function(dt)
            -- 1. CharGen check: if character generation is not finished, return early
            if not types.Player.isCharGenFinished(self) then return end

            -- 2. Compute caps
            local attrCap = exclusions.attributeCap
            local skillCap = exclusions.skillCap
            state.maxCount = exclusions.potionLimit

            -- 4. Check attributes (if statLimit enabled and not active)
            local limitAttribute = false
            if exclusions.statLimitEnabled then
                limitAttribute = checkAttributes(attrCap)
            end
            if limitAttribute and not state.active then
                ui.showMessage(L("attributeLimit"))
            end

            -- 5. Check skills (if statLimit enabled and not active)
            local limitSkill = false
            if exclusions.statLimitEnabled then
                limitSkill = checkSkills(skillCap)
            end
            if limitSkill and not state.active then
                ui.showMessage(L("skillLimit"))
            end

            -- 6. Detect potion drink by counting active potion effects
            if exclusions.potionLimitEnabled then
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
                -- Seed baseline: current active effects are "already accounted for"
                state.baselinePotionEffects = potionEffectCount
                state.detectedDrinks = 0
                state.potionEffectsInitialized = true
            else
                -- Cumulative detection: any active effects above baseline are new drinks.
                -- This count only goes up — expired effects lower potionEffectCount but
                -- detectedDrinks remembers all drinks that were ever detected this window.
                local currentDelta = potionEffectCount - state.baselinePotionEffects
                if currentDelta > state.detectedDrinks then
                    local newDrinks = currentDelta - state.detectedDrinks
                    for i = 1, newDrinks do
                        handleDrinkDetected()
                    end
                    state.detectedDrinks = currentDelta
                end
            end

            -- 7. Update potion timer
            updatePotionTimer(dt)
            end

            -- 8. Update drinkOverdose
            state.drinkOverdose = (state.drinkCount >= state.maxCount)

            -- 9. Handle knockout/recovery
            handleKnockoutRecovery(limitAttribute, limitSkill)

            -- 10. Write state to player storage for menu scripts to read (only when changed)
            local countdown = state.drinkCount > 0 and math.max(0, exclusions.potionCooldown - state.timer) or 0
            local section = storage.playerSection('sptLimits_state')
            if lastSent.active ~= state.active then
                section:set('active', state.active)
                lastSent.active = state.active
            end
            if lastSent.drinkCount ~= state.drinkCount then
                section:set('drinkCount', state.drinkCount)
                lastSent.drinkCount = state.drinkCount
            end
            if lastSent.maxCount ~= state.maxCount then
                section:set('maxCount', state.maxCount)
                lastSent.maxCount = state.maxCount
            end
            -- Countdown changes every frame while active, but only write when visually different (0.1s precision)
            local countdownRounded = math.floor(countdown * 10) / 10
            if lastSent.countdown ~= countdownRounded then
                section:set('countdown', countdown)
                lastSent.countdown = countdownRounded
            end
            if lastSent.drinkOverdose ~= state.drinkOverdose then
                section:set('drinkOverdose', state.drinkOverdose)
                lastSent.drinkOverdose = state.drinkOverdose
            end

            -- 11. Send state to global script for item blocking (only when changed)
            if lastSent.globalActive ~= state.active or lastSent.globalOverdose ~= state.drinkOverdose then
                core.sendGlobalEvent('spt_limits_state_update', {
                    active = state.active,
                    drinkOverdose = state.drinkOverdose,
                })
                lastSent.globalActive = state.active
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
            if not data then return end
            if not exclusions.trainingLimitEnabled then return end
            checkTrainingLevelReset()
            if state.trainCount >= exclusions.trainingLimit and data.newMode == 'Training' then
                if interfaces.UI and interfaces.UI.removeMode then
                    interfaces.UI.removeMode('Training')
                    interfaces.UI.removeMode('Dialogue')
                    interfaces.UI.removeMode('Interface')
                end
                ui.showMessage(L("trainLimitReached"))
            end
        end,
    },
    interfaceName = "StatsAndPotionsLimit",
    interface = {
        version = 1,
        --- Returns true if the player is currently knocked out (overdose/stat limit).
        isKnockedOut = function() return state.active end,
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
