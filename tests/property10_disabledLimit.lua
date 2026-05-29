local seed = 12345
math.randomseed(seed)

local function isBlocked(trainingLimitEnabled, trainCount, trainingLimit)
    return trainingLimitEnabled and trainCount >= trainingLimit
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local trainCount = math.random(0, 99)
    local trainingLimit = math.random(1, 99)

    local result = isBlocked(false, trainCount, trainingLimit)

    if result ~= false then
        print(string.format("FAIL iteration %d: disabled limit should never block, got %s", i, tostring(result)))
        print(string.format("  trainCount=%d trainingLimit=%d", trainCount, trainingLimit))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 10: Disabled limit never blocks (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
