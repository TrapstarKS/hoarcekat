local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local DebugOverlay = Roact.PureComponent:extend("DebugOverlay")

function DebugOverlay:init()
	self.maid = Maid.new()
	self.elementMaids = {} -- [Instance] = Maid
end

function DebugOverlay:didMount()
	self:updateElements()
end

function DebugOverlay:didUpdate(prevProps)
	if prevProps.Target ~= self.props.Target or prevProps.Visible ~= self.props.Visible then
		self:updateElements()
	end
end

function DebugOverlay:willUnmount()
	self.maid:DoCleaning()
	self:clearAdornments()
end

function DebugOverlay:clearAdornments()
	for _, m in pairs(self.elementMaids) do
		m:DoCleaning()
	end
	self.elementMaids = {}
end

function DebugOverlay:updateElements()
	self.maid:DoCleaning()

	if not self.props.Visible or not self.props.Target then
		self:clearAdornments()
		return
	end

	-- Scan initial
	local function scan(obj)
		if obj:IsA("GuiObject") and obj ~= self.props.Target then
			self:adorn(obj)
		end
		for _, child in ipairs(obj:GetChildren()) do
			scan(child)
		end
	end

	scan(self.props.Target)

	-- Watch additions
	self.maid:GiveTask(self.props.Target.DescendantAdded:Connect(function(desc)
		if desc:IsA("GuiObject") then
			self:adorn(desc)
		end
	end))

	-- Watch removals
	self.maid:GiveTask(self.props.Target.DescendantRemoving:Connect(function(desc)
		if self.elementMaids[desc] then
			self.elementMaids[desc]:DoCleaning()
			self.elementMaids[desc] = nil
		end
	end))
end

function DebugOverlay:adorn(guiObject)
	if self.elementMaids[guiObject] then return end

	local m = Maid.new()

	-- Create UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "HoarcekatDebugStroke"
	stroke.Color = Color3.fromRGB(255, 0, 255) -- Magenta
	stroke.Thickness = 1
	stroke.Transparency = 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = guiObject

	m:GiveTask(stroke)

	self.elementMaids[guiObject] = m
end

function DebugOverlay:render()
	return nil
end

return DebugOverlay
