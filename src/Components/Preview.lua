local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Assets = require(Hoarcekat.Plugin.Assets)
local EventConnection = require(script.Parent.EventConnection)
local FloatingButton = require(script.Parent.FloatingButton)
local StatsOverlay = require(script.Parent.StatsOverlay)
local DebugOverlay = require(script.Parent.DebugOverlay)
local DeviceEmulator = require(script.Parent.DeviceEmulator)
local Maid = require(Hoarcekat.Plugin.Maid)
local Roact = require(Hoarcekat.Vendor.Roact)
local RoactRodux = require(Hoarcekat.Vendor.RoactRodux)
local resolveRequirePath = require(Hoarcekat.Plugin.resolveRequirePath)

local e = Roact.createElement

local Preview = Roact.PureComponent:extend("Preview")

function Preview:init()
	self.rootRef = Roact.createRef()

	self.currentPreview = nil -- { state1, state2? }
	self.errorID = 0

	local display = Instance.new("ScreenGui")
	display.Name = "HoarcekatDisplay"
	display.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.display = display

	self.expand = false

	self.openSelection = function()
		-- Select all targets
		local selection = {}
		if self.currentPreview then
			if self.currentPreview.target then
				table.insert(selection, self.currentPreview.target)
			elseif type(self.currentPreview) == "table" then
				-- Assuming new structure for multi-preview
				for _, state in pairs(self.currentPreview) do
					if state.target then
						table.insert(selection, state.target)
					end
				end
			end
		end

		if #selection > 0 then
			Selection:Set(selection)
		end
	end

	self.expandSelection = function()
		self.expand = not self.expand
		self.display.Parent = self.expand and CoreGui or nil

		self:updateDisplay()
	end

	self.state = {
		showStats = false,
		showDebug = false,
		renderCount = 0,
		layoutMode = "Split", -- "Split" or "Stack"
		deviceSize = nil, -- Vector2 or nil
	}

	self.updateDeviceSize = function(size)
		self:setState({
			deviceSize = size
		})
	end

	self.toggleStats = function()
		self:setState({
			showStats = not self.state.showStats,
		})
	end

	self.toggleDebug = function()
		self:setState({
			showDebug = not self.state.showDebug,
		})
	end

	self.toggleLayout = function()
		self:setState({
			layoutMode = self.state.layoutMode == "Split" and "Stack" or "Split"
		})
	end
end

function Preview:didMount()
	self:refreshPreview()
end

function Preview:didUpdate(prevProps)
	if prevProps.selectedStory ~= self.props.selectedStory then
		self:refreshPreview()
	end
end

function Preview:willUnmount()
	self:clearPreview()

	if self.display then
		self.display:Destroy()
	end
end

local ERROR_DELAY = 1
function Preview:setError(err)
	local id = self.errorID + 1
	self.errorID = id
	task.delay(ERROR_DELAY, function()
		if self.errorID ~= id then
			-- Error was canceled or replaced.
			return
		end
		warn(err)
	end)
end

function Preview:cancelError()
	self.errorID += 1
end

function Preview:updateDisplay()
	if not self.currentPreview then
		return
	end

	-- Handle multiple previews or single preview
	local states = self.currentPreview
	-- If it's a single state (old behavior), wrap it
	if states.target then
		states = {states}
	end

	for _, state in pairs(states) do
		local target = state.target
		if target then
			if self.expand then
				target.Parent = self.display
			else
				target.Parent = self.rootRef:getValue()
			end
		end
	end
end

function Preview:refreshPreview()
	-- Support list of stories or single story
	local selectedStories = self.props.selectedStory
	if type(selectedStories) ~= "table" or selectedStories.ClassName then
		-- Single instance or nil
		selectedStories = {selectedStories}
	end

	if #selectedStories == 0 or not selectedStories[1] then
		self:clearPreview()
		return
	end

	self:clearPreview()
	self:cancelError()

	local newStates = {}

	for i, story in ipairs(selectedStories) do
		local err, nextState = self:prepareState(story)
		if err then
			self:setError(err)
			-- Cleanup already prepared states
			for _, s in pairs(newStates) do
				s:destroy()
			end
			return
		end

		-- Position the targets if multiple
		if #selectedStories > 1 then
			if self.state.layoutMode == "Split" then
				nextState.target.Size = UDim2.new(1 / #selectedStories, 0, 1, 0)
				nextState.target.Position = UDim2.new((i - 1) / #selectedStories, 0, 0, 0)
				nextState.target.BorderSizePixel = 1
				nextState.target.BorderColor3 = Color3.fromRGB(100, 100, 100)
			else -- Stack
				nextState.target.Size = UDim2.new(1, 0, 1, 0)
				nextState.target.Position = UDim2.new(0, 0, 0, 0)
				nextState.target.BackgroundTransparency = 1 -- Ensure stacking works visually
				nextState.target.BorderSizePixel = 0
			end
		end

		-- Device Emulation (Applied to all targets)
		if self.state.deviceSize then
			local dSize = self.state.deviceSize
			local container = Instance.new("Frame")
			container.Name = "DeviceContainer"
			container.BackgroundTransparency = 1
			container.Size = UDim2.fromScale(1, 1)

			local wrapper = Instance.new("Frame")
			wrapper.Name = "DeviceWrapper"
			wrapper.Size = UDim2.fromOffset(dSize.X, dSize.Y)
			wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
			wrapper.Position = UDim2.fromScale(0.5, 0.5)
			wrapper.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Black bg for device
			wrapper.BorderSizePixel = 2
			wrapper.BorderColor3 = Color3.fromRGB(100, 100, 100)
			wrapper.ClipsDescendants = true
			wrapper.Parent = container

			nextState.target.Parent = wrapper
			nextState.target = container -- Replace target with container for display update
		end

		table.insert(newStates, nextState)
	end

	self.currentPreview = newStates
	self:updateDisplay()

	-- We can't setState inside refreshPreview if it's called from didUpdate
	-- without checking conditions, otherwise we loop.
	-- But refreshPreview IS called from didUpdate (guarded now).
	-- And it's called from hot-reload (monkeyRequire).

	-- We want to bump renderCount whenever the story is REBUILT.
	-- If we just built it, we can safely setState if we are not in the middle of a render cycle?
	-- Actually, setState inside didUpdate is fine IF guarded.
	-- But refreshPreview sets state at the end.

	-- The issue was: didUpdate -> refreshPreview -> setState -> didUpdate -> ...
	-- Now didUpdate is guarded by props check.
	-- So calling setState here should be fine, as it will trigger didUpdate,
	-- but props won't have changed, so it won't call refreshPreview again.

	self:setState({
		renderCount = self.state.renderCount + 1
	})
end

function Preview:clearPreview()
	self:cancelError()
	local states = self.currentPreview
	if states == nil then
		return
	end

	if states.destroy then
		states:destroy()
	elseif type(states) == "table" then
		for _, s in pairs(states) do
			if s.destroy then s:destroy() end
		end
	end

	self.currentPreview = nil
end

function Preview:prepareState(selectedStory)
	local state = {
		cleanup = nil,
		monkeyRequireCache = {},
		monkeyGlobalTable = {},
		monkeyRequireMaid = Maid.new(),
		target = nil,
	}

	function state:destroy()
		self.monkeyRequireMaid:DoCleaning()

		if self.cleanup then
			local ok, result = pcall(self.cleanup)
			if not ok then
				warn("Error cleaning up story: " .. result)
			end

			self.cleanup = nil
		end

		if self.target then
			self.target:Destroy()
		end
	end

	local function monkeyRequire(otherScript, root)
		if typeof(otherScript) == "string" then
			otherScript = resolveRequirePath(otherScript, root)
		end

		if state.monkeyRequireCache[otherScript] then
			return state.monkeyRequireCache[otherScript]
		end

		-- Bolt: Throttle hot reloading to avoid lag while typing.
		-- Reloading on every keystroke (Source change) is too expensive.
		local reloadParams = { cancelled = false }
		state.monkeyRequireMaid:GiveTask(function()
			reloadParams.cancelled = true
		end)

		state.monkeyRequireMaid:GiveTask(otherScript.Changed:connect(function()
			-- Cancel any pending reload for this script
			reloadParams.cancelled = true

			-- Create a new reload task
			local myParams = { cancelled = false }
			reloadParams = myParams

			task.delay(0.5, function()
				if myParams.cancelled then return end
				self:refreshPreview()
			end)
		end))

		-- loadstring is used to avoid cache while preserving `script` (which requiring a clone wouldn't do)
		local result, parseError = loadstring(otherScript.Source, otherScript:GetFullName())
		if result == nil then
			error(("Could not parse %s: %s"):format(otherScript:GetFullName(), parseError))
			return
		end

		local fenv = setmetatable({
			require = function(requiringScript)
				return monkeyRequire(requiringScript, otherScript)
			end,
			script = otherScript,
			_G = state.monkeyGlobalTable,
		}, {
			__index = getfenv(),
		})

		setfenv(result, fenv)

		local output = result()
		state.monkeyRequireCache[otherScript] = output

		return output
	end

	local requireOk, result = xpcall(monkeyRequire, debug.traceback, selectedStory)
	if not requireOk then
		state:destroy()
		return "Error requiring story: " .. result, nil
	end

	state.target = Instance.new("Frame")
	state.target.Name = "Preview"
	state.target.BackgroundTransparency = 1
	state.target.Size = UDim2.fromScale(1, 1)

	local execOk, cleanup = xpcall(function()
		return result(state.target)
	end, debug.traceback)

	if not execOk then
		state:destroy()
		return "Error executing story: " .. cleanup, nil
	end

	state.cleanup = cleanup
	return nil, state
end

function Preview:render()
	local selectedStory = self.props.selectedStory

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		[Roact.Ref] = self.rootRef,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
		}),

		DeviceEmulator = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(120, 30),
			ZIndex = 5,
		}, {
			Emulator = e(DeviceEmulator, {
				OnResize = self.updateDeviceSize
			})
		}),

		SelectButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.openSelection,
				Image = Assets.preview,
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		ExpandButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -45, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.expandSelection,
				Image = "rbxasset://textures/ui/VR/toggle2D.png",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		LayoutButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -90, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleLayout,
				Image = self.state.layoutMode == "Split" and "rbxasset://textures/ui/ViewToggle_Col.png" or "rbxasset://textures/ui/ViewToggle_Row.png", -- Better valid icons for layout
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		StatsButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -135, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleStats,
				Image = "http://www.roblox.com/asset/?id=6031084742",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		DebugButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -180, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleDebug,
				Image = "http://www.roblox.com/asset/?id=6026568210",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
			}),
		}),

		StatsOverlay = e(StatsOverlay, {
			Visible = self.state.showStats,
			RenderCount = self.state.renderCount,
		}),

		DebugOverlay = e(DebugOverlay, {
			Visible = self.state.showDebug,
			-- For multi-preview, we might want to target specific frames or the container.
			-- Ideally we want to outline everything inside the preview root.
			-- self.currentPreview can be a table of states.
			-- Let's pass the list of targets if possible, or just the whole preview root?
			-- Actually, the DebugOverlay expects a single "Target" root to scan.
			-- If we have multiple stories, they are parented to `self.rootRef`.
			-- So let's pass `self.rootRef`'s value as the target?
			-- But `self.rootRef` is the container for the Preview component itself.
			-- Let's try passing the ref value if available.
			Target = self.rootRef:getValue(),
		}),

		-- Bolt: Handle TrackRemoved for multiple stories
		TrackRemoved = e(Roact.createFragment, {}, (function()
			local connections = {}
			local stories = self.props.selectedStory
			if type(stories) ~= "table" then stories = {stories} end

			for i, story in ipairs(stories) do
				if story and story.Parent then
					connections["TrackRemoved_"..i] = e(EventConnection, {
						callback = function()
							if not story:IsDescendantOf(game) then
								self.props.endPreview()
							end
						end,
						event = story.AncestryChanged,
					})
				end
			end
			return connections
		end)())
	})
end

return RoactRodux.connect(function(state)
	return {
		selectedStory = state.StoryPicker,
	}
end, function(dispatch)
	return {
		endPreview = function()
			dispatch({
				type = "SetSelectedStory",
			})
		end,
	}
end)(Preview)
