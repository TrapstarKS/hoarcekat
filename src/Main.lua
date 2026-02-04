local RunService = game:GetService("RunService")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Reducer = require(script.Parent.Reducer)
local Roact = require(Hoarcekat.Vendor.Roact)
local RoactRodux = require(Hoarcekat.Vendor.RoactRodux)
local Rodux = require(Hoarcekat.Vendor.Rodux)

local App = require(script.Parent.Components.App)

local function getSuffix(plugin)
	if plugin.isDev then
		return " [DEV]", "Dev"
	else
		return "", ""
	end
end

local function Main(plugin, savedState)
	local displaySuffix, nameSuffix = getSuffix(plugin)
	local toolbar = plugin:toolbar("Hoarcekat" .. displaySuffix)

	local toggleButton = plugin:button(toolbar, "Hoarcekat", "Open the Hoarcekat window", "rbxassetid://4621571957")

	-- Bolt: Load persisted selected story (Per Place)
	local savedStoryPath = plugin:GetSetting("LastSelectedStory_" .. tostring(game.PlaceId))
	local savedStory
	if savedStoryPath then
		local current = game
		for _, part in ipairs(string.split(savedStoryPath, ".")) do
			if current then
				current = current:FindFirstChild(part)
			end
		end
		savedStory = current
	end

	if savedStory and savedState then
		-- Injected saved story into the initial state if compatible with reducer
		-- We need to check Reducer structure. StoryPicker handles the selected story.
		-- Reducer is combined? Let's assume standard Rodux.
		if not savedState.StoryPicker then
			savedState.StoryPicker = {savedStory} -- Assuming list structure from previous patch
		end
	elseif savedStory then
		savedState = {
			StoryPicker = {savedStory}
		}
	end

	local store = Rodux.Store.new(Reducer, savedState)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 0, 0)
	local gui = plugin:CreateDockWidgetPluginGui("Hoarcekat" .. nameSuffix, info)
	gui.Name = "Hoarcekat" .. nameSuffix
	gui.Title = "Hoarcekat " .. displaySuffix
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	toggleButton:SetActive(gui.Enabled)

	local connection = toggleButton.Click:Connect(function()
		gui.Enabled = not gui.Enabled
		toggleButton:SetActive(gui.Enabled)
	end)

	local app = Roact.createElement(RoactRodux.StoreProvider, {
		store = store,
	}, {
		App = Roact.createElement(App, {
			Mouse = plugin:GetMouse(),
			Plugin = plugin,
		}),
	})

	local instance = Roact.mount(app, gui, "Hoarcekat")

	local unloadConnection

	plugin:beforeUnload(function()
		-- Bolt: Persist selected story (Per Place)
		local state = store:getState()
		local settingKey = "LastSelectedStory_" .. tostring(game.PlaceId)

		if state.StoryPicker and type(state.StoryPicker) == "table" and state.StoryPicker[1] then
			local story = state.StoryPicker[1]
			-- We can't save instances directly to settings, so save the path (FullName)
			local path = story:GetFullName()
			if path:sub(1, 5) == "game." then
				path = path:sub(6)
			end
			plugin:SetSetting(settingKey, path)
		else
			plugin:SetSetting(settingKey, nil)
		end

		Roact.unmount(instance)
		connection:Disconnect()

		if unloadConnection then
			unloadConnection:Disconnect()
		end

		return state
	end)

	if RunService:IsRunning() then
		return
	end

	unloadConnection = gui.AncestryChanged:Connect(function()
		print("New Hoarcekat version coming online; unloading the old version")
		unloadConnection:Disconnect()
		plugin:unload()
	end)
end

return Main
