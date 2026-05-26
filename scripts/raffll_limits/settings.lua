local async = require("openmw.async")
local interfaces = require('openmw.interfaces')
local storage = require("openmw.storage")
local world = require('openmw.world')

local l10nKey = 'raffll_limits'
local settingsPageKey = 'SPL'

interfaces.Settings.registerGroup({
	key = 'raffll_limits_main',
	page = settingsPageKey,
	l10n = l10nKey,
	name = 'Settings',
	order = 0,
	permanentStorage = true,
	settings = {
		{
			key = 'potionLimit',
			renderer = 'checkbox',
			name = 'Potion Limit',
			description = 'Limits how many potions you can drink in a short time.',
			default = true
		},
		{
			key = 'statLimit',
			renderer = 'checkbox',
			name = 'Stat Limit',
			description = 'Limits attributes and skills. Exceeding causes collapse.',
			default = true
		},
		{
			key = 'trainingLimit',
			renderer = 'checkbox',
			name = 'Training Limit',
			description = 'Limits training sessions per level. Trainers will refuse to teach you until you level up.',
			default = true
		},
	},
})

local function sendSettingToPlayers(key, value)
	for _, player in ipairs(world.players) do
		player:sendEvent('raffll_limits_settingChanged', { key = key, value = value })
	end
end

local mainStorage = storage.globalSection('raffll_limits_main')

local function sendAllSettings(player)
	player:sendEvent('raffll_limits_settingChanged', { key = 'potionLimit', value = mainStorage:get('potionLimit') ~= false })
	player:sendEvent('raffll_limits_settingChanged', { key = 'statLimit', value = mainStorage:get('statLimit') ~= false })
	player:sendEvent('raffll_limits_settingChanged', { key = 'trainingLimit', value = mainStorage:get('trainingLimit') ~= false })
end

mainStorage:subscribe(async:callback(function(_, key)
	sendSettingToPlayers(key, mainStorage:get(key))
end))

local initialSettingsSent = false

return {

	engineHandlers = {
		onPlayerAdded = function(player)
			sendAllSettings(player)
			initialSettingsSent = true
		end,
		onUpdate = function()
			if not initialSettingsSent and #world.players > 0 then
				sendAllSettings(world.players[1])
				initialSettingsSent = true
			end
		end,
	},
}
