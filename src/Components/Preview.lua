local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Assets = require(Hoarcekat.Plugin.Assets)
local EventConnection = require(script.Parent.EventConnection)
local FloatingButton = require(script.Parent.FloatingButton)
local StatsOverlay = require(script.Parent.StatsOverlay)
local DebugOverlay = require(script.Parent.DebugOverlay)
local InspectorOverlay = require(script.Parent.InspectorOverlay)
local DeviceEmulator = require(script.Parent.DeviceEmulator)
local Maid = require(Hoarcekat.Plugin.Maid)
local Roact = require(Hoarcekat.Vendor.Roact)
local RoactRodux = require(Hoarcekat.Vendor.RoactRodux)
local resolveRequirePath = require(Hoarcekat.Plugin.resolveRequirePath)

local e = Roact.createElement

local Preview = Roact.PureComponent:extend("Preview")

function Preview:init()
	self.rootRef = Roact.createRef()
	self.storyContainerRef = Roact.createRef()

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

		self:refreshPreview()
	end

	self.state = {
		showStats = false,
		showDebug = false,
		showInspector = false,
		renderCount = 0,
		layoutMode = "Stack", -- "Split" or "Stack" (Default: Stack)
		deviceSize = nil, -- Vector2 or nil
		deviceName = nil, -- Saved device name
		isPoppedOut = false,
		backgroundColorIndex = 1,
		hoveredButton = nil,
		customBgColor = nil, -- For custom settings
		customBgImage = nil,
		showBgControls = false,
	}

	self.setHoveredButton = function(key)
		self:setState({
			hoveredButton = key
		})
	end

	self.clearHoveredButton = function(key)
		if self.state.hoveredButton == key then
			self:setState({
				hoveredButton = Roact.None
			})
		end
	end

	-- Load settings
	if self.props.Plugin then
		task.spawn(function()
			-- Load Device Name
			local successDevice, savedName = pcall(function()
				return self.props.Plugin:GetSetting("Hoarcekat_DeviceName")
			end)
			if successDevice and savedName then
				self:setState({ deviceName = savedName })
			end

			-- Load Layout Mode
			local successLayout, savedLayout = pcall(function()
				return self.props.Plugin:GetSetting("Hoarcekat_LayoutMode")
			end)
			if successLayout and savedLayout and (savedLayout == "Split" or savedLayout == "Stack") then
				self:setState({ layoutMode = savedLayout })
			end

			-- Load Custom BG
			local successBg, savedBg = pcall(function()
				return self.props.Plugin:GetSetting("Hoarcekat_CustomBg")
			end)
			if successBg and savedBg then
				-- Saved as string "r,g,b" or "imageid"
				if savedBg:match("^%d+,%d+,%d+$") then
					local r, g, b = savedBg:match("^(%d+),(%d+),(%d+)$")
					self:setState({
						customBgColor = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b)),
						backgroundColorIndex = 0 -- 0 indicates custom
					})
				elseif savedBg:len() > 0 then
					self:setState({
						customBgImage = savedBg,
						backgroundColorIndex = 0
					})
				end
			end
		end)
	end

	self.toggleBackgroundColor = function()
		if self.state.showBgControls then
			self:setState({ showBgControls = false })
			return
		end

		local colors = {
			Color3.fromRGB(0, 0, 0),       -- Black
			Color3.fromRGB(255, 255, 255), -- White
			Color3.fromRGB(46, 46, 46),    -- Dark Grey (Roblox Dark)
			Color3.fromRGB(240, 240, 240), -- Light Grey (Roblox Light)
		}

		local nextIndex = (self.state.backgroundColorIndex % #colors) + 1
		self:setState({
			backgroundColorIndex = nextIndex,
			customBgColor = nil,
			customBgImage = nil,
		})
	end

	self.openBgControls = function()
		self:setState({
			showBgControls = not self.state.showBgControls
		})
	end

	self.applyCustomBg = function(text)
		if text:match("^%d+,%d+,%d+$") then
			local r, g, b = text:match("^(%d+),(%d+),(%d+)$")
			local col = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
			self:setState({
				customBgColor = col,
				customBgImage = nil,
				backgroundColorIndex = 0,
				showBgControls = false
			})
			if self.props.Plugin then
				pcall(function() self.props.Plugin:SetSetting("Hoarcekat_CustomBg", text) end)
			end
		else
			-- Assume Image ID
			local id = text
			if not id:match("^rbxassetid://") and not id:match("^http") and id:match("^%d+$") then
				id = "rbxassetid://" .. id
			end

			self:setState({
				customBgImage = id,
				customBgColor = nil,
				backgroundColorIndex = 0,
				showBgControls = false
			})
			if self.props.Plugin then
				pcall(function() self.props.Plugin:SetSetting("Hoarcekat_CustomBg", id) end)
			end
		end
	end

	self.popOutWidget = nil
	self.togglePopOut = function()
		if not self.props.Plugin then return end

		if not self.popOutWidget then
			local widget = self.props.Plugin:CreateDockWidgetPluginGui(
				"HoarcekatPreviewPopOut_v2", -- Changed ID to force new widget creation if old one is stuck
				DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 800, 600)
			)
			widget.Title = "Hoarcekat Preview"
			widget.Name = "HoarcekatPreviewPopOut"
			widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

			-- Bolt: Ensure we listen to the widget's close event effectively
			widget:GetPropertyChangedSignal("Enabled"):Connect(function()
				-- Only update state if it actually changed to avoid cycles
				if self.state.isPoppedOut ~= widget.Enabled then
					self:setState({
						isPoppedOut = widget.Enabled
					})
				end
			end)

			self.popOutWidget = widget
		end

		-- Explicitly set enabled state
		self.popOutWidget.Enabled = not self.popOutWidget.Enabled

		-- Force state update immediately for responsiveness, though signal will also fire
		self:setState({
			isPoppedOut = self.popOutWidget.Enabled
		})
	end

	self.updateDeviceSize = function(size, device)
		self:setState({
			deviceSize = size,
			deviceName = device and device.Name
		})

		if device and self.props.Plugin then
			pcall(function()
				self.props.Plugin:SetSetting("Hoarcekat_DeviceName", device.Name)
			end)
		end
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

	self.toggleInspector = function()
		self:setState({
			showInspector = not self.state.showInspector
		})
	end

	self.toggleLayout = function()
		local newMode = self.state.layoutMode == "Split" and "Stack" or "Split"
		self:setState({
			layoutMode = newMode
		})

		if self.props.Plugin then
			pcall(function()
				self.props.Plugin:SetSetting("Hoarcekat_LayoutMode", newMode)
			end)
		end
	end

	self.deviceScaleRef = nil
	self.updateScale = function()
		if not self.state.deviceSize or not self.deviceScaleRef then
			return
		end

		local container = self.rootRef:getValue()
		if not container then return end

		-- Account for padding (5px on left/top + margin)
		local availableSize = container.AbsoluteSize - Vector2.new(20, 20)
		local deviceSize = self.state.deviceSize

		if availableSize.X <= 0 or availableSize.Y <= 0 then return end

		local scale = math.min(availableSize.X / deviceSize.X, availableSize.Y / deviceSize.Y, 1)
		self.deviceScaleRef.Scale = scale
	end
end

function Preview:didMount()
	self:refreshPreview()
end

function Preview:didUpdate(prevProps, prevState)
	if prevProps.selectedStory ~= self.props.selectedStory
		or prevState.deviceSize ~= self.state.deviceSize
		or prevState.layoutMode ~= self.state.layoutMode
		or prevState.backgroundColorIndex ~= self.state.backgroundColorIndex
		or prevState.isPoppedOut ~= self.state.isPoppedOut then
		self:refreshPreview()
	end
end

function Preview:willUnmount()
	self:clearPreview()

	if self.display then
		self.display:Destroy()
	end

	if self.popOutWidget then
		self.popOutWidget:Destroy()
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

	local parent
	if self.expand then
		parent = self.display
	elseif self.state.isPoppedOut and self.popOutWidget then
		parent = self.popOutWidget
	else
		parent = self.storyContainerRef:getValue()
	end

	for _, state in pairs(states) do
		if state.target then
			state.target.Parent = parent
		end
	end
end

function Preview:refreshPreview()
	-- Bolt: Debounce refresh to avoid rapid reloads (infinite loops)
	local now = os.clock()
	if self.lastRefreshTime and (now - self.lastRefreshTime < 0.1) then
		return
	end
	self.lastRefreshTime = now

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
		-- Bolt: Always wrap to apply background color, even if not emulating size (fit mode)
		local dSize = self.state.deviceSize
		local bgColors = {
			Color3.fromRGB(0, 0, 0),       -- Black
			Color3.fromRGB(255, 255, 255), -- White
			Color3.fromRGB(46, 46, 46),    -- Dark Grey
			Color3.fromRGB(240, 240, 240), -- Light Grey
		}
		local bgColor = bgColors[self.state.backgroundColorIndex]
		local bgImage = nil

		if self.state.backgroundColorIndex == 0 then
			if self.state.customBgColor then
				bgColor = self.state.customBgColor
			elseif self.state.customBgImage then
				bgColor = Color3.new(1, 1, 1)
				bgImage = self.state.customBgImage
			else
				bgColor = bgColors[1] -- Fallback
			end
		elseif not bgColor then
			bgColor = bgColors[1]
		end

		-- Bolt: Disable emulation wrapper/background when expanded or popped out to avoid obstruction
		local isExpandedMode = self.expand or self.state.isPoppedOut

		if dSize and not isExpandedMode then
			local container = Instance.new("Frame")
			container.Name = "DeviceContainer"
			container.BackgroundTransparency = 1
			container.Size = UDim2.fromScale(1, 1)

			local wrapper = Instance.new("ImageLabel") -- Changed to ImageLabel to support ImageID
			wrapper.Name = "DeviceWrapper"
			wrapper.Size = UDim2.fromOffset(dSize.X, dSize.Y)
			wrapper.AnchorPoint = Vector2.new(0.5, 0.5)
			wrapper.Position = UDim2.fromScale(0.5, 0.5)

			wrapper.BackgroundColor3 = bgColor
			if bgImage then
				wrapper.Image = bgImage
				wrapper.BackgroundTransparency = 0
			else
				wrapper.Image = ""
				wrapper.BackgroundTransparency = 0
			end

			wrapper.BorderSizePixel = 2
			wrapper.BorderColor3 = Color3.fromRGB(100, 100, 100)
			wrapper.ClipsDescendants = true
			wrapper.Parent = container

			local scale = Instance.new("UIScale")
			scale.Parent = wrapper
			self.deviceScaleRef = scale
			self.updateScale()

			nextState.target.Parent = wrapper
			nextState.target = container -- Replace target with container for display update
		elseif not isExpandedMode then
			-- No specific device size (Fit mode)
			-- We still want to apply the background color behind the story
			local container = Instance.new("ImageLabel") -- Changed to ImageLabel
			container.Name = "FitContainer"
			container.Size = UDim2.fromScale(1, 1)
			container.BackgroundColor3 = bgColor
			if bgImage then
				container.Image = bgImage
				container.BackgroundTransparency = 0
			else
				container.Image = ""
				container.BackgroundTransparency = 0
			end
			container.BorderSizePixel = 0

			nextState.target.Parent = container
			nextState.target = container
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
	self.deviceScaleRef = nil
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
		-- Bolt: Ensure proper cleanup order.
		-- 1. Run user cleanup (disconnects user events)
		if self.cleanup then
			local ok, result = pcall(self.cleanup)
			if not ok then
				warn("Error cleaning up story: " .. result)
			end
			self.cleanup = nil
		end

		-- 2. Clean up internal connections (hot reload listeners)
		self.monkeyRequireMaid:DoCleaning()

		-- 3. Clear environment references to allow GC
		table.clear(self.monkeyGlobalTable)
		table.clear(self.monkeyRequireCache)

		-- 4. Destroy target UI
		if self.target then
			self.target:Destroy()
			self.target = nil
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

		-- Bolt: Create a sandbox to intercept potentially leaking connections (RunService, etc)
		-- We need to proxy global services.
		local env = getfenv()
		local sandbox = {}

		-- Proxy 'Instance' to track creation
		local instanceProxy = newproxy(true)
		local instanceMeta = getmetatable(instanceProxy)
		instanceMeta.__index = function(_, key)
			local realValue = Instance[key]
			if key == "new" then
				return function(className, parent)
					local obj = Instance.new(className, parent)
					state.monkeyRequireMaid:GiveTask(obj) -- Track ALL instances
					return obj
				end
			elseif key == "fromExisting" then
				return function(existing)
					local obj = Instance.fromExisting(existing)
					state.monkeyRequireMaid:GiveTask(obj)
					return obj
				end
			end
			return realValue
		end

		-- Proxy 'game' to intercept GetService
		local gameProxy = newproxy(true)
		local gameMeta = getmetatable(gameProxy)
		local serviceCache = {} -- Bolt: Cache services to avoid creating new proxies every call

		gameMeta.__index = function(_, key)
			if key == "GetService" then
				return function(_, serviceName)
					if serviceCache[serviceName] then
						return serviceCache[serviceName]
					end

					local service = game:GetService(serviceName)
					-- Intercept RunService to track connections
					if serviceName == "RunService" then
						local rsProxy = newproxy(true)
						local rsMeta = getmetatable(rsProxy)
						rsMeta.__index = function(_, rsKey)
							local realValue = service[rsKey]
							-- Wrap signals to track connection
							if (rsKey == "Heartbeat" or rsKey == "RenderStepped" or rsKey == "Stepped") and typeof(realValue) == "RBXScriptSignal" then
								local signalProxy = newproxy(true)
								local signalMeta = getmetatable(signalProxy)
								signalMeta.__index = function(_, sigKey)
									if sigKey == "Connect" then
										return function(_, callback)
											local conn = realValue:Connect(callback)
											state.monkeyRequireMaid:GiveTask(conn) -- Track it!
											return conn
										end
									end
									return realValue[sigKey]
								end
								return signalProxy
							elseif typeof(realValue) == "function" then
								-- Bolt: Fix for method calls like RunService:IsStudio().
								-- The proxy 'self' causes the real method to fail because it expects a Service instance.
								-- We wrap it to ignore the proxy 'self' and pass the real service.
								return function(_, ...)
									return realValue(service, ...)
								end
							end
							return realValue
						end
						serviceCache[serviceName] = rsProxy
						return rsProxy
					end

					serviceCache[serviceName] = service
					return service
				end
			end
			return game[key]
		end

		local fenv = setmetatable({
			require = function(requiringScript)
				return monkeyRequire(requiringScript, otherScript)
			end,
			script = otherScript,
			_G = state.monkeyGlobalTable,
			game = gameProxy, -- Inject proxy
			Instance = instanceProxy, -- Inject proxy
		}, {
			__index = env,
		})

		setfenv(result, fenv)

		local output = result()
		state.monkeyRequireCache[otherScript] = output

		return output
	end

	local requireOk, result = xpcall(monkeyRequire, debug.traceback, selectedStory)
	if not requireOk then
		-- Bolt: Even if requiring fails, we MUST keep the maid/listeners active.
		-- If we destroy the state here, we lose the `.Changed` event on the story script,
		-- so the user can never "fix" the syntax error by typing.
		-- Instead of destroying, we return the error but keep the state alive (sans target).
		return "Error requiring story: " .. result, state
	end

	state.target = Instance.new("Frame")
	state.target.Name = "Preview"
	state.target.BackgroundTransparency = 1
	state.target.Size = UDim2.fromScale(1, 1)
	-- Bolt: Ensure the Preview frame doesn't block input for the Inspector
	-- But it must allow child elements to receive input.
	-- Frames by default block input if Active is true or if they have a background (but transparency=1 usually passes through).
	-- Just to be safe for Click-to-Select.
	state.target.Active = false

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
		[Roact.Change.AbsoluteSize] = self.updateScale,
	}, {
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 5),
			PaddingTop = UDim.new(0, 5),
		}),

		DeviceEmulator = DeviceEmulator and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(120, 30),
			ZIndex = 5,
		}, {
			Emulator = e(DeviceEmulator, {
				OnResize = self.updateDeviceSize,
				InitialDeviceName = self.state.deviceName,
			})
		}),

		SelectButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.99, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Select" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.openSelection,
				Image = Assets.preview,
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Show in Explorer",
				OnHover = function() self.setHoveredButton("Select") end,
				OnUnhover = function() self.clearHoveredButton("Select") end,
			}),
		}),

		ExpandButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -45, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Expand" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.expandSelection,
				Image = "rbxasset://textures/ui/VR/toggle2D.png",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Expand / Collapse",
				OnHover = function() self.setHoveredButton("Expand") end,
				OnUnhover = function() self.clearHoveredButton("Expand") end,
			}),
		}),

		PopOutButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -90, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "PopOut" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.togglePopOut,
				Image = "http://www.roblox.com/asset/?id=6026568256",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				ImageColor3 = self.state.isPoppedOut and Color3.fromRGB(0, 170, 255) or Color3.new(1, 1, 1),
				Tooltip = "Pop Out Window",
				OnHover = function() self.setHoveredButton("PopOut") end,
				OnUnhover = function() self.clearHoveredButton("PopOut") end,
			}),
		}),

		LayoutButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -135, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Layout" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleLayout,
				Image = self.state.layoutMode == "Split" and "http://www.roblox.com/asset/?id=6031225820" or "http://www.roblox.com/asset/?id=6026568194",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Change Multi-View Layout. (" .. self.state.layoutMode .. ")",
				OnHover = function() self.setHoveredButton("Layout") end,
				OnUnhover = function() self.clearHoveredButton("Layout") end,
			}),
		}),

		BackgroundColorButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -270, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Background" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleBackgroundColor,
				-- Right click to open controls
				[Roact.Event.MouseButton2Click] = self.openBgControls,
				Image = "http://www.roblox.com/asset/?id=6026568253",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Change Background (Right Click for Custom)",
				OnHover = function() self.setHoveredButton("Background") end,
				OnUnhover = function() self.clearHoveredButton("Background") end,
			}),

			Controls = self.state.showBgControls and e("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(0, -5, 0, 0), -- To the left of the button
				Size = UDim2.fromOffset(200, 40),
				BackgroundColor3 = Color3.fromRGB(46, 46, 46),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				ZIndex = 20,
			}, {
				Input = e("TextBox", {
					Size = UDim2.new(1, -10, 1, -10),
					Position = UDim2.fromOffset(5, 5),
					Text = "",
					PlaceholderText = "R,G,B or Image ID",
					ClearTextOnFocus = false,
					BackgroundColor3 = Color3.fromRGB(30, 30, 30),
					TextColor3 = Color3.new(1, 1, 1),
					[Roact.Event.FocusLost] = function(rbx)
						self.applyCustomBg(rbx.Text)
					end
				})
			})
		}),

		StatsButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -180, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Stats" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleStats,
				Image = "http://www.roblox.com/asset/?id=6031084742",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Toggle Stats Performance",
				OnHover = function() self.setHoveredButton("Stats") end,
				OnUnhover = function() self.clearHoveredButton("Stats") end,
			}),
		}),

		DebugButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -225, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Debug" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleDebug,
				Image = "http://www.roblox.com/asset/?id=6026568210",
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Toggle Debug Overlay",
				OnHover = function() self.setHoveredButton("Debug") end,
				OnUnhover = function() self.clearHoveredButton("Debug") end,
			}),
		}),

		InspectorButton = e("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.99, -315, 0.99),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = self.state.hoveredButton == "Inspector" and 10 or 2,
		}, {
			Button = e(FloatingButton, {
				Activated = self.toggleInspector,
				Image = "rbxasset://textures/StudioToolbox/Search.png", -- Generic search/eye icon
				ImageSize = UDim.new(0, 24),
				Size = UDim.new(0, 40),
				Tooltip = "Toggle Element Inspector",
				OnHover = function() self.setHoveredButton("Inspector") end,
				OnUnhover = function() self.clearHoveredButton("Inspector") end,
			}),
		}),

		StatsOverlay = (function()
			if not StatsOverlay then return nil end

			local target = self.storyContainerRef:getValue()
			local portalTarget = nil

			if self.expand and self.display then
				target = self.display
				portalTarget = self.display
			elseif self.state.isPoppedOut and self.popOutWidget then
				target = self.popOutWidget
				portalTarget = self.popOutWidget
			end

			local overlay = e(StatsOverlay, {
				Visible = self.state.showStats,
				RenderCount = self.state.renderCount,
				Target = target,
			})

			if portalTarget then
				return e(Roact.Portal, { target = portalTarget }, { Overlay = overlay })
			end
			return overlay
		end)(),

		StoryContainer = e("Frame", {
			Name = "StoryContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			[Roact.Ref] = self.storyContainerRef,
		}),

		DebugOverlay = DebugOverlay and e(DebugOverlay, {
			Visible = self.state.showDebug,
			Target = (function()
				if self.expand and self.display then
					return self.display
				elseif self.state.isPoppedOut and self.popOutWidget then
					return self.popOutWidget
				else
					return self.storyContainerRef:getValue()
				end
			end)(),
		}),

		InspectorOverlay = InspectorOverlay and e(InspectorOverlay, {
			Enabled = self.state.showInspector,
			Target = (function()
				-- Inspector should target the active display area
				if self.expand and self.display then
					return self.display
				elseif self.state.isPoppedOut and self.popOutWidget then
					return self.popOutWidget
				else
					return self.storyContainerRef:getValue()
				end
			end)(),
		}),

		-- Bolt: Handle TrackRemoved for multiple stories
		-- Using "Folder" instead of createFragment to avoid potential version issues or nil errors
		TrackRemoved = e("Folder", {}, (function()
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
