local self = require("openmw.self")
local types = require("openmw.types")
local ui = require("openmw.ui")
local interfaces = require("openmw.interfaces")
local core = require("openmw.core")

local settings = require("scripts.sptLimits.player.settings")
local L = core.l10n("sptLimits")

local state = {
    trainCount = 0,
    trainLevel = 0,
    banked = 0,
}

local function getAllowance()
    local limit = settings.get("trainingLimit")
    if settings.get("trainingBankingEnabled") then
        return limit + state.banked
    end
    return limit
end

local function blockTrainingWindow()
    core.sendGlobalEvent("sptLimitsTrainBlock", { blocked = true })
end

local function unblockTrainingWindow()
    core.sendGlobalEvent("sptLimitsTrainBlock", { blocked = false })
end

local function checkTrainingLevelReset()
    local level = types.Actor.stats.level(self).current
    if state.trainLevel ~= level then
        if settings.get("trainingBankingEnabled") then
            state.banked = math.max(0, getAllowance() - state.trainCount)
        end
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
        if state.trainCount >= getAllowance() then
            ui.showMessage(L("trainLimitReached"))
            return false
        end
        state.trainCount = state.trainCount + 1
        if state.trainCount >= getAllowance() then
            blockTrainingWindow()
        end
    end
end)

local function onSettingChanged(key, newValue)
    if key == "trainingLimitEnabled" then
        if not newValue then
            unblockTrainingWindow()
        elseif state.trainCount >= getAllowance() then
            blockTrainingWindow()
        end
    elseif key == "trainingLimit" or key == "trainingBankingEnabled" then
        if settings.get("trainingLimitEnabled") then
            if state.trainCount >= getAllowance() then
                blockTrainingWindow()
            else
                unblockTrainingWindow()
            end
        end
    end
end

local function onLoad(data)
    if data then
        state.trainCount = data.trainCount or 0
        state.trainLevel = data.trainLevel or types.Actor.stats.level(self).current
        state.banked = data.trainBanked or 0
    else
        state.trainCount = 0
        state.trainLevel = 0
        state.banked = 0
    end
    if settings.get("trainingLimitEnabled") and state.trainCount >= getAllowance() then
        blockTrainingWindow()
    else
        unblockTrainingWindow()
    end
end

return {
    state = state,
    onSettingChanged = onSettingChanged,
    onLoad = onLoad,
    checkTrainingLevelReset = checkTrainingLevelReset,
}
