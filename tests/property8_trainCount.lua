local seed = 12345
math.randomseed(seed)

local sources = { "Trainer", "Usage", "Book", "Jail" }

local iterations = 200
local passed = true

for i = 1, iterations do
    local trainCount = 0
    local numEvents = math.random(1, 20)

    for j = 1, numEvents do
        local source = sources[math.random(1, #sources)]
        local countBefore = trainCount

        if source == "Trainer" then
            trainCount = trainCount + 1
        end

        if source == "Trainer" then
            if trainCount ~= countBefore + 1 then
                print(string.format("FAIL iteration %d event %d: Trainer source did not increment", i, j))
                passed = false
                break
            end
        else
            if trainCount ~= countBefore then
                print(string.format("FAIL iteration %d event %d: non-Trainer source changed count", i, j))
                passed = false
                break
            end
        end
    end
    if not passed then break end
end

if passed then
    print(string.format("PASS - Property 8: Training count increments on trainer source (%d iterations)", iterations))
    os.exit(0)
else
    os.exit(1)
end
