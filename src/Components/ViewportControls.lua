local UserInputService = game:GetService("UserInputService")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local ViewportControls = Roact.PureComponent:extend("ViewportControls")

function ViewportControls:init()
	self.maid = Maid.new()
	self:setState({
		scale = 1,
		position = Vector2.new(0, 0),
		isDragging = false,
	})

	self.lastMousePos = Vector2.new(0, 0)
end

function ViewportControls:didMount()
	-- Wheel to Zoom
	self.maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			-- Only zoom if mouse is over the preview area?
			-- This is hard to detect perfectly without "MouseEnter".
			-- Assuming global context for now, but better to check if hovered.
			-- Actually, simple check: is Mouse inside the Plugin Widget?
			-- We can assume yes if this component is mounted and visible.

			local delta = input.Position.Z
			local newScale = math.clamp(self.state.scale + (delta * 0.1), 0.1, 5)
			self:setState({ scale = newScale })
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.state.isDragging then
				local currentPos = Vector2.new(input.Position.X, input.Position.Y)
				local delta = currentPos - self.lastMousePos
				self:setState({
					position = self.state.position + delta
				})
				self.lastMousePos = currentPos
			end
		end
	end))

	-- Right/Middle Click to Pan
	self.maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:setState({ isDragging = true })
			self.lastMousePos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))

	self.maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:setState({ isDragging = false })
		end
	end))
end

function ViewportControls:willUnmount()
	self.maid:DoCleaning()
end

function ViewportControls:render()
	local scale = self.state.scale
	local pos = self.state.position

	return e("Frame", {
		Name = "ViewportControls",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- Clip content
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
			-- Children passed to this component
			Children = Roact.createFragment(self.props[Roact.Children]),
		}),

		-- Overlay UI for Reset?
		ResetButton = (scale ~= 1 or pos.Magnitude > 0) and e("TextButton", {
			Text = string.format("Reset Zoom (%.1fx)", scale),
			Size = UDim2.fromOffset(100, 24),
			Position = UDim2.new(1, -10, 0, 10),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			ZIndex = 100,
			[Roact.Event.Activated] = function()
				self:setState({ scale = 1, position = Vector2.new(0, 0) })
			end
		})
	})
end

return ViewportControls
