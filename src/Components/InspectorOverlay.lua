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

		-- Debug: Check what we are scanning
		-- print("Scanning:", instance.Name, instance.ClassName, depth)

		-- Handle ScreenGui/Roots which are not GuiObjects but have children
		if not instance:IsA("GuiObject") then
			if instance:IsA("ScreenGui") or instance:IsA("Folder") or instance:IsA("Frame") or instance == root then
				for _, child in ipairs(instance:GetChildren()) do
					scan(child, depth + 1)
				end
			end
			return
		end

		if not instance.Visible then return end

		local absPos = instance.AbsolutePosition
		local absSize = instance.AbsoluteSize

		-- print("Checking:", instance.Name, "Pos:", absPos, "Size:", absSize, "Mouse:", pos)

		if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and
		   pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then

			-- Basic ZIndex check. We prefer deeper elements (children on top of parents)
			if depth >= bestDepth then
				bestCandidate = instance
				bestDepth = depth
				-- print("New Candidate:", instance.Name)
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
	local guides = nil

	if hi and target then
		-- Bolt: Safely get AbsolutePosition for Target (handles ScreenGui/PluginGui)
		local tAbs = Vector2.new(0, 0)
		if target:IsA("GuiObject") then
			tAbs = target.AbsolutePosition
		end

		local hAbs = hi.AbsolutePosition
		local hSize = hi.AbsoluteSize
		local relX = hAbs.X - tAbs.X
		local relY = hAbs.Y - tAbs.Y

		highlight = e("Frame", {
			Name = "InspectorHighlight", -- Bolt: Key for ignoring in scan
			BackgroundTransparency = 0.8,
			BackgroundColor3 = Color3.fromRGB(0, 170, 255),
			BorderSizePixel = 2,
			BorderColor3 = Color3.fromRGB(0, 170, 255),
			Size = UDim2.fromOffset(hSize.X, hSize.Y),
			Position = UDim2.fromOffset(relX, relY),
			ZIndex = 2147483647, -- Max ZIndex to ensure it's on top
		})

		-- Smart Guides Logic
		local parent = hi.Parent
		if parent and (parent:IsA("GuiObject") or parent == target) then
			local pAbs = Vector2.new(0, 0)
			local pSize = Vector2.new(0, 0)

			if parent:IsA("GuiObject") then
				pAbs = parent.AbsolutePosition
				pSize = parent.AbsoluteSize
			elseif parent == target and target:IsA("GuiObject") then
				pAbs = target.AbsolutePosition
				pSize = target.AbsoluteSize
			elseif parent == target then
				-- Target is LayerCollector, assume full screen?
				-- Hard to know exact size without AbsoluteSize API on ScreenGui (it exists on ScreenGui.AbsoluteSize in newer API but safe to fallback)
				if target:IsA("ScreenGui") or target:IsA("DockWidgetPluginGui") then
					pAbs = Vector2.new(0, 0) -- Relative to target root
					-- We can't easily guess size, so maybe skip guides or rely on screen bounds?
					-- Let's skip guides if parent is a Root Layer to avoid visual clutter/bugs
					parent = nil
				end
			end

			if parent then
				local distTop = math.floor(hAbs.Y - pAbs.Y)
				local distLeft = math.floor(hAbs.X - pAbs.X)
				local distRight = math.floor((pAbs.X + pSize.X) - (hAbs.X + hSize.X))
				local distBottom = math.floor((pAbs.Y + pSize.Y) - (hAbs.Y + hSize.Y))

				local function createGuide(name, size, pos, text)
					return e("Frame", {
						Name = "Guide_" .. name,
						BackgroundColor3 = Color3.fromRGB(255, 100, 100),
						BorderSizePixel = 0,
						Size = size,
						Position = pos,
						ZIndex = 2147483646,
					}, {
						Label = e("TextLabel", {
							Text = text,
							TextColor3 = Color3.fromRGB(255, 100, 100),
							TextStrokeTransparency = 0,
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							Position = UDim2.fromOffset(5, 5), -- Offset slightly
							TextSize = 10,
							Font = Enum.Font.Code,
							ZIndex = 2147483647,
						})
					})
				end

				local guideColor = Color3.fromRGB(255, 80, 80)
				local thin = 1

				-- Render Lines extending from element to parent edges
				-- Top Line (Center of element up to parent top)
				local midX = relX + (hSize.X / 2)
				local midY = relY + (hSize.Y / 2)

				guides = e("Folder", {}, {
					Top = distTop > 0 and e("Frame", {
						Name = "GuideTop",
						BackgroundColor3 = guideColor,
						BorderSizePixel = 0,
						Size = UDim2.new(0, 1, 0, distTop),
						Position = UDim2.fromOffset(midX, relY - distTop),
						ZIndex = 2147483646,
					}, {
						Label = e("TextLabel", {
							Text = tostring(distTop),
							TextColor3 = guideColor,
							TextStrokeTransparency = 1,
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 20, 0, 10),
							Position = UDim2.new(0, 2, 0.5, -5),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextSize = 10,
							Font = Enum.Font.Code,
							ZIndex = 2147483647,
						})
					}),
					Bottom = distBottom > 0 and e("Frame", {
						Name = "GuideBottom",
						BackgroundColor3 = guideColor,
						BorderSizePixel = 0,
						Size = UDim2.new(0, 1, 0, distBottom),
						Position = UDim2.fromOffset(midX, relY + hSize.Y),
						ZIndex = 2147483646,
					}, {
						Label = e("TextLabel", {
							Text = tostring(distBottom),
							TextColor3 = guideColor,
							TextStrokeTransparency = 1,
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 20, 0, 10),
							Position = UDim2.new(0, 2, 0.5, -5),
							TextXAlignment = Enum.TextXAlignment.Left,
							TextSize = 10,
							Font = Enum.Font.Code,
							ZIndex = 2147483647,
						})
					}),
					Left = distLeft > 0 and e("Frame", {
						Name = "GuideLeft",
						BackgroundColor3 = guideColor,
						BorderSizePixel = 0,
						Size = UDim2.new(0, distLeft, 0, 1),
						Position = UDim2.fromOffset(relX - distLeft, midY),
						ZIndex = 2147483646,
					}, {
						Label = e("TextLabel", {
							Text = tostring(distLeft),
							TextColor3 = guideColor,
							TextStrokeTransparency = 1,
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 20, 0, 10),
							Position = UDim2.new(0.5, -10, 0, -12),
							TextXAlignment = Enum.TextXAlignment.Center,
							TextSize = 10,
							Font = Enum.Font.Code,
							ZIndex = 2147483647,
						})
					}),
					Right = distRight > 0 and e("Frame", {
						Name = "GuideRight",
						BackgroundColor3 = guideColor,
						BorderSizePixel = 0,
						Size = UDim2.new(0, distRight, 0, 1),
						Position = UDim2.fromOffset(relX + hSize.X, midY),
						ZIndex = 2147483646,
					}, {
						Label = e("TextLabel", {
							Text = tostring(distRight),
							TextColor3 = guideColor,
							TextStrokeTransparency = 1,
							BackgroundTransparency = 1,
							Size = UDim2.new(0, 20, 0, 10),
							Position = UDim2.new(0.5, -10, 0, -12),
							TextXAlignment = Enum.TextXAlignment.Center,
							TextSize = 10,
							Font = Enum.Font.Code,
							ZIndex = 2147483647,
						})
					})
				})
			end
		end

		tooltip = e("Frame", {
			Name = "InspectorTooltip", -- Bolt: Key for ignoring in scan
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderColor3 = Color3.fromRGB(100, 100, 100),
			Position = UDim2.fromOffset(relX, relY - 80), -- Above element
			ZIndex = 2147483647,
		}, {

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
			Guides = guides,
			Tooltip = tooltip
		})
	else
		return nil
	end
end

return InspectorOverlay
