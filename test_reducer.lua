local function reducer(state, action)
    state = state or {}
    if action.type == "SetSelectedStory" then
        return { action.story }
    elseif action.type == "ToggleCompareStory" then
        local newState = {}
        local found = false
        for _, s in ipairs(state) do
            if s == action.story then
                found = true
            else
                table.insert(newState, s)
            end
        end
        if not found then
            if #newState < 2 then
                table.insert(newState, action.story)
            else
                newState[2] = action.story
            end
        end
        return newState
    end
    return state
end

local s1 = "Story1"
local s2 = "Story2"
local s3 = "Story3"

local state = {}
print("Initial:", #state)

-- Select S1 (Single)
state = reducer(state, { type = "SetSelectedStory", story = s1 })
print("After Set S1:", #state, state[1])

-- Toggle Compare S2
state = reducer(state, { type = "ToggleCompareStory", story = s2 })
print("After Toggle S2:", #state, state[1], state[2])

-- Toggle Compare S3 (Should replace S2)
state = reducer(state, { type = "ToggleCompareStory", story = s3 })
print("After Toggle S3:", #state, state[1], state[2])

-- Toggle Compare S1 (Should remove S1)
state = reducer(state, { type = "ToggleCompareStory", story = s1 })
print("After Toggle S1:", #state, state[1], state[2])
