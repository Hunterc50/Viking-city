--[[
	CouncilController
	The Jarl's Table: press J (or the button under the colony panel).
	Four tabs:
	  Land       buy the next, bigger stage of land
	  War band   hire warriors, give orders, send them on expeditions
	  Diplomacy  gifts, tribute, alliances and trade deals with the holds
	  Rites      feasts and the season's blót
	Also shows the report when the war band comes home from an expedition.
	Everything it shows comes from state.council (CouncilService on the server).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)

local CouncilController = {}

local controllers
local player = Players.LocalPlayer

local THEME = {
	Panel = Color3.fromRGB(20, 20, 22),
	Card = Color3.fromRGB(38, 38, 41),
	Button = Color3.fromRGB(60, 55, 48),
	ButtonOff = Color3.fromRGB(30, 30, 32),
	Accent = Color3.fromRGB(226, 206, 160),
	Text = Color3.fromRGB(238, 234, 226),
	Muted = Color3.fromRGB(156, 152, 146),
	Good = Color3.fromRGB(130, 200, 110),
	Bad = Color3.fromRGB(230, 110, 96),
}

local TABS = {
	{ id = "land", title = "🗺  Land" },
	{ id = "warband", title = "⚔️  War band" },
	{ id = "diplomacy", title = "🤝  Diplomacy" },
	{ id = "rites", title = "🔥  Rites" },
}

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

local function text(parent, str: string, props)
	local defaults = {
		Size = UDim2.new(1, 0, 0, 20),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Text,
		Text = str,
		Parent = parent,
	}
	for k, v in props or {} do
		defaults[k] = v
	end
	return new("TextLabel", defaults)
end

-- Sends an action to the server and shows the answer as a toast.
local function act(action: string, arg: string?)
	local ok, msg = Remotes.Council:InvokeServer(action, arg)
	if msg then
		controllers.StateController:LocalNotify(msg, ok and "good" or "bad")
	end
end

local function button(parent, label: string, enabled: boolean, onClick, width: number?)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(width or 170, 34),
		BackgroundColor3 = enabled and THEME.Button or THEME.ButtonOff,
		AutoButtonColor = enabled,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = enabled and THEME.Accent or THEME.Muted,
		Text = label,
		Parent = parent,
	})
	corner(b, 6)
	b.Activated:Connect(function()
		-- disabled buttons still ask the server, which explains what's missing
		onClick()
	end)
	return b
end

local function row(parent, order: number)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = f })
	return f
end

local function card(parent, order: number)
	local c = new("Frame", {
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Card,
		LayoutOrder = order,
		Parent = parent,
	})
	corner(c)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = c })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = c })
	return c
end

local function have(state, cost): boolean
	return state ~= nil and cost ~= nil and Grid.canAfford(state.resources, cost)
end

-- Tab builders ------------------------------------------------------------------

local function buildLand(body, state)
	local land = state.council.land
	local c = card(body, 1)
	text(c, "Your land: " .. land.name, { Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = THEME.Accent, LayoutOrder = 1 })
	text(c, "Size " .. land.size .. " cells. The border stakes show where it ends.", { TextColor3 = THEME.Muted, LayoutOrder = 2 })
	local n = card(body, 2)
	if land.nextName then
		text(n, "Next: " .. land.nextName .. "  (" .. land.nextSize .. " cells)", { Font = Enum.Font.GothamBold, TextSize = 17, LayoutOrder = 1 })
		local need = Grid.costText(land.nextCost)
		if land.nextRank then
			need ..= "   ·   rank " .. land.nextRank
		end
		text(n, "Costs " .. need, { TextColor3 = have(state, land.nextCost) and THEME.Good or THEME.Bad, LayoutOrder = 2 })
		if land.blocker then
			text(n, land.blocker, { TextColor3 = THEME.Muted, TextSize = 13, LayoutOrder = 3 })
		end
		local r = row(n, 4)
		button(r, "Buy land", land.blocker == nil, function()
			act("BuyLand")
		end)
	else
		text(n, "Your land is as big as it can grow. A true Great Steading!", { TextColor3 = THEME.Good, LayoutOrder = 1 })
	end
	text(body, "Bigger land grows toward the meadow and into the gaps beside your plot. It never touches a neighbour.", { TextColor3 = THEME.Muted, TextSize = 13, LayoutOrder = 3 })

	-- clan colours for your banners and sail
	local cc = card(body, 4)
	text(cc, "Clan colours", { Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = THEME.Accent, LayoutOrder = 1 })
	text(cc, "They fly on your banners, your Great Hall's standards and your longship's sail.", { TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 2 })
	local cr = row(cc, 3)
	local current = state.council.clan or "Blood"
	for _, clan in Config.ClanColours do
		local on = clan.Name == current
		local b = button(cr, (on and "» " or "") .. clan.Label, not on, function()
			act("Colours", clan.Name)
		end, 128)
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 6, 1, -8)
		swatch.Position = UDim2.fromOffset(4, 4)
		swatch.BackgroundColor3 = clan.Main
		swatch.BorderSizePixel = 0
		swatch.Parent = b
	end
end

local function buildWarband(body, state)
	local w = state.council.warband
	local c = card(body, 1)
	local modeText = ({ home = "guarding the village", follow = "following you", away = "away raiding " .. tostring(w.target) })[w.mode] or w.mode
	text(c, "War band: " .. w.count .. " / " .. w.max .. " warriors, " .. modeText, { Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = THEME.Accent, LayoutOrder = 1 })
	if w.mode == "away" and w.secondsLeft then
		text(c, "Back in about " .. math.max(1, math.ceil(w.secondsLeft / 60)) .. " min (" .. w.secondsLeft .. " s).", { TextColor3 = THEME.Muted, LayoutOrder = 2 })
	end
	local names = {}
	for _, m in w.members do
		table.insert(names, m.name .. (m.away and "" or (" " .. m.hp .. "%")))
	end
	text(c, #names > 0 and table.concat(names, ",  ") or "No warriors yet. Hire grown villagers below; they stop working while they serve.", { TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 3 })
	local r = row(c, 4)
	button(r, "Hire (" .. Grid.costText(w.hireCost) .. ")", w.mode ~= "away" and w.count < w.max and have(state, w.hireCost), function()
		act("Hire")
	end, 210)
	button(r, "Dismiss one", w.mode ~= "away" and w.count > 0, function()
		act("Dismiss")
	end, 130)
	local r2 = row(c, 5)
	button(r2, "Follow me", w.mode == "home" and w.count > 0, function()
		act("Follow")
	end, 150)
	button(r2, "Guard the village", w.mode == "follow", function()
		act("StayHome")
	end, 180)
	local r4 = row(c, 6)
	for _, key in { "loose", "wall", "wedge" } do
		local f = Config.Formations[key]
		local on = w.formation == key and w.mode == "follow"
		button(r4, (on and "» " or "") .. f.Label, w.mode ~= "away" and w.count > 0 and not on, function()
			act("Formation", key)
		end, 140)
	end
	local f = Config.Formations[w.formation or "loose"]
	text(c, "Formation: " .. f.Label .. ", " .. f.Text .. ". Press G in the field to switch.", { TextSize = 12, TextColor3 = THEME.Muted, LayoutOrder = 7 })
	text(c, "Following warriors fight beside you and row your longship: faster ship, one more arrow each per volley. At a rival hold they hack at the gate with you; a wedge rams it twice as hard.", { TextSize = 12, TextColor3 = THEME.Muted, LayoutOrder = 8 })

	local e = card(body, 2)
	text(e, "Send them raiding on their own (strength " .. w.power .. ")", { Font = Enum.Font.GothamBold, TextSize = 16, LayoutOrder = 1 })
	text(e, "They're away a few minutes and bring back loot, so you can stay home and build. Some may not come back.", { TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 2 })
	for i, t in w.targets do
		local r3 = row(e, 2 + i)
		local label = t.name .. (t.sea and " (by sea)" or "") .. "   ·   " .. (t.allied and "ally" or (t.chance .. "% to win"))
		text(r3, label, { Size = UDim2.new(0, 330, 0, 34), AutomaticSize = Enum.AutomaticSize.None, TextColor3 = t.allied and THEME.Muted or (t.chance >= 50 and THEME.Good or THEME.Bad) })
		button(r3, "Send", w.mode ~= "away" and w.count > 0 and not t.allied, function()
			act("Expedition", t.name)
		end, 90)
	end
end

local function moodWord(m: number): string
	if m >= 60 then
		return "friendly"
	elseif m >= 30 then
		return "warm"
	elseif m > -30 then
		return "wary"
	elseif m > -60 then
		return "hostile"
	end
	return "blood feud"
end

local function buildDiplomacy(body, state)
	local d = state.council.diplomacy
	for i, h in d.holds do
		local c = card(body, i)
		local status = h.allied and "Sworn allies" or (h.tributeDays > 0 and ("Paying you tribute (" .. h.tributeDays .. " days left)") or ("Mood " .. h.mood .. " (" .. moodWord(h.mood) .. ")"))
		text(c, h.name .. "   ·   " .. status, { Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = h.allied and THEME.Good or (h.mood < -30 and THEME.Bad or THEME.Accent), LayoutOrder = 1 })
		if h.dealText then
			text(c, (h.deal and "Trade deal running: " or "Trade deal: ") .. h.dealText .. (h.deal and "" or ("  (needs mood " .. d.dealMood .. ")")), { TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 2 })
		end
		local r = row(c, 3)
		button(r, "Gift (" .. Grid.costText(d.giftCost) .. ")", have(state, d.giftCost), function()
			act("Gift", h.name)
		end, 170)
		button(r, "Demand tribute", not h.allied and h.tributeDays <= 0 and h.fear >= d.demandNeed, function()
			act("Demand", h.name)
		end, 150)
		button(r, h.allied and "Allied" or ("Alliance (" .. Grid.costText(d.allianceCost) .. ")"), not h.allied and h.mood >= d.allianceMood, function()
			act("Ally", h.name)
		end, 190)
		if h.dealText then
			button(r, h.deal and "End deal" or "Trade deal", h.deal or h.allied or h.mood >= d.dealMood, function()
				act("Deal", h.name)
			end, 120)
		end
	end
	text(body, "Gifts warm a hold's mood. Allies never raid you and their guards leave you be. Tribute needs a war band at least " .. d.demandNeed .. "% as strong as the hold. Attacking a hold breaks every pact with it.", { TextSize = 13, TextColor3 = THEME.Muted, LayoutOrder = 10 })
end

local function buildRites(body, state)
	local r = state.council.rites
	local f = card(body, 1)
	text(f, "Feast in the hall", { Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = THEME.Accent, LayoutOrder = 1 })
	local fText = "Mead, meat and song: +" .. r.feastHappiness .. " happiness for a day. Costs " .. Grid.costText(r.feastCost) .. "."
	if not r.hasHall then
		fText ..= " Needs a Longhouse or Great Hall."
	elseif r.feastActive then
		fText ..= " The feast is on!"
	elseif state.day < r.feastReadyDay then
		fText ..= " Next feast from day " .. r.feastReadyDay .. "."
	end
	text(f, fText, { TextSize = 14, TextColor3 = THEME.Muted, LayoutOrder = 2 })
	local fr = row(f, 3)
	button(fr, "Hold a feast", r.hasHall and state.day >= r.feastReadyDay and have(state, r.feastCost), function()
		act("Feast")
	end)

	local b = card(body, 2)
	text(b, (r.blotName or "Blót") .. "  ·  " .. r.season, { Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = THEME.Accent, LayoutOrder = 1 })
	local bText = (r.blotText or "") .. " Once per season, at the Shrine. Costs " .. (r.blotCost and Grid.costText(r.blotCost) or "?") .. "."
	if not r.hasShrine then
		bText ..= " Build a Shrine first."
	elseif r.blotDone then
		bText ..= " Held this season: the gods are pleased."
	end
	text(b, bText, { TextSize = 14, TextColor3 = THEME.Muted, LayoutOrder = 2 })
	local br = row(b, 3)
	button(br, "Hold the blót", r.hasShrine and not r.blotDone and have(state, r.blotCost), function()
		act("Blot")
	end)
end

local BUILDERS = { land = buildLand, warband = buildWarband, diplomacy = buildDiplomacy, rites = buildRites }

function CouncilController:Init(all)
	controllers = all
end

function CouncilController:Start()
	local gui = new("ScreenGui", { Name = "JarlsTable", ResetOnSpawn = false, DisplayOrder = 11, Parent = player:WaitForChild("PlayerGui") })

	local openButton = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -129, 0, 170),
		Size = UDim2.fromOffset(113, 36),
		BackgroundColor3 = Color3.fromRGB(70, 54, 34),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = THEME.Accent,
		Text = "Jarl's Table (J)",
		Parent = gui,
	})
	corner(openButton)

	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(760, 560),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 12)
	new("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.4, Parent = panel })
	text(panel, "The Jarl's Table", { Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -80, 0, 34), AutomaticSize = Enum.AutomaticSize.None, Font = Enum.Font.Garamond, TextSize = 30, TextColor3 = THEME.Accent })
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

	local tabBar = new("Frame", { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 36), BackgroundTransparency = 1, Parent = panel })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar })
	local body = new("ScrollingFrame", {
		Position = UDim2.fromOffset(16, 102),
		Size = UDim2.new(1, -32, 1, -118),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})

	local current = "land"
	local lastKey = ""
	local tabButtons = {}

	local function render(force: boolean?)
		local state = controllers.StateController.State
		if not state or not state.council then
			return
		end
		local tabState = state.council[current]
		-- rebuild only when something shown actually changed (keeps buttons steady)
		local key = current .. HttpService:JSONEncode(tabState) .. HttpService:JSONEncode(state.resources) .. tostring(state.day)
		if key == lastKey and not force then
			return
		end
		lastKey = key
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		if not body:FindFirstChildOfClass("UIListLayout") then
			new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
		end
		local ok, err = pcall(BUILDERS[current], body, state)
		if not ok then
			warn("[CouncilController] " .. tostring(err))
		end
		for id, b in tabButtons do
			b.BackgroundColor3 = id == current and THEME.Button or THEME.Card
			b.TextColor3 = id == current and THEME.Accent or THEME.Text
		end
	end

	for i, tab in TABS do
		local b = new("TextButton", {
			Size = UDim2.fromOffset(170, 36),
			BackgroundColor3 = THEME.Card,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = THEME.Text,
			Text = tab.title,
			LayoutOrder = i,
			Parent = tabBar,
		})
		corner(b, 6)
		b.Activated:Connect(function()
			current = tab.id
			render(true)
		end)
		tabButtons[tab.id] = b
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			render(true)
		end
	end
	CouncilController.Toggle = toggle
	openButton.Activated:Connect(toggle)
	close.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.J then
			toggle()
		elseif not processed and input.KeyCode == Enum.KeyCode.G then
			act("Formation", "next")
		end
	end)
	controllers.StateController.Changed:Connect(function()
		if panel.Visible then
			render(false)
		end
	end)

	-------------------------------------------------------------- war report
	local report = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		Parent = gui,
	})
	corner(report, 12)
	new("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.3, Parent = report })
	new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), Parent = report })
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = report })
	local rTitle = text(report, "", { Font = Enum.Font.Garamond, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1 })
	local rBody = text(report, "", { TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2 })
	local okRow = new("Frame", { Size = UDim2.fromOffset(140, 34), BackgroundTransparency = 1, LayoutOrder = 3, Parent = report })
	button(okRow, "Skål!", true, function()
		report.Visible = false
	end, 140)

	Remotes.WarReport.OnClientEvent:Connect(function(r)
		if type(r) ~= "table" then
			return
		end
		rTitle.Text = (r.won and "Victory at " or "Beaten back at ") .. tostring(r.hold)
		rTitle.TextColor3 = r.won and THEME.Accent or THEME.Bad
		local lines = { "You sent " .. tostring(r.sent) .. " warriors." }
		local loot = r.loot and next(r.loot) and Grid.costText(r.loot) or "nothing"
		table.insert(lines, "They brought home: " .. loot)
		if r.fallen and #r.fallen > 0 then
			table.insert(lines, "Fallen: " .. table.concat(r.fallen, ", "))
		else
			table.insert(lines, "Every warrior came home.")
		end
		if r.wounded and #r.wounded > 0 then
			table.insert(lines, "Wounded (healing at home): " .. table.concat(r.wounded, ", "))
		end
		rBody.Text = table.concat(lines, "\n")
		report.Visible = true
	end)
end

return CouncilController
