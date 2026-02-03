local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

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

		-- Use PlayerGui:GetGuiObjectsAtPosition for standard UI scanning
		-- Since this is running in Plugin, we might need a different strategy depending on where 'target' is.
		-- However, GetGuiObjectsAtPosition works relative to the screen.

		local mousePos = input.Position
		local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then
			-- In edit mode, we might not have PlayerGui readily available for this API if checking inside a widget.
			-- Fallback: Recursive raycast/check is expensive.
			-- Actually, CoreGui has generic GetGuiObjectsAtPosition methods? No.
			-- If 'target' is in CoreGui (Expanded), `playerGui:GetGuiObjectsAtPosition` usually ignores CoreGui.
			-- If 'target' is in Widget, it's definitely ignored.

			-- Robust solution: Recursively check 'target' descendants for "Contains Point".
			-- Since we only care about the previewed story, this is actually faster than scanning the whole screen.
			self:findInstanceAt(target, Vector2.new(mousePos.X, mousePos.Y))
			return
		end

		self:findInstanceAt(target, Vector2.new(mousePos.X, mousePos.Y))
	end
end

function InspectorOverlay:findInstanceAt(root, pos)
	local bestCandidate = nil
	local bestZIndex = -math.huge
	local bestDepth = -1

	local function scan(instance, depth)
		if not instance:IsA("GuiObject") or not instance.Visible then return end

		local absPos = instance.AbsolutePosition
		local absSize = instance.AbsoluteSize

		if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
		   pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then

			-- Basic ZIndex check (Roblox uses GlobalZIndex for Sibling, but locally ZIndex matters)
			-- We prefer deeper elements (children on top of parents)
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
	self.maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self.updateHover(input)
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

	local highlight = nil
	local tooltip = nil

	if hi then
		highlight = e("Frame", {
			BackgroundTransparency = 0.8,
			BackgroundColor3 = Color3.fromRGB(0, 170, 255),
			BorderSizePixel = 2,
			BorderColor3 = Color3.fromRGB(0, 170, 255),
			Size = UDim2.fromOffset(hi.AbsoluteSize.X, hi.AbsoluteSize.Y),
			Position = UDim2.fromOffset(hi.AbsolutePosition.X, hi.AbsolutePosition.Y),
			ZIndex = 100, -- On top of everything
		})

		tooltip = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderColor3 = Color3.fromRGB(100, 100, 100),
			Position = UDim2.fromOffset(hi.AbsolutePosition.X, hi.AbsolutePosition.Y - 80), -- Above element
			ZIndex = 101,
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
		return Roact.createPortal({
			Highlight = highlight,
			Tooltip = tooltip
		}, self.props.Target)
	else
		return nil
	end
end

return InspectorOverlay
