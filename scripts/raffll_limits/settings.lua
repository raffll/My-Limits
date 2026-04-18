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
			key = 'potionsByAlchemy',
			renderer = 'checkbox',
			name = 'Progressive Potion Limit',
			description = 'Potion limit increase with level.',
			default = false
		},
		{
			key = 'progressiveLimit',
			renderer = 'checkbox',
			name = 'Progressive Stats Limit',
			description = 'Attribute and skill limits depend on level.',
			default = false
		},
	},
})

local function setPotionsOnly(arg)
	if arg == true then
		world.mwscript.getGlobalVariables(player).r_potionsOnly = 1
	else
		world.mwscript.getGlobalVariables(player).r_potionsOnly = 0
	end
	print("setPotionsOnly: " .. tostring(arg))
end

local function setPotionsByAlchemy(arg)
	if arg == true then
		world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 1
	else
		world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 0
	end
	print("setPotionsByAlchemy: " .. tostring(arg))
end

local function setProgressiveLimit(arg)
	if arg == true then
		world.mwscript.getGlobalVariables(player).r_progressiveLimit = 1
	else
		world.mwscript.getGlobalVariables(player).r_progressiveLimit = 0
	end
	print("setProgressiveLimit: " .. tostring(arg))
end

local globalStorage = storage.globalSection('Main')
local potionsOnly = globalStorage:get('potionsOnly')
local potionsByAlchemy = globalStorage:get('potionsByAlchemy')
local progressiveLimit = globalStorage:get('progressiveLimit')

setPotionsOnly(potionsOnly)
setPotionsByAlchemy(potionsByAlchemy)
setProgressiveLimit(progressiveLimit)

local function updateOption(_, key)
	if key == 'potionsOnly' then
		potionsOnly = globalStorage:get('potionsOnly')
		setPotionsOnly(potionsOnly)
	end

	if key == 'potionsByAlchemy' then
		potionsByAlchemy = globalStorage:get('potionsByAlchemy')
		setPotionsByAlchemy(potionsByAlchemy)
	end

	if key == 'progressiveLimit' then
		progressiveLimit = globalStorage:get('progressiveLimit')
		setProgressiveLimit(progressiveLimit)
	end
end
globalStorage:subscribe(async:callback(updateOption))

return {
	interfaceName = 'raffll_limits',
	interface = {
		version = 1,
		setPotionsOnly = setPotionsOnly,
		setPotionsByAlchemy = setPotionsByAlchemy,
		setProgressiveLimit = setProgressiveLimit
	}
}