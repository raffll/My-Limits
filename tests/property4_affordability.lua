local seed = 12345
math.randomseed(seed)

local function getButtonSkin(playerGold, price)
    if playerGold >= price then
        return "SandTextButton"
    else
        return "SandTextButtonDisabled"
    end
end

local function randomInt(lo, hi)
    return math.random(lo, hi)
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local playerGold = randomInt(0, 1000000)
    local price = randomInt(1, 100000)

    local result = getButtonSkin(playerGold, price)

    local expectedSkin
    if playerGold >= price then
        expectedSkin = "SandTextButton"
    else
        expectedSkin = "SandTextButtonDisabled"
    end

    if result ~= expectedSkin then
        print(string.format("FAIL iteration %d: expected %s, got %s", i, expectedSkin, result))
        print(string.format("  playerGold=%d price=%d", playerGold, price))
        passed = false
        break
    end

    if playerGold >= price and result ~= "SandTextButton" then
        print(string.format("FAIL iteration %d: gold >= price but skin is not SandTextButton", i))
        print(string.format("  playerGold=%d price=%d skin=%s", playerGold, price, result))
        passed = false
        break
    end

    if playerGold < price and result ~= "SandTextButtonDisabled" then
        print(string.format("FAIL iteration %d: gold < price but skin is not SandTextButtonDisabled", i))
        print(string.format("  playerGold=%d price=%d skin=%s", playerGold, price, result))
        passed = false
        break
    end
end

if passed then
    print(string.format("PASS - Property 4: Affordability determines button skin (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
