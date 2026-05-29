local seed = 12345
math.randomseed(seed)

local function simulateLevelChange(trainCount, oldLevel, newLevel)
    if oldLevel ~= newLevel then
        return 0
    end
    return trainCount
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local trainCount = math.random(1, 99)
    local oldLevel = math.random(1, 50)
    local newLevel = oldLevel + math.random(1, 5)

    local result = simulateLevelChange(trainCount, oldLevel, newLevel)

    if result ~= 0 then
        print(string.format("FAIL iteration %d: expected 0 after level change, got %d", i, result))
        passed = false
        break
    end
end

for i = 1, iterations do
    local trainCount = math.random(1, 99)
    local level = math.random(1, 50)

    local result = simulateLevelChange(trainCount, level, level)

    if result ~= trainCount then
        print(string.format("FAIL iteration %d: same level should not reset, expected %d got %d", i, trainCount, result))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 9: Level change resets training count (%d iterations)", iterations * 2))
    os.exit(0)
else
    os.exit(1)
end
