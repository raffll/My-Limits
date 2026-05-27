local core = require("openmw.core")
local interfaces = require("openmw.interfaces")
local types = require("openmw.types")
local world = require("openmw.world")

local config = require("scripts.spt_limits.config")
local L = core.l10n("spt_limits")

-- Local cache of player state, updated via events from the player script
local playerState = {
    knockedOut = false,
    drinkOverdose = false,
}

-- Potion handler: skip non-players, block if knockout or overdose, otherwise allow
interfaces.ItemUsage.addHandlerForType(types.Potion, function(potion, player)
    if not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        if playerState.drinkOverdose then
            player:sendEvent("spt_limits_show_message", { text = L("cant_drink_now") })
            return false
        end
        return nil
    end

    if playerState.drinkOverdose then
        player:sendEvent("spt_limits_show_message", { text = L("cant_drink_more") })
        return false
    end

    return nil
end)

-- Apparatus handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Apparatus, function(apparatus, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("spt_limits_show_message", { text = L("cant_use_now") })
        return false
    end

    return nil
end)

-- Repair handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Repair, function(repair, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("spt_limits_show_message", { text = L("cant_use_now") })
        return false
    end

    return nil
end)

-- Miscellaneous handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Miscellaneous, function(miscellaneous, player)
    if not config.statLimitEnabled and not config.potionLimitEnabled then
        return nil
    end
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.knockedOut then
        player:sendEvent("spt_limits_show_message", { text = L("cant_use_now") })
        return false
    end

    return nil
end)

return {
    eventHandlers = {
        spt_limits_state_update = function(data)
            if data then
                playerState.knockedOut = data.knocked_out or false
                playerState.drinkOverdose = data.drink_overdose or false
            end
        end,
    },
}
