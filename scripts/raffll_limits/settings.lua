local async = require("openmw.async")
local storage = require("openmw.storage")
local world = require('openmw.world')

local potionsByAlchemyValues = {
	['By Level']	 = 0,
	['By Alchemy']	 = 1,
	['By Endurance'] = 2,
	['Constant 3']	 = 3,
}

local function setPotionsOnly(arg)
	if arg == true then
		world.mwscript.getGlobalVariables(player).r_potionsOnly = 1
	else
		world.mwscript.getGlobalVariables(player).r_potionsOnly = 0
	end
	print("setPotionsOnly: " .. tostring(arg))
end

local function setPotionsByAlchemy(arg)
	world.mwscript.getGlobalVariables(player).r_potionsByAlchemy = potionsByAlchemyValues[arg] or 0
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
setPotionsOnly(globalStorage:get('potionsOnly'))
setPotionsByAlchemy(globalStorage:get('potionsByAlchemy'))
setProgressiveLimit(globalStorage:get('progressiveLimit'))

return {
	interfaceName = 'raffll_limits',
	interface = {
		version = 1,
		setPotionsOnly = setPotionsOnly,
		setPotionsByAlchemy = setPotionsByAlchemy,
		setProgressiveLimit = setProgressiveLimit
	},
	eventHandlers = {
		raffll_settingChanged = function(data)
			if data.key == 'potionsOnly' then
				setPotionsOnly(data.value)
			elseif data.key == 'potionsByAlchemy' then
				setPotionsByAlchemy(data.value)
			elseif data.key == 'progressiveLimit' then
				setProgressiveLimit(data.value)
			end
		end
	}
}