local UserInputService = game:GetService("UserInputService")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local ViewportControls = Roact.PureComponent:extend("ViewportControls")

function ViewportControls:init()
	self.maid = Maid.new()
	self.ref = Roact.createRef()

	self.isDragging = false
	self.lastMousePos = Vector2.new(0, 0)
end

function ViewportControls:didMount()
	-- Bolt: Use Global Input with robust bounds checking.
	-- This ensures we catch input even if the internal UI blocks standard bubbling.

	self.maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if not self.props.Enabled then return end

		local frame = self.ref:getValue()
		if not frame then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Bounds Check
			local mousePos = UserInputService:GetMouseLocation()
			local absPos = frame.AbsolutePosition
			local absSize = frame.AbsoluteSize

			if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
			   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then

				local currentScale = self.props.Scale or 1
				local delta = input.Position.Z
				local newScale = math.clamp(currentScale + (delta * 0.1), 0.1, 5)

				if self.props.OnChange then
					self.props.OnChange(newScale, self.props.Position)
				end
			end

		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.isDragging then
				local currentPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentPos - self.lastMousePos

				local newPos = (self.props.Position or Vector2.new(0,0)) + delta

				if self.props.OnChange then
					self.props.OnChange(self.props.Scale, newPos)
				end

				self.lastMousePos = currentPos
			end
		end
	end))

	self.maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if not self.props.Enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			local frame = self.ref:getValue()
			if not frame then return end

			local mousePos = UserInputService:GetMouseLocation()
			local absPos = frame.AbsolutePosition
			local absSize = frame.AbsoluteSize

			if mousePos.X >= absPos.X and mousePos.X <= absPos.X + absSize.X and
			   mousePos.Y >= absPos.Y and mousePos.Y <= absPos.Y + absSize.Y then

				self.isDragging = true
				self.lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
			end
		end
	end))

	self.maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.isDragging = false
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
		[Roact.Ref] = self.ref,
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
