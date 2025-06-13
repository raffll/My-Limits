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
            key = 'potionsByLevel',
            renderer = 'checkbox',
            name = 'Potions Limit by Level',
            description = 'Potion limit depends on Level instead of Alchemy.',
            default = false
        },
		{
            key = 'constStatsLimit',
            renderer = 'checkbox',
            name = 'Constant Stats Limit',
            description = 'Stats limit set to constant 300/150 without Level influence.',
            default = false
        },
    },
})

local globalStorage = storage.globalSection('Main')

local potionsOnly = globalStorage:get('potionsOnly')
if potionsOnly == true then
	world.mwscript.getGlobalVariables(player).r_onlyPotions = 1
else
	world.mwscript.getGlobalVariables(player).r_onlyPotions = 0
end

local potionsByLevel = globalStorage:get('potionsByLevel')
if potionsByLevel == true then
	world.mwscript.getGlobalVariables(player).r_potionsByLevel = 1
else
	world.mwscript.getGlobalVariables(player).r_potionsByLevel = 0
end

local constStatsLimit = globalStorage:get('constStatsLimit')
if constStatsLimit == true then
	world.mwscript.getGlobalVariables(player).r_constStatsLimit = 1
else
	world.mwscript.getGlobalVariables(player).r_constStatsLimit = 0
end
		
local function updateOption(_, key)
    if key == 'potionsOnly' then
		potionsOnly = globalStorage:get('potionsOnly')
		if potionsOnly == true then
			world.mwscript.getGlobalVariables(player).r_onlyPotions = 1
		else
			world.mwscript.getGlobalVariables(player).r_onlyPotions = 0
		end
    end
	
	if key == 'potionsByLevel' then
		potionsByLevel = globalStorage:get('potionsByLevel')
		if potionsByLevel == true then
			world.mwscript.getGlobalVariables(player).r_potionsByLevel = 1
		else
			world.mwscript.getGlobalVariables(player).r_potionsByLevel = 0
		end
    end
	
	if key == 'constStatsLimit' then
		constStatsLimit = globalStorage:get('constStatsLimit')
		if constStatsLimit == true then
			world.mwscript.getGlobalVariables(player).r_constStatsLimit = 1
		else
			world.mwscript.getGlobalVariables(player).r_constStatsLimit = 0
		end
    end
end
globalStorage:subscribe(async:callback(updateOption))