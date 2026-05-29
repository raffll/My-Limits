local seed = 12345
math.randomseed(seed)

local function validateTraining(playerGold, price, trainerSkillValue, playerBaseSkill, governingAttributeModified)
    if playerGold < price then
        return "gold"
    end
    if trainerSkillValue <= playerBaseSkill then
        return "trainerSkill"
    end
    if playerBaseSkill >= governingAttributeModified then
        return "attribute"
    end
    return nil
end

local function randomInt(lo, hi)
    return math.random(lo, hi)
end

local iterations = 200
local passed = true

for i = 1, iterations do
    local playerGold = randomInt(0, 1000)
    local price = randomInt(1, 500)
    local trainerSkillValue = randomInt(1, 200)
    local playerBaseSkill = randomInt(0, 200)
    local governingAttributeModified = randomInt(1, 200)

    local result = validateTraining(playerGold, price, trainerSkillValue, playerBaseSkill, governingAttributeModified)

    local goldFails = playerGold < price
    local trainerFails = trainerSkillValue <= playerBaseSkill
    local attributeFails = playerBaseSkill >= governingAttributeModified

    local expected
    if goldFails then
        expected = "gold"
    elseif trainerFails then
        expected = "trainerSkill"
    elseif attributeFails then
        expected = "attribute"
    else
        expected = nil
    end

    if result ~= expected then
        local resultStr = result or "nil"
        local expectedStr = expected or "nil"
        print(string.format("FAIL iteration %d: expected %s, got %s", i, expectedStr, resultStr))
        print(string.format("  playerGold=%d price=%d trainerSkillValue=%d playerBaseSkill=%d governingAttributeModified=%d",
            playerGold, price, trainerSkillValue, playerBaseSkill, governingAttributeModified))
        passed = false
        break
    end

    if goldFails and trainerFails then
        if result ~= "gold" then
            print(string.format("FAIL iteration %d: both gold and trainerSkill fail but got %s instead of gold", i, result or "nil"))
            passed = false
            break
        end
    end

    if goldFails and attributeFails then
        if result ~= "gold" then
            print(string.format("FAIL iteration %d: both gold and attribute fail but got %s instead of gold", i, result or "nil"))
            passed = false
            break
        end
    end

    if not goldFails and trainerFails and attributeFails then
        if result ~= "trainerSkill" then
            print(string.format("FAIL iteration %d: trainerSkill and attribute fail but got %s instead of trainerSkill", i, result or "nil"))
            passed = false
            break
        end
    end
end

if passed then
    print(string.format("PASS - Property 5: Validation checks follow strict ordering (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
