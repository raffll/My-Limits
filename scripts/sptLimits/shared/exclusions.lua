local interfaces = require("openmw.interfaces")
local config = require("scripts.sptLimits.shared.config")

local excludedPotions = {}
local excludedPotionPatterns = {}

for _, entry in ipairs(config.potions or {}) do
    if entry:find("[%%%[%]%.%+%-%*%?%^%$%(%)]") then
        table.insert(excludedPotionPatterns, entry:lower())
    else
        excludedPotions[entry:lower()] = true
    end
end

local function isPotionExcluded(id, excludeSunsDusk)
    local lowerId = id:lower()
    if excludedPotions[lowerId] then
        return true
    end
    if excludeSunsDusk and interfaces.SunsDusk and interfaces.SunsDusk.isConsumable then
        if interfaces.SunsDusk.isConsumable(id) then
            return true
        end
    end
    for _, pattern in ipairs(excludedPotionPatterns) do
        if lowerId:match(pattern) then
            return true
        end
    end
    return false
end

return {
    excludedPotions = excludedPotions,
    isPotionExcluded = isPotionExcluded,
}
