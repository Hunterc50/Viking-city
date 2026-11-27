--[[
	ResourceNodeService
	Scatters trees, rocks and berry bushes on each plot. Walk up to a tree
	with the Axe (or a rock with the Pickaxe) and click to swing: chips fly,
	it shakes, a bar shows how many blows are left, then the tree topples or
	the rock breaks apart. Better tools (Iron Blades, Steel Edges, Masonry)
	need fewer blows. Berries are picked by hand: hold E. Gathering also
	clears land for building. Nodes slowly regrow.
]]

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
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

	local node = { kind = kind, x = x, z = z, model = model, main = main, key = key, hp = def.Hits, maxHp = def.Hits }
	colony.nodes[key] = node
	ColonyService:Block(colony, x, z, "node")

	if def.Hits then
		return -- trees and rocks are cut by swinging the tool at them (see Hit)
	end

	-- berries are picked by hand: hold E
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = def.Action
	prompt.ObjectText = "Berry bush"
	prompt.HoldDuration = def.Hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = main
	prompt.Triggered:Connect(function(player)
		if player ~= colony.player or colony.nodes[key] ~= node then
			return
		end
		Sounds.play("Chop", model:GetPivot().Position)
		ResourceNodeService:Harvest(colony, node)
		model:Destroy()
	end)
end

-- Gives the node's resources and frees its cell.
function ResourceNodeService:Harvest(colony, node)
	local ColonyService = services.ColonyService
	local def = Config.Nodes[node.kind]
	colony.nodes[node.key] = nil
	ColonyService:Unblock(colony, node.x, node.z)
	services.QuestService:Count(colony, node.kind == "Rock" and "mine" or (node.kind == "Tree" and "chop" or "forage"))
	local amount = def.Amount
	if node.kind == "Tree" and ColonyService:Has(colony, "IronAxes") then
		amount *= 1.5
	end
	if ColonyService:Has(colony, "PathWoods") then
		amount *= 2
	end
	amount = math.floor(amount)
	ColonyService:Add(colony, def.Gives, amount)
	ColonyService:Notify(colony, "+" .. amount .. " " .. def.Gives, "gain")
	ColonyService:Sync(colony)
end

-- Little bits flying off with each blow: wood chips or stone grit and sparks.
local function chips(at: Vector3, stone: boolean)
	local holder = Instance.new("Attachment")
	holder.WorldPosition = at
	holder.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Rate = 0
	p.Lifetime = NumberRange.new(0.4, 0.9)
	p.Speed = NumberRange.new(8, 16)
	p.SpreadAngle = Vector2.new(60, 60)
	p.Acceleration = Vector3.new(0, -40, 0)
	p.Size = NumberSequence.new(stone and 0.25 or 0.35, 0.1)
	p.Color = ColorSequence.new(stone and Color3.fromRGB(170, 168, 160) or Color3.fromRGB(196, 150, 96))
	p.Parent = holder
	p:Emit(stone and 10 or 14)
	if stone then
		local spark = Instance.new("ParticleEmitter")
		spark.Rate = 0
		spark.LightEmission = 1
		spark.Lifetime = NumberRange.new(0.15, 0.3)
		spark.Speed = NumberRange.new(14, 22)
		spark.SpreadAngle = Vector2.new(70, 70)
		spark.Size = NumberSequence.new(0.15, 0)
		spark.Color = ColorSequence.new(Color3.fromRGB(255, 210, 120))
		spark.Parent = holder
		spark:Emit(6)
	end
	task.delay(2, function()
		holder:Destroy()
	end)
end

local function healthBar(node)
	if node.bar then
		return node.bar
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(70, 8)
	gui.StudsOffsetWorldSpace = Vector3.new(0, node.kind == "Tree" and 9 or 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 40
	gui.Adornee = node.main
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = node.kind == "Tree" and Color3.fromRGB(150, 200, 90) or Color3.fromRGB(190, 190, 200)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = node.model
	node.bar = fill
	return fill
end

local function shake(model: Model)
	local base = model:GetPivot()
	task.spawn(function()
		for i = 1, 6 do
			if not model.Parent then
				return
			end
			local a = math.rad(2.2) * (7 - i) / 6 * (i % 2 == 0 and 1 or -1)
			model:PivotTo(base * CFrame.Angles(a, 0, a * 0.6))
			task.wait(0.03)
		end
		if model.Parent then
			model:PivotTo(base)
		end
	end)
end

-- The tree topples away from you, or the rock breaks apart, then fades.
local function fell(node, from: Vector3)
	local model = node.model
	local base = model:GetPivot()
	if node.kind == "Tree" then
		local away = Vector3.new(base.Position.X - from.X, 0, base.Position.Z - from.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		local axis = Vector3.new(0, 1, 0):Cross(away)
		task.spawn(function()
			local t0 = os.clock()
			while model.Parent do
				local t = math.min((os.clock() - t0) / 1.3, 1)
				local angle = (t * t) * math.rad(88)
				model:PivotTo(CFrame.fromAxisAngle(axis, angle) * (base - base.Position) + base.Position)
				if t >= 1 then
					break
				end
				task.wait()
			end
			Sounds.play("Build", base.Position + away * 8)
			task.wait(1.5)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					TweenService:Create(d, TweenInfo.new(1), { Transparency = 1 }):Play()
				end
			end
			task.wait(1)
			model:Destroy()
		end)
	else
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = true
				d:ApplyImpulse(Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1)) * d.AssemblyMass * 18)
				TweenService:Create(d, TweenInfo.new(2.5), { Size = d.Size * 0.4 }):Play()
			end
		end
		task.delay(2.5, function()
			model:Destroy()
		end)
	end
end

-- A swing from `player` holding `toolName`: hits the nearest tree or rock in
-- front of them. Returns true if it hit something.
function ResourceNodeService:Hit(player: Player, toolName: string, root: BasePart): boolean
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony then
		return false
	end
	local best, bestDist = nil, 9
	for _, node in colony.nodes do
		if node.hp and node.model.Parent then
			local p = node.model:GetPivot().Position
			local offset = Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z)
			local d = offset.Magnitude
			local facing = d < 3 or offset.Unit:Dot(Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit) > 0.3
			if d < bestDist and facing then
				best, bestDist = node, d
			end
		end
	end
	if not best then
		return false
	end
	local def = Config.Nodes[best.kind]
	if def.Tool ~= toolName then
		if toolName ~= "Sword" then
			local slot = table.find(Config.Tools, def.Tool) or 1
			ColonyService:Notify(colony, "Use the " .. def.Tool .. " for that (press " .. slot .. ")", "bad")
		end
		return false
	end
	local power = 1
	if best.kind == "Tree" then
		power = ColonyService:Has(colony, "SteelEdges") and 2 or (ColonyService:Has(colony, "IronAxes") and 1.5 or 1)
	elseif best.kind == "Rock" then
		power = ColonyService:Has(colony, "Masonry") and 1.5 or 1
	end
	best.hp -= power
	local p = best.model:GetPivot().Position
	local at = Vector3.new(p.X, p.Y + (best.kind == "Tree" and 2.5 or 1.5), p.Z):Lerp(root.Position, 0.25)
	Sounds.play(best.kind == "Rock" and "Mine" or "Chop", at)
	chips(at, best.kind == "Rock")
	local bar = healthBar(best)
	bar.Size = UDim2.fromScale(math.max(best.hp, 0) / best.maxHp, 1)
	if best.hp <= 0 then
		best.hp = nil
		if best.bar then
			best.bar.Parent.Parent:Destroy()
		end
		self:Harvest(colony, best)
		fell(best, root.Position)
	else
		shake(best.model)
	end
	return true
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
