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

local function tick()
    local settingsSection = storage.playerSection("sptLimitsPotions")
    local hudCounterEnabled = settingsSection:get("hudCounterEnabled")
    local potionLimitEnabled = settingsSection:get("potionLimitEnabled")

    -- Default to true if nil (first load, no stored settings yet)
    if hudCounterEnabled == nil then
        hudCounterEnabled = true
    end
    if potionLimitEnabled == nil then
        potionLimitEnabled = true
    end

    if not hudCounterEnabled or not potionLimitEnabled then
        element.layout.props.visible = false
        element:update()
        return
    end

    local ok, vals = pcall(function()
        local stateSection = storage.playerSection("sptLimitsState")
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
        element.layout.props.text = string.format("%.1fs %d/%d", vals.countdown, vals.drinkCount, limit)
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
