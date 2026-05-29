local seed = 12345
math.randomseed(seed)

local function executeGoldTransfer(playerGold, trainerBarterGold, price)
    local newPlayerGold = playerGold - price
    local newTrainerGold = trainerBarterGold + price
    return newPlayerGold, newTrainerGold
end

local function randomInt(lo, hi)
    return math.random(lo, hi)
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local price = randomInt(1, 100000)
    local playerGold = randomInt(math.max(100, price), 1000000)
    local trainerBarterGold = randomInt(0, 10000)

    local totalBefore = playerGold + trainerBarterGold

    local newPlayerGold, newTrainerGold = executeGoldTransfer(playerGold, trainerBarterGold, price)

    local totalAfter = newPlayerGold + newTrainerGold

    if totalAfter ~= totalBefore then
        print(string.format("FAIL iteration %d: gold not conserved", i))
        print(string.format("  playerGold=%d trainerBarterGold=%d price=%d", playerGold, trainerBarterGold, price))
        print(string.format("  totalBefore=%d totalAfter=%d", totalBefore, totalAfter))
        passed = false
        break
    end

    if newPlayerGold ~= playerGold - price then
        print(string.format("FAIL iteration %d: playerGold did not decrease by exactly price", i))
        print(string.format("  playerGold=%d price=%d newPlayerGold=%d expected=%d", playerGold, price, newPlayerGold, playerGold - price))
        passed = false
        break
    end

    if newTrainerGold ~= trainerBarterGold + price then
        print(string.format("FAIL iteration %d: trainerBarterGold did not increase by exactly price", i))
        print(string.format("  trainerBarterGold=%d price=%d newTrainerGold=%d expected=%d", trainerBarterGold, price, newTrainerGold, trainerBarterGold + price))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 6: Gold conservation on successful training (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
