local ui = require("openmw.ui")
local util = require("openmw.util")
local storage = require("openmw.storage")
local interfaces = require("openmw.interfaces")

local config = require("scripts.sptLimits.config")

local maxIcons = config.maxSlotDisplay
local normalColor = util.color.rgb(0.79, 0.65, 0.38)
local baseX = -12
local baseY = -90 - 32 + 4
local slotSpacing = 22
local iconSize = 16

local textureCache = {}

local function getTexture(path)
    if not path or path == "" then
        return nil
    end
    if not textureCache[path] then
        textureCache[path] = ui.texture({ path = path })
    end
    return textureCache[path]
end

local countdownElement = ui.create({
    layer = "HUD",
    type = ui.TYPE.Text,
    props = {
        relativePosition = util.vector2(1, 1),
        anchor = util.vector2(1, 1),
        position = util.vector2(baseX, baseY),
        text = "",
        textSize = 16,
        textColor = normalColor,
        textFont = "Default",
        visible = false,
    },
})

local limitElement = ui.create({
    layer = "HUD",
    type = ui.TYPE.Text,
    props = {
        relativePosition = util.vector2(1, 1),
        anchor = util.vector2(1, 1),
        position = util.vector2(baseX, baseY - slotSpacing),
        text = "",
        textSize = 16,
        textColor = normalColor,
        textFont = "Default",
        visible = false,
    },
})

local iconElements = {}
for i = 1, maxIcons do
    iconElements[i] = ui.create({
        layer = "HUD",
        type = ui.TYPE.Widget,
        template = interfaces.MWUI.templates.borders,
        props = {
            relativePosition = util.vector2(1, 1),
            anchor = util.vector2(1, 1),
            position = util.vector2(baseX, baseY - (i + 1) * slotSpacing),
            size = util.vector2(iconSize + 4, iconSize + 4),
            visible = false,
        },
        content = ui.content({
            {
                name = "icon",
                type = ui.TYPE.Image,
                props = {
                    size = util.vector2(iconSize, iconSize),
                },
            },
        }),
    })
end

local initialized = false

local function parseIcons(iconsStr)
    if not iconsStr or iconsStr == "" then
        return {}
    end
    local icons = {}
    for part in string.gmatch(iconsStr, "[^|]+") do
        icons[#icons + 1] = part
    end
    return icons
end

local function hideAll()
    if countdownElement.layout.props.visible then
        countdownElement.layout.props.visible = false
        countdownElement:update()
    end
    if limitElement.layout.props.visible then
        limitElement.layout.props.visible = false
        limitElement:update()
    end
    for i = 1, maxIcons do
        if iconElements[i].layout.props.visible then
            iconElements[i].layout.props.visible = false
            iconElements[i]:update()
        end
    end
end

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
        hideAll()
        return
    end

    local stateSection = storage.playerSection("sptLimitsState")
    local trackingMode = stateSection:get("trackingMode")
    if trackingMode == "slots" then
        hideAll()
        return
    end

    local drinkCount = stateSection:get("drinkCount") or 0
    local countdown = stateSection:get("countdown") or 0
    local potionLimit = stateSection:get("potionLimit") or 3
    local iconsStr = stateSection:get("drinkIcons") or ""
    local icons = parseIcons(iconsStr)

    if drinkCount == 0 then
        hideAll()
        return
    end

    if hudCounterMode == "minimal" then
        countdownElement.layout.props.visible = false
        countdownElement:update()
        limitElement.layout.props.visible = false
        limitElement:update()
    else
        countdownElement.layout.props.visible = true
        countdownElement.layout.props.text = string.format("%.1fs", countdown)
        countdownElement:update()
        limitElement.layout.props.visible = true
        limitElement.layout.props.text = string.format("%d/%d", drinkCount, potionLimit)
        limitElement:update()
    end

    local displayCount = math.min(#icons, maxIcons)
    for i = 1, maxIcons do
        local el = iconElements[i]
        if i > displayCount then
            if el.layout.props.visible then
                el.layout.props.visible = false
                el:update()
            end
        else
            local tex = getTexture(icons[i])
            if tex then
                el.layout.props.visible = true
                el.layout.content[1].props.resource = tex
                el:update()
            else
                if el.layout.props.visible then
                    el.layout.props.visible = false
                    el:update()
                end
            end
        end
    end
end

return {
    engineHandlers = {
        onFrame = function()
            tick()
        end,
    },
}
