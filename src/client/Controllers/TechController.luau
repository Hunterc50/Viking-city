--[[
	TechController
	The research screen. Press T (or the Research button) to open it.
	Five columns: Buildings, Gear, Boats, Culture, Religion. Each card shows
	what a tech does, what it costs and what it still needs. Click a card
	you can afford to research it.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)

local TechController = {}

local controllers
local player = Players.LocalPlayer

local THEME = {
	Panel = Color3.fromRGB(28, 23, 18),
	Card = Color3.fromRGB(52, 42, 32),
	Done = Color3.fromRGB(46, 72, 44),
	Ready = Color3.fromRGB(86, 66, 34),
	Locked = Color3.fromRGB(40, 36, 32),
	Accent = Color3.fromRGB(214, 170, 92),
	Text = Color3.fromRGB(245, 235, 215),
	Muted = Color3.fromRGB(170, 156, 134),
	Bad = Color3.fromRGB(230, 110, 96),
}

local BRANCH_ICON = { Buildings = "Hall", Gear = "Forge", Boats = "Keel", Culture = "Saga", Religion = "Faith" }

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = parent })
end

-- Mirrors TechService:CanResearch on the client for display.
local function status(state, id: string): (string, string?)
	local tech = Config.Tech[id]
	local known = {}
	for _, t in state.tech or {} do
		known[t] = true
	end
	if known[id] then
		return "done", nil
	end
	for _, req in tech.Requires or {} do
		if not known[req] then
			return "locked", "Needs " .. Config.Tech[req].Name
		end
	end
	if tech.Building and not (state.buildingTypes and state.buildingTypes[tech.Building]) then
		return "locked", "Needs a " .. Config.Buildings[tech.Building].Display
	end
	if tech.Group then
		for t in known do
			if Config.Tech[t] and Config.Tech[t].Group == tech.Group then
				return "locked", "You follow " .. Config.Tech[t].Name
			end
		end
	end
	if not Grid.canAfford(state.resources, tech.Cost) then
		return "poor", nil
	end
	return "ready", nil
end

function TechController:Init(allControllers)
	controllers = allControllers
end

function TechController:Start()
	local gui = new("ScreenGui", { Name = "Research", ResetOnSpawn = false, DisplayOrder = 10, Parent = player:WaitForChild("PlayerGui") })

	local openButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 170),
		Size = UDim2.fromOffset(113, 36),
		BackgroundColor3 = Color3.fromRGB(70, 54, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = THEME.Accent,
		Text = "Research (T)",
		Parent = gui,
	})
	corner(openButton)

	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1060, 560),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 12)
	new("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.4, Parent = panel })

	new("TextLabel", {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -40, 0, 34),
		BackgroundTransparency = 1,
		Font = Enum.Font.Fantasy,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Accent,
		Text = "Research",
		Parent = panel,
	})
	local loreLabel = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -60, 0, 18),
		Size = UDim2.fromOffset(420, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(150, 185, 240),
		Text = "",
		Parent = panel,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = THEME.Card,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = THEME.Text,
		Text = "X",
		Parent = panel,
	})
	corner(close, 6)

	local columns = new("Frame", {
		Position = UDim2.fromOffset(16, 58),
		Size = UDim2.new(1, -32, 1, -74),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = columns })

	local cards = {}
	for i, branch in Config.TechBranches do
		local col = new("Frame", {
			Size = UDim2.new(0.2, -8, 1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Parent = columns,
		})
		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			TextColor3 = THEME.Accent,
			Text = string.upper(branch) .. "  ·  " .. BRANCH_ICON[branch],
			Parent = col,
		})
		local list = new("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 1, -30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Parent = col,
		})
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

		-- order the techs so prerequisites come first
		local ids = {}
		for id, tech in Config.Tech do
			if tech.Branch == branch then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			local ra, rb = #(Config.Tech[a].Requires or {}), #(Config.Tech[b].Requires or {})
			if ra ~= rb then
				return ra < rb
			end
			return Config.Tech[a].Name < Config.Tech[b].Name
		end)

		for order, id in ids do
			local tech = Config.Tech[id]
			local card = new("TextButton", {
				Size = UDim2.new(1, -6, 0, 112),
				BackgroundColor3 = THEME.Card,
				AutoButtonColor = true,
				Text = "",
				LayoutOrder = order,
				Parent = list,
			})
			corner(card)
			local stroke = new("UIStroke", { ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = THEME.Accent, Thickness = 1.5, Transparency = 0.7, Parent = card })
			new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6), Parent = card })
			new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = THEME.Text,
				Text = tech.Name,
				Parent = card,
			})
			new("TextLabel", {
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.new(1, 0, 0, 46),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = THEME.Muted,
				Text = tech.Description,
				Parent = card,
			})
			local foot = new("TextLabel", {
				Position = UDim2.fromOffset(0, 72),
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = THEME.Accent,
				Text = Grid.costText(tech.Cost),
				Parent = card,
			})
			card.Activated:Connect(function()
				local ok, msg = Remotes.Research:InvokeServer(id)
				controllers.StateController:LocalNotify(msg, ok and "good" or "bad")
				if ok then
					-- a little flash of gold
					card.BackgroundColor3 = THEME.Accent
					TweenService:Create(card, TweenInfo.new(0.6), { BackgroundColor3 = THEME.Done }):Play()
				end
			end)
			cards[id] = { card = card, foot = foot, stroke = stroke }
		end
	end

	local function refresh(state)
		if not state then
			return
		end
		loreLabel.Text = string.format("Lore %d   ·   build a Lore Hall to gather more", state.resources.Lore or 0)
		for id, c in cards do
			local st, why = status(state, id)
			local tech = Config.Tech[id]
			if st == "done" then
				c.card.BackgroundColor3 = THEME.Done
				c.foot.Text = "Known"
				c.foot.TextColor3 = Color3.fromRGB(150, 220, 140)
				c.stroke.Transparency = 0.9
			elseif st == "locked" then
				c.card.BackgroundColor3 = THEME.Locked
				c.foot.Text = why .. "   ·   " .. Grid.costText(tech.Cost)
				c.foot.TextColor3 = THEME.Muted
				c.stroke.Transparency = 0.9
			elseif st == "poor" then
				c.card.BackgroundColor3 = THEME.Card
				c.foot.Text = Grid.costText(tech.Cost)
				c.foot.TextColor3 = THEME.Bad
				c.stroke.Transparency = 0.7
			else
				c.card.BackgroundColor3 = THEME.Ready
				c.foot.Text = Grid.costText(tech.Cost) .. "   ·   click to research"
				c.foot.TextColor3 = THEME.Accent
				c.stroke.Transparency = 0.1
			end
		end
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh(controllers.StateController.State)
		end
	end
	TechController.Toggle = toggle
	openButton.Activated:Connect(toggle)
	close.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.T then
			toggle()
		end
	end)
	controllers.StateController.Changed:Connect(function(state)
		if panel.Visible then
			refresh(state)
		end
	end)
end

return TechController
