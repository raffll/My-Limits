local async = require("openmw.async")
local interfaces = require('openmw.interfaces')
local storage = require("openmw.storage")
local world = require('openmw.world')

local l10nKey = 'raffll_limits'
local settingsPageKey = 'SPL'

interfaces.Settings.registerGroup({
	key = 'Main',
	page = settingsPageKey,
	l10n = l10nKey,
	name = 'Main',
	permanentStorage = true,
	settings = {
		{
			key = 'potionsOnly',
			renderer = 'checkbox',
			name = 'Potions-Only Limit',
			description = 'Disables attribute and skill limits; only potion limit apply.',
			default = false
		},
		{
			key = 'progressivePotions',
			renderer = 'checkbox',
			name = 'Progressive Potion Limit',
			description = 'Potion limit increases every 10 levels, from 3 to 8 by level 50.',
			default = false
		},
		{
			key = 'progressiveStats',
			renderer = 'checkbox',
			name = 'Progressive Stats Limit',
			description = 'Attributes: 100 + (level * 5), max 300.\nSkills: 100 + level, max 150.',
			default = false
		},
	},
})

local function sendSettingToPlayers(key, value)
	for _, player in ipairs(world.players) do
		player:sendEvent('raffll_limits_settingChanged', { key = key, value = value })
	end
end

local function setPotionsOnly(arg)
	sendSettingToPlayers('potionsOnly', arg)
end

local function setProgressivePotions(arg)
	sendSettingToPlayers('progressivePotions', arg)
end

local function setProgressiveStats(arg)
	sendSettingToPlayers('progressiveStats', arg)
end

local globalStorage = storage.globalSection('Main')

-- Send initial setting values on script load
local potionsOnly = globalStorage:get('potionsOnly')
local progressivePotions = globalStorage:get('progressivePotions')
local progressiveStats = globalStorage:get('progressiveStats')

setPotionsOnly(potionsOnly)
setProgressivePotions(progressivePotions)
setProgressiveStats(progressiveStats)

-- Subscribe to setting changes and send events to players
local function updateOption(_, key)
	if key == 'potionsOnly' then
		potionsOnly = globalStorage:get('potionsOnly')
		setPotionsOnly(potionsOnly)
	end

	if key == 'progressivePotions' then
		progressivePotions = globalStorage:get('progressivePotions')
		setProgressivePotions(progressivePotions)
	end

	if key == 'progressiveStats' then
		progressiveStats = globalStorage:get('progressiveStats')
		setProgressiveStats(progressiveStats)
	end
end
globalStorage:subscribe(async:callback(updateOption))

local initialSettingsSent = false

return {
	interfaceName = 'raffll_limits',
	interface = {
		version = 2,
		setPotionsOnly = setPotionsOnly,
		setProgressivePotions = setProgressivePotions,
		setProgressiveStats = setProgressiveStats
	},
	engineHandlers = {
		onPlayerAdded = function(player)
			-- Send current settings to the player when they enter the world
			player:sendEvent('raffll_limits_settingChanged', { key = 'potionsOnly', value = globalStorage:get('potionsOnly') or false })
			player:sendEvent('raffll_limits_settingChanged', { key = 'progressivePotions', value = globalStorage:get('progressivePotions') or false })
			player:sendEvent('raffll_limits_settingChanged', { key = 'progressiveStats', value = globalStorage:get('progressiveStats') or false })
			initialSettingsSent = true
		end,
		onUpdate = function()
			-- Fallback: if onPlayerAdded didn't fire (e.g. load game), send on first update
			if not initialSettingsSent and #world.players > 0 then
				local player = world.players[1]
				player:sendEvent('raffll_limits_settingChanged', { key = 'potionsOnly', value = globalStorage:get('potionsOnly') or false })
				player:sendEvent('raffll_limits_settingChanged', { key = 'progressivePotions', value = globalStorage:get('progressivePotions') or false })
				player:sendEvent('raffll_limits_settingChanged', { key = 'progressiveStats', value = globalStorage:get('progressiveStats') or false })
				initialSettingsSent = true
			end
		end,
	},
}
