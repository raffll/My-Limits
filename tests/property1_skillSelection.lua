local seed = 12345
math.randomseed(seed)

local function getTrainerSkills(skillValues)
    local candidates = {}
    for i, value in ipairs(skillValues) do
        if value > 0 then
            candidates[#candidates + 1] = { value = value, index = i }
        end
    end
    table.sort(candidates, function(a, b)
        if a.value ~= b.value then
            return a.value > b.value
        end
        return a.index < b.index
    end)
    local result = {}
    for i = 1, math.min(3, #candidates) do
        result[i] = { value = candidates[i].value, index = candidates[i].index }
    end
    return result
end

local function generateSkillValues()
    local values = {}
    for i = 1, 27 do
        values[i] = math.random(0, 200)
    end
    return values
end

local function countPositive(values)
    local count = 0
    for _, v in ipairs(values) do
        if v > 0 then
            count = count + 1
        end
    end
    return count
end

local function formatValues(values)
    local parts = {}
    for i, v in ipairs(values) do
        parts[i] = tostring(v)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local iterations = 200
local passed = true
local failMessage = nil

for iter = 1, iterations do
    local skillValues = generateSkillValues()
    local result = getTrainerSkills(skillValues)
    local positiveCount = countPositive(skillValues)
    local expectedLength = math.min(3, positiveCount)

    if #result ~= expectedLength then
        passed = false
        failMessage = string.format(
            "Iteration %d: expected %d results, got %d. Input: %s",
            iter, expectedLength, #result, formatValues(skillValues)
        )
        break
    end

    for i, entry in ipairs(result) do
        if entry.value <= 0 then
            passed = false
            failMessage = string.format(
                "Iteration %d: result[%d] has value %d <= 0. Input: %s",
                iter, i, entry.value, formatValues(skillValues)
            )
            break
        end
    end
    if not passed then break end

    for i = 1, #result - 1 do
        if result[i].value < result[i + 1].value then
            passed = false
            failMessage = string.format(
                "Iteration %d: not sorted descending at index %d (value %d < %d). Input: %s",
                iter, i, result[i].value, result[i + 1].value, formatValues(skillValues)
            )
            break
        end
    end
    if not passed then break end

    for i = 1, #result - 1 do
        if result[i].value == result[i + 1].value then
            if result[i].index >= result[i + 1].index then
                passed = false
                failMessage = string.format(
                    "Iteration %d: unstable sort at index %d (same value %d, index %d >= %d). Input: %s",
                    iter, i, result[i].value, result[i].index, result[i + 1].index, formatValues(skillValues)
                )
                break
            end
        end
    end
    if not passed then break end
end

if passed then
    print(string.format("PASS - Property 1: Skill selection returns top skills in stable descending order (%d iterations)", iterations))
    os.exit(0)
else
    print("FAIL - Property 1: Skill selection returns top skills in stable descending order")
    print(failMessage)
    os.exit(1)
end
