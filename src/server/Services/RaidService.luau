--[[
	RaidService
	Greywater Hold: a rival NPC village behind a palisade at the west end of
	the valley (walk past plot 1). You can raid it:

	  - Sound the war horn at the gate (optional) and the guards form a
	    shield wall, then charge.
	  - Fight the guards with the Axe (click) or the Bow.
	  - Hold the Torch and press F at a building to set it alight. Fire
	    chars it black and can spread to neighbours. Buildings are never
	    deleted, only scorched.
	  - Plunder the chests by the storehouses for food, silver and wood.
	  - Once every guard has fallen, the hold's villagers may accept your
	    offer of a new home and join your settlement (needs free housing).

	After a raid the hold rebuilds itself (fires out, walls repaired, chests
	refilled, guards back) after Config.Rival.RegenSeconds.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local ModelFactory = require(Shared.ModelFactory)

local RaidService = {}

local R = Config.Rival
local services
local rng = Random.new()
local folder: Folder
local statusLabel: TextLabel

local state = {
	raidedAt = nil, -- os.clock() of the first hostile act, nil when peaceful
	alarm = false, -- guards hunt anyone nearby
	buildings = {},
	chests = {},
	defenders = {},
	folk = {},
	horn = nil,
}

local CENTER = R.Center
local CHAR = Color3.fromRGB(34, 28, 24)
local WALK_ANIM = "rbxassetid://507777826"
local IDLE_ANIM = "rbxassetid://507766388"

function RaidService:Init(allServices)
	services = allServices
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function notifyAll(text: string, kind: string)
	local ColonyService = services.ColonyService
	for _, colony in ColonyService:All() do
		ColonyService:Notify(colony, text, kind)
	end
end

local function markRaid()
	if not state.raidedAt then
		state.raidedAt = os.clock()
	end
end

local function makePrompt(parent: Instance, action: string, objectText: string, key: Enum.KeyCode, hold: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function anchorPart(cf: CFrame, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = "PromptAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = cf
	p.Parent = parent
	return p
end

-- Fire ------------------------------------------------------------------------

local function ignite(building)
	if building.burning then
		return
	end
	building.burning = true
	building.firePrompt.Enabled = false
	markRaid()

	local parts = {}
	for _, d in building.model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "PromptAnchor" then
			if d:GetAttribute("PreBurnColor") == nil then
				d:SetAttribute("PreBurnColor", d.Color)
				d:SetAttribute("PreBurnTransparency", d.Transparency)
			end
			table.insert(parts, d)
			TweenService:Create(d, TweenInfo.new(R.BurnSeconds), { Color = CHAR }):Play()
		end
	end
	-- flames on a handful of the bigger parts
	table.sort(parts, function(a, b)
		return a.Size.Magnitude > b.Size.Magnitude
	end)
	local flames = {}
	for i = 1, math.min(6, #parts) do
		local part = parts[i]
		local fire = Instance.new("Fire")
		fire.Name = "BurnFx"
		fire.Size = 9
		fire.Heat = 16
		fire.Color = Color3.fromRGB(255, 130, 40)
		fire.SecondaryColor = Color3.fromRGB(255, 50, 10)
		fire.Parent = part
		local smoke = Instance.new("Smoke")
		smoke.Name = "BurnFx"
		smoke.Color = Color3.fromRGB(40, 36, 34)
		smoke.Opacity = 0.35
		smoke.RiseVelocity = 9
		smoke.Size = 7
		smoke.Parent = part
		local light = Instance.new("PointLight")
		light.Name = "BurnFx"
		light.Color = Color3.fromRGB(255, 120, 40)
		light.Range = 34
		light.Brightness = 3
		light.Parent = part
		table.insert(flames, { fire = fire, light = light })
	end

	-- spread to close neighbours, then die down to embers
	task.delay(8, function()
		for _, other in state.buildings do
			if other ~= building and not other.burning and (other.position - building.position).Magnitude < 48 and rng:NextNumber() < 0.45 then
				ignite(other)
			end
		end
	end)
	task.delay(R.BurnSeconds, function()
		if not building.burning then
			return
		end
		for _, f in flames do
			f.fire.Size = 3
			f.light.Brightness = 1
		end
		for _, part in parts do
			if part.Name == "Roof" or part.Name == "Gable" then
				part.Transparency = 0.45 -- burned through
			end
		end
	end)
end

local function restoreBuilding(building)
	building.burning = false
	building.firePrompt.Enabled = true
	for _, d in building.model:GetDescendants() do
		if d.Name == "BurnFx" then
			d:Destroy()
		elseif d:IsA("BasePart") and d:GetAttribute("PreBurnColor") then
			d.Color = d:GetAttribute("PreBurnColor")
			d.Transparency = d:GetAttribute("PreBurnTransparency") or 0
		end
	end
end

-- Chests ----------------------------------------------------------------------

local function makeChest(cf: CFrame)
	local model = Instance.new("Model")
	model.Name = "LootChest"
	local add = ModelFactory.addPart
	add(model, { Name = "Box", Size = Vector3.new(4, 2.2, 2.6), CFrame = cf * CFrame.new(0, 1.1, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks })
	local lid = add(model, { Name = "Lid", Size = Vector3.new(4.1, 0.6, 2.7), CFrame = cf * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(96, 60, 34), Material = Enum.Material.WoodPlanks })
	for _, x in { -1.4, 1.4 } do
		add(model, { Name = "Band", Size = Vector3.new(0.3, 2.9, 2.8), CFrame = cf * CFrame.new(x, 1.4, 0), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal })
	end
	local glint = add(model, { Name = "Silver", Size = Vector3.new(3, 0.4, 1.8), CFrame = cf * CFrame.new(0, 2.15, 0), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Foil })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 230, 160)
	light.Range = 8
	light.Brightness = 0.8
	light.Parent = glint
	model.Parent = folder

	local chest = { model = model, lid = lid, lidClosed = lid.CFrame, hinge = cf * CFrame.new(0, 2.5, 1.3), looted = false }
	chest.prompt = makePrompt(lid, "Plunder", "Chest", Enum.KeyCode.E, 1.5)
	chest.prompt.Triggered:Connect(function(player)
		if chest.looted then
			return
		end
		local ColonyService = services.ColonyService
		local colony = ColonyService:Get(player)
		if not colony then
			return
		end
		chest.looted = true
		chest.prompt.Enabled = false
		markRaid()
		-- swing the lid open
		lid.CFrame = chest.hinge * CFrame.Angles(math.rad(-100), 0, 0) * chest.hinge:Inverse() * chest.lidClosed
		local parts = {}
		local mult = 1
		if ColonyService:Has(colony, "SeaRaiders") then
			mult *= 1.5
		end
		if ColonyService:Has(colony, "PathStorm") then
			mult *= 1.5
		end
		for resource, base in R.ChestLoot do
			local amount = math.floor(base * mult)
			ColonyService:Add(colony, resource, amount)
			table.insert(parts, "+" .. amount .. " " .. resource)
		end
		ColonyService:Notify(colony, "Plundered! " .. table.concat(parts, ", "), "gain")
		ColonyService:Sync(colony)
	end)
	table.insert(state.chests, chest)
end

-- Guards ----------------------------------------------------------------------

local function weld(part: BasePart, to: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function gear(parent: Model, attachTo: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.Massless = true
	p.CFrame = attachTo.CFrame * offset
	p.Parent = parent
	weld(p, attachTo)
	return p
end

local shieldColors = { Color3.fromRGB(46, 70, 120), Color3.fromRGB(220, 214, 200), Color3.fromRGB(40, 90, 80) }

local function spawnDefender(post: Vector3)
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(226, 186, 150)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(58, 66, 84)
	desc.LeftLegColor = Color3.fromRGB(60, 52, 44)
	desc.RightLegColor = Color3.fromRGB(60, 52, 44)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[RaidService] could not create guard: " .. tostring(model))
		return
	end
	model.Name = "Greywater Guard"
	model:SetAttribute("Defender", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = "Greywater Guard"
	humanoid.MaxHealth = R.DefenderHealth
	humanoid.Health = R.DefenderHealth
	humanoid.WalkSpeed = 13
	humanoid.NameDisplayDistance = 60
	humanoid.HealthDisplayDistance = 60

	local head = model:FindFirstChild("Head")
	local leftHand = model:FindFirstChild("LeftHand")
	local rightHand = model:FindFirstChild("RightHand")
	if head then
		gear(model, head, "Helmet", Vector3.new(1.35, 0.7, 1.35), CFrame.new(0, 0.45, 0), Color3.fromRGB(90, 92, 98), Enum.Material.Metal, Enum.PartType.Ball)
		gear(model, head, "NoseGuard", Vector3.new(0.15, 0.6, 0.15), CFrame.new(0, 0.1, -0.62), Color3.fromRGB(90, 92, 98))
	end
	if leftHand then
		gear(model, leftHand, "Shield", Vector3.new(0.3, 3.4, 3.4), CFrame.new(-0.3, 0, 0), shieldColors[rng:NextInteger(1, #shieldColors)], Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	if rightHand then
		gear(model, rightHand, "Haft", Vector3.new(0.25, 3.2, 0.25), CFrame.new(0, -0.6, -0.4) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
		gear(model, rightHand, "AxeHead", Vector3.new(0.2, 1, 1.1), CFrame.new(0, 0.1, -1.9), Color3.fromRGB(120, 122, 130))
	end

	model:PivotTo(CFrame.new(post + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.pi / 2, 0))
	model.Parent = folder.Guards
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end

	-- walk / idle animations (Roblox's standard R15 ones)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local tracks = {}
	pcall(function()
		local walk = Instance.new("Animation")
		walk.AnimationId = WALK_ANIM
		tracks.walk = animator:LoadAnimation(walk)
		local idle = Instance.new("Animation")
		idle.AnimationId = IDLE_ANIM
		tracks.idle = animator:LoadAnimation(idle)
		tracks.idle:Play()
	end)
	humanoid.Running:Connect(function(speed)
		if not tracks.walk then
			return
		end
		if speed > 0.5 and not tracks.walk.IsPlaying then
			tracks.walk:Play()
		elseif speed <= 0.5 and tracks.walk.IsPlaying then
			tracks.walk:Stop()
		end
	end)

	local guard = { model = model, humanoid = humanoid, root = root, post = post, home = post, lastHit = 0, rightHand = rightHand }
	humanoid.Died:Connect(function()
		guard.dead = true
		markRaid()
		task.delay(6, function()
			model:Destroy()
		end)
		local alive = 0
		for _, g in state.defenders do
			if not g.dead then
				alive += 1
			end
		end
		if alive == 0 then
			notifyAll(R.Name .. " has fallen! Its people may accept a new home with you.", "raid")
			for _, f in state.folk do
				f.prompt.Enabled = true
			end
		end
	end)
	table.insert(state.defenders, guard)
end

-- Called by ToolService when an axe blow or arrow lands on a guard.
function RaidService:DamageDefender(model: Model, amount: number, attacker: Player)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)
	if not state.alarm then
		state.alarm = true
		notifyAll(attacker.DisplayName .. " is raiding " .. R.Name .. "!", "raid")
	end
	markRaid()
end

function RaidService:FindDefender(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Defender") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

-- Guards within reach of `player`, in front of them. Used for axe blows.
function RaidService:DefendersNear(position: Vector3, look: Vector3, range: number)
	local found = {}
	for _, g in state.defenders do
		if not g.dead and g.root then
			local offset = flat(g.root.Position - position)
			if offset.Magnitude <= range and (offset.Magnitude < 2 or offset.Unit:Dot(flat(look).Unit) > 0.2) then
				table.insert(found, g.model)
			end
		end
	end
	return found
end

local function nearestTarget(from: Vector3, maxDist: number): (Model?, number)
	local best, bestDist = nil, maxDist
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local inTerritory = flat(root.Position - CENTER).Magnitude < R.DefenderAggro
			local d = (root.Position - from).Magnitude
			if (inTerritory or state.alarm) and d < bestDist then
				best, bestDist = character, d
			end
		end
	end
	return best, bestDist
end

local function swingAxe(guard)
	local hand = guard.rightHand
	if not hand then
		return
	end
	-- a quick lean forward with the axe arm
	local shoulder = guard.model:FindFirstChild("RightUpperArm")
	local motor = shoulder and shoulder:FindFirstChild("RightShoulder")
	if motor and motor:IsA("Motor6D") then
		task.spawn(function()
			motor.Transform = CFrame.Angles(math.rad(-110), 0, 0)
			task.wait(0.2)
			motor.Transform = CFrame.new()
		end)
	end
end

local function guardLoop()
	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, g in state.defenders do
			if not g.dead and g.root then
				local target, dist = nearestTarget(g.root.Position, state.alarm and R.DefenderAggro * 1.6 or R.DefenderAggro)
				if target then
					local troot = target:FindFirstChild("HumanoidRootPart")
					g.humanoid:MoveTo(troot.Position)
					if dist < 6 and now - g.lastHit > 1.1 then
						g.lastHit = now
						swingAxe(g)
						local hum = target:FindFirstChildOfClass("Humanoid")
						if hum then
							local victim = Players:GetPlayerFromCharacter(target)
							local colony = victim and services.ColonyService:Get(victim)
							local damage = R.DefenderDamage
							if services.ColonyService:Has(colony, "PathStorm") then
								damage *= 0.7
							end
							hum:TakeDamage(damage)
						end
					end
				elseif flat(g.root.Position - g.post).Magnitude > 3 then
					g.humanoid:MoveTo(g.post)
				end
			end
		end
	end
end

-- Folk (the hold's villagers) ---------------------------------------------------

local function spawnFolk()
	local model = ModelFactory.villager(Config.Names[rng:NextInteger(1, #Config.Names)], false, rng)
	local offset = model:GetAttribute("GroundOffset")
	local pos = CENTER + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
	model:PivotTo(CFrame.new(pos + Vector3.new(0, offset, 0)))
	model.Parent = folder.Folk
	local folk = { model = model, offset = offset, busyUntil = 0 }
	folk.prompt = makePrompt(model.PrimaryPart, "Offer a new home", model.Name .. " of " .. R.Name, Enum.KeyCode.E, 1)
	folk.prompt.Enabled = false
	folk.prompt.Triggered:Connect(function(player)
		local ColonyService = services.ColonyService
		local colony = ColonyService:Get(player)
		if not colony or not model.Parent then
			return
		end
		local pop = 0
		for _ in colony.villagers do
			pop += 1
		end
		if ColonyService:Housing(colony) - pop <= 0 then
			ColonyService:Notify(colony, "You need a free home first. Build a longhouse or cottage.", "bad")
			return
		end
		local name = model.Name
		model:Destroy()
		table.remove(state.folk, table.find(state.folk, folk))
		local v = services.VillagerService:Add(colony, false, colony.origin + Vector3.new(80, 0, -6))
		v.name = name
		local tag = v.model:FindFirstChild("NameTag", true)
		if tag and tag:FindFirstChild("Label") then
			tag.Label.Text = name
		end
		ColonyService:Notify(colony, name .. " of " .. R.Name .. " accepted a new home in your settlement.", "good")
		ColonyService:Sync(colony)
	end)
	table.insert(state.folk, folk)
end

local function folkLoop()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, f in state.folk do
			local body = f.model.PrimaryPart
			if body and now >= f.busyUntil then
				local fearful = state.alarm
				local target = CENTER + Vector3.new(rng:NextNumber(-30, 30), 0, rng:NextNumber(10, 45) * (fearful and 1 or (rng:NextNumber() < 0.5 and -1 or 1)))
				local from = body.Position
				local to = Vector3.new(target.X, CENTER.Y + f.offset, target.Z)
				local flatDir = flat(to - from)
				if flatDir.Magnitude > 1 then
					local t = flatDir.Magnitude / (fearful and 12 or 5)
					body.CFrame = CFrame.lookAt(from, from + flatDir)
					TweenService:Create(body, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + flatDir) }):Play()
					f.busyUntil = now + t + rng:NextNumber(2, 6)
				end
			end
		end
	end
end

-- Building the hold -------------------------------------------------------------

local LAYOUT = {
	{ "Longhouse", Vector3.new(0, 0, 52) },
	{ "Cottage", Vector3.new(-55, 0, -30) },
	{ "Cottage", Vector3.new(55, 0, -32) },
	{ "Cottage", Vector3.new(-62, 0, 35) },
	{ "Cottage", Vector3.new(60, 0, 40) },
	{ "Storehouse", Vector3.new(-30, 0, -58) },
	{ "Storehouse", Vector3.new(30, 0, -58) },
}

local function buildHold()
	folder = Instance.new("Folder")
	folder.Name = "RivalVillage"
	for _, name in { "Guards", "Folk" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = folder
	end
	folder.Parent = workspace

	for _, entry in LAYOUT do
		local kind, offset = entry[1], entry[2]
		local pos = CENTER + offset
		local cf = CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z))
		local model = ModelFactory.building(kind)
		model:PivotTo(cf)
		model:SetAttribute("RivalBuilding", true)
		model.Parent = folder
		local building = { model = model, position = pos, kind = kind, burning = false }
		local anchor = anchorPart(cf * CFrame.new(0, 4, 0), model)
		building.firePrompt = makePrompt(anchor, "Set alight", kind, Enum.KeyCode.F, 1)
		building.firePrompt.MaxActivationDistance = 18
		building.firePrompt.Triggered:Connect(function(player)
			if not services.ToolService:IsHolding(player, "Torch") then
				local colony = services.ColonyService:Get(player)
				if colony then
					services.ColonyService:Notify(colony, "Hold your Torch first (press 4)", "bad")
				end
				return
			end
			if not state.alarm then
				state.alarm = true
				notifyAll(player.DisplayName .. " is raiding " .. R.Name .. "!", "raid")
			end
			ignite(building)
		end)
		table.insert(state.buildings, building)
		if kind == "Storehouse" then
			makeChest(cf * CFrame.new(0, 0, -15))
		end
	end

	-- the village square
	local square = Instance.new("Model")
	square.Name = "Square"
	ModelFactory.campfire(square, CENTER)
	square.Parent = folder

	-- palisade ring with a gate facing east, toward the player settlements
	local segments = math.floor(2 * math.pi * R.Radius / Config.CELL)
	for i = 0, segments - 1 do
		local a = i / segments * math.pi * 2
		if math.abs(math.atan2(math.sin(a), math.cos(a))) > 0.2 then
			local pos = CENTER + Vector3.new(math.cos(a) * R.Radius, 0, math.sin(a) * R.Radius)
			local wall = ModelFactory.building("Palisade")
			wall:PivotTo(CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z)))
			wall.Parent = folder
		end
	end

	-- the war horn on a post just outside the gate
	local gate = CENTER + Vector3.new(R.Radius + 10, 0, 14)
	local hornModel = Instance.new("Model")
	hornModel.Name = "WarHorn"
	local add = ModelFactory.addPart
	add(hornModel, { Size = Vector3.new(0.8, 7, 0.8), Position = gate + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(74, 52, 36) })
	for k = 0, 4 do
		add(hornModel, {
			Name = "Horn",
			Size = Vector3.new(0.5 + k * 0.18, 0.5 + k * 0.18, 0.9),
			CFrame = CFrame.new(gate + Vector3.new(0, 6.2 + math.sin(k * 0.5) * 0.6, -0.6 - k * 0.7)) * CFrame.Angles(k * 0.25, 0, 0),
			Color = Color3.fromRGB(230, 214, 180),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	hornModel.Parent = folder
	state.hornPrompt = makePrompt(hornModel:FindFirstChild("Horn"), "Sound the war horn", R.Name, Enum.KeyCode.E, 1.5)
	state.hornPrompt.Triggered:Connect(function(player)
		state.hornPrompt.Enabled = false
		markRaid()
		notifyAll("The war horn sounds! " .. R.Name .. " forms a shield wall!", "raid")
		-- guards line up shoulder to shoulder at the gate, then charge
		local n = #state.defenders
		for i, g in state.defenders do
			g.post = CENTER + Vector3.new(R.Radius - 14, 0, (i - (n + 1) / 2) * 3.6)
		end
		task.delay(7, function()
			state.alarm = true
		end)
	end)

	-- a status sign above the hold
	local signPart = anchorPart(CFrame.new(CENTER + Vector3.new(0, 30, 0)), folder)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(320, 60)
	sign.MaxDistance = 600
	sign.AlwaysOnTop = true
	sign.Parent = signPart
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Fantasy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(232, 206, 150)
	title.TextStrokeTransparency = 0.3
	title.Text = R.Name
	title.Parent = sign
	statusLabel = Instance.new("TextLabel")
	statusLabel.Position = UDim2.fromScale(0, 0.58)
	statusLabel.Size = UDim2.new(1, 0, 0.42, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextScaled = true
	statusLabel.TextColor3 = Color3.fromRGB(240, 235, 225)
	statusLabel.TextStrokeTransparency = 0.4
	statusLabel.Parent = sign
end

local function populate()
	for i = 1, R.Defenders do
		local a = (i / R.Defenders) * math.pi * 2
		spawnDefender(CENTER + Vector3.new(math.cos(a) * 28, 0, math.sin(a) * 28))
	end
	for _ = 1, R.Villagers do
		spawnFolk()
	end
end

local function rebuild()
	for _, b in state.buildings do
		restoreBuilding(b)
	end
	for _, c in state.chests do
		c.looted = false
		c.prompt.Enabled = true
		c.lid.CFrame = c.lidClosed
	end
	for _, g in state.defenders do
		if not g.dead then
			g.model:Destroy()
		end
	end
	state.defenders = {}
	for _, f in state.folk do
		f.model:Destroy()
	end
	state.folk = {}
	populate()
	state.alarm = false
	state.raidedAt = nil
	state.hornPrompt.Enabled = true
	notifyAll(R.Name .. " has rebuilt its walls and restocked its stores.", "info")
end

function RaidService:Start()
	buildHold()
	populate()
	task.spawn(guardLoop)
	task.spawn(folkLoop)

	while true do
		task.wait(1)
		if state.raidedAt then
			local left = R.RegenSeconds - (os.clock() - state.raidedAt)
			if left <= 0 then
				rebuild()
			else
				local secs = math.floor(left)
				statusLabel.Text = string.format("Raided! Rebuilds in %d:%02d", secs // 60, secs % 60)
				statusLabel.TextColor3 = Color3.fromRGB(255, 150, 120)
			end
		end
		if not state.raidedAt then
			statusLabel.Text = "Guarded. Raid it for food and silver"
			statusLabel.TextColor3 = Color3.fromRGB(240, 235, 225)
		end
	end
end

return RaidService
