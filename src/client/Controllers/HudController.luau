--[[
	HudController
	Draws the on-screen interface entirely from code:
	  - resource bar (top left)
	  - colony panel: population, jobs, happiness, day (top right)
	  - build menu with tabs (Housing, Production, ...) and building cards,
	    tooltips and Demolish (bottom centre)
	  - controls help (bottom left, H hides it)
	  - message feed (top centre)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Sounds = require(Shared.Sounds)

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

-- thin gold border used on every panel
local function frameStroke()
	return new("UIStroke", { Color = THEME.Accent, Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local DEFAULT_HINT = "Pick a tab and a building. Walk up to trees, rocks and bushes and hold E to gather."

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
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		corner(10),
		padding(8),
		frameStroke(),
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

	---------------------------------------------------------------- saga (quest guide)
	local saga = new("Frame", {
		Name = "Saga",
		Position = UDim2.fromOffset(12, 64),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.12,
		Parent = gui,
	}, {
		corner(10),
		padding(10),
		frameStroke(),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local sagaHead = label({ Size = UDim2.new(1, 0, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = THEME.Muted, LayoutOrder = 1, Parent = saga })
	local sagaTitle = label({ Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = THEME.Accent, LayoutOrder = 2, Parent = saga })
	local sagaText = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 14, LayoutOrder = 3, Parent = saga })
	local sagaBar = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = THEME.PanelLight, LayoutOrder = 4, Parent = saga }, { corner(3) })
	local sagaFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Good, Parent = sagaBar }, { corner(3) })
	local sagaReward = label({ Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = THEME.Muted, LayoutOrder = 5, Parent = saga })

	---------------------------------------------------------------- colony panel
	local panel = new("Frame", {
		Name = "Colony",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(230, 150),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		corner(10),
		padding(10),
		frameStroke(),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local dayLabel = label({ Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.GothamBold, TextColor3 = THEME.Accent, LayoutOrder = 1, Parent = panel })
	local dayBar = new("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = THEME.PanelLight, LayoutOrder = 2, Parent = panel }, { corner(2) })
	local dayFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Accent, Parent = dayBar }, { corner(2) })
	local popLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 3, Parent = panel })
	local jobLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4, TextColor3 = THEME.Muted, TextSize = 14, Parent = panel })
	local moodLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 5, Parent = panel })
	local warnLabel = label({ Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 6, TextColor3 = THEME.Bad, TextSize = 14, Parent = panel })

	---------------------------------------------------------------- build menu
	--[[
		A row of tabs (Housing, Production, ...) above a row of building
		cards. Click a tab to open it, click it again to fold the menu away.
		Hovering a card shows a tooltip with everything about the building.
	]]
	local CARD_W, CARD_H = 124, 96
	local buildMenu = new("Frame", {
		Name = "BuildMenu",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		corner(12),
		padding(8),
		frameStroke(),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	local tabRow = new("Frame", {
		Name = "Tabs",
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = buildMenu,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local cardRow = new("Frame", {
		Name = "Cards",
		Size = UDim2.fromOffset(0, CARD_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = buildMenu,
	}, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- hint line just above the menu
	local hint = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(700, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextStrokeTransparency = 0.4,
		Text = DEFAULT_HINT,
		Parent = gui,
	})
	local function placeHint()
		hint.Position = UDim2.new(0.5, 0, 1, -12 - buildMenu.AbsoluteSize.Y - 6)
	end
	buildMenu:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHint)
	placeHint()

	-- tooltip that follows the hovered card
	local tooltip = new("Frame", {
		Name = "Tooltip",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(260, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	}, {
		corner(8),
		padding(10),
		frameStroke(),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local tipTitle = label({ Size = UDim2.new(1, 0, 0, 22), Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = THEME.Accent, LayoutOrder = 1, ZIndex = 21, Parent = tooltip })
	local tipBody = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 14, LayoutOrder = 2, ZIndex = 21, Parent = tooltip })
	local tipStats = label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 3, ZIndex = 21, Parent = tooltip })
	local tipCost = label({ Size = UDim2.new(1, 0, 0, 18), TextSize = 14, Font = Enum.Font.GothamBold, LayoutOrder = 4, ZIndex = 21, Parent = tooltip })

	local lastState = nil
	local known = {}

	local function statsText(def): string
		local bits = {}
		if def.Housing then
			table.insert(bits, "Homes for " .. def.Housing)
		end
		if def.Workers then
			table.insert(bits, def.Workers .. (def.Workers == 1 and " job" or " jobs"))
		end
		for res, rate in def.Produces or {} do
			table.insert(bits, string.format("+%.2g %s/s per worker", rate, res))
		end
		if def.Storage then
			table.insert(bits, "+" .. def.Storage .. " storage")
		end
		if def.Happiness then
			table.insert(bits, "+" .. def.Happiness .. " happiness")
		end
		table.insert(bits, def.Size[1] .. "x" .. def.Size[2] .. " tiles")
		return table.concat(bits, "  ·  ")
	end

	local function shortStat(def): string
		if def.Housing then
			return def.Housing .. " homes"
		elseif def.Produces then
			local res = next(def.Produces)
			return res .. ", " .. def.Workers .. (def.Workers == 1 and " job" or " jobs")
		elseif def.Storage then
			return "+" .. def.Storage .. " storage"
		elseif def.Happiness then
			return "+" .. def.Happiness .. " happiness"
		end
		return def.Size[1] .. "x" .. def.Size[2]
	end

	local function showTooltip(buildingType: string, card: GuiObject)
		local def = Config.Buildings[buildingType]
		tipTitle.Text = (Config.BuildingIcons[buildingType] or "") .. "  " .. def.Display
		tipBody.Text = def.Description
		tipStats.Text = statsText(def)
		if def.Requires and not known[def.Requires] then
			tipCost.Text = "🔒 Research " .. Config.Tech[def.Requires].Name .. " first (T)"
			tipCost.TextColor3 = THEME.Bad
		else
			local affordable = lastState and Grid.canAfford(lastState.resources, def.Cost)
			tipCost.Text = "Cost: " .. Grid.costText(def.Cost)
			tipCost.TextColor3 = affordable and THEME.Good or THEME.Bad
		end
		local pos = card.AbsolutePosition
		tooltip.Position = UDim2.fromOffset(pos.X + card.AbsoluteSize.X / 2, pos.Y - 34)
		tooltip.Visible = true
	end

	local buttons = {}
	local function makeCard(key: string, icon: string, title: string, sub: string, order: number)
		local b = new("TextButton", {
			Name = key,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = THEME.PanelLight,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = order,
			Visible = false,
			Parent = cardRow,
		}, {
			corner(8),
			new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 180, 170)) }),
		})
		new("UIStroke", { Name = "Stroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = THEME.Accent, Thickness = 2, Enabled = false, Parent = b })
		label({ Name = "Icon", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Text = icon, Parent = b })
		label({ Size = UDim2.new(1, -6, 0, 18), Position = UDim2.fromOffset(3, 36), Font = Enum.Font.GothamBold, TextSize = 14, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Text = title, Parent = b })
		local statLabel = label({ Name = "Stat", Size = UDim2.new(1, -6, 0, 15), Position = UDim2.fromOffset(3, 56), TextSize = 12, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Center, Text = "", Parent = b })
		local costLabel = label({ Name = "Cost", Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 74), TextSize = 12, TextScaled = true, Font = Enum.Font.GothamBold, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Center, Text = sub, Parent = b })
		buttons[key] = { button = b, cost = costLabel, stat = statLabel }
		return b
	end

	local BuildController = controllers.BuildController
	local tabs = {}
	local openTab = nil

	local function setTab(index)
		openTab = index
		for i, tab in tabs do
			local active = i == index
			tab.button.BackgroundColor3 = active and THEME.Accent or THEME.PanelLight
			tab.button.TextColor3 = active and THEME.Panel or THEME.Text
			for _, buildingType in tab.buildings do
				buttons[buildingType].button.Visible = active
			end
		end
		cardRow.Visible = index ~= nil
		buttons.Demolish.button.Visible = index ~= nil
		tooltip.Visible = false
	end

	for i, category in Config.BuildCategories do
		local tabButton = new("TextButton", {
			Name = category.Name,
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.PanelLight,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = THEME.Text,
			Text = category.Icon .. "  " .. category.Name,
			LayoutOrder = i,
			Parent = tabRow,
		}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
		tabs[i] = { button = tabButton, buildings = category.Buildings }
		tabButton.Activated:Connect(function()
			setTab(openTab ~= i and i or nil)
		end)

		for j, buildingType in category.Buildings do
			local def = Config.Buildings[buildingType]
			local card = makeCard(buildingType, Config.BuildingIcons[buildingType] or "", def.Display, Grid.costText(def.Cost), i * 100 + j)
			buttons[buildingType].stat.Text = shortStat(def)
			card.Activated:Connect(function()
				BuildController:SelectBuild(buildingType)
			end)
			card.MouseEnter:Connect(function()
				showTooltip(buildingType, card)
			end)
			card.MouseLeave:Connect(function()
				tooltip.Visible = false
			end)
		end
	end

	-- Demolish lives at the right end of the tab row, always reachable.
	local demolish = new("TextButton", {
		Name = "Demolish",
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(96, 40, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = THEME.Text,
		Text = "🔨  Demolish",
		LayoutOrder = 999,
		Parent = tabRow,
	}, { corner(8), new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	new("UIStroke", { Name = "Stroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = THEME.Accent, Thickness = 2, Enabled = false, Parent = demolish })
	buttons.Demolish = { button = { Visible = true }, stroke = demolish.Stroke }
	demolish.Activated:Connect(function()
		BuildController:SelectDemolish()
	end)
	demolish.MouseEnter:Connect(function()
		hint.Text = "Demolish: tear down one of your buildings and get half its cost back."
	end)

	setTab(1)

	BuildController.ModeChanged:Connect(function(mode)
		for key, entry in buttons do
			local stroke = entry.stroke or entry.button.Stroke
			stroke.Enabled = mode ~= nil and (mode.type == key or (mode.kind == "demolish" and key == "Demolish"))
		end
		if mode == nil then
			hint.Text = DEFAULT_HINT
		elseif mode.kind == "place" then
			hint.Text = "Click to place " .. Config.Buildings[mode.type].Display .. ".  R = rotate,  Q = cancel"
		else
			hint.Text = "Click one of your buildings to tear it down.  Q = cancel"
		end
	end)

	---------------------------------------------------------------- controls help
	local helpOpen = true
	local help = new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, {
		corner(10),
		padding(10),
		frameStroke(),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBold, TextColor3 = THEME.Accent, TextSize = 14, Text = "Controls  (H to hide)", LayoutOrder = 1, Parent = help })
	local helpBody = label({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 13,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = 2,
		Text = "1 Axe: chop trees, click to fight\n2 Pickaxe: mine rocks\n3 Bow: click to shoot\n4 Torch: F sets enemy buildings alight\nE: gather, loot, talk\nT: research\nRaid Greywater Hold: walk west\nWheel: zoom   Right-drag: turn   V: camera",
		Parent = help,
	})
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.H then
			helpOpen = not helpOpen
			helpBody.Visible = helpOpen
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
		if kind == "quest" then
			Sounds.play("QuestDone")
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

		lastState = state
		local q = state.quest
		if q then
			if q.done then
				sagaHead.Text = "SAGA COMPLETE"
				sagaTitle.Text = "Your name will be sung"
				sagaText.Text = "Every goal is done. Keep growing, raiding and sailing!"
				sagaFill.Size = UDim2.fromScale(1, 1)
				sagaReward.Text = ""
			else
				sagaHead.Text = string.format("SAGA  %d / %d", q.index, q.total)
				sagaTitle.Text = q.title
				sagaText.Text = q.text
				sagaFill.Size = UDim2.fromScale(math.clamp(q.have / q.goal, 0, 1), 1)
				sagaReward.Text = string.format("%d / %d   ·   Reward: %s", q.have, q.goal, q.reward)
			end
		end
		table.clear(known)
		for _, id in state.tech or {} do
			known[id] = true
		end
		for _, buildingType in Config.BuildOrder do
			local def = Config.Buildings[buildingType]
			local entry = buttons[buildingType]
			if def.Requires and not known[def.Requires] then
				entry.cost.Text = "🔒 " .. Config.Tech[def.Requires].Name
				entry.cost.TextColor3 = THEME.Muted
				entry.button.BackgroundTransparency = 0.55
			else
				entry.cost.Text = Grid.costText(def.Cost)
				entry.button.BackgroundTransparency = 0
				local affordable = Grid.canAfford(state.resources, def.Cost)
				entry.cost.TextColor3 = affordable and THEME.Good or THEME.Bad
			end
		end
	end)
end

return HudController
