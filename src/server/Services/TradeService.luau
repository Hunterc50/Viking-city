--[[
	TradeService
	A trader's stall on the beach in front of every plot. Hold E there to
	open the trade window and swap goods for silver (or silver for goods).
	Prices follow the seasons: food is dear in winter and cheap at harvest.
	Offers are in Config.Trade.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)
local Sounds = require(Shared.Sounds)

local TradeService = {}

local services
local stalls = {} -- [plotIndex] = position

function TradeService:Init(allServices)
	services = allServices
end

-- What offer `i` costs right now (season-adjusted), and what it gives.
function TradeService.Price(i: number, season: string?)
	local offer = Config.Trade.Offers[i]
	if not offer then
		return nil, nil
	end
	local mult = offer.Season and offer.Season[season or "Summer"] or 1
	local give = {}
	for res, n in offer.Give do
		give[res] = math.max(1, math.floor(n * mult + 0.5))
	end
	return give, offer.Get
end

local function nearStall(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, pos in stalls do
		if (root.Position - pos).Magnitude < 18 then
			return true
		end
	end
	return false
end

function TradeService:Trade(player: Player, i)
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony or typeof(i) ~= "number" then
		return false, "Not ready"
	end
	if not nearStall(player) then
		return false, "Walk back to the trader's stall"
	end
	local give, get = TradeService.Price(math.floor(i), workspace:GetAttribute("Season"))
	if not give then
		return false, "Unknown offer"
	end
	if not ColonyService:Spend(colony, give) then
		return false, "You need " .. Grid.costText(give)
	end
	for res, n in get do
		ColonyService:Add(colony, res, n)
	end
	services.QuestService:Count(colony, "trade")
	Sounds.play("Build", player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
	ColonyService:Sync(colony)
	return true, "Traded " .. Grid.costText(give) .. " for " .. Grid.costText(get)
end

local function buildStall(index: number)
	local o = Grid.plotOrigin(index)
	local x, z = o.X + 100, -16
	local y = services.WorldService:GroundHeight(x, z)
	local base = CFrame.new(x, y, z)
	local model = Instance.new("Model")
	model.Name = "TraderStall"
	local add = ModelFactory.addPart
	local wood = Color3.fromRGB(110, 78, 50)
	for _, c in { { -4, -2.5 }, { 4, -2.5 }, { -4, 2.5 }, { 4, 2.5 } } do
		add(model, { Name = "Post", Size = Vector3.new(0.6, 7, 0.6), CFrame = base * CFrame.new(c[1], 3.5, c[2]), Color = wood })
	end
	add(model, { Name = "Counter", Size = Vector3.new(9, 3, 2), CFrame = base * CFrame.new(0, 1.5, -2.2), Color = Color3.fromRGB(96, 68, 44), Material = Enum.Material.WoodPlanks })
	-- striped awning
	for i = 0, 4 do
		add(model, {
			Name = "Awning",
			Size = Vector3.new(1.9, 0.2, 6.6),
			CFrame = base * CFrame.new(-3.8 + i * 1.9, 7.3, 0) * CFrame.Angles(math.rad(-12), 0, 0),
			Color = i % 2 == 0 and Color3.fromRGB(160, 46, 40) or Color3.fromRGB(226, 214, 186),
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- goods on the counter
	add(model, { Name = "Crate", Size = Vector3.new(1.6, 1.4, 1.4), CFrame = base * CFrame.new(-3, 3.7, -2.2), Color = Color3.fromRGB(150, 110, 70) })
	add(model, { Name = "Pelts", Size = Vector3.new(2.4, 0.4, 1.4), CFrame = base * CFrame.new(0, 3.2, -2.2), Color = Color3.fromRGB(140, 96, 60), Material = Enum.Material.Fabric })
	add(model, { Name = "Silver", Size = Vector3.new(1.2, 0.5, 1.2), CFrame = base * CFrame.new(3, 3.25, -2.2), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Foil })
	local trader = ModelFactory.villager("Ottar the Trader", false, Random.new(index), "elder")
	local offset = trader:GetAttribute("GroundOffset") or 2
	trader:PivotTo(base * CFrame.new(0, offset, 0.5) * CFrame.Angles(0, math.pi, 0))
	trader.Parent = model
	model.Parent = workspace

	local anchor = model:FindFirstChild("Counter")
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Trade"
	prompt.ObjectText = "Ottar's stall"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		Remotes.OpenTrade:FireClient(player)
	end)
	stalls[index] = Vector3.new(x, y, z)
end

function TradeService:Start()
	for i = 1, Config.MAX_PLOTS do
		buildStall(i)
	end
	Remotes.Trade.OnServerInvoke = function(player, i)
		return self:Trade(player, i)
	end
end

return TradeService
