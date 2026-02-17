local Hoarcekat = script:FindFirstAncestor("Hoarcekat")

local Assets = require(Hoarcekat.Plugin.Assets)
local AutomatedScrollingFrame = require(script.Parent.AutomatedScrollingFrame)
local Collapsible = require(script.Parent.Collapsible)
local IconListItem = require(script.Parent.IconListItem)
local Maid = require(Hoarcekat.Plugin.Maid)
local Roact = require(Hoarcekat.Vendor.Roact)
local RoactRodux = require(Hoarcekat.Vendor.RoactRodux)
local StudioThemeAccessor = require(script.Parent.StudioThemeAccessor)
local TextLabel = require(script.Parent.TextLabel)
local Tooltip = require(script.Parent.Tooltip)

local e = Roact.createElement

local Sidebar = Roact.PureComponent:extend("Sidebar")

local NONE = newproxy(true)
local USER_SERVICES = {
	"Workspace",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPlayer",
}

local function isStoryScript(instance)
	return instance:IsA("ModuleScript") and instance.Name:match("%.story$")
end

local function isSelected(story, selectedStory)
	if type(selectedStory) == "table" then
		for _, s in ipairs(selectedStory) do
			if s == story then return true end
		end
		return false
	end
	return story == selectedStory
end

local function SidebarList(props)
	local contents = {}

	for childName, child in pairs(props.Children) do
		if typeof(child) == "Instance" then
			contents["Instance" .. child.Name] = e(IconListItem, {
				Activated = function(rbx, input)
					props.SelectStory(child, input)
				end,
				OnRightClick = function()
					props.TogglePin(child)
				end,
				Icon = Assets.hamburger,
				Selected = isSelected(child, props.SelectedStory),
				Text = child.Name:sub(1, #child.Name - #".story"),
			})
		else
			contents["Folder" .. childName] = e(SidebarList, {
				Children = child,
				SelectStory = props.SelectStory,
				SelectedStory = props.SelectedStory,
				Title = childName,
				TogglePin = props.TogglePin,
			})
		end
	end

	return e(Collapsible, {
		Title = props.Title,
	}, contents)
end

function Sidebar:init()
	self.maid = Maid.new()
	self.watcherMaid = Maid.new()
	self.maid:GiveTask(self.watcherMaid)

	self.state = {
		searchTerm = "",
		pinnedStories = {},
		isMultiSelectEnabled = false,
		multiSelectHovered = false,
	}

	self.toggleMultiSelect = function()
		self:setState({
			isMultiSelectEnabled = not self.state.isMultiSelectEnabled
		})
	end

	self.hoverMultiSelect = function()
		self:setState({
			multiSelectHovered = true
		})
	end

	self.unhoverMultiSelect = function()
		self:setState({
			multiSelectHovered = false
		})
	end

	self.updateSearch = function(rbx)
		self:setState({
			searchTerm = rbx.Text
		})
	end

	self.togglePin = function(story)
		local pinned = self.state.pinnedStories
		local newPinned = {}
		local found = false
		for _, s in ipairs(pinned) do
			if s ~= story then
				table.insert(newPinned, s)
			else
				found = true
			end
		end

		if not found then
			table.insert(newPinned, story)
		end

		self:setState({
			pinnedStories = newPinned
		})
	end

	self.handleSelectStory = function(story, input)
		local isCtrl = false
		if input then
			if input:IsModifierKeyDown(Enum.ModifierKey.Ctrl) then
				isCtrl = true
			end
		else
			-- Fallback check if input isn't passed
			local UserInputService = game:GetService("UserInputService")
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
				isCtrl = true
			end
		end

		if self.state.isMultiSelectEnabled or isCtrl then
			self.props.toggleCompareStory(story)
		else
			self.props.setSelectedStory(story)
		end
	end

	for _, serviceName in ipairs(USER_SERVICES) do
		local service = game:GetService(serviceName)

		self:lookForStories(service)

		self.maid:GiveTask(service.DescendantAdded:Connect(function(child)
			-- Bolt: DescendantAdded fires for every descendant, so we don't need to recursively scan (O(N^2)).
			-- We just check the child itself.
			self:checkStory(child)
		end))
	end
end

function Sidebar:patchStoryScripts(patch)
	if self.cleaning then return end

	local storyScripts = {}

	for storyScript in pairs(self.state.storyScripts or {}) do
		storyScripts[storyScript] = true
	end

	local modified = false

	for key, value in pairs(patch) do
		if value == NONE then
			value = nil
		end

		if storyScripts[key] ~= value then
			modified = true
			storyScripts[key] = value
		end
	end

	if modified then
		self:setState({
			storyScripts = storyScripts,
		})
	end
end

function Sidebar:lookForStories(instance)
	for _, child in ipairs(instance:GetDescendants()) do
		self:checkStory(child)
	end
end

function Sidebar:checkStory(instance)
	if isStoryScript(instance) then
		self:addStoryScript(instance)
	else
		self:removeStoryScript(instance)
	end
end

function Sidebar:addStoryScript(storyScript)
	self.watcherMaid[storyScript] = nil

	local instanceMaid = Maid.new()

	instanceMaid:GiveTask(function()
		self:removeStoryScript(storyScript)
		self.maid[instanceMaid] = nil
	end)

	instanceMaid:GiveTask(storyScript.Changed:Connect(function()
		if not isStoryScript(storyScript) then
			-- We were a story script, now we're not, remove us
			instanceMaid:DoCleaning()
		end
	end))

	instanceMaid:GiveTask(storyScript.AncestryChanged:Connect(function()
		if not storyScript:IsDescendantOf(game) then
			-- We were removed from the data model
			instanceMaid:DoCleaning()
		end
	end))

	self:patchStoryScripts({
		[storyScript] = true,
	})

	self.maid[instanceMaid] = instanceMaid
end

function Sidebar:removeStoryScript(storyScript)
	self:patchStoryScripts({
		[storyScript] = NONE,
	})

	-- Bolt: Only watch ModuleScripts for name changes. Watching every Instance (Parts, Folders, etc.)
	-- creates thousands of unnecessary connections and checks.
	if storyScript:IsDescendantOf(game) and storyScript:IsA("ModuleScript") then
		self.watcherMaid[storyScript] = storyScript.Changed:Connect(function()
			if isStoryScript(storyScript) then
				-- We didn't use to be a story script, now we are, add us
				self.watcherMaid[storyScript] = nil
				self:addStoryScript(storyScript)
			end
		end)
	else
		self.watcherMaid[storyScript] = nil
	end
end

function Sidebar:willUnmount()
	self.cleaning = true
	self.maid:DoCleaning()
end

function Sidebar:render()
	return e(StudioThemeAccessor, {}, {
		function(theme)
			local storyTree = {}
			local searchTerm = self.state.searchTerm and self.state.searchTerm:lower() or ""
			local storyScripts = self.state.storyScripts or {}

			-- Bolt: Memoized-like structure building.
			-- In React we'd use useMemo, here we just do it efficiently in render.
			-- If the list is huge, we should move this to didUpdate/reducer, but for now,
			-- iterating the set of stories is O(N_stories), which is generally small (<1000).
			-- The O(N^2) was in DescendantAdded. This loop is fine unless N is huge.

			for storyScript in pairs(storyScripts) do
				if searchTerm ~= "" and not storyScript.Name:lower():find(searchTerm, 1, true) then
					continue
				end

				-- Build hierarchy path
				local hierarchy = {}
				local parent = storyScript

				-- Optimization: We can cache the hierarchy path for each storyScript if needed,
				-- but crawling up parents is fast enough for <1000 items.
				repeat
					table.insert(hierarchy, 1, parent)
					parent = parent.Parent
				until parent == game or parent == nil

				local current = storyTree
				for _, node in ipairs(hierarchy) do
					if node == storyScript then
						table.insert(current, storyScript)
						break
					end

					local name = node.Name

					if not current[name] then
						current[name] = {}
					end

					current = current[name]
				end
			end

			local storyLists = {}

			if #self.state.pinnedStories > 0 then
				local pinnedChildren = {}
				for _, story in ipairs(self.state.pinnedStories) do
					pinnedChildren[story.Name] = story
				end

				storyLists["0_Pinned"] = e(SidebarList, {
					Children = pinnedChildren,
					SelectStory = self.handleSelectStory,
					SelectedStory = self.props.selectedStory,
					Title = "📌 Pinned",
					TogglePin = self.togglePin,
				})
			end

			for parent, children in pairs(storyTree) do
				storyLists[parent] = e(SidebarList, {
					Children = children,
					SelectStory = self.handleSelectStory,
					SelectedStory = self.props.selectedStory,
					Title = parent,
					TogglePin = self.togglePin,
				})
			end

			return e("Frame", {
				BackgroundColor3 = theme:GetColor("ScrollBarBackground", "Default"),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.fromScale(1, 1),
			}, {
				UIListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				UIPadding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 2),
				}),

				Header = e("Frame", {
					BackgroundTransparency = 1,
					LayoutOrder = 0,
					Size = UDim2.new(1, -10, 0, 24),
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					SearchBar = e("TextBox", {
						BackgroundColor3 = theme:GetColor("InputFieldBackground", "Default"),
						BorderSizePixel = 1,
						BorderColor3 = theme:GetColor("InputFieldBorder", "Default"),
						LayoutOrder = 1,
						Size = UDim2.new(1, -28, 1, 0), -- Adjusted width
						Text = "",
						PlaceholderText = "Search...",
						TextColor3 = theme:GetColor("MainText", "Default"),
						PlaceholderColor3 = theme:GetColor("DimmedText", "Default"),
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						[Roact.Change.Text] = self.updateSearch,
					}, {
						UIPadding = e("UIPadding", {
							PaddingLeft = UDim.new(0, 5),
						}),
					}),

					MultiSelectButton = e("ImageButton", {
						BackgroundColor3 = self.state.isMultiSelectEnabled and theme:GetColor("Button", "Selected") or theme:GetColor("Button", "Default"),
						BorderSizePixel = 0,
						LayoutOrder = 2,
						Size = UDim2.fromOffset(24, 24),
						Image = "http://www.roblox.com/asset/?id=6034510026", -- Valid built-in generic icon
						ImageColor3 = theme:GetColor("MainText", "Default"),
						[Roact.Event.Activated] = self.toggleMultiSelect,
						[Roact.Event.MouseEnter] = self.hoverMultiSelect,
						[Roact.Event.MouseLeave] = self.unhoverMultiSelect,
					}, {
						Tooltip = e(Tooltip, {
							Text = "Toggle Multi-View",
							Visible = self.state.multiSelectHovered,
						}),
					}),
				}),

				StoriesLabel = e(TextLabel, {
					Font = Enum.Font.SourceSansBold,
					LayoutOrder = 1,
					Text = "STORIES",
					TextColor3 = theme:GetColor("DimmedText", "Default"),
				}),

				StoryLists = e(AutomatedScrollingFrame, {
					LayoutClass = "UIListLayout",

					Native = {
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 1, -20),
					},
				}, storyLists),
			})
		end,
	})
end

return RoactRodux.connect(function(state)
	return {
		selectedStory = state.StoryPicker,
	}
end, function(dispatch)
	return {
		setSelectedStory = function(story)
			dispatch({
				type = "SetSelectedStory",
				story = story,
			})
		end,
		toggleCompareStory = function(story)
			dispatch({
				type = "ToggleCompareStory",
				story = story,
			})
		end,
	}
end)(Sidebar)
