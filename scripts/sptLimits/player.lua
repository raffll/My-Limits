local core = require("openmw.core")
local self = require("openmw.self")
local types = require("openmw.types")
local ui = require("openmw.ui")
local storage = require("openmw.storage")
local interfaces = require("openmw.interfaces")

local config = require("scripts.sptLimits.config")
local settings = require("scripts.sptLimits.settings")
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

local function initSlots()
    local slotCount = settings.get("potionSlotCount")
    state.slots = {}
    for i = 1, slotCount + 1 do
        state.slots[i] = { activeSpellId = nil, countdown = 0, icon = nil }
    end
end

local function getOccupiedNormalCount()
    local slotCount = settings.get("potionSlotCount")
    local count = 0
    for i = 1, slotCount do
        if state.slots[i] and state.slots[i].activeSpellId ~= nil then
            count = count + 1
        end
    end
    return count
end

local function isOverflowOccupied()
    local slotCount = settings.get("potionSlotCount")
    local overflow = state.slots[slotCount + 1]
    return overflow ~= nil and overflow.activeSpellId ~= nil
end

local function assignDrinkToSlot(activeSpellId, longestDuration, icon)
    local slotCount = settings.get("potionSlotCount")
    for i = 1, slotCount do
        if state.slots[i] and state.slots[i].activeSpellId == nil then
            state.slots[i].activeSpellId = activeSpellId
            state.slots[i].countdown = longestDuration
            state.slots[i].icon = icon
            return true
        end
    end
    return false
end

local function assignDrinkToOverflow(activeSpellId, longestDuration, icon)
    local slotCount = settings.get("potionSlotCount")
    local overflow = state.slots[slotCount + 1]
    if overflow == nil then
        return
    end
    overflow.activeSpellId = activeSpellId
    overflow.countdown = longestDuration
    overflow.icon = icon
    state.knockedOut = true
    types.Actor.stats.dynamic.fatigue(self).current = -1
    ui.showMessage(L("overdose"))
end

local function handleOverflowRecovery()
    state.knockedOut = false
    local attrs = types.Actor.stats.attributes
    local baseMax = attrs.strength(self).modified
        + attrs.willpower(self).modified
        + attrs.agility(self).modified
        + attrs.endurance(self).modified
    types.Actor.stats.dynamic.fatigue(self).base = baseMax
    types.Actor.stats.dynamic.fatigue(self).current = 0
end

local function tickSlots(dt)
    local slotCount = settings.get("potionSlotCount")
    for i = 1, slotCount + 1 do
        local slot = state.slots[i]
        if slot and slot.activeSpellId ~= nil then
            local prevCountdown = slot.countdown
            if prevCountdown > 0 then
                slot.countdown = prevCountdown - dt
                if slot.countdown < 0 then
                    slot.countdown = 0
                end
                -- Expire the slot when countdown reaches 0
                if slot.countdown == 0 then
                    if i <= slotCount then
                        slot.activeSpellId = nil
                        slot.countdown = 0
                        slot.icon = nil
                    else
                        slot.activeSpellId = nil
                        slot.countdown = 0
                        slot.icon = nil
                        handleOverflowRecovery()
                    end
                end
            end
            -- If prevCountdown was already 0 (instant-effect), do NOT decrement or clear
        end
    end
end

local function validateSlots(activeSpells)
    local slotCount = settings.get("potionSlotCount")
    for i = 1, slotCount + 1 do
        local slot = state.slots[i]
        if slot and slot.activeSpellId ~= nil then
            if not activeSpells[slot.activeSpellId] then
                slot.activeSpellId = nil
                slot.countdown = 0
                if i == slotCount + 1 then
                    handleOverflowRecovery()
                end
            end
        end
    end
end

local function writeSlotStorage()
    local slotCount = settings.get("potionSlotCount")
    local section = storage.playerSection("sptLimitsState")
    local occupiedNormal = getOccupiedNormalCount()
    local overflowOcc = isOverflowOccupied()

    if lastSent.slotTrackingMode ~= "slots" then
        section:set("trackingMode", "slots")
        lastSent.slotTrackingMode = "slots"
    end
    if lastSent.slotCount ~= slotCount then
        section:set("slotCount", slotCount)
        lastSent.slotCount = slotCount
    end
    for i = 1, slotCount + 1 do
        local slot = state.slots[i]
        local occupied = slot and slot.activeSpellId ~= nil
        local countdown = occupied and slot.countdown or 0
        -- Write 0 if below display threshold to avoid stale "0.1s"
        if countdown < 0.1 then
            countdown = 0
        end
        local countdownRounded = math.floor(countdown * 10) / 10
        local lastKey = "slot" .. i .. "Countdown"
        local prevRounded = lastSent[lastKey]
        if prevRounded ~= countdownRounded or (not occupied and prevRounded ~= nil and prevRounded ~= 0) then
            section:set(lastKey, countdown)
            lastSent[lastKey] = occupied and countdownRounded or 0
        end
        local icon = occupied and slot.icon or ""
        local iconKey = "slot" .. i .. "Icon"
        if lastSent[iconKey] ~= icon then
            section:set(iconKey, icon)
            lastSent[iconKey] = icon
        end
    end
    if lastSent.occupiedSlots ~= occupiedNormal then
        section:set("occupiedSlots", occupiedNormal)
        lastSent.occupiedSlots = occupiedNormal
    end
    if lastSent.overflowOccupied ~= overflowOcc then
        section:set("overflowOccupied", overflowOcc)
        lastSent.overflowOccupied = overflowOcc
    end
end

local function sendSlotStateEvent()
    local allFull = (getOccupiedNormalCount() == settings.get("potionSlotCount"))
    if lastSent.slotKnockedOut ~= state.knockedOut or lastSent.slotAllFull ~= allFull then
        core.sendGlobalEvent("sptLimitsStateUpdate", {
            knockedOut = state.knockedOut,
            allNormalSlotsFull = allFull,
            potionTrackingMode = "slots",
        })
        lastSent.slotKnockedOut = state.knockedOut
        lastSent.slotAllFull = allFull
    end
end

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
    state.potionTrackingMode = settings.get("potionTrackingMode")
    state.slots = {}

    if state.potionTrackingMode == "slots" then
        initSlots()
    end

    lastSent.drinkCount = nil
    lastSent.countdown = nil
    lastSent.potionLimit = nil
    lastSent.globalKnockedOut = nil
    lastSent.globalOverdose = nil
    lastSent.slotTrackingMode = nil
    lastSent.slotCount = nil
    lastSent.occupiedSlots = nil
    lastSent.overflowOccupied = nil
    lastSent.slotKnockedOut = nil
    lastSent.slotAllFull = nil
    for i = 1, 11 do
        lastSent["slot" .. i .. "Countdown"] = nil
        lastSent["slot" .. i .. "Icon"] = nil
    end
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
    if state.potionTrackingMode == "slots" and isOverflowOccupied() then
        anyLimit = true
    end

    if not state.knockedOut and anyLimit then
        state.knockedOut = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
        local currentMode = interfaces.UI and interfaces.UI.getMode and interfaces.UI.getMode()
        if not currentMode and interfaces.UI and interfaces.UI.setMode then
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

    if (currentHour - state.drinkHour) >= 1 then
        state.drinkCount = 0
        state.timer = 0
        state.overdoseCollapse = false
        state.drinkOverdose = false
        state.potionSpellIdsInitialized = false
        state.knownPotionSpellIds = {}
        return
    end

    state.timer = state.timer + dt

    if state.timer >= settings.get("potionCooldown") then
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

    -- Death branch: unreachable in current OpenMW (engine blocks hotkeys while
    -- collapsed). Kept as a safeguard for potential future engine changes.
    if state.drinkCount >= settings.get("potionLimit") + 2 then
        ui.showMessage(L("overdoseDeath"))
        types.Actor.stats.dynamic.health(self).current = 0
        return
    end

    if state.drinkCount >= settings.get("potionLimit") + 1 then
        ui.showMessage(L("overdose"))
        state.overdoseCollapse = true
        state.knockedOut = true
        types.Actor.stats.dynamic.fatigue(self).base = 0
        types.Actor.stats.dynamic.fatigue(self).current = -1
    end
end

local function sendSettingsToGlobal()
    core.sendGlobalEvent("sptLimitsSettingsUpdate", {
        potionLimitEnabled = settings.get("potionLimitEnabled"),
        statLimitEnabled = settings.get("statLimitEnabled"),
        excludeSunsDusk = settings.get("excludeSunsDusk"),
    })
end

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
    if not settings.get("trainingLimitEnabled") then
        return
    end
    if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
        checkTrainingLevelReset()
        if state.trainCount >= settings.get("trainingLimit") then
            ui.showMessage(L("trainLimitReached"))
            return false
        end
        state.trainCount = state.trainCount + 1
        if state.trainCount >= settings.get("trainingLimit") then
            blockTrainingWindow()
        end
    end
end)

settings.subscribe(function(key, newValue)
    if key == "trainingLimitEnabled" then
        if not newValue then
            unblockTrainingWindow()
        elseif state.trainCount >= settings.get("trainingLimit") then
            blockTrainingWindow()
        end
    elseif key == "trainingLimit" then
        if settings.get("trainingLimitEnabled") then
            if state.trainCount >= newValue then
                blockTrainingWindow()
            else
                unblockTrainingWindow()
            end
        end
    elseif key == "potionLimitEnabled" or key == "statLimitEnabled" or key == "excludeSunsDusk" then
        sendSettingsToGlobal()
    elseif key == "potionTrackingMode" then
        if newValue ~= state.potionTrackingMode then
            local wasKnockedOut = state.knockedOut
            state.potionTrackingMode = newValue
            if newValue == "slots" then
                initSlots()
                state.drinkCount = 0
                state.timer = 0
                state.drinkHour = 0
                state.drinkOverdose = false
                state.knockedOut = false
                state.overdoseCollapse = false
            elseif newValue == "counter" then
                state.slots = {}
                state.drinkCount = 0
                state.timer = 0
                state.drinkHour = 0
                state.drinkOverdose = false
                state.knockedOut = false
                state.overdoseCollapse = false
            end

            -- Restore fatigue if player was knocked out
            if wasKnockedOut then
                local attrs = types.Actor.stats.attributes
                local baseMax = attrs.strength(self).modified
                    + attrs.willpower(self).modified
                    + attrs.agility(self).modified
                    + attrs.endurance(self).modified
                types.Actor.stats.dynamic.fatigue(self).base = baseMax
                types.Actor.stats.dynamic.fatigue(self).current = 0
            end
            state.knownPotionSpellIds = {}
            state.potionSpellIdsInitialized = false

            -- Reset all lastSent values to force fresh writes
            lastSent.drinkCount = nil
            lastSent.countdown = nil
            lastSent.potionLimit = nil
            lastSent.globalKnockedOut = nil
            lastSent.globalOverdose = nil
            lastSent.slotTrackingMode = nil
            lastSent.slotCount = nil
            lastSent.occupiedSlots = nil
            lastSent.overflowOccupied = nil
            lastSent.slotKnockedOut = nil
            lastSent.slotAllFull = nil
            for i = 1, 11 do
                lastSent["slot" .. i .. "Countdown"] = nil
                lastSent["slot" .. i .. "Icon"] = nil
            end

            -- Clear storage for the mode we're leaving
            local section = storage.playerSection("sptLimitsState")
            section:set("trackingMode", newValue)
            if newValue == "counter" then
                -- Leaving slots mode: zero out all slot storage keys
                for i = 1, 11 do
                    section:set("slot" .. i .. "Countdown", 0)
                    section:set("slot" .. i .. "Icon", "")
                end
                section:set("occupiedSlots", 0)
                section:set("overflowOccupied", false)
                section:set("slotCount", 0)
            else
                -- Leaving counter mode: zero out counter storage keys
                section:set("drinkCount", 0)
                section:set("countdown", 0)
            end

            -- Send clean initial state event for the new mode
            if newValue == "slots" then
                core.sendGlobalEvent("sptLimitsStateUpdate", {
                    knockedOut = false,
                    allNormalSlotsFull = false,
                    potionTrackingMode = "slots",
                })
            else
                core.sendGlobalEvent("sptLimitsStateUpdate", {
                    knockedOut = state.knockedOut,
                    drinkOverdose = false,
                    potionTrackingMode = "counter",
                })
            end
        end
    end
end)

return {
    engineHandlers = {
        onInit = function()
            settings.registerPage()
            settings.syncToStorage()
            initState()
            sendSettingsToGlobal()
            local section = storage.playerSection("sptLimitsState")
            section:set("trackingMode", state.potionTrackingMode)
            if state.potionTrackingMode == "counter" then
                section:set("drinkCount", 0)
                section:set("countdown", 0)
                section:set("potionLimit", settings.get("potionLimit"))
                -- Clear stale slot data
                for i = 1, 11 do
                    section:set("slot" .. i .. "Countdown", 0)
                    section:set("slot" .. i .. "Icon", "")
                end
                section:set("occupiedSlots", 0)
                section:set("overflowOccupied", false)
                section:set("slotCount", 0)
            end
        end,
        onLoad = function(data)
            settings.registerPage()
            if data and data.settings then
                -- Save includes persisted settings — restore them
                settings.loadAll(data.settings)
            else
                -- No data (save predates the mod) or no settings key (older
                -- mod version). Reset to defaults to prevent session bleed.
                settings.syncToStorage()
            end
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
            state.drinkOverdose = (state.drinkCount >= settings.get("potionLimit"))

            if settings.get("trainingLimitEnabled") and state.trainCount >= settings.get("trainingLimit") then
                blockTrainingWindow()
            end

            -- Restore slot data if mode is "slots" and save has slot data
            if state.potionTrackingMode == "slots" and data and data.slots then
                local slotCount = settings.get("potionSlotCount")
                local targetSize = slotCount + 1

                if type(data.slots) ~= "table" then
                    -- Corrupted: not a table → fresh start
                    initSlots()
                else
                    state.slots = {}
                    -- Restore entries from save data
                    local sourceLen = #data.slots
                    local restoreCount = math.min(sourceLen, targetSize)
                    for i = 1, restoreCount do
                        local entry = data.slots[i]
                        if type(entry) ~= "table" then
                            -- Malformed entry → treat as empty
                            state.slots[i] = { activeSpellId = nil, countdown = 0, icon = nil }
                        else
                            local activeSpellId = entry.activeSpellId
                            local countdown = entry.countdown
                            local icon = entry.icon

                            -- Validate activeSpellId: must be a string or nil
                            if activeSpellId ~= nil and type(activeSpellId) ~= "string" then
                                activeSpellId = nil
                            end

                            -- Validate countdown: must be a number, clamp negatives to 0
                            if type(countdown) ~= "number" then
                                countdown = 0
                            elseif countdown < 0 then
                                countdown = 0
                            end

                            -- Validate icon: must be a string or nil
                            if icon ~= nil and type(icon) ~= "string" then
                                icon = nil
                            end

                            state.slots[i] = { activeSpellId = activeSpellId, countdown = countdown, icon = icon }
                        end
                    end
                    -- Pad if too short
                    for i = restoreCount + 1, targetSize do
                        state.slots[i] = { activeSpellId = nil, countdown = 0, icon = nil }
                    end
                    -- Truncate handled by restoreCount = min(sourceLen, targetSize)

                    -- Validate activeSpellIds against current active spells
                    local activeSpells = types.Actor.activeSpells(self)
                    local activeSpellIdSet = {}
                    for _, spell in pairs(activeSpells) do
                        activeSpellIdSet[spell.activeSpellId] = true
                    end

                    for i = 1, targetSize do
                        local slot = state.slots[i]
                        if slot.activeSpellId ~= nil then
                            if not activeSpellIdSet[slot.activeSpellId] then
                                slot.activeSpellId = nil
                                slot.countdown = 0
                            end
                        end
                    end

                    -- Handle overflow slot state for knockedOut
                    local overflow = state.slots[targetSize]
                    if overflow and overflow.activeSpellId ~= nil then
                        state.knockedOut = true
                    else
                        -- Overflow spell is gone or empty → not knocked out from overflow
                        if data.knockedOut and not state.overdoseCollapse then
                            state.knockedOut = false
                        end
                    end
                end
            elseif state.potionTrackingMode == "slots" then
                -- No slot data in save (counter mode save or nil) → fresh slots
                initSlots()
            end

            state.knownPotionSpellIds = {}
            local activeSpells = types.Actor.activeSpells(self)
            local excludeSunsDusk = settings.get("excludeSunsDusk")
            for _, spell in pairs(activeSpells) do
                local rok, rec = pcall(types.Potion.record, spell.id)
                if rok and rec then
                    if not isPotionExcluded(spell.id, excludeSunsDusk) then
                        state.knownPotionSpellIds[spell.activeSpellId] = true
                    elseif not excludedPotions[spell.id] then
                        excludedPotions[spell.id] = true
                        core.sendGlobalEvent("sptLimitsExcludePotion", { recordId = spell.id })
                    end
                end
            end
            state.potionSpellIdsInitialized = true
            sendSettingsToGlobal()

            -- Write tracking mode and clear stale storage from the inactive mode
            local section = storage.playerSection("sptLimitsState")
            section:set("trackingMode", state.potionTrackingMode)
            if state.potionTrackingMode == "counter" then
                for i = 1, 11 do
                    section:set("slot" .. i .. "Countdown", 0)
                    section:set("slot" .. i .. "Icon", "")
                end
                section:set("occupiedSlots", 0)
                section:set("overflowOccupied", false)
                section:set("slotCount", 0)
            end
        end,
        onSave = function()
            if state.potionTrackingMode == "slots" then
                local slotCount = settings.get("potionSlotCount")
                local slotsData = {}
                for i = 1, slotCount + 1 do
                    local slot = state.slots[i]
                    if slot then
                        slotsData[i] = { activeSpellId = slot.activeSpellId, countdown = slot.countdown, icon = slot.icon }
                    else
                        slotsData[i] = { activeSpellId = nil, countdown = 0, icon = nil }
                    end
                end
                return {
                    knockedOut = state.knockedOut,
                    overdoseCollapse = state.overdoseCollapse,
                    trainCount = state.trainCount,
                    trainLevel = state.trainLevel,
                    settings = settings.saveAll(),
                    slots = slotsData,
                }
            else
                return {
                    knockedOut = state.knockedOut,
                    drinkCount = state.drinkCount,
                    timer = state.timer,
                    drinkHour = state.drinkHour,
                    overdoseCollapse = state.overdoseCollapse,
                    trainCount = state.trainCount,
                    trainLevel = state.trainLevel,
                    settings = settings.saveAll(),
                }
            end
        end,
        onUpdate = function(dt)
            if not types.Player.isCharGenFinished(self) then
                return
            end

            if not settings.get("statLimitEnabled") and not settings.get("potionLimitEnabled") then
                return
            end

            local limitAttribute = false
            local limitSkill = false

            if settings.get("statLimitEnabled") then
                limitAttribute = checkAttributes(settings.get("attributeCap"))
                if limitAttribute and not state.knockedOut then
                    ui.showMessage(L("attributeLimit"))
                end

                limitSkill = checkSkills(settings.get("skillCap"))
                if limitSkill and not state.knockedOut then
                    ui.showMessage(L("skillLimit"))
                end
            end

            if settings.get("potionLimitEnabled") and state.potionTrackingMode == "counter" then
                local currentIds = {}
                local activeSpells = types.Actor.activeSpells(self)
                local excludeSunsDusk = settings.get("excludeSunsDusk")
                for _, spell in pairs(activeSpells) do
                    local rok, rec = pcall(types.Potion.record, spell.id)
                    if rok and rec then
                        if not isPotionExcluded(spell.id, excludeSunsDusk) then
                            currentIds[spell.activeSpellId] = true
                        elseif not excludedPotions[spell.id] then
                            -- Potion excluded by Sun's Dusk interface check; sync to global
                            excludedPotions[spell.id] = true
                            core.sendGlobalEvent("sptLimitsExcludePotion", { recordId = spell.id })
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
                state.drinkOverdose = (state.drinkCount >= settings.get("potionLimit"))
            end

            if settings.get("potionLimitEnabled") and state.potionTrackingMode == "slots" then
                local currentPotionSpellIds = {}
                local activeSpells = types.Actor.activeSpells(self)
                local excludeSunsDusk = settings.get("excludeSunsDusk")
                for _, spell in pairs(activeSpells) do
                    local rok, rec = pcall(types.Potion.record, spell.id)
                    if rok and rec then
                        currentPotionSpellIds[spell.activeSpellId] = spell
                    end
                end

                if not state.potionSpellIdsInitialized then
                    -- First frame: populate knownPotionSpellIds without treating as new drinks
                    for activeSpellId, _ in pairs(currentPotionSpellIds) do
                        state.knownPotionSpellIds[activeSpellId] = true
                    end
                    state.potionSpellIdsInitialized = true
                else
                    -- Detect new drinks
                    for activeSpellId, spell in pairs(currentPotionSpellIds) do
                        if not state.knownPotionSpellIds[activeSpellId] then
                            -- Check if excluded
                            if isPotionExcluded(spell.id, excludeSunsDusk) then
                                -- Excluded potion: track but don't assign to slot
                                state.knownPotionSpellIds[activeSpellId] = true
                                if not excludedPotions[spell.id] then
                                    excludedPotions[spell.id] = true
                                    core.sendGlobalEvent("sptLimitsExcludePotion", { recordId = spell.id })
                                end
                            else
                                -- Non-excluded: compute longestDuration and assign
                                local longestDuration = 0
                                local icon = nil
                                if spell.effects then
                                    for _, effect in pairs(spell.effects) do
                                        if effect.duration and effect.duration > longestDuration then
                                            longestDuration = effect.duration
                                            if effect.id then
                                                local mgef = core.magic.effects.records[effect.id]
                                                if mgef and mgef.icon then
                                                    icon = mgef.icon
                                                end
                                            end
                                        end
                                    end
                                    -- If all effects are instant (longestDuration=0), use first effect's icon
                                    if icon == nil then
                                        for _, effect in pairs(spell.effects) do
                                            if effect.id then
                                                local mgef = core.magic.effects.records[effect.id]
                                                if mgef and mgef.icon then
                                                    icon = mgef.icon
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                                -- Try normal slot first
                                if not assignDrinkToSlot(activeSpellId, longestDuration, icon) then
                                    -- All normal slots full — try overflow
                                    if not isOverflowOccupied() then
                                        assignDrinkToOverflow(activeSpellId, longestDuration, icon)
                                    end
                                    -- Else: all slots occupied, ignore drink
                                end
                                state.knownPotionSpellIds[activeSpellId] = true
                            end
                        end
                    end

                    -- Prune knownPotionSpellIds: remove IDs no longer active
                    for id, _ in pairs(state.knownPotionSpellIds) do
                        if not currentPotionSpellIds[id] then
                            state.knownPotionSpellIds[id] = nil
                        end
                    end
                end

                -- Tick slot countdowns
                tickSlots(dt)

                -- Validate slots against active spells (clear expired)
                local activeSpellIdSet = {}
                for activeSpellId, _ in pairs(currentPotionSpellIds) do
                    activeSpellIdSet[activeSpellId] = true
                end
                validateSlots(activeSpellIdSet)

                -- Maintain overdose state
                if state.knockedOut and isOverflowOccupied() then
                    types.Actor.stats.dynamic.fatigue(self).base = 0
                    types.Actor.stats.dynamic.fatigue(self).current = 0
                end

                -- Write storage and send state event
                writeSlotStorage()
                sendSlotStateEvent()
            end

            handleKnockoutRecovery(limitAttribute, limitSkill)

            if settings.get("potionLimitEnabled") and state.potionTrackingMode == "counter" then
                local countdown = state.drinkCount > 0 and math.max(0, settings.get("potionCooldown") - state.timer)
                    or 0
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
                local currentPotionLimit = settings.get("potionLimit")
                if lastSent.potionLimit ~= currentPotionLimit then
                    section:set("potionLimit", currentPotionLimit)
                    lastSent.potionLimit = currentPotionLimit
                end
            end

            if state.potionTrackingMode == "counter" then
                if lastSent.globalKnockedOut ~= state.knockedOut or lastSent.globalOverdose ~= state.drinkOverdose then
                    core.sendGlobalEvent("sptLimitsStateUpdate", {
                        knockedOut = state.knockedOut,
                        drinkOverdose = state.drinkOverdose,
                        potionTrackingMode = "counter",
                    })
                    lastSent.globalKnockedOut = state.knockedOut
                    lastSent.globalOverdose = state.drinkOverdose
                end
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
            if not settings.get("trainingLimitEnabled") then
                return
            end
            checkTrainingLevelReset()
            if state.trainCount >= settings.get("trainingLimit") and data.newMode == "Training" then
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
