local self = require("openmw.self")
local types = require("openmw.types")
local interfaces = require("openmw.interfaces")
local ui = require("openmw.ui")
local core = require("openmw.core")
local util = require("openmw.util")
local async = require("openmw.async")

local settings = require("scripts.sptLimits.player.settings")
local L = core.l10n("sptLimits")

local state = {
    trainCount = 0,
    trainLevel = 0,
}

local windowState = {
    element = nil,
    trainer = nil,
    blocked = false,
    advancing = false,
    advanceTimer = 0,
    fadePhase = "none",
    skillOptions = {},
}

local allSkillIds = {
    "block", "armorer", "mediumarmor", "heavyarmor", "bluntweapon",
    "longblade", "axe", "spear", "athletics", "enchant",
    "destruction", "alteration", "illusion", "conjuration", "mysticism",
    "restoration", "alchemy", "unarmored", "security", "sneak",
    "acrobatics", "lightarmor", "shortblade", "marksman", "mercantile",
    "speechcraft", "handtohand",
}

local function getTrainerSkills(trainer)
    local useBase = core.getGMST("mTrainersTrainingSkillsBasedOnBaseSkill")
    local candidates = {}
    for i, skillId in ipairs(allSkillIds) do
        local stat = types.NPC.stats.skills[skillId](trainer)
        local value = useBase and stat.base or stat.modified
        if value > 0 then
            candidates[#candidates + 1] = { skillId = skillId, trainerValue = value, index = i }
        end
    end
    table.sort(candidates, function(a, b)
        if a.trainerValue ~= b.trainerValue then
            return a.trainerValue > b.trainerValue
        end
        return a.index < b.index
    end)
    local result = {}
    for i = 1, math.min(3, #candidates) do
        result[i] = { skillId = candidates[i].skillId, trainerValue = candidates[i].trainerValue }
    end
    return result
end

local function getBarterOffer(rawPrice, trainer)
    local playerMerc = types.NPC.stats.skills.mercantile(self).modified
    local playerPers = types.Actor.stats.attributes.personality(self).modified
    local playerLuck = types.Actor.stats.attributes.luck(self).modified

    local trainerMerc = types.NPC.stats.skills.mercantile(trainer).modified
    local trainerPers = types.Actor.stats.attributes.personality(trainer).modified
    local trainerLuck = types.Actor.stats.attributes.luck(trainer).modified

    local playerFatBase = types.Actor.stats.dynamic.fatigue(self).base
    local playerFatCur = types.Actor.stats.dynamic.fatigue(self).current
    local trainerFatBase = types.Actor.stats.dynamic.fatigue(trainer).base
    local trainerFatCur = types.Actor.stats.dynamic.fatigue(trainer).current

    local pcFatigueTerm = 1
    if playerFatBase > 0 then
        pcFatigueTerm = math.max(0, playerFatCur) / playerFatBase
    end
    local npcFatigueTerm = 1
    if trainerFatBase > 0 then
        npcFatigueTerm = math.max(0, trainerFatCur) / trainerFatBase
    end

    local pcTerm = (playerMerc + 0.1 * playerPers + 0.2 * playerLuck) * pcFatigueTerm
    local npcTerm = (trainerMerc + 0.1 * trainerPers + 0.2 * trainerLuck) * npcFatigueTerm

    local buyTerm = 0.01 * (100 - 0.5 * (pcTerm - npcTerm))
    buyTerm = math.max(0, math.min(1, buyTerm))

    local finalPrice = math.floor(rawPrice * buyTerm)
    return math.max(1, finalPrice)
end

local function getRawPrice(skillId)
    local playerBaseSkill = types.NPC.stats.skills[skillId](self).base
    local iTrainingMod = core.getGMST("iTrainingMod") or 10
    return math.max(1, playerBaseSkill * iTrainingMod)
end

local function checkTrainingLevelReset()
    local level = types.Actor.stats.level(self).current
    if state.trainLevel ~= level then
        state.trainCount = 0
        state.trainLevel = level
        windowState.blocked = false
    end
end

local function validateTraining(skillOption)
    local playerGold = types.Actor.inventory(self):countOf("gold_001")
    if playerGold < skillOption.price then
        return "gold"
    end
    local playerBaseSkill = types.NPC.stats.skills[skillOption.skillId](self).base
    if skillOption.trainerValue <= playerBaseSkill then
        return "trainerSkill"
    end
    local attributeId = core.stats.Skill.record(skillOption.skillId).attribute
    local attributeModified = types.Actor.stats.attributes[attributeId](self).modified
    if playerBaseSkill >= attributeModified then
        return "attribute"
    end
    return nil
end

local function hideFn()
    if windowState.element then
        windowState.element:destroy()
        windowState.element = nil
    end
    if windowState.advancing then
        windowState.advancing = false
        windowState.fadePhase = "none"
        windowState.advanceTimer = 0
        interfaces.UI.removeMode("Training")
    end
end

local function executeTrain(skillOption)
    local result = interfaces.SkillProgression.skillLevelUp(
        skillOption.skillId,
        interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer
    )
    if result == false then
        return
    end

    local goldItem = types.Actor.inventory(self):find("gold_001")
    if goldItem then
        goldItem:remove(skillOption.price)
    end
    types.Actor.setBarterGold(
        windowState.trainer,
        types.Actor.getBarterGold(windowState.trainer) + skillOption.price
    )

    hideFn()
    windowState.advancing = true
    windowState.advanceTimer = 0
    windowState.fadePhase = "fadeOut"
end

local function onSkillClick(index)
    local skillOption = windowState.skillOptions[index]
    local result = validateTraining(skillOption)
    if result == "gold" then
        return
    elseif result == "trainerSkill" then
        ui.showMessage(core.getGMST("sServiceTrainingWords"))
        return
    elseif result == "attribute" then
        ui.showMessage(core.getGMST("sNotifyMessage17"))
        return
    end
    executeTrain(skillOption)
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
            windowState.blocked = true
        end
    end
end)

local I = interfaces

local function buildWindow()
    local playerGold = types.Actor.inventory(self):countOf("gold_001")
    local goldText = core.getGMST("sGold") .. ": " .. playerGold
    local trainerSkills = getTrainerSkills(windowState.trainer)

    windowState.skillOptions = {}
    local skillRows = {}
    for i, skill in ipairs(trainerSkills) do
        local rawPrice = getRawPrice(skill.skillId)
        local price = getBarterOffer(rawPrice, windowState.trainer)
        local skillName = core.stats.Skill.record(skill.skillId).name
        local text = skillName .. " - " .. price .. core.getGMST("sgp")
        local affordable = playerGold >= price

        windowState.skillOptions[i] = {
            skillId = skill.skillId,
            price = price,
            affordable = affordable,
            trainerValue = skill.trainerValue,
        }

        local textColor = affordable and util.color.rgb(0.8, 0.7, 0.5) or util.color.rgb(0.4, 0.4, 0.4)

        skillRows[i] = {
            type = ui.TYPE.Text,
            props = {
                text = text,
                textSize = 16,
                textColor = textColor,
            },
            events = {
                mouseClick = async:callback(function() onSkillClick(i) end),
            },
        }
    end

    local contentChildren = {
        {
            type = ui.TYPE.Text,
            props = {
                text = core.getGMST("sServiceTrainingTitle"),
                textSize = 18,
                textColor = util.color.rgb(1, 1, 1),
                textAlignH = ui.ALIGNMENT.Center,
            },
        },
        {
            type = ui.TYPE.Text,
            props = {
                text = core.getGMST("sTrainingServiceTitle"),
                textSize = 16,
                textColor = util.color.rgb(0.8, 0.7, 0.5),
            },
        },
        {
            type = ui.TYPE.Widget,
            props = {
                size = util.vector2(0, 8),
            },
        },
        {
            type = ui.TYPE.Flex,
            content = ui.content(skillRows),
        },
        {
            type = ui.TYPE.Widget,
            props = {
                size = util.vector2(0, 8),
            },
        },
        {
            type = ui.TYPE.Text,
            props = {
                text = goldText,
                textSize = 16,
                textColor = util.color.rgb(0.8, 0.7, 0.5),
            },
        },
    }

    if settings.get("trainingLimitEnabled") then
        contentChildren[#contentChildren + 1] = {
            type = ui.TYPE.Text,
            props = {
                text = state.trainCount .. "/" .. settings.get("trainingLimit"),
                textSize = 16,
                textColor = util.color.rgb(0.8, 0.7, 0.5),
            },
        }
    end

    contentChildren[#contentChildren + 1] = {
        type = ui.TYPE.Widget,
        props = {
            size = util.vector2(0, 8),
        },
    }
    contentChildren[#contentChildren + 1] = {
        type = ui.TYPE.Text,
        props = {
            text = core.getGMST("sOK") or "OK",
            textSize = 16,
            textColor = util.color.rgb(0.8, 0.7, 0.5),
        },
        events = {
            mouseClick = async:callback(function()
                interfaces.UI.removeMode("Training")
            end),
        },
    }

    windowState.element = ui.create({
        layer = "Windows",
        props = {
            size = util.vector2(320, 220),
            anchor = util.vector2(0.5, 0.5),
            relativePosition = util.vector2(0.5, 0.5),
        },
        content = ui.content({
            {
                type = ui.TYPE.Image,
                props = {
                    resource = ui.texture({ path = "black" }),
                    relativeSize = util.vector2(1, 1),
                    alpha = 0.85,
                },
            },
            {
                template = I.MWUI.templates.bordersThick,
                props = {
                    relativeSize = util.vector2(1, 1),
                },
            },
            {
                type = ui.TYPE.Flex,
                props = {
                    position = util.vector2(12, 8),
                    size = util.vector2(296, 0),
                },
                content = ui.content(contentChildren),
            },
        }),
    })
end

local function showFn(actor)
    if not actor then
        interfaces.UI.removeMode("Training")
        return
    end
    if windowState.advancing then
        return
    end
    if windowState.blocked then
        ui.showMessage(L("trainLimitReached"))
        interfaces.UI.removeMode("Training")
        return
    end
    windowState.trainer = actor
    buildWindow()
end

interfaces.UI.registerWindow("Training", showFn, hideFn)

local function onSettingChanged(key, newValue)
    if key == "trainingLimitEnabled" then
        if not newValue then
            windowState.blocked = false
        else
            windowState.blocked = state.trainCount >= settings.get("trainingLimit")
        end
    elseif key == "trainingLimit" then
        windowState.blocked = settings.get("trainingLimitEnabled") and state.trainCount >= newValue
    end
end

local function onLoad(data)
    if not data then
        return
    end
    state.trainCount = data.trainCount or 0
    state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
    windowState.blocked = settings.get("trainingLimitEnabled") and state.trainCount >= settings.get("trainingLimit")
end

local function onUpdate(dt)
    if not windowState.advancing then
        return
    end

    windowState.advanceTimer = windowState.advanceTimer + dt

    if windowState.fadePhase == "fadeOut" then
        if windowState.advanceTimer >= 0.2 then
            windowState.advanceTimer = 0
            windowState.fadePhase = "fadeDelay"
        end
    elseif windowState.fadePhase == "fadeDelay" then
        if windowState.advanceTimer >= 0.2 then
            windowState.advanceTimer = 0
            windowState.fadePhase = "fadeIn"
        end
    elseif windowState.fadePhase == "fadeIn" then
        if windowState.advanceTimer >= 0.2 then
            windowState.fadePhase = "rest"
        end
    elseif windowState.fadePhase == "rest" then
        core.sendGlobalEvent("Rest", { hours = 2, sleeping = false })
        windowState.fadePhase = "done"
    elseif windowState.fadePhase == "done" then
        windowState.advancing = false
        windowState.fadePhase = "none"
        windowState.advanceTimer = 0
        interfaces.UI.removeMode("Training")
        if windowState.blocked then
            ui.showMessage(L("trainLimitReached"))
        end
    end
end

return {
    state = state,
    onSettingChanged = onSettingChanged,
    onLoad = onLoad,
    onUpdate = onUpdate,
}
