local async = require("openmw.async")
local interfaces = require('openmw.interfaces')
local storage = require("openmw.storage")
local world = require('openmw.world')

local l10nKey = 'raffll_limits'
local settingsPageKey = 'SPL'

interfaces.Settings.registerGroup({
	key = 'raffll_limits',
	page = settingsPageKey,
	l10n = l10nKey,
	name = 'Main',
	order = 0,
	permanentStorage = true,
	settings = {
		{
			key = 'potionsOnly',
			renderer = 'checkbox',
			name = 'Potions-Only Limit',
			description = 'Disables attribute and skill limits. Only the potion limit remains active.',
			default = false
		},
		{
			key = 'progressivePotions',
			renderer = 'checkbox',
			name = 'Progressive Potion Limit',
			description = 'Potion limit scales with level: starts at 3, gains +1 every 10 levels, up to 8 at level 50.',
			default = false
		},
		{
			key = 'progressiveStats',
			renderer = 'checkbox',
			name = 'Progressive Stats Limit',
			description = 'Attribute and skill caps scale with level. Attributes: 100 + (level × 5), capped at 300. Skills: 100 + level, capped at 150. When disabled, caps are fixed at 300/150.',
			default = false
		},
	},
})

interfaces.Settings.registerGroup({
	key = 'raffll_limits_training',
	page = settingsPageKey,
	l10n = l10nKey,
	name = 'Training',
	order = 1,
	permanentStorage = true,
	settings = {
		{
			key = 'trainingLimit',
			renderer = 'checkbox',
			name = "Training Limit",
			description = "When enabled, training sessions are limited to 5 per level. Trainers will refuse to teach you until you level up.",
			default = true
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

local function setTrainingLimit(arg)
	sendSettingToPlayers('trainingLimit', arg)
end

local globalStorage = storage.globalSection('raffll_limits')
local trainingStorage = storage.globalSection('raffll_limits_training')

-- Send initial setting values on script load
local potionsOnly = globalStorage:get('potionsOnly')
local progressivePotions = globalStorage:get('progressivePotions')
local progressiveStats = globalStorage:get('progressiveStats')
local trainingLimit = trainingStorage:get('trainingLimit')

setPotionsOnly(potionsOnly)
setProgressivePotions(progressivePotions)
setProgressiveStats(progressiveStats)
setTrainingLimit(trainingLimit)

-- Subscribe to setting changes and send events to players
local function updateMainOption(_, key)
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
globalStorage:subscribe(async:callback(updateMainOption))

local function updateTrainingOption(_, key)
	if key == 'trainingLimit' then
		trainingLimit = trainingStorage:get('trainingLimit')
		setTrainingLimit(trainingLimit)
	end
end
trainingStorage:subscribe(async:callback(updateTrainingOption))

local initialSettingsSent = false

return {
	interfaceName = 'raffll_limits',
	interface = {
		version = 3,
		setPotionsOnly = setPotionsOnly,
		setProgressivePotions = setProgressivePotions,
		setProgressiveStats = setProgressiveStats,
		setTrainingLimit = setTrainingLimit
	},
	engineHandlers = {
		onPlayerAdded = function(player)
			-- Send current settings to the player when they enter the world
			player:sendEvent('raffll_limits_settingChanged', { key = 'potionsOnly', value = globalStorage:get('potionsOnly') or false })
			player:sendEvent('raffll_limits_settingChanged', { key = 'progressivePotions', value = globalStorage:get('progressivePotions') or false })
			player:sendEvent('raffll_limits_settingChanged', { key = 'progressiveStats', value = globalStorage:get('progressiveStats') or false })
			player:sendEvent('raffll_limits_settingChanged', { key = 'trainingLimit', value = trainingStorage:get('trainingLimit') ~= false })
			initialSettingsSent = true
		end,
		onUpdate = function()
			-- Fallback: if onPlayerAdded didn't fire (e.g. load game), send on first update
			if not initialSettingsSent and #world.players > 0 then
				local player = world.players[1]
				player:sendEvent('raffll_limits_settingChanged', { key = 'potionsOnly', value = globalStorage:get('potionsOnly') or false })
				player:sendEvent('raffll_limits_settingChanged', { key = 'progressivePotions', value = globalStorage:get('progressivePotions') or false })
				player:sendEvent('raffll_limits_settingChanged', { key = 'progressiveStats', value = globalStorage:get('progressiveStats') or false })
				player:sendEvent('raffll_limits_settingChanged', { key = 'trainingLimit', value = trainingStorage:get('trainingLimit') ~= false })
				initialSettingsSent = true
			end
		end,
	},
}
