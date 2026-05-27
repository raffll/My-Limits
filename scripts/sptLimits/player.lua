local core = require("openmw.core")
local self = require("openmw.self")
local types = require("openmw.types")
local ui = require("openmw.ui")
local storage = require("openmw.storage")
local interfaces = require("openmw.interfaces")

local config = require("scripts.sptLimits.config")
local exclusions = require("scripts.sptLimits.exclusions")
local L = core.l10n("sptLimits")

local excludedPotions = exclusions.excludedPotions
local isPotionExcluded = exclusions.isPotionExcluded

local state = {}

local excludedAttributeSpells = {}
for attr, spells in pairs(config.attributes or {}) do
    excludedAttributeSpells[attr] = {}
    for _, id in ipairs(spells) do
        excludedAttributeSpells[attr][id] = true
    end
end

local excludedSkillSpells = {}
for skill, spells in pairs(config.skills or {}) do
    excludedSkillSpells[skill] = {}
    for _, id in ipairs(spells) do
        excludedSkillSpells[skill][id] = true
    end
end

local skippedAttributes = {}
local skippedSkills = {}
local lastSent = {}

local function initState()
    state.knockedOut = false
    state.drinkCount = 0
    state.timer = 0
    state.drinkHour = 0
    state.drinkOverdose = false
    state.overdoseCollapse = false
    state.knownPotionSpellIds = {}
    state.potionSpellIdsInitialized = false
    state.trainCount = 0
    state.trainLevel = 0

    lastSent.drinkCount = nil
    lastSent.countdown = nil
    lastSent.globalKnockedOut = nil
    lastSent.globalOverdose = nil
end

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

local function shouldSkipAttribute(name)
    return skippedAttributes[name] or hasExcludedSpellActive(excludedAttributeSpells[name])
end

local function shouldSkipSkill(name)
    return skippedSkills[name] or hasExcludedSpellActive(excludedSkillSpells[name])
end

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
        state.potionSpellIdsInitialized = false
        state.knownPotionSpellIds = {}
    end
end

local function updatePotionTimer(dt)
    if state.drinkCount == 0 then
        return
    end

    local currentHour = core.getGameTime() / 3600

    if (currentHour - state.drinkHour) > 1 then
        state.drinkCount = 0
        state.timer = 0
        state.overdoseCollapse = false
        state.drinkOverdose = false
        state.potionSpellIdsInitialized = false
        state.knownPotionSpellIds = {}
        return
    end

    state.timer = state.timer + dt

    if state.timer >= config.potionCooldown then
        state.drinkCount = 0
        state.timer = 0
        state.overdoseCollapse = false
        state.drinkOverdose = false
        state.potionSpellIdsInitialized = false
        state.knownPotionSpellIds = {}
    end
end

local function handleDrinkDetected()
    state.timer = 0
    state.drinkHour = core.getGameTime() / 3600
    state.drinkCount = state.drinkCount + 1

    if state.drinkCount >= config.potionLimit + 2 then
        ui.showMessage(L("overdoseDeath"))
        types.Actor.stats.dynamic.health(self).current = 0
    elseif state.drinkCount >= config.potionLimit + 1 then
        ui.showMessage(L("overdose"))
        state.overdoseCollapse = true
        state.knockedOut = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
    end
end

local trainingBlockElement = nil

local function blockTrainingWindow()
    if interfaces.UI and interfaces.UI.registerWindow then
        interfaces.UI.registerWindow("Training", function()
            if interfaces.UI.removeMode then
                interfaces.UI.removeMode("Training")
                interfaces.UI.removeMode("Dialogue")
            end
            ui.showMessage(L("trainLimitReached"))
        end, function() end)
    end
end

local function unblockTrainingWindow()
    if interfaces.UI and interfaces.UI.registerWindow then
        interfaces.UI.registerWindow("Training", nil, nil)
    end
end

local function checkTrainingLevelReset()
    local level = types.Actor.stats.level(self).current
    if state.trainLevel ~= level then
        state.trainCount = 0
        state.trainLevel = level
        unblockTrainingWindow()
    end
end

interfaces.SkillProgression.addSkillLevelUpHandler(function(skillid, source, options)
    if not config.trainingLimitEnabled then
        return
    end
    if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
        checkTrainingLevelReset()
        if state.trainCount >= config.trainingLimit then
            ui.showMessage(L("trainLimitReached"))
            return false
        end
        state.trainCount = state.trainCount + 1
        if state.trainCount >= config.trainingLimit then
            blockTrainingWindow()
        end
    end
end)

return {
    engineHandlers = {
        onInit = function()
            initState()
        end,
        onLoad = function(data)
            initState()
            if data then
                state.knockedOut = data.knockedOut or false
                state.drinkCount = data.drinkCount or 0
                state.timer = data.timer or 0
                state.drinkHour = data.drinkHour or 0
                state.overdoseCollapse = data.overdoseCollapse or false
                state.trainCount = data.trainCount or 0
                state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
            end
            state.drinkOverdose = (state.drinkCount >= config.potionLimit)

            if config.trainingLimitEnabled and state.trainCount >= config.trainingLimit then
                blockTrainingWindow()
            end

            state.knownPotionSpellIds = {}
            local activeSpells = types.Actor.activeSpells(self)
            for _, spell in pairs(activeSpells) do
                local rok, rec = pcall(types.Potion.record, spell.id)
                if rok and rec then
                    if not isPotionExcluded(spell.id) then
                        state.knownPotionSpellIds[spell.activeSpellId] = true
                    end
                end
            end
            state.potionSpellIdsInitialized = true
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
                    ui.showMessage(L("attributeLimit"))
                end

                limitSkill = checkSkills(config.skillCap)
                if limitSkill and not state.knockedOut then
                    ui.showMessage(L("skillLimit"))
                end
            end

            if config.potionLimitEnabled then
                local currentIds = {}
                local activeSpells = types.Actor.activeSpells(self)
                for _, spell in pairs(activeSpells) do
                    local rok, rec = pcall(types.Potion.record, spell.id)
                    if rok and rec then
                        if not isPotionExcluded(spell.id) then
                            currentIds[spell.activeSpellId] = true
                        end
                    end
                end

                if not state.potionSpellIdsInitialized then
                    state.knownPotionSpellIds = currentIds
                    state.potionSpellIdsInitialized = true
                else
                    for id, _ in pairs(currentIds) do
                        if not state.knownPotionSpellIds[id] then
                            handleDrinkDetected()
                            state.knownPotionSpellIds[id] = true
                        end
                    end
                    for id, _ in pairs(state.knownPotionSpellIds) do
                        if not currentIds[id] then
                            state.knownPotionSpellIds[id] = nil
                        end
                    end
                end

                updatePotionTimer(dt)
                state.drinkOverdose = (state.drinkCount >= config.potionLimit)
            end

            handleKnockoutRecovery(limitAttribute, limitSkill)

            if config.potionLimitEnabled then
                local countdown = state.drinkCount > 0 and math.max(0, config.potionCooldown - state.timer) or 0
                local section = storage.playerSection("sptLimitsState")
                if lastSent.drinkCount ~= state.drinkCount then
                    section:set("drinkCount", state.drinkCount)
                    lastSent.drinkCount = state.drinkCount
                end
                local countdownRounded = math.floor(countdown * 10) / 10
                if lastSent.countdown ~= countdownRounded then
                    section:set("countdown", countdown)
                    lastSent.countdown = countdownRounded
                end
            end

            if lastSent.globalKnockedOut ~= state.knockedOut or lastSent.globalOverdose ~= state.drinkOverdose then
                core.sendGlobalEvent("sptLimitsStateUpdate", {
                    knockedOut = state.knockedOut,
                    drinkOverdose = state.drinkOverdose,
                })
                lastSent.globalKnockedOut = state.knockedOut
                lastSent.globalOverdose = state.drinkOverdose
            end
        end,
    },
    eventHandlers = {
        sptLimitsShowMessage = function(data)
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
                blockTrainingWindow()
            end
        end,
    },
    interfaceName = "sptLimits",
    interface = {
        version = 1,
        isKnockedOut = function()
            return state.knockedOut
        end,
        excludePotion = function(recordId)
            if recordId then
                excludedPotions[recordId] = true
                core.sendGlobalEvent("sptLimitsExcludePotion", { recordId = recordId })
            end
        end,
        includePotion = function(recordId)
            if recordId then
                excludedPotions[recordId] = nil
                core.sendGlobalEvent("sptLimitsIncludePotion", { recordId = recordId })
            end
        end,
        skipAttribute = function(attributeName)
            if attributeName then
                skippedAttributes[attributeName] = true
            end
        end,
        unskipAttribute = function(attributeName)
            if attributeName then
                skippedAttributes[attributeName] = nil
            end
        end,
        skipSkill = function(skillName)
            if skillName then
                skippedSkills[skillName] = true
            end
        end,
        unskipSkill = function(skillName)
            if skillName then
                skippedSkills[skillName] = nil
            end
        end,
    },
}
