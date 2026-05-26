local core = require('openmw.core')
local interfaces = require('openmw.interfaces')
local types = require('openmw.types')
local world = require('openmw.world')

local L = core.l10n('spt_limits')

-- Local cache of player state, updated via events from the player script
local playerState = {
    active = false,
    drinkOverdose = false,
}

-- Potion handler: skip non-players, block if knockout or overdose, otherwise allow
interfaces.ItemUsage.addHandlerForType(types.Potion, function(potion, player)
    if not types.Player.objectIsInstance(player) then
        return nil -- allow NPCs to drink freely
    end

    if playerState.active then
        if playerState.drinkOverdose then
            player:sendEvent('spt_limits_show_message', { text = L("cantDrinkNow") })
            return false
        end
        -- Collapsed from stat limit, but potions still allowed
        return nil
    end

    if playerState.drinkOverdose then
        player:sendEvent('spt_limits_show_message', { text = L("cantDrinkMore") })
        return false
    end

    -- Potion allowed: player script detects consumption via active spell count tracking
    return nil
end)

-- Apparatus handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Apparatus, function(apparatus, player)
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.active then
        player:sendEvent('spt_limits_show_message', { text = L("cantUseNow") })
        return false
    end

    return nil
end)

-- Repair handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Repair, function(repair, player)
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.active then
        player:sendEvent('spt_limits_show_message', { text = L("cantUseNow") })
        return false
    end

    return nil
end)

-- Miscellaneous handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Miscellaneous, function(miscellaneous, player)
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.active then
        player:sendEvent('spt_limits_show_message', { text = L("cantUseNow") })
        return false
    end

    return nil
end)

return {
    eventHandlers = {
        spt_limits_state_update = function(data)
            if data then
                playerState.active = data.active or false
                playerState.drinkOverdose = data.drinkOverdose or false
            end
        end,
    },
}
