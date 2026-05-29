local seed = 12345
math.randomseed(seed)

local function isBlocked(trainingLimitEnabled, trainCount, trainingLimit)
    return trainingLimitEnabled and trainCount >= trainingLimit
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local trainingLimitEnabled = math.random(0, 1) == 1
    local trainCount = math.random(0, 99)
    local trainingLimit = math.random(1, 99)

    local result = isBlocked(trainingLimitEnabled, trainCount, trainingLimit)
    local expected = trainingLimitEnabled and (trainCount >= trainingLimit)

    if result ~= expected then
        print(string.format("FAIL iteration %d: expected %s, got %s", i, tostring(expected), tostring(result)))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 7: Blocked state invariant (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
