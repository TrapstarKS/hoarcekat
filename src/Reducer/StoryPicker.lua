return function(state, action)
	-- state is now a table { primary = story1, secondary = story2 }
	-- or just a list? Let's keep it backward compatible if possible, or migrate.
	-- The rest of the app expects `state` to be a Story instance (userData).
	-- Refactoring strict compatibility might be hard.
	-- However, the Redux store structure is:
	-- { StoryPicker = (Instance or nil) }

	-- We need to change the state shape to support multiple stories.
	-- New shape: { selected = { story1, story2? } } OR just { story1, story2 }
	-- BUT `Sidebar.lua` and `Preview.lua` map `state.StoryPicker` directly.

	-- Let's change state to be a table of stories.
	state = state or {}

	if action.type == "SetSelectedStory" then
		-- Legacy behavior: Click to select one.
		-- New behavior: If Ctrl is held (we can't detect keys here easily without passing them),
		-- or if we use a specific action type "ToggleStory".

		-- For simplicity/safety, let's say "SetSelectedStory" sets the PRIMARY (clears others).
		return { action.story }
	elseif action.type == "ToggleCompareStory" then
		-- Toggles a story in the secondary slot.
		-- Max 2 stories.
		local newState = {}
		local found = false

		for _, s in ipairs(state) do
			if s == action.story then
				found = true -- Remove it
			else
				table.insert(newState, s)
			end
		end

		if not found then
			if #newState < 2 then
				table.insert(newState, action.story)
			else
				-- Replace the second one
				newState[2] = action.story
			end
		end

		return newState
	end

	return state
end
