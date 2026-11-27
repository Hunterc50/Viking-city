--[[
	TradeController
	The trade window that opens at Ottar's stall on your beach. Each row
	swaps what you give for what you get; click Trade to do it. Prices that
	change with the season are marked. Walk away or press X to close.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)

local TradeController = {}

local controllers
local player = Players.LocalPlayer

local THEME = {
	Panel = Color3.fromRGB(28, 23, 18),
	Row = Color3.fromRGB(52, 42, 32),
	Accent = Color3.fromRGB(214, 170, 92),
	Text = Color3.fromRGB(245, 235, 215),
	Muted = Color3.fromRGB(170, 156, 134),
	Good = Color3.fromRGB(130, 200, 110),
	Bad = Color3.fromRGB(230, 110, 96),
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

local function price(offer)
	local season = workspace:GetAttribute("Season") or "Summer"
	local mult = offer.Season and offer.Season[season] or 1
	local give = {}
	for res, n in offer.Give do
		give[res] = math.max(1, math.floor(n * mult + 0.5))
	end
	return give, mult
end

function TradeController:Init(all)
	controllers = all
end

function TradeController:Start()
	local gui = new("ScreenGui", { Name = "Trade", ResetOnSpawn = false, DisplayOrder = 9, Parent = player:WaitForChild("PlayerGui") })
	local panel = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = panel })
	new("UIStroke", { Color = THEME.Accent, Thickness = 2, Transparency = 0.4, Parent = panel })
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14), Parent = panel })
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = panel })

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 0, Parent = panel })
	new("TextLabel", {
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Fantasy,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Accent,
		Text = "Ottar's Stall",
		Parent = header,
	})
	local close = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = THEME.Row,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = THEME.Text,
		Text = "X",
		Parent = header,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = close })
	local seasonLabel = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Muted,
		LayoutOrder = 1,
		Parent = panel,
	})
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = THEME.Good,
		Text = "",
		LayoutOrder = 999,
		Parent = panel,
	})

	local rows = {}
	for i, offer in Config.Trade.Offers do
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Row, LayoutOrder = 10 + i, Parent = panel })
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = row })
		local text = new("TextLabel", {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -120, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = THEME.Text,
			Parent = row,
		})
		local button = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -6, 0.5, 0),
			Size = UDim2.fromOffset(96, 30),
			BackgroundColor3 = Color3.fromRGB(86, 66, 34),
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = THEME.Accent,
			Text = "Trade",
			Parent = row,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 6), Parent = button })
		button.Activated:Connect(function()
			local ok, message = Remotes.Trade:InvokeServer(i)
			status.Text = message or ""
			status.TextColor3 = ok and THEME.Good or THEME.Bad
		end)
		rows[i] = { offer = offer, text = text, button = button }
	end

	local function refresh()
		seasonLabel.Text = "Season: " .. (workspace:GetAttribute("Season") or "Summer") .. ". Food prices change with the seasons."
		local state = controllers.StateController and controllers.StateController.State
		for _, r in rows do
			local give, mult = price(r.offer)
			local tag = mult > 1.01 and "  (dear)" or (mult < 0.99 and "  (cheap)" or "")
			r.text.Text = "Give " .. Grid.costText(give) .. "   →   Get " .. Grid.costText(r.offer.Get) .. tag
			local affordable = state == nil or Grid.canAfford(state.resources, give)
			r.text.TextColor3 = affordable and THEME.Text or THEME.Muted
		end
	end

	local openedAt
	Remotes.OpenTrade.OnClientEvent:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		openedAt = root and root.Position
		status.Text = ""
		refresh()
		panel.Visible = true
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		if not panel.Visible then
			return
		end
		timer += dt
		if timer > 0.5 then
			timer = 0
			refresh()
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and openedAt and (root.Position - openedAt).Magnitude > 16 then
				panel.Visible = false
			end
		end
	end)
end

return TradeController
