--[[
	ResourceNodeService
	Scatters trees, rocks and berry bushes on each plot. The player walks up
	and holds E to gather them: trees need the Axe, rocks the Pickaxe, berries
	bare hands. Gathering also clears land for building. Nodes slowly regrow.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)

local ResourceNodeService = {}

local services
local rng = Random.new()

function ResourceNodeService:Init(allServices)
	services = allServices
end

local function randomFreeCell(colony)
	for _ = 1, 60 do
		local x = rng:NextInteger(0, Config.PLOT_CELLS - 1)
		local z = rng:NextInteger(0, Config.PLOT_CELLS - 1)
		if not colony.blocked[Grid.key(x, z)] then
			return x, z
		end
	end
	return nil
end

local function countKind(colony, kind: string): number
	local n = 0
	for _, node in colony.nodes do
		if node.kind == kind then
			n += 1
		end
	end
	return n
end

function ResourceNodeService:Spawn(colony, kind: string, x: number, z: number)
	local ColonyService = services.ColonyService
	local def = Config.Nodes[kind]
	local key = Grid.key(x, z)

	local model, main = ModelFactory.node(kind, rng)
	local jitter = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
	model:PivotTo(CFrame.new(Grid.rectCenter(colony.origin, x, z, 1, 1) + jitter) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	services.SeasonService:ApplyTo(model)
	model.Parent = colony.plot.Nodes

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = def.Action
	prompt.ObjectText = (kind == "Bush" and "Berry bush" or kind) .. (def.Tool and (" (" .. def.Tool .. ")") or "")
	prompt.HoldDuration = def.Hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = main

	local node = { kind = kind, x = x, z = z, model = model }
	colony.nodes[key] = node
	ColonyService:Block(colony, x, z, "node")

	prompt.Triggered:Connect(function(player)
		if player ~= colony.player or colony.nodes[key] ~= node then
			return
		end
		if def.Tool and not services.ToolService:IsHolding(player, def.Tool) then
			local slot = table.find(Config.Tools, def.Tool) or 1
			ColonyService:Notify(colony, "Hold your " .. def.Tool .. " first (press " .. slot .. ")", "bad")
			return
		end
		colony.nodes[key] = nil
		model:Destroy()
		ColonyService:Unblock(colony, x, z)
		local amount = def.Amount
		if kind == "Tree" and ColonyService:Has(colony, "IronAxes") then
			amount *= 1.5
		end
		if ColonyService:Has(colony, "PathWoods") then
			amount *= 2
		end
		amount = math.floor(amount)
		ColonyService:Add(colony, def.Gives, amount)
		ColonyService:Notify(colony, "+" .. amount .. " " .. def.Gives, "gain")
		ColonyService:Sync(colony)
	end)
end

function ResourceNodeService:SpawnInitial(colony)
	for kind, def in Config.Nodes do
		for _ = 1, def.Count do
			local x, z = randomFreeCell(colony)
			if x then
				self:Spawn(colony, kind, x, z)
			end
		end
	end
end

function ResourceNodeService:Tick(colony, dt: number)
	colony.regrowTimer = (colony.regrowTimer or 0) + dt
	if colony.regrowTimer < Config.NodeRegrowInterval then
		return
	end
	colony.regrowTimer = 0
	for kind, def in Config.Nodes do
		if def.Regrow > 0 and countKind(colony, kind) < def.Regrow then
			local x, z = randomFreeCell(colony)
			if x then
				self:Spawn(colony, kind, x, z)
			end
		end
	end
end

return ResourceNodeService
