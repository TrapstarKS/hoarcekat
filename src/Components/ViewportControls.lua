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
			-- Bolt: Ensure we only zoom if the mouse is hovering over OUR container (to avoid zooming when scrolling sidebar)
			-- But InputChanged is global.
			-- We need a flag 'isHovered'.
			if not self.isHovered then return end

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

	-- Bolt: Move reset button logic to render properly
	local resetButton = nil
	if scale ~= 1 or pos.Magnitude > 0 then
		resetButton = e("TextButton", {
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
	end

	return e("Frame", {
		Name = "ViewportControls",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- Clip content
		-- Track Hover for Zoom
		[Roact.Event.MouseEnter] = function() self.isHovered = true end,
		[Roact.Event.MouseLeave] = function() self.isHovered = false end,
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

		-- Overlay UI for Reset
		ResetButton = resetButton and (
			self.props.PortalTarget and e(Roact.Portal, { target = self.props.PortalTarget }, {
				ZoomResetOverlay = e("ScreenGui", { DisplayOrder = 100 }, { -- Ensure it's on top
					Container = e("Frame", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
					}, { Button = resetButton })
				})
			}) or resetButton
		)
	})
end

return ViewportControls
