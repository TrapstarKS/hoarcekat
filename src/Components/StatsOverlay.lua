local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local StatsOverlay = Roact.PureComponent:extend("StatsOverlay")

function StatsOverlay:init()
	self.maid = Maid.new()
	self.targetMaid = Maid.new()
	self.maid:GiveTask(self.targetMaid)

	self:setState({
		fps = 60,
		memory = 0,
		instances = 0,
	})

	self.instanceCount = 0

	self.updateInstanceTracking = function()
		self.targetMaid:DoCleaning()
		self.instanceCount = 0

		local target = self.props.Target
		if not target then return end

		-- Initial count
		self.instanceCount = #target:GetDescendants()
		self:setState({ instances = self.instanceCount })

		-- Listen for changes
		self.targetMaid:GiveTask(target.DescendantAdded:Connect(function()
			self.instanceCount = self.instanceCount + 1
			-- self:setState({ instances = self.instanceCount }) -- Too spammy to set state here?
		end))

		self.targetMaid:GiveTask(target.DescendantRemoving:Connect(function()
			self.instanceCount = self.instanceCount - 1
		end))
	end
end

function StatsOverlay:didMount()
	local lastUpdate = os.clock()
	local frames = 0

	self.updateInstanceTracking()

	self.maid:GiveTask(RunService.RenderStepped:Connect(function()
		frames = frames + 1
		local now = os.clock()
		if now - lastUpdate >= 1 then
			local fps = math.floor(frames / (now - lastUpdate))
			local memory = math.floor(Stats:GetTotalMemoryUsageMb())

			self:setState({
				fps = fps,
				memory = memory,
				instances = self.instanceCount,
			})

			frames = 0
			lastUpdate = now
		end
	end))
end

function StatsOverlay:didUpdate(prevProps)
	if prevProps.Target ~= self.props.Target then
		self.updateInstanceTracking()
	end
end

function StatsOverlay:willUnmount()
	self.maid:DoCleaning()
end

function StatsOverlay:render()
	if not self.props.Visible then
		return nil
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		Position = UDim2.new(1, -50, 0, 10), -- Positioned below the toolbar buttons
		Size = UDim2.fromOffset(120, 90),
		ZIndex = 10,
	}, {
		UICorner = e("UICorner", { CornerRadius = UDim.new(0, 4) }),
		UIListLayout = e("UIListLayout", {
			Padding = UDim.new(0, 2),
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		}),
		FPSLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.Code,
			Text = string.format("FPS: %d ⚡", self.state.fps),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		MemLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.Code,
			Text = string.format("MEM: %d MB", self.state.memory),
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		InstancesLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.Code,
			Text = string.format("INST: %d", self.state.instances),
			TextColor3 = Color3.fromRGB(255, 200, 100),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		RenderLabel = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.Code,
			Text = string.format("RELOADS: %d", self.props.RenderCount or 0),
			TextColor3 = Color3.fromRGB(150, 255, 150),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return StatsOverlay
