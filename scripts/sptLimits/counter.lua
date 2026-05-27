local ui = require("openmw.ui")
local util = require("openmw.util")
local storage = require("openmw.storage")
local config = require("scripts.sptLimits.config")

if not config.potionLimitEnabled then
    return {}
end

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

local function tick()
    local ok, vals = pcall(function()
        return {
            countdown = storage.playerSection("sptLimitsState"):get("countdown"),
            drinkCount = storage.playerSection("sptLimitsState"):get("drinkCount"),
        }
    end)
    if ok and vals ~= nil and vals.countdown ~= nil and vals.drinkCount ~= nil then
        local hide = vals.drinkCount == 0
        element.layout.props.visible = not hide
        element.layout.props.text = string.format("%.1fs %d/%d", vals.countdown, vals.drinkCount, config.potionLimit)
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
