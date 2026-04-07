local interfaces = require('openmw.interfaces')
local storage = require("openmw.storage")
local async = require("openmw.async")

local l10nKey = 'raffll_limits'
local settingsPageKey = 'SPL'

interfaces.Settings.registerPage({
	key = settingsPageKey,
	l10n = l10nKey,
	name = 'Stats & Potions Limit',
	description = 'Stats & Potions Limit OpenMW Lua addon configuration.',
})

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
            renderer = 'select',
            name = 'Potions Limit by Alchemy',
            description = 'Potion limit depends on Alchemy instead of Level.',
            default = 'Disabled',
            argument = {
                l10n = l10nKey,
                items = { 'By Level', 'By Alchemy', 'By Endurance', 'Constant 3' },
            },
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

local function updateOption(_, key)
    core.sendGlobalEvent('raffll_settingChanged', { key = key, value = globalStorage:get(key) })
end

globalStorage:subscribe(async:callback(updateOption))