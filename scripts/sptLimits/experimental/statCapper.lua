local self = require("openmw.self")
local types = require("openmw.types")
local core = require("openmw.core")

local config = require("scripts.sptLimits.shared.config")

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

local activeDrainIds = {}
local activeDrainMagnitudes = {}

local attributeNames = {
    "strength",
    "intelligence",
    "willpower",
    "agility",
    "speed",
    "endurance",
    "personality",
    "luck",
}

local skillNames = {
    "alchemy",
    "longblade",
    "acrobatics",
    "bluntweapon",
    "enchant",
    "security",
    "axe",
    "conjuration",
    "sneak",
    "armorer",
    "alteration",
    "lightarmor",
    "mediumarmor",
    "destruction",
    "marksman",
    "heavyarmor",
    "mysticism",
    "shortblade",
    "spear",
    "restoration",
    "handtohand",
    "block",
    "illusion",
    "mercantile",
    "athletics",
    "unarmored",
    "speechcraft",
}

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

local function clampStats(attributeCap, skillCap)
    local attrs = types.Actor.stats.attributes
    local drains = {}

    for _, name in ipairs(attributeNames) do
        local key = "attr:" .. name
        if not shouldSkipAttribute(name) then
            local modified = attrs[name](self).modified
            local currentDrain = activeDrainMagnitudes[key] or 0
            local natural = modified + currentDrain
            local needed = 0
            if natural > attributeCap then
                needed = natural - attributeCap
            end
            if needed ~= currentDrain then
                drains[#drains + 1] = { type = "attribute", name = name, magnitude = needed, prevId = activeDrainIds[key] }
                activeDrainMagnitudes[key] = needed
                if needed == 0 then
                    activeDrainIds[key] = nil
                end
            end
        else
            local currentDrain = activeDrainMagnitudes[key] or 0
            if currentDrain > 0 then
                drains[#drains + 1] = { type = "attribute", name = name, magnitude = 0, prevId = activeDrainIds[key] }
                activeDrainMagnitudes[key] = 0
                activeDrainIds[key] = nil
            end
        end
    end

    local skills = types.NPC.stats.skills
    for _, name in ipairs(skillNames) do
        local key = "skill:" .. name
        if not shouldSkipSkill(name) then
            local modified = skills[name](self).modified
            local currentDrain = activeDrainMagnitudes[key] or 0
            local natural = modified + currentDrain
            local needed = 0
            if natural > skillCap then
                needed = natural - skillCap
            end
            if needed ~= currentDrain then
                drains[#drains + 1] = { type = "skill", name = name, magnitude = needed, prevId = activeDrainIds[key] }
                activeDrainMagnitudes[key] = needed
                if needed == 0 then
                    activeDrainIds[key] = nil
                end
            end
        else
            local currentDrain = activeDrainMagnitudes[key] or 0
            if currentDrain > 0 then
                drains[#drains + 1] = { type = "skill", name = name, magnitude = 0, prevId = activeDrainIds[key] }
                activeDrainMagnitudes[key] = 0
                activeDrainIds[key] = nil
            end
        end
    end

    if #drains > 0 then
        core.sendGlobalEvent("sptLimitsApplyDrains", { drains = drains })
    end
end

local function onDrainApplied(data)
    if data then
        for _, entry in ipairs(data) do
            local key = entry.type .. ":" .. entry.name
            activeDrainIds[key] = entry.activeSpellId
        end
    end
end

local function removeAllDrains()
    local removals = {}
    for key, id in pairs(activeDrainIds) do
        removals[#removals + 1] = id
    end
    if #removals > 0 then
        core.sendGlobalEvent("sptLimitsRemoveAllDrains", { ids = removals })
    end
    activeDrainIds = {}
    activeDrainMagnitudes = {}
end

local function resetTracking()
    activeDrainIds = {}
    activeDrainMagnitudes = {}
end

return {
    clampStats = clampStats,
    onDrainApplied = onDrainApplied,
    removeAllDrains = removeAllDrains,
    resetTracking = resetTracking,
    skippedAttributes = skippedAttributes,
    skippedSkills = skippedSkills,
}
