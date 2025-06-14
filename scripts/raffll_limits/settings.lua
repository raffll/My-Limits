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
			name = 'Potions Limit Only',
			description = 'Disables attribute and skill limits.',
			default = false
		},
		{
			key = 'potionsByAlchemy',
			renderer = 'checkbox',
			name = 'Potions Limit by Alchemy',
			description = 'Potion limit depends on Alchemy instead of Level.',
			default = false
		},
		{
			key = 'progressiveLimit',
			renderer = 'checkbox',
			name = 'Progressive Limits',
			description = 'Attribute and skill limits depends on Level.',
			default = false
		},
	},
})

local globalStorage = storage.globalSection('Main')

local potionsOnly = globalStorage:get('potionsOnly')
if potionsOnly == true then
	world.mwscript.getGlobalVariables(player).r_potionsOnly = 1
else
	world.mwscript.getGlobalVariables(player).r_potionsOnly = 0
end

local potionsByAlchemy = globalStorage:get('potionsByAlchemy')
if potionsByAlchemy == true then
	world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 1
else
	world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 0
end

local progressiveLimit = globalStorage:get('progressiveLimit')
if progressiveLimit == true then
	world.mwscript.getGlobalVariables(player).r_progressiveLimit = 1
else
	world.mwscript.getGlobalVariables(player).r_progressiveLimit = 0
end

local function updateOption(_, key)
	if key == 'potionsOnly' then
		potionsOnly = globalStorage:get('potionsOnly')
		if potionsOnly == true then
			world.mwscript.getGlobalVariables(player).r_potionsOnly = 1
		else
			world.mwscript.getGlobalVariables(player).r_potionsOnly = 0
		end
	end

	if key == 'potionsByAlchemy' then
		potionsByAlchemy = globalStorage:get('potionsByAlchemy')
		if potionsByAlchemy == true then
			world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 1
		else
			world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = 0
		end
	end

	if key == 'progressiveLimit' then
		progressiveLimit = globalStorage:get('progressiveLimit')
		if progressiveLimit == true then
			world.mwscript.getGlobalVariables(player).r_progressiveLimit = 1
		else
			world.mwscript.getGlobalVariables(player).r_progressiveLimit = 0
		end
	end
end
globalStorage:subscribe(async:callback(updateOption))