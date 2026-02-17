local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local ViewportControls = Roact.PureComponent:extend("ViewportControls")

function ViewportControls:init()
	self.maid = Maid.new()
	self.isDragging = false
	self.lastMousePos = Vector2.new(0, 0)

	self.onInputChanged = function(rbx, input)
		if not self.props.Enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local currentScale = self.props.Scale or 1
			-- InputObject.Position.Z is the scroll delta
			local delta = input.Position.Z
			local newScale = math.clamp(currentScale + (delta * 0.1), 0.1, 5)

			if self.props.OnChange then
				self.props.OnChange(newScale, self.props.Position)
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
	end

	self.onInputBegan = function(rbx, input)
		if not self.props.Enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.isDragging = true
			self.lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end

	self.onInputEnded = function(rbx, input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self.isDragging = false
		end
	end
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
		Active = true, -- Bolt: Critical! Ensures input events are captured here if not handled by children.

		[Roact.Event.InputChanged] = self.onInputChanged,
		[Roact.Event.InputBegan] = self.onInputBegan,
		[Roact.Event.InputEnded] = self.onInputEnded,
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
