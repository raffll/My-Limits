local core = require('openmw.core')
local interfaces = require('openmw.interfaces')
local types = require('openmw.types')
local ui = require('openmw.ui')
local util = require('openmw.util')
local self = require('openmw.self')

local trainCount
local currentLevel

local function onInit()
	trainCount = 0
	currentLevel = types.Actor.stats.level(self).current
	core.sendGlobalEvent("trainCountEvent", { trainCount })
end

local function onSave()
	return {
		tc = trainCount,
		cl = currentLevel
	}
end

local function onLoad(data)
	trainCount = data.tc
	currentLevel = data.cl
	core.sendGlobalEvent("trainCountEvent", { trainCount })
end

local function onUpdate(dt)
	if currentLevel ~= types.Actor.stats.level(self).current then
		onInit()
	end
end

interfaces.SkillProgression.addSkillLevelUpHandler(function(skillid, source, options)
	if source == interfaces.SkillProgression.SKILL_INCREASE_SOURCES.Trainer then
		trainCount = trainCount + 1
		core.sendGlobalEvent("trainCountEvent", { trainCount })
	end
end)

return {
	engineHandlers = {
		onInit = onInit,
		onSave = onSave,
		onLoad = onLoad,
		onUpdate = onUpdate,
	}
}
