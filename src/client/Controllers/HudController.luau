--[[
	HudController
	Draws the on-screen interface entirely from code:
	  - resource bar (top left)
	  - colony panel: population, jobs, happiness, day (top right)
	  - build bar with a button per building, plus Demolish (bottom)
	  - message feed (top centre)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local HudController = {}

local controllers
local player = Players.LocalPlayer

local THEME = {
	Panel = Color3.fromRGB(34, 28, 22),
	PanelLight = Color3.fromRGB(58, 47, 36),
	Accent = Color3.fromRGB(214, 170, 92),
	Text = Color3.fromRGB(245, 235, 215),
	Muted = Color3.fromRGB(180, 165, 140),
	Good = Color3.fromRGB(130, 200, 110),
	Bad = Color3.fromRGB(230, 100, 90),
}

local RESOURCE_COLORS = {
	Wood = Color3.fromRGB(150, 100, 60),
	Stone = Color3.fromRGB(150, 150, 158),
	Food = Color3.fromRGB(220, 190, 90),
	Hides = Color3.fromRGB(176, 120, 84),
	Silver = Color3.fromRGB(210, 214, 224),
	Lore = Color3.fromRGB(120, 160, 230),
}

local function new(className: string, props, children)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function padding(px)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
	})
end

local function label(props)
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = THEME.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

local function moodWord(h: number): string
	if h >= 75 then
		return "Joyful"
	elseif h >= 55 then
		return "Content"
	elseif h >= 35 then
		return "Uneasy"
	end
	return "Miserable"
end

function HudController:Init(allControllers)
	controllers = allControllers
end

function HudController:Start()
	local gui = new("ScreenGui", {
		Name = "VikingHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	---------------------------------------------------------------- resources
	local resBar = new("Frame", {
		Name = "Resources",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(830, 44),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		corner(10),
		padding(8),
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), VerticalAlignment = Enum.VerticalAlignment.Center }),
	})

	local resLabels = {}
	for i, name in Config.ResourceOrder do
		local item = new("Frame", { Size = UDim2.fromOffset(122, 28), BackgroundTransparency = 1, LayoutOrder = i, Parent = resBar })
		new("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.new(0, 0, 0.5, -8),
			BackgroundColor3 = RESOURCE_COLORS[name],
			Parent = item,
		}, { corner(4) })
		resLabels[name] = label({
			Size = UDim2.new(1, -22, 1, 0),
			Position = UDim2.fromOffset(22, 0),
			Text = name .. " 0",
			Parent = item,
		})
	end

	---------------------------------------------------------------- colony panel
	local panel = new("Frame", {
		Name = "Colony",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(230, 150),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		corner(10),
		padding(10),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dayLabel = label({ Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBold, TextColor3 = THEME.Accent, LayoutOrder = 1, Parent = panel })
	local dayBar = new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = THEME.PanelLight, LayoutOrder = 2, Parent = panel }, { corner(2) })
	local dayFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Accent, Parent = dayBar }, { corner(2) })
	local popLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3, Parent = panel })
	local jobLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4, TextColor3 = THEME.Muted, TextSize = 14, Parent = panel })
	local moodLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 5, Parent = panel })
	local warnLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 6, TextColor3 = THEME.Bad, TextSize = 14, Parent = panel })

	---------------------------------------------------------------- build bar
	local buildBar = new("Frame", {
		Name = "BuildBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, {
		corner(10),
		padding(8),
		-- two rows of buttons
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(112, 54),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = 7,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local hint = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -152),
		Size = UDim2.fromOffset(640, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		Text = "Pick a building below. Walk up to trees, rocks and bushes and hold E to gather.",
		Parent = gui,
	})

	label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(330, 120),
		TextSize = 13,
		TextColor3 = THEME.Muted,
		TextStrokeTransparency = 0.5,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "1 Axe: chop trees, click to fight\n2 Pickaxe: mine rocks\n3 Bow: click to shoot\n4 Torch: F to set enemy buildings alight\nRaid Greywater Hold: walk west past your plot\nMouse wheel: zoom   Right-drag: turn   V: camera",
		Parent = gui,
	})

	local buttons = {}
	local function makeButton(key: string, title: string, sub: string, order: number)
		local b = new("TextButton", {
			Name = key,
			Size = UDim2.fromOffset(112, 54),
			BackgroundColor3 = THEME.PanelLight,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = order,
			Parent = buildBar,
		}, { corner(8) })
		new("UIStroke", { Name = "Stroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = THEME.Accent, Thickness = 2, Enabled = false, Parent = b })
		label({ Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 6), Font = Enum.Font.GothamBold, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Text = title, Parent = b })
		local costLabel = label({
			Name = "Cost",
			Size = UDim2.new(1, -6, 0, 18),
			Position = UDim2.fromOffset(3, 30),
			TextSize = 12,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			Text = sub,
			Parent = b,
		})
		buttons[key] = { button = b, cost = costLabel }
		return b
	end

	local BuildController = controllers.BuildController
	for i, buildingType in Config.BuildOrder do
		local def = Config.Buildings[buildingType]
		local b = makeButton(buildingType, def.Display, Grid.costText(def.Cost), i)
		b.Activated:Connect(function()
			BuildController:SelectBuild(buildingType)
		end)
		b.MouseEnter:Connect(function()
			hint.Text = def.Display .. ": " .. def.Description
		end)
	end
	local demolish = makeButton("Demolish", "Demolish", "refund 50%", #Config.BuildOrder + 1)
	demolish.BackgroundColor3 = Color3.fromRGB(90, 40, 34)
	demolish.Activated:Connect(function()
		BuildController:SelectDemolish()
	end)

	BuildController.ModeChanged:Connect(function(mode)
		for key, entry in buttons do
			entry.button.Stroke.Enabled = mode ~= nil and (mode.type == key or (mode.kind == "demolish" and key == "Demolish"))
		end
		if mode == nil then
			hint.Text = "Pick a building below. Walk up to trees, rocks and bushes and hold E to gather."
		elseif mode.kind == "place" then
			hint.Text = "Click to place " .. Config.Buildings[mode.type].Display .. ".  R = rotate,  Q = cancel"
		else
			hint.Text = "Click one of your buildings to tear it down.  Q = cancel"
		end
	end)

	---------------------------------------------------------------- message feed
	local feed = new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local feedOrder = 0
	local kindColor = { good = THEME.Good, bad = THEME.Bad, gain = THEME.Accent, info = THEME.Text }

	-- a big cinematic title for raid moments
	local raidTitle = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(900, 60),
		Font = Enum.Font.Fantasy,
		TextSize = 42,
		TextColor3 = Color3.fromRGB(240, 210, 150),
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		TextStrokeColor3 = Color3.fromRGB(40, 10, 6),
		Parent = gui,
	})
	local raidToken = 0
	local function showRaidTitle(text: string)
		raidToken += 1
		local token = raidToken
		raidTitle.Text = text
		raidTitle.TextTransparency = 1
		raidTitle.TextStrokeTransparency = 1
		TweenService:Create(raidTitle, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.2 }):Play()
		task.delay(4, function()
			if token == raidToken then
				TweenService:Create(raidTitle, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			end
		end)
	end

	controllers.StateController.Notified:Connect(function(text, kind)
		if kind == "raid" then
			showRaidTitle(text)
			return
		end
		feedOrder += 1
		local item = new("TextLabel", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 0.15,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextColor3 = kindColor[kind] or THEME.Text,
			Text = text,
			LayoutOrder = feedOrder,
			Parent = feed,
		}, { corner(6), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
		-- keep at most 5 messages
		local items = {}
		for _, c in feed:GetChildren() do
			if c:IsA("TextLabel") then
				table.insert(items, c)
			end
		end
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #items - 5 do
			items[i]:Destroy()
		end
		task.delay(kind == "gain" and 1.5 or 5, function()
			if item.Parent then
				local t = TweenService:Create(item, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
				t:Play()
				t.Completed:Wait()
				item:Destroy()
			end
		end)
	end)

	---------------------------------------------------------------- updates
	controllers.StateController.Changed:Connect(function(state)
		for _, name in Config.ResourceOrder do
			resLabels[name].Text = string.format("%s %d/%d", name, state.resources[name] or 0, state.storage)
		end
		dayLabel.Text = "Day " .. state.day .. "  ·  " .. (state.season or "")
		dayFill.Size = UDim2.fromScale(math.clamp(state.dayProgress, 0, 1), 1)
		popLabel.Text = string.format("Population %d / %d homes", state.population, state.housing)
		jobLabel.Text = string.format("%d working, %d idle, %d children", state.workers, state.idle, state.children)
		moodLabel.Text = string.format("Happiness %d (%s)", state.happiness, moodWord(state.happiness))
		moodLabel.TextColor3 = state.happiness >= 55 and THEME.Good or (state.happiness >= 35 and THEME.Text or THEME.Bad)
		if state.starving then
			warnLabel.Text = "Starving! Get food fast."
		elseif state.population > state.housing then
			warnLabel.Text = "Not enough housing!"
		elseif state.idle > 0 then
			warnLabel.Text = "Idle villagers: build workplaces."
			warnLabel.TextColor3 = THEME.Muted
		else
			warnLabel.Text = ""
		end
		if state.starving or state.population > state.housing then
			warnLabel.TextColor3 = THEME.Bad
		end

		local known = {}
		for _, id in state.tech or {} do
			known[id] = true
		end
		for _, buildingType in Config.BuildOrder do
			local def = Config.Buildings[buildingType]
			local entry = buttons[buildingType]
			if def.Requires and not known[def.Requires] then
				entry.cost.Text = "Research " .. Config.Tech[def.Requires].Name
				entry.cost.TextColor3 = THEME.Muted
				entry.button.BackgroundTransparency = 0.5
			else
				entry.cost.Text = Grid.costText(def.Cost)
				entry.button.BackgroundTransparency = 0
				local affordable = Grid.canAfford(state.resources, def.Cost)
				entry.cost.TextColor3 = affordable and THEME.Muted or THEME.Bad
			end
		end
	end)
end

return HudController
