local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local ViewportControls = Roact.PureComponent:extend("ViewportControls")

function ViewportControls:init()
	self.maid = Maid.new()
	self.isDragging = false
	self.lastMousePos = Vector2.new(0, 0)
end

function ViewportControls:didMount()
	local mouse = self.props.Mouse
	if not mouse then return end

	-- Bolt: Using PluginMouse events is far more reliable for plugins than UserInputService/GuiObject events

	self.maid:GiveTask(mouse.WheelForward:Connect(function()
		if not self.props.Enabled then return end
		local currentScale = self.props.Scale or 1
		local newScale = math.clamp(currentScale + 0.1, 0.1, 5)
		if self.props.OnChange then
			self.props.OnChange(newScale, self.props.Position)
		end
	end))

	self.maid:GiveTask(mouse.WheelBackward:Connect(function()
		if not self.props.Enabled then return end
		local currentScale = self.props.Scale or 1
		local newScale = math.clamp(currentScale - 0.1, 0.1, 5)
		if self.props.OnChange then
			self.props.OnChange(newScale, self.props.Position)
		end
	end))

	self.maid:GiveTask(mouse.Button2Down:Connect(function()
		if not self.props.Enabled then return end
		self.isDragging = true
		self.lastMousePos = Vector2.new(mouse.X, mouse.Y)
	end))

	self.maid:GiveTask(mouse.Button2Up:Connect(function()
		self.isDragging = false
	end))

	self.maid:GiveTask(mouse.Move:Connect(function()
		if self.isDragging and self.props.Enabled then
			local currentPos = Vector2.new(mouse.X, mouse.Y)
			local delta = currentPos - self.lastMousePos

			local newPos = (self.props.Position or Vector2.new(0,0)) + delta

			if self.props.OnChange then
				self.props.OnChange(self.props.Scale, newPos)
			end

			self.lastMousePos = currentPos
		end
	end))
end

function ViewportControls:willUnmount()
	self.maid:DoCleaning()
end

function ViewportControls:render()
	local scale = self.props.Scale or 1
	local pos = self.props.Position or Vector2.new(0, 0)

	return e("Frame", {
		Name = "ViewportControls",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, {
		Content = e("Frame", {
			Name = "ZoomContainer",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(pos.X, pos.Y),
			BackgroundTransparency = 1,
		}, {
			Scale = e("UIScale", {
				Scale = scale,
			}),
			Children = Roact.createFragment(self.props[Roact.Children]),
		})
	})
end

return ViewportControls
