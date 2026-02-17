local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Roact = require(Hoarcekat.Vendor.Roact)
local Maid = require(Hoarcekat.Plugin.Maid)

local e = Roact.createElement

local DeviceEmulator = Roact.PureComponent:extend("DeviceEmulator")

local DEVICES = {
	{ Name = "Fit", Size = nil },
	{ Name = "iPhone 14", Size = Vector2.new(390, 844) },
	{ Name = "iPhone 14 Pro Max", Size = Vector2.new(430, 932) },
	{ Name = "iPad Pro 12.9", Size = Vector2.new(1024, 1366) },
	{ Name = "HD (1080p)", Size = Vector2.new(1920, 1080) },
	{ Name = "SD (720p)", Size = Vector2.new(1280, 720) },
	{ Name = "VGA (480p)", Size = Vector2.new(640, 480) },
}

function DeviceEmulator:init()
	local selectedDevice = DEVICES[1]
	if self.props.InitialDeviceName then
		for _, device in ipairs(DEVICES) do
			if device.Name == self.props.InitialDeviceName then
				selectedDevice = device
				break
			end
		end
	end

	self.state = {
		isOpen = false,
		selectedDevice = selectedDevice,
	}

	self.toggleDropdown = function()
		self:setState({
			isOpen = not self.state.isOpen
		})
	end

	self.selectDevice = function(device)
		self:setState({
			selectedDevice = device,
			isOpen = false,
		})
		if self.props.OnResize then
			self.props.OnResize(device.Size, device)
		end
	end
end

function DeviceEmulator:didMount()
	-- If we started with a specific device (restored from settings), trigger the resize immediately
	if self.props.InitialDeviceName and self.state.selectedDevice.Name ~= "Fit" then
		if self.props.OnResize then
			self.props.OnResize(self.state.selectedDevice.Size, self.state.selectedDevice)
		end
	end
end

function DeviceEmulator:render()
	local selected = self.state.selectedDevice

	local options = {}
	if self.state.isOpen then
		for i, device in ipairs(DEVICES) do
			options["Option_"..i] = e("TextButton", {
				Text = device.Name,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				TextColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				LayoutOrder = i,
				[Roact.Event.Activated] = function()
					self.selectDevice(device)
				end,
			})
		end
	end

	return e("Frame", {
		Size = UDim2.fromOffset(120, 24),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, {
		CurrentButton = e("TextButton", {
			Text = selected.Name .. " ▼",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			TextColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 1,
			[Roact.Event.Activated] = self.toggleDropdown,
		}),

		Dropdown = self.state.isOpen and e("Frame", {
			Position = UDim2.new(0, 0, 1, 2),
			Size = UDim2.new(1, 0, 0, #DEVICES * 24),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 1,
			ZIndex = 10,
		}, {
			Layout = e("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Options = Roact.createFragment(options)
		})
	})
end

return DeviceEmulator
