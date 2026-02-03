local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local StudioThemeAccessor = require(script.Parent.StudioThemeAccessor)

local e = Roact.createElement

local Tooltip = Roact.PureComponent:extend("Tooltip")

function Tooltip:render()
	local text = self.props.Text
	local visible = self.props.Visible

	return e(StudioThemeAccessor, {}, {
		function(theme)
			-- Map binding if it is one, or just use value
			local visibleValue = visible
			if type(visible) ~= "boolean" and visible.map then
				visibleValue = visible
			end

			return e("Frame", {
				Visible = visibleValue,
				ZIndex = 10,
				-- Position tooltip to the left of the button by default (since buttons are on the right)
				-- Or maybe centered below? Buttons in Preview are on bottom right.
				-- Let's put it to the LEFT of the button.
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(0, -5, 0.5, 0),
				Size = UDim2.fromOffset(0, 24), -- Width will be automatic
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = theme:GetColor("MainBackground", "Default"),
				BorderColor3 = theme:GetColor("Border", "Default"),
			}, {
				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 5),
					PaddingRight = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
				}),

				Label = e("TextLabel", {
					Text = text,
					TextColor3 = theme:GetColor("MainText", "Default"),
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					AutomaticSize = Enum.AutomaticSize.X,
					Font = Enum.Font.SourceSans,
					TextSize = 14,
				})
			})
		end,
	})
end

return Tooltip
