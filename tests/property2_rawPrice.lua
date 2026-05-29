local function getRawPrice(playerBaseSkill, iTrainingMod)
    return math.max(1, playerBaseSkill * iTrainingMod)
end

local seed = 12345
math.randomseed(seed)

local iterations = 200
local passed = 0
local failed = 0

for i = 1, iterations do
    local playerBaseSkill = math.random(0, 999)
    local iTrainingMod = math.random(1, 100)
    local expected = math.max(1, playerBaseSkill * iTrainingMod)
    local result = getRawPrice(playerBaseSkill, iTrainingMod)

    if result ~= expected then
        print(string.format("FAIL iteration %d: playerBaseSkill=%d iTrainingMod=%d expected=%d got=%d",
            i, playerBaseSkill, iTrainingMod, expected, result))
        failed = failed + 1
    else
        passed = passed + 1
    end
end

local edgeCaseResult = getRawPrice(0, math.random(1, 100))
if edgeCaseResult ~= 1 then
    print(string.format("FAIL edge case: playerBaseSkill=0 expected=1 got=%d", edgeCaseResult))
    failed = failed + 1
else
    passed = passed + 1
end

local edgeCaseResult2 = getRawPrice(0, 1)
if edgeCaseResult2 ~= 1 then
    print(string.format("FAIL edge case: playerBaseSkill=0 iTrainingMod=1 expected=1 got=%d", edgeCaseResult2))
    failed = failed + 1
else
    passed = passed + 1
end

local edgeCaseResult3 = getRawPrice(1, 1)
if edgeCaseResult3 ~= 1 then
    print(string.format("FAIL edge case: playerBaseSkill=1 iTrainingMod=1 expected=1 got=%d", edgeCaseResult3))
    failed = failed + 1
else
    passed = passed + 1
end

print(string.format("Property 2: Raw training price calculation - %d/%d passed", passed, passed + failed))

if failed > 0 then
    print("FAIL")
    os.exit(1)
else
    print("PASS")
    os.exit(0)
end
