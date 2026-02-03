local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Selection = game:GetService("Selection")

local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local InspectorOverlay = Roact.PureComponent:extend("InspectorOverlay")

function InspectorOverlay:init()
	self.maid = Maid.new()
	self:setState({
		hoveredInstance = nil,
		hoveredProps = {}, -- { ClassName, Size, Position, Padding }
	})

	self.updateHover = function(input)
		local target = self.props.Target
		if not target then return end

		local mousePos = input.Position
		self:findInstanceAt(target, Vector2.new(mousePos.X, mousePos.Y))
	end
end

function InspectorOverlay:findInstanceAt(root, pos)
	local bestCandidate = nil
	local bestZIndex = -math.huge
	local bestDepth = -1

	local function scan(instance, depth)
		-- Bolt: Ignore self-detection of the Inspector UI itself!
		if instance.Name == "InspectorHighlight" or instance.Name == "InspectorTooltip" then return end
		if not instance:IsA("GuiObject") or not instance.Visible then return end

		local absPos = instance.AbsolutePosition
		local absSize = instance.AbsoluteSize

		if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
		   pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then

			-- Basic ZIndex check. We prefer deeper elements (children on top of parents)
			-- Bolt: Also prefer higher ZIndex if depth is equal?
			-- Actually, the render order (depth) usually defines visibility.
			if depth >= bestDepth then
				bestCandidate = instance
				bestDepth = depth
			end

			for _, child in ipairs(instance:GetChildren()) do
				scan(child, depth + 1)
			end
		end
	end

	scan(root, 0)

	if bestCandidate ~= self.state.hoveredInstance then
		-- Debug print (Uncomment if needed)
		-- if bestCandidate then warn("Inspector Hover:", bestCandidate:GetFullName()) end

		if bestCandidate then
			local padding = bestCandidate:FindFirstChildWhichIsA("UIPadding")
			self:setState({
				hoveredInstance = bestCandidate,
				hoveredProps = {
					ClassName = bestCandidate.ClassName,
					Name = bestCandidate.Name,
					Size = string.format("%.0f, %.0f", bestCandidate.AbsoluteSize.X, bestCandidate.AbsoluteSize.Y),
					Position = string.format("%.0f, %.0f", bestCandidate.AbsolutePosition.X, bestCandidate.AbsolutePosition.Y),
					Padding = padding and string.format("L:%d R:%d T:%d B:%d", padding.PaddingLeft.Offset, padding.PaddingRight.Offset, padding.PaddingTop.Offset, padding.PaddingBottom.Offset) or "None",
				}
			})
		else
			self:setState({
				hoveredInstance = Roact.None,
				hoveredProps = {}
			})
		end
	end
end

function InspectorOverlay:didMount()
	self.lastUpdate = 0

	-- Mouse Movement (Hover)
	self.maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if not self.props.Enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Bolt: Throttle inspector updates to ~30 FPS to save CPU
			local now = os.clock()
			if now - self.lastUpdate > 0.033 then
				self.lastUpdate = now
				self.updateHover(input)
			end
		end
	end))

	-- Click (Select)
	self.maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if not self.props.Enabled then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self.state.hoveredInstance and self.state.hoveredInstance ~= Roact.None then
				-- Bolt: Feature - Click to select in Explorer
				Selection:Set({self.state.hoveredInstance})
				-- print("Selected:", self.state.hoveredInstance)
			end
		end
	end))
end

function InspectorOverlay:willUnmount()
	self.maid:DoCleaning()
end

function InspectorOverlay:render()
	if not self.props.Enabled then return nil end

	local hi = self.state.hoveredInstance
	local props = self.state.hoveredProps
	local target = self.props.Target

	local highlight = nil
	local tooltip = nil

	if hi and target then
		local tAbs = target.AbsolutePosition
		local hAbs = hi.AbsolutePosition
		local relX = hAbs.X - tAbs.X
		local relY = hAbs.Y - tAbs.Y

		highlight = e("Frame", {
			Name = "InspectorHighlight", -- Bolt: Key for ignoring in scan
			BackgroundTransparency = 0.8,
			BackgroundColor3 = Color3.fromRGB(0, 170, 255),
			BorderSizePixel = 2,
			BorderColor3 = Color3.fromRGB(0, 170, 255),
			Size = UDim2.fromOffset(hi.AbsoluteSize.X, hi.AbsoluteSize.Y),
			Position = UDim2.fromOffset(relX, relY),
			ZIndex = 2147483647, -- Max ZIndex to ensure it's on top
		})

		tooltip = e("Frame", {
			Name = "InspectorTooltip", -- Bolt: Key for ignoring in scan
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderColor3 = Color3.fromRGB(100, 100, 100),
			Position = UDim2.fromOffset(relX, relY - 80), -- Above element
			ZIndex = 2147483647,
		}, {
			UIPadding = e("UIPadding", {
				PaddingTop = UDim.new(0, 5),
				PaddingBottom = UDim.new(0, 5),
				PaddingLeft = UDim.new(0, 5),
				PaddingRight = UDim.new(0, 5),
			}),
			UIListLayout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			NameLabel = e("TextLabel", {
				Text = props.Name .. " (" .. props.ClassName .. ")",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				Font = Enum.Font.SourceSansBold,
				TextSize = 14,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			SizeLabel = e("TextLabel", {
				Text = "Size: " .. props.Size,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.Code,
				TextSize = 12,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			PadLabel = e("TextLabel", {
				Text = "Pad: " .. props.Padding,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				Font = Enum.Font.Code,
				TextSize = 12,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end

	-- We render the highlight inside a FullScreen ScreenGui or just a top-level Frame?
	-- Currently Preview renders things inside 'display' or 'storyContainer'.
	-- To guarantee this is ON TOP, we should probably wrap it in a ScreenGui if possible,
	-- but Roact portals might be complex here.
	-- Let's render it as a sibling of the target in Preview.lua, effectively covering it if ZIndex is high.

	if self.props.Target then
		return e(Roact.Portal, {
			target = self.props.Target,
		}, {
			Highlight = highlight,
			Tooltip = tooltip
		})
	else
		return nil
	end
end

return InspectorOverlay
