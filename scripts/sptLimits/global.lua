local core = require("openmw.core")
local interfaces = require("openmw.interfaces")
local types = require("openmw.types")

local config = require("scripts.sptLimits.config")
local exclusions = require("scripts.sptLimits.exclusions")
local L = core.l10n("sptLimits")

local excludedPotions = exclusions.excludedPotions
local isPotionExcluded = exclusions.isPotionExcluded

local playerState = {
    knockedOut = false,
    drinkOverdose = false,
}

interfaces.ItemUsage.addHandlerForType(types.Potion, function(potion, player)
    if not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    local potionRecord = types.Potion.record(potion)
    if potionRecord and isPotionExcluded(potionRecord.id) then
        return nil
    end

    if playerState.knockedOut then
        if playerState.drinkOverdose then
            player:sendEvent("sptLimitsShowMessage", { text = L("cantDrinkNow") })
            return false
        end
        return nil
    end

    if playerState.drinkOverdose then
        player:sendEvent("sptLimitsShowMessage", { text = L("cantDrinkMore") })
        return false
    end

    return nil
end)

interfaces.ItemUsage.addHandlerForType(types.Apparatus, function(apparatus, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("sptLimitsShowMessage", { text = L("cantUseNow") })
        return false
    end

    return nil
end)

interfaces.ItemUsage.addHandlerForType(types.Repair, function(repair, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("sptLimitsShowMessage", { text = L("cantUseNow") })
        return false
    end

    return nil
end)

interfaces.ItemUsage.addHandlerForType(types.Miscellaneous, function(miscellaneous, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("sptLimitsShowMessage", { text = L("cantUseNow") })
        return false
    end

    return nil
end)

return {
    eventHandlers = {
        sptLimitsStateUpdate = function(data)
            if data then
                playerState.knockedOut = data.knockedOut or false
                playerState.drinkOverdose = data.drinkOverdose or false
            end
        end,
        sptLimitsExcludePotion = function(data)
            if data and data.recordId then
                excludedPotions[data.recordId] = true
            end
        end,
        sptLimitsIncludePotion = function(data)
            if data and data.recordId then
                excludedPotions[data.recordId] = nil
            end
        end,
    },
}
