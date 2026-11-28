--[[
	WildlandsService
	The wildlands (Config.Wildlands): the rough forest behind the meadow, up
	toward the mountains, open to everyone. Trees and rocks there are nobody's,
	so anyone may cut and mine them, for bigger yields than at home, and now
	and then a silver vein glints among the stones. They grow back in time.
	But it is dangerous: bandits camp out there and fall on anyone who comes
	near their fire (WildlifeService adds the wolves, boars and the bear).
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)
local Sounds = require(Shared.Sounds)

local WildlandsService = {}

local WL = Config.Wildlands
local services
local rng = Random.new()
local folder: Folder
local nodes = {} -- [model] = node
local bandits = {} -- list of bandit records
local camps = {} -- list of { position = Vector3 }
WildlandsService.Camps = camps
local WALK_ANIM = "rbxassetid://507777826"

local PLOTS_END_X = Config.MAX_PLOTS * (Grid.PLOT_SIZE + Config.PLOT_GAP) - Config.PLOT_GAP
local MIN_X, MAX_X = -200, PLOTS_END_X + 200

function WildlandsService:Init(all)
	services = all
end

local adopt

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Everything behind the plot fences is wild land anyone may harvest.
local _, _, _, LAND_MAX_Z = Grid.maxBounds()
local HARVEST_MIN_Z = LAND_MAX_Z * Config.CELL + 16
local HARVEST_MAX_Z = 620

-- True if (x, z) is in the wildlands.
function WildlandsService:InWild(pos: Vector3): boolean
	return pos.Z >= HARVEST_MIN_Z and pos.Z <= HARVEST_MAX_Z and pos.X >= MIN_X and pos.X <= MAX_X
end

-- A spot on open, walkable ground in the wildlands (not water, cliff or snow).
local function openSpot(): Vector3?
	for _ = 1, 30 do
		local x = rng:NextNumber(MIN_X, MAX_X)
		local z = rng:NextNumber(WL.MinZ, WL.MaxZ)
		local y = services.WorldService:GroundHeight(x, z)
		local yx = services.WorldService:GroundHeight(x + 3, z)
		local yz = services.WorldService:GroundHeight(x, z + 3)
		if y > 2 and y < 110 and math.abs(yx - y) < 2.2 and math.abs(yz - y) < 2.2 then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

-- Trees, rocks and silver veins --------------------------------------------------

local function spawnNode(kind: string)
	local at = openSpot()
	if not at then
		return
	end
	local model, main
	if kind == "Tree" then
		if rng:NextNumber() < 0.5 then
			model, main = ModelFactory.spruce(rng, rng:NextNumber(1.1, 1.6))
		else
			model, main = ModelFactory.pine(rng, rng:NextNumber(1.1, 1.6))
		end
	else
		model, main = ModelFactory.boulder(rng, rng:NextNumber(1.2, 1.8))
		if kind == "Vein" then
			-- bright flecks of silver in the stone
			local _, size = model:GetBoundingBox()
			for _ = 1, 7 do
				local fleck = Instance.new("Part")
				fleck.Name = "Silver"
				fleck.Anchored = true
				fleck.CanCollide = false
				fleck.Size = Vector3.new(0.5, 0.5, 0.5) * rng:NextNumber(0.7, 1.4)
				fleck.Color = Color3.fromRGB(214, 218, 226)
				fleck.Material = Enum.Material.Foil
				fleck.Reflectance = 0.3
				local a = rng:NextNumber(0, math.pi * 2)
				fleck.CFrame = CFrame.new(math.cos(a) * size.X * 0.35, rng:NextNumber(0.3, 0.8) * size.Y, math.sin(a) * size.Z * 0.35) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0)
				fleck.Parent = model
			end
			local glint = Instance.new("PointLight")
			glint.Color = Color3.fromRGB(200, 210, 255)
			glint.Range = 8
			glint.Brightness = 0.6
			glint.Parent = main
		end
	end
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model:SetAttribute("NodeKind", kind == "Tree" and "Tree" or "Rock")
	model:SetAttribute("Wild", true)
	model.Parent = folder
	local hits = kind == "Tree" and 7 or 8
	nodes[model] = { model = model, main = main, kind = kind == "Tree" and "Tree" or "Rock", vein = kind == "Vein", hp = hits, maxHp = hits }
end

-- The forest and boulders that the world grew behind the plots become
-- harvestable too, so every tree out there can be chopped.
local SCENERY_KINDS = { Pine = "Tree", Spruce = "Tree", Birch = "Tree", Boulder = "Rock" }
adopt = function(model: Instance)
	local kind = model:IsA("Model") and SCENERY_KINDS[model.Name]
	if not kind or nodes[model] then
		return
	end
	if not WildlandsService:InWild(model:GetPivot().Position) then
		return
	end
	local main = model:FindFirstChild("Trunk") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	local hits = kind == "Tree" and 6 or 7
	model:SetAttribute("NodeKind", kind)
	model:SetAttribute("Wild", true)
	nodes[model] = { model = model, main = main, kind = kind, vein = false, hp = hits, maxHp = hits, scenery = true }
end

local function harvest(colony, node)
	local ColonyService = services.ColonyService
	local got = {}
	if node.kind == "Tree" then
		got.Wood = WL.TreeWood
	elseif node.vein then
		got.Silver, got.Stone = WL.VeinSilver, WL.VeinStone
	else
		got.Stone = WL.RockStone
	end
	if ColonyService:Has(colony, "PathWoods") then
		for res, n in got do
			got[res] = n * 2
		end
	end
	for res, n in got do
		ColonyService:Add(colony, res, n)
	end
	services.QuestService:Count(colony, node.kind == "Tree" and "chop" or "mine")
	ColonyService:Notify(colony, (node.vein and "A silver vein! " or "") .. "+" .. Grid.costText(got), "gain")
	ColonyService:Sync(colony)
	-- it grows back: scenery where it stood, our own nodes somewhere in the wilds
	local regrow = node.scenery and node.model:Clone()
	local parent = node.model.Parent
	task.delay(WL.RegrowSeconds, function()
		if regrow then
			regrow.Parent = parent
			adopt(regrow)
		else
			spawnNode(node.vein and "Vein" or node.kind)
		end
	end)
end

-- A swing of the Axe or Pickaxe in the wildlands. Returns true if it hit something.
function WildlandsService:Hit(player: Player, toolName: string, root: BasePart): boolean
	local colony = services.ColonyService:Get(player)
	if not colony or not self:InWild(root.Position) then
		return false
	end
	local best, bestDist = nil, 10
	local look = flat(root.CFrame.LookVector)
	for model, node in nodes do
		if node.hp and model.Parent then
			local offset = flat(model:GetPivot().Position - root.Position)
			local d = offset.Magnitude
			if d < bestDist and (d < 3.5 or offset.Unit:Dot(look.Unit) > 0.3) then
				best, bestDist = node, d
			end
		end
	end
	if not best then
		return false
	end
	local need = best.kind == "Tree" and "Axe" or "Pickaxe"
	if toolName ~= need then
		services.ColonyService:Notify(colony, "Use the " .. need .. " for that (press " .. (table.find(Config.Tools, need) or 1) .. ")", "bad")
		return false
	end
	local ColonyService = services.ColonyService
	local power = 1
	if best.kind == "Tree" then
		power = ColonyService:Has(colony, "SteelEdges") and 2 or (ColonyService:Has(colony, "IronAxes") and 1.5 or 1)
	else
		power = ColonyService:Has(colony, "Masonry") and 1.5 or 1
	end
	best.hp -= power
	local fx = services.ResourceNodeService.fx
	local p = best.model:GetPivot().Position
	local at = Vector3.new(p.X, p.Y + (best.kind == "Tree" and 2.5 or 1.5), p.Z):Lerp(root.Position, 0.25)
	Sounds.play(best.kind == "Rock" and "Mine" or "Chop", at)
	fx.chips(at, best.kind == "Rock")
	local bar = fx.healthBar(best)
	bar.Size = UDim2.fromScale(math.max(best.hp, 0) / best.maxHp, 1)
	if best.hp <= 0 then
		best.hp = nil
		nodes[best.model] = nil
		if best.bar then
			best.bar.Parent.Parent:Destroy()
		end
		harvest(colony, best)
		fx.fell(best, root.Position)
	else
		fx.shake(best.model)
	end
	return true
end

-- Bandits ------------------------------------------------------------------------

local function spawnBandit(camp)
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(206, 166, 132)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(70, 58, 44)
	desc.LeftLegColor = Color3.fromRGB(46, 40, 34)
	desc.RightLegColor = Color3.fromRGB(46, 40, 34)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return
	end
	model.Name = "Bandit"
	model:SetAttribute("Bandit", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Bandit"
	humanoid.MaxHealth = WL.BanditHealth
	humanoid.Health = WL.BanditHealth
	humanoid.WalkSpeed = 13
	local function gear(onto, name, size, offset, color, material, shape)
		if not onto then
			return
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		if shape then
			p.Shape = shape
		end
		p.CanCollide = false
		p.Massless = true
		p.CFrame = onto.CFrame * offset
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = onto
		w.Part1 = p
		w.Parent = p
	end
	-- a ragged hood and a hand axe
	gear(model:FindFirstChild("Head"), "Hood", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 0.25, 0.1), Color3.fromRGB(52, 46, 40), Enum.Material.Fabric, Enum.PartType.Ball)
	local hand = model:FindFirstChild("RightHand")
	gear(hand, "Haft", Vector3.new(0.22, 2.6, 0.22), CFrame.new(0, -0.5, -0.4) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(100, 70, 44), Enum.Material.Wood)
	gear(hand, "AxeHead", Vector3.new(0.18, 0.8, 0.9), CFrame.new(0, 0.1, -1.6), Color3.fromRGB(110, 112, 118), Enum.Material.Metal)
	local spot = camp.position + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
	model:PivotTo(CFrame.new(spot + Vector3.new(0, 3.2, 0)))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local walkTrack
	pcall(function()
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local anim = Instance.new("Animation")
		anim.AnimationId = WALK_ANIM
		walkTrack = animator:LoadAnimation(anim)
	end)
	humanoid.Running:Connect(function(speed)
		if walkTrack then
			if speed > 0.5 and not walkTrack.IsPlaying then
				walkTrack:Play()
			elseif speed <= 0.5 and walkTrack.IsPlaying then
				walkTrack:Stop()
			end
		end
	end)
	local b = { model = model, humanoid = humanoid, root = root, camp = camp, lastHit = 0, nextWander = 0 }
	humanoid.Died:Connect(function()
		b.dead = true
		local killer = b.lastAttacker
		local colony = killer and services.ColonyService:Get(killer)
		if colony then
			for res, n in WL.BanditLoot do
				services.ColonyService:Add(colony, res, n)
			end
			services.ColonyService:Notify(colony, "A bandit falls! +" .. Grid.costText(WL.BanditLoot), "gain")
			services.ColonyService:Sync(colony)
		end
		task.delay(4, function()
			model:Destroy()
		end)
		task.delay(WL.BanditRespawnSeconds, function()
			local i = table.find(bandits, b)
			if i then
				table.remove(bandits, i)
			end
			spawnBandit(camp)
		end)
	end)
	table.insert(bandits, b)
end

-- A camp: a fire ring, a lean-to and a stolen chest.
local function makeCamp(at: Vector3)
	local camp = Instance.new("Model")
	camp.Name = "BanditCamp"
	local function part(props)
		local p = Instance.new("Part")
		p.Anchored = true
		for k, v in props do
			p[k] = v
		end
		p.Parent = camp
		return p
	end
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2
		part({ Size = Vector3.new(1, 0.7, 0.9), CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 1.8, 0.3, math.sin(a) * 1.8)) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(110, 108, 104), Material = Enum.Material.Slate })
	end
	local embers = part({ Name = "Embers", Size = Vector3.new(2, 0.3, 2), CFrame = CFrame.new(at + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(255, 110, 40), Material = Enum.Material.Neon, CanCollide = false })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	fire.Parent = embers
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 140, 60)
	light.Range = 24
	light.Brightness = 1.8
	light.Parent = embers
	-- a hide lean-to on two poles
	for _, x in { -2.5, 2.5 } do
		part({ Size = Vector3.new(0.35, 4.5, 0.35), CFrame = CFrame.new(at + Vector3.new(x, 2.25, 5)), Color = Color3.fromRGB(80, 58, 40), Material = Enum.Material.Wood })
	end
	part({ Size = Vector3.new(6, 0.2, 4.6), CFrame = CFrame.new(at + Vector3.new(0, 2.6, 6.4)) * CFrame.Angles(math.rad(-38), 0, 0), Color = Color3.fromRGB(120, 88, 60), Material = Enum.Material.Fabric })
	part({ Size = Vector3.new(2, 1.4, 1.3), CFrame = CFrame.new(at + Vector3.new(3.6, 0.7, 3.4)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(110, 76, 46), Material = Enum.Material.WoodPlanks })
	camp.Parent = folder
	return { position = at }
end

local function nearestPlayer(pos: Vector3, range: number): (Player?, BasePart?, Humanoid?)
	local best, bestRoot, bestHum, bestD = nil, nil, nil, range
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local d = (root.Position - pos).Magnitude
			if d < bestD then
				best, bestRoot, bestHum, bestD = player, root, hum, d
			end
		end
	end
	return best, bestRoot, bestHum
end

local function tickBandits(now: number)
	for _, b in bandits do
		if b.dead or not b.root or not b.root.Parent then
			continue
		end
		local pos = b.root.Position
		local fromCamp = flat(pos - b.camp.position).Magnitude
		local _, proot, phum = nearestPlayer(pos, WL.BanditSight)
		if proot and fromCamp < WL.BanditLeash then
			b.humanoid:MoveTo(proot.Position)
			if (proot.Position - pos).Magnitude < 6 and now - b.lastHit > 1.3 then
				b.lastHit = now
				phum:TakeDamage(WL.BanditDamage)
				Sounds.play("Swing", b.root)
			end
		elseif fromCamp > 12 then
			b.humanoid:MoveTo(b.camp.position) -- back to the fire
		elseif now > b.nextWander then
			b.nextWander = now + rng:NextNumber(4, 10)
			b.humanoid:MoveTo(b.camp.position + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8)))
		end
	end
end

-- Combat hooks (ToolService, the war band) ---------------------------------------------

function WildlandsService:FindBandit(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Bandit") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

function WildlandsService:BanditsNear(position: Vector3, look: Vector3, range: number): { Model }
	local found = {}
	for _, b in bandits do
		if not b.dead and b.root and b.root.Parent then
			local offset = flat(b.root.Position - position)
			if offset.Magnitude <= range and (offset.Magnitude < 2 or offset.Unit:Dot(flat(look).Unit) > 0.2) then
				table.insert(found, b.model)
			end
		end
	end
	return found
end

function WildlandsService:NearestBandit(position: Vector3, range: number): (Model?, BasePart?)
	local best, bestRoot, bestD = nil, nil, range
	for _, b in bandits do
		if not b.dead and b.root and b.root.Parent then
			local d = (b.root.Position - position).Magnitude
			if d < bestD then
				best, bestRoot, bestD = b.model, b.root, d
			end
		end
	end
	return best, bestRoot
end

function WildlandsService:DamageBandit(model: Model, amount: number, attacker: Player?)
	for _, b in bandits do
		if b.model == model and not b.dead then
			if attacker then
				b.lastAttacker = attacker
			end
			b.humanoid:TakeDamage(amount)
			return
		end
	end
end

-- Start -------------------------------------------------------------------------

function WildlandsService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Wildlands"
	folder.Parent = workspace
	-- wait for the valley to be built before looking for ground
	task.wait(2)
	local scenery = workspace:WaitForChild("Scenery", 60)
	if scenery then
		for _, model in scenery:GetChildren() do
			adopt(model)
		end
		scenery.ChildAdded:Connect(adopt)
	end
	for _ = 1, WL.Trees do
		spawnNode("Tree")
	end
	for _ = 1, WL.Rocks do
		spawnNode("Rock")
	end
	for _ = 1, WL.SilverVeins do
		spawnNode("Vein")
	end
	for i = 1, WL.BanditCamps do
		-- spread the camps out along the valley
		local at
		for _ = 1, 20 do
			local spot = openSpot()
			if spot then
				local x0 = MIN_X + (MAX_X - MIN_X) * (i - 0.5) / WL.BanditCamps
				if math.abs(spot.X - x0) < (MAX_X - MIN_X) / WL.BanditCamps / 2 then
					at = spot
					break
				end
				at = at or spot
			end
		end
		if at then
			local camp = makeCamp(at)
			table.insert(camps, camp)
			for _ = 1, WL.BanditsPerCamp do
				spawnBandit(camp)
			end
		end
	end

	-- a warning the first time each player walks into the wilds
	local warned = {}
	Players.PlayerRemoving:Connect(function(player)
		warned[player] = nil
	end)
	while true do
		task.wait(0.4)
		local now = os.clock()
		local ok, err = pcall(tickBandits, now)
		if not ok then
			warn("[WildlandsService] " .. tostring(err))
		end
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local inside = root and self:InWild(root.Position)
			if inside and not warned[player] then
				warned[player] = true
				local colony = services.ColonyService:Get(player)
				if colony then
					services.ColonyService:Notify(colony, "You enter the wildlands. Rich timber, stone and silver here, but beware bandits, wolves and bears!", "raid")
				end
			elseif not inside and warned[player] and root and root.Position.Z < HARVEST_MIN_Z - 20 then
				warned[player] = nil
			end
		end
	end
end

return WildlandsService
