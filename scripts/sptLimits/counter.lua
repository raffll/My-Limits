local ui = require("openmw.ui")
local util = require("openmw.util")
local storage = require("openmw.storage")

local element = ui.create({
    layer = "HUD",
    type = ui.TYPE.Text,
    props = {
        relativePosition = util.vector2(1, 1),
        anchor = util.vector2(1, 1),
        position = util.vector2(-12, -90 - 32 + 4),
        text = "",
        textSize = 16,
        textColor = util.color.rgb(0.79, 0.65, 0.38),
        textFont = "Default",
        visible = false,
    },
})

local initialized = false

local function tick()
    local settingsSection = storage.playerSection("sptLimitsPotions")
    local hudCounterMode = settingsSection:get("hudCounterMode")
    local potionLimitEnabled = settingsSection:get("potionLimitEnabled")

    if hudCounterMode == nil and potionLimitEnabled == nil then
        if not initialized then
            return
        end
    else
        initialized = true
    end

    if hudCounterMode == "hidden" or potionLimitEnabled == false then
        element.layout.props.visible = false
        element:update()
        return
    end

    local stateSection = storage.playerSection("sptLimitsState")
    local trackingMode = stateSection:get("trackingMode")
    if trackingMode == "slots" then
        element.layout.props.visible = false
        element:update()
        return
    end

    local ok, vals = pcall(function()
        return {
            countdown = stateSection:get("countdown"),
            drinkCount = stateSection:get("drinkCount"),
            potionLimit = stateSection:get("potionLimit"),
        }
    end)

    if ok and vals and vals.countdown ~= nil and vals.drinkCount ~= nil then
        local hide = vals.drinkCount == 0
        element.layout.props.visible = not hide
        local limit = vals.potionLimit or 3
        local timerPart = ""
        if hudCounterMode == "detailed" then
            timerPart = string.format("%.1fs ", vals.countdown)
        elseif hudCounterMode == "compact" then
            timerPart = string.format("%ds ", math.floor(vals.countdown))
        end
        element.layout.props.text = timerPart .. string.format("%d/%d", vals.drinkCount, limit)
        element:update()
    end
end

return {
    engineHandlers = {
        onFrame = function()
            tick()
        end,
    },
}
