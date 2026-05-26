local interfaces = require('openmw.interfaces')
local types = require('openmw.types')
local world = require('openmw.world')

-- Local cache of player state, updated via events from the player script
local playerState = {
    active = false,
    drinkOverdose = false,
}

-- Potion handler: skip non-players, block if knockout or overdose, otherwise allow and notify player
interfaces.ItemUsage.addHandlerForType(types.Potion, function(potion, player)
    if not types.Player.objectIsInstance(player) then
        return nil -- allow NPCs to drink freely
    end

    if playerState.active then
        player:sendEvent('raffll_limits_showMessage', { text = "You can't drink potions right now." })
        return false
    end

    if playerState.drinkOverdose then
        player:sendEvent('raffll_limits_showMessage', { text = "You can't drink any more potions." })
        return false
    end

    -- Potion allowed: drink sound will play, player script detects via ambient.isSoundPlaying
    return nil
end)

-- Apparatus handler: block if knockout active
interfaces.ItemUsage.addHandlerForType(types.Apparatus, function(apparatus, player)
    if not types.Player.objectIsInstance(player) then
        return nil
    end

    if playerState.active then
        player:sendEvent('raffll_limits_showMessage', { text = "You can't create potions right now." })
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
        player:sendEvent('raffll_limits_showMessage', { text = "You can't repair right now." })
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
        player:sendEvent('raffll_limits_showMessage', { text = "You can't use this right now." })
        return false
    end

    return nil
end)

return {
    eventHandlers = {
        raffll_limits_stateUpdate = function(data)
            if data then
                playerState.active = data.active or false
                playerState.drinkOverdose = data.drinkOverdose or false
            end
        end,
    },
}
