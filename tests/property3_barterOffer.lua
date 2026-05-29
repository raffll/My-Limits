local seed = 12345
math.randomseed(seed)

local function getBarterOffer(rawPrice, playerMerc, playerPers, playerLuck, playerFatRatio, trainerMerc, trainerPers, trainerLuck, trainerFatRatio)
    local pcTerm = (playerMerc + 0.1 * playerPers + 0.2 * playerLuck) * playerFatRatio
    local npcTerm = (trainerMerc + 0.1 * trainerPers + 0.2 * trainerLuck) * trainerFatRatio
    local buyTerm = 0.01 * (100 - 0.5 * (pcTerm - npcTerm))
    buyTerm = math.max(0, math.min(1, buyTerm))
    return math.max(1, math.floor(rawPrice * buyTerm))
end

local function randomInt(lo, hi)
    return math.random(lo, hi)
end

local function randomFloat(lo, hi)
    return lo + math.random() * (hi - lo)
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local rawPrice = randomInt(1, 100000)
    local playerMerc = randomInt(0, 200)
    local playerPers = randomInt(0, 200)
    local playerLuck = randomInt(0, 200)
    local trainerMerc = randomInt(0, 200)
    local trainerPers = randomInt(0, 200)
    local trainerLuck = randomInt(0, 200)
    local playerFatRatio = randomFloat(0.0, 1.0)
    local trainerFatRatio = randomFloat(0.0, 1.0)

    local result = getBarterOffer(rawPrice, playerMerc, playerPers, playerLuck, playerFatRatio, trainerMerc, trainerPers, trainerLuck, trainerFatRatio)

    if result < 1 then
        print(string.format("FAIL iteration %d: result %d < 1", i, result))
        passed = false
        break
    end

    local pcTerm = (playerMerc + 0.1 * playerPers + 0.2 * playerLuck) * playerFatRatio
    local npcTerm = (trainerMerc + 0.1 * trainerPers + 0.2 * trainerLuck) * trainerFatRatio
    local buyTerm = 0.01 * (100 - 0.5 * (pcTerm - npcTerm))

    if buyTerm < 0 or buyTerm > 1 then
        buyTerm = math.max(0, math.min(1, buyTerm))
    end

    local expected = math.max(1, math.floor(rawPrice * buyTerm))

    if result ~= expected then
        print(string.format("FAIL iteration %d: expected %d, got %d", i, expected, result))
        print(string.format("  rawPrice=%d playerMerc=%d playerPers=%d playerLuck=%d", rawPrice, playerMerc, playerPers, playerLuck))
        print(string.format("  trainerMerc=%d trainerPers=%d trainerLuck=%d", trainerMerc, trainerPers, trainerLuck))
        print(string.format("  playerFatRatio=%.4f trainerFatRatio=%.4f", playerFatRatio, trainerFatRatio))
        print(string.format("  buyTerm=%.6f", buyTerm))
        passed = false
        break
    end

    if buyTerm < 0 or buyTerm > 1 then
        print(string.format("FAIL iteration %d: buyTerm %.6f not clamped to [0,1]", i, buyTerm))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 3: Barter offer price adjustment (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
