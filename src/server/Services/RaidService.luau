--[[
	RaidService
	Rival NPC villages behind palisades (Config.Rivals): Greywater Hold at
	the west end of the valley (walk past plot 1) and Ravensfell at the far
	east end. You can raid them:

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
local Sounds = require(Shared.Sounds)
local ModelFactory = require(Shared.ModelFactory)

local RaidService = {}

local services
-- Builds one rival hold from its settings (an entry of Config.Rivals).
local function newHold(R)
	local hold = { def = R }
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
	-- the gate faces this way (0 = east, toward the player plots from the west end)
	local GATE = R.GateAngle or 0
	local gateDir = Vector3.new(math.cos(GATE), 0, math.sin(GATE))
	local gateSide = Vector3.new(-gateDir.Z, 0, gateDir.X)
	local CHAR = Color3.fromRGB(34, 28, 24)
	local WALK_ANIM = "rbxassetid://507777826"
	local IDLE_ANIM = "rbxassetid://507766388"


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

	local function gateBroken(): boolean
		return state.gate == nil or state.gate.broken
	end

	local function lockedOut(player: Player): boolean
		if gateBroken() then
			return false
		end
		local colony = services.ColonyService:Get(player)
		if colony then
			services.ColonyService:Notify(colony, "Break the gate of " .. R.Name .. " first!", "bad")
		end
		return true
	end

	local function makePrompt(parent: Instance, action: string, objectText: string, key: Enum.KeyCode, holdTime: number)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = action
		prompt.ObjectText = objectText
		prompt.KeyboardKeyCode = key
		prompt.HoldDuration = holdTime
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
			if i == 1 then
				local crackle = Sounds.loop("Fire", part)
				if crackle then
					crackle.Name = "BurnFx"
				end
			end
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
			if chest.looted or lockedOut(player) then
				return
			end
			local ColonyService = services.ColonyService
			local colony = ColonyService:Get(player)
			if not colony then
				return
			end
			chest.looted = true
			chest.prompt.Enabled = false
			services.QuestService:Count(colony, "plunder")
			if services.DiplomacyService then
				services.DiplomacyService:OnHostile(colony, R.Name)
			end
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

	local function weld(part: BasePart, to: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = to
		w.Part1 = part
		w.Parent = part
	end

	local buildGate
	-- Gate ------------------------------------------------------------------------
	-- A pair of heavy doors between two towers in the palisade gap. Raiders must
	-- break it before they can plunder or burn anything inside.

	local function updateGateLabel()
		local g = state.gate
		if not g then
			return
		end
		if g.broken then
			g.label.Text = "The gate is broken!"
			g.label.TextColor3 = Color3.fromRGB(255, 150, 120)
		else
			g.label.Text = string.format("Gate %d / %d", math.ceil(g.hp), g.max)
			g.label.TextColor3 = g.hp < g.max and Color3.fromRGB(255, 205, 140) or Color3.fromRGB(240, 235, 225)
		end
		g.bar.Size = UDim2.fromScale(math.clamp(g.hp / g.max, 0, 1), 1)
	end

	local function setGateOpen(open: boolean)
		local g = state.gate
		for _, leaf in g.leaves do
			leaf.part.CanCollide = not open
			if open then
				TweenService:Create(leaf.part, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = leaf.fallen }):Play()
			else
				leaf.part.CFrame = leaf.closed
			end
		end
		g.bar.Parent.Visible = not open
	end

	buildGate = function(segments: number)
		-- the gap's half-width, from the nearest wall segment on either side
		local step = math.pi * 2 / segments
		local aMin = math.huge
		for i = 0, segments - 1 do
			local a = i * step - GATE
			a = math.abs(math.atan2(math.sin(a), math.cos(a)))
			if a > 0.2 then
				aMin = math.min(aMin, a)
			end
		end
		local half = math.max(8, R.Radius * math.sin(aMin) - Config.CELL / 2 + 1)
		local centre = CENTER + gateDir * (R.Radius * math.cos(aMin * 0.5))
		local frame = CFrame.lookAt(centre, centre + gateDir) -- X along the wall, -Z outward
		local model = Instance.new("Model")
		model.Name = "Gate"
		local add = ModelFactory.addPart
		local WOOD = Color3.fromRGB(96, 66, 42)
		local DARK = Color3.fromRGB(70, 48, 32)
		local IRON = Color3.fromRGB(58, 58, 62)
		local H = 13
		-- the two gate towers, with a fighting platform across the top
		for _, side in { -1, 1 } do
			local x = side * (half + 2)
			add(model, { Name = "GateTower", Size = Vector3.new(5, 19, 5), CFrame = frame * CFrame.new(x, 9.5, 0), Color = DARK, Material = Enum.Material.WoodPlanks })
			add(model, { Name = "GateTowerTop", Size = Vector3.new(6.4, 1, 6.4), CFrame = frame * CFrame.new(x, 19.5, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
			add(model, { Name = "Roof", Size = Vector3.new(4.6, 4.6, 4.6), CFrame = frame * CFrame.new(x, 21.6, 0) * CFrame.Angles(0, math.rad(45), 0) * CFrame.Angles(math.rad(45), 0, 0), Color = Color3.fromRGB(58, 44, 34), Material = Enum.Material.Wood })
			for _, y in { 4, 11 } do
				add(model, { Name = "Band", Size = Vector3.new(5.2, 0.5, 5.2), CFrame = frame * CFrame.new(x, y, 0), Color = IRON, Material = Enum.Material.Metal })
			end
		end
		add(model, { Name = "GateWalk", Size = Vector3.new(half * 2 + 4, 1.4, 4.6), CFrame = frame * CFrame.new(0, H + 2.6, 0), Color = WOOD, Material = Enum.Material.WoodPlanks })
		for k = -3, 3 do
			add(model, { Name = "Stake", Size = Vector3.new(0.9, 2.6, 0.9), CFrame = frame * CFrame.new(k * half / 3.2, H + 4.4, -2), Color = DARK, Material = Enum.Material.Wood })
		end
		-- the doors: two heavy leaves that fall outward when the gate breaks
		local leaves = {}
		for _, side in { -1, 1 } do
			local x = side * half / 2
			local closed = frame * CFrame.new(x, H / 2, 0)
			local leaf = add(model, { Name = "GateDoor", Size = Vector3.new(half - 0.1, H, 1.6), CFrame = closed, Color = WOOD, Material = Enum.Material.WoodPlanks })
			leaf.CanCollide = true
			for _, y in { -H * 0.3, H * 0.3 } do
				local band = add(model, { Name = "Band", Size = Vector3.new(half - 0.4, 0.6, 1.9), CFrame = closed * CFrame.new(0, y, 0), Color = IRON, Material = Enum.Material.Metal })
				band.Anchored = false
				band.CanCollide = false
				weld(band, leaf)
			end
			local boss = add(model, { Name = "Band", Size = Vector3.new(1.2, 1.2, 2), CFrame = closed * CFrame.new(-side * (half / 2 - 1.2), 0, 0), Color = IRON, Material = Enum.Material.Metal })
			boss.Anchored = false
			boss.CanCollide = false
			weld(boss, leaf)
			-- fallen flat on the ground outside, a little askew
			local fallen = frame * CFrame.new(x, 0.9, -H / 2 - 0.5) * CFrame.Angles(math.rad(-88), math.rad(side * 6), 0)
			table.insert(leaves, { part = leaf, closed = closed, fallen = fallen })
		end
		-- fire baskets either side of the gate, outside
		for _, side in { -1, 1 } do
			ModelFactory.brazier(model, (frame * CFrame.new(side * (half + 6), 0, -5)).Position, 4.4)
		end
		model.Parent = folder

		-- health over the gate
		local anchor = anchorPart(frame * CFrame.new(0, H + 7, 0), model)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 46)
		gui.MaxDistance = 160
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0.55, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		local back = Instance.new("Frame")
		back.Position = UDim2.fromScale(0.1, 0.66)
		back.Size = UDim2.fromScale(0.8, 0.22)
		back.BackgroundColor3 = Color3.fromRGB(30, 24, 20)
		back.BorderSizePixel = 0
		back.Parent = gui
		local bar = Instance.new("Frame")
		bar.Size = UDim2.fromScale(1, 1)
		bar.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
		bar.BorderSizePixel = 0
		bar.Parent = back

		state.gate = {
			hold = hold,
			model = model,
			leaves = leaves,
			position = centre,
			out = gateDir,
			side = gateSide,
			half = half,
			hp = Config.Siege.GateHealth,
			max = Config.Siege.GateHealth,
			broken = false,
			label = label,
			bar = bar,
		}
		updateGateLabel()
	end

	-- A blow on the gate. Returns true when it landed.
	function hold:DamageGate(amount: number, attacker: Player?): boolean
		local g = state.gate
		if not g or g.broken then
			return false
		end
		markRaid()
		local colony = attacker and services.ColonyService:Get(attacker)
		if colony and services.DiplomacyService then
			services.DiplomacyService:OnHostile(colony, R.Name)
		end
		if not state.alarm then
			state.alarm = true
			notifyAll((attacker and attacker.DisplayName or "Raiders") .. " is storming the gate of " .. R.Name .. "!", "raid")
		end
		g.hp -= amount
		Sounds.play("Chop", g.position + Vector3.new(0, 4, 0))
		-- the doors shudder
		for _, leaf in g.leaves do
			leaf.part.CFrame = leaf.closed * CFrame.new(0, 0, -0.25)
			task.delay(0.08, function()
				if not g.broken then
					leaf.part.CFrame = leaf.closed
				end
			end)
		end
		if g.hp <= 0 then
			g.hp = 0
			g.broken = true
			setGateOpen(true)
			Sounds.play("Build", g.position)
			Sounds.play("WarHorn", g.position)
			notifyAll("The gate of " .. R.Name .. " is broken! Storm the hold!", "raid")
			if colony then
				services.QuestService:Count(colony, "gate")
			end
		end
		updateGateLabel()
		return true
	end

	-- The standing gate if `position` is within `range` of it.
	function hold:GateNear(position: Vector3, range: number)
		local g = state.gate
		if not g or g.broken then
			return nil
		end
		local rel = position - g.position
		local along = math.abs(rel:Dot(g.side))
		local depth = math.abs(rel:Dot(g.out))
		if along <= g.half + range * 0.5 and depth <= range then
			return g
		end
		return nil
	end

	local function restoreGate()
		local g = state.gate
		if g then
			g.hp = g.max
			g.broken = false
			setGateOpen(false)
			updateGateLabel()
		end
	end

	-- Guards ----------------------------------------------------------------------


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

	local archerShoot -- defined below (archers use it from the guard loop)

	local function spawnDefender(post: Vector3, archer: boolean?)
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
		local title = archer and "Greywater Archer" or "Greywater Guard"
		model.Name = title
		model:SetAttribute("Defender", true)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		humanoid.DisplayName = title
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
		if archer and leftHand then
			gear(model, leftHand, "BowLimb", Vector3.new(0.2, 4.2, 0.2), CFrame.new(0, 0, -0.3), Color3.fromRGB(80, 56, 36), Enum.Material.Wood)
		elseif leftHand then
			gear(model, leftHand, "Shield", Vector3.new(0.3, 3.4, 3.4), CFrame.new(-0.3, 0, 0), shieldColors[rng:NextInteger(1, #shieldColors)], Enum.Material.Wood, Enum.PartType.Cylinder)
		end
		if rightHand and not archer then
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

		local guard = { model = model, humanoid = humanoid, root = root, post = post, home = post, lastHit = 0, rightHand = rightHand, archer = archer }
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
	function hold:DamageDefender(model: Model, amount: number, attacker: Player)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		humanoid:TakeDamage(amount)
		local colony = attacker and services.ColonyService:Get(attacker)
		if colony and services.DiplomacyService then
			services.DiplomacyService:OnHostile(colony, R.Name)
		end
		if not state.alarm then
			state.alarm = true
			notifyAll(attacker.DisplayName .. " is raiding " .. R.Name .. "!", "raid")
		end
		markRaid()
	end

	function hold:FindDefender(inst: Instance?): Model?
		while inst and inst ~= workspace do
			if inst:IsA("Model") and inst:GetAttribute("Defender") then
				return inst
			end
			inst = inst.Parent
		end
		return nil
	end

	-- Guards within reach of `player`, in front of them. Used for axe blows.
	function hold:DefendersNear(position: Vector3, look: Vector3, range: number)
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

	-- The closest living guard to `position` (for the war band).
	function hold:NearestDefender(position: Vector3, range: number): (Model?, BasePart?)
		local best, bestRoot, bestD = nil, nil, range
		for _, g in state.defenders do
			if not g.dead and g.root and g.root.Parent then
				local d = (g.root.Position - position).Magnitude
				if d < bestD then
					best, bestRoot, bestD = g.model, g.root, d
				end
			end
		end
		return best, bestRoot
	end

	local function nearestTarget(from: Vector3, maxDist: number): (Model?, number)
		local best, bestDist = nil, maxDist
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			-- allies of this hold are left alone (DiplomacyService)
			local allied = services.DiplomacyService and services.DiplomacyService:IsAlliedPlayer(player, R.Name)
			if root and hum and hum.Health > 0 and not allied then
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

	-- Archers hold their tower and loose arrows at raiders in range.
	archerShoot = function(g, now: number)
		if now - g.lastHit < R.ArcherCooldown then
			return
		end
		local target = nearestTarget(g.root.Position, R.ArcherRange)
		local troot = target and target:FindFirstChild("HumanoidRootPart")
		if not troot then
			return
		end
		g.lastHit = now
		local from = g.root.Position + Vector3.new(0, 1.5, 0)
		g.root.CFrame = CFrame.lookAt(g.root.Position, Vector3.new(troot.Position.X, g.root.Position.Y, troot.Position.Z))
		local hit = rng:NextNumber() < 0.6
		local to = hit and troot.Position or (troot.Position + Vector3.new(rng:NextNumber(-6, 6), -2, rng:NextNumber(-6, 6)))
		local arrow = ModelFactory.arrow()
		arrow.CFrame = CFrame.lookAt(from, to)
		arrow.Parent = workspace
		Sounds.play("Bow", from)
		local flight = (to - from).Magnitude / 140
		TweenService:Create(arrow, TweenInfo.new(flight, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }):Play()
		task.delay(flight + 2, function()
			arrow:Destroy()
		end)
		if hit then
			task.delay(flight, function()
				local hum = target:FindFirstChildOfClass("Humanoid")
				if hum then
					local victim = Players:GetPlayerFromCharacter(target)
					local colony = victim and services.ColonyService:Get(victim)
					hum:TakeDamage(R.ArcherDamage * (services.ColonyService:Has(colony, "PathStorm") and 0.7 or 1))
				end
			end)
		end
	end

	local function guardLoop()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for _, g in state.defenders do
				if g.archer and not g.dead and g.root then
					archerShoot(g, now)
				elseif not g.dead and g.root then
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
		local model = ModelFactory.villager(Config.Names[rng:NextInteger(1, #Config.Names)], false, rng, nil, rng:NextInteger(1, 2))
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

	local LAYOUT = R.Layout or {
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
		folder.Name = "RivalVillage_" .. R.Name:gsub("%s", "")
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
				if lockedOut(player) then
					return
				end
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
			local fromGate = a - GATE
			if math.abs(math.atan2(math.sin(fromGate), math.cos(fromGate))) > 0.2 then
				local pos = CENTER + Vector3.new(math.cos(a) * R.Radius, 0, math.sin(a) * R.Radius)
				local wall = ModelFactory.building("Palisade")
				wall:PivotTo(CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z)))
				wall.Parent = folder
			end
		end
		buildGate(segments)

		-- the war horn on a post just outside the gate
		local gate = CENTER + gateDir * (R.Radius + 10) + gateSide * 14
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
			Sounds.play("WarHorn", CENTER)
			markRaid()
			notifyAll("The war horn sounds! " .. R.Name .. " forms a shield wall!", "raid")
			-- guards line up shoulder to shoulder at the gate, then charge
			local n = #state.defenders
			for i, g in state.defenders do
				g.post = CENTER + gateDir * (R.Radius - 14) + gateSide * ((i - (n + 1) / 2) * 3.6)
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
		-- archers on wooden towers just inside the palisade
		for i = 1, R.Archers do
			local a = (i / R.Archers) * math.pi * 2 + math.pi / R.Archers
			local p = CENTER + Vector3.new(math.cos(a) * (R.Radius - 14), 0, math.sin(a) * (R.Radius - 14))
			if not folder:FindFirstChild("Tower" .. i) then
				local tower = Instance.new("Model")
				tower.Name = "Tower" .. i
				for _, c in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
					ModelFactory.addPart(tower, { Name = "Leg", Size = Vector3.new(0.8, 9, 0.8), Position = p + Vector3.new(c[1], 4.5, c[2]), Color = Color3.fromRGB(96, 70, 48) })
				end
				ModelFactory.addPart(tower, { Name = "Deck", Size = Vector3.new(6, 0.8, 6), Position = p + Vector3.new(0, 9, 0), Color = Color3.fromRGB(110, 80, 54), Material = Enum.Material.WoodPlanks })
				tower.Parent = folder
			end
			spawnDefender(p + Vector3.new(0, 9.4, 0), true)
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
		restoreGate()
		notifyAll(R.Name .. " has rebuilt its walls and restocked its stores.", "info")
	end

	function hold:Start()
		buildHold()
		hold.folder = folder
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

	return hold
end

function RaidService:Init(allServices)
	services = allServices
end

local holds = {}

local function holdOf(model: Instance)
	for _, h in holds do
		if h.folder and model:IsDescendantOf(h.folder) then
			return h
		end
	end
	return nil
end

-- Called by ToolService when an axe blow or arrow lands on a guard.
function RaidService:DamageDefender(model: Model, amount: number, attacker: Player)
	local h = holdOf(model)
	if h then
		h:DamageDefender(model, amount, attacker)
	end
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

-- Guards within reach, in front of `look`, from every hold. Used for melee blows.
function RaidService:DefendersNear(position: Vector3, look: Vector3, range: number)
	local found = {}
	for _, h in holds do
		for _, m in h:DefendersNear(position, look, range) do
			table.insert(found, m)
		end
	end
	return found
end

-- The closest living guard of any hold (for the war band), and its damage.
function RaidService:NearestDefender(position: Vector3, range: number): (Model?, BasePart?, number?)
	local best, bestRoot, bestDmg, bestD = nil, nil, nil, range
	for _, h in holds do
		local m, root = h:NearestDefender(position, bestD)
		if m and root then
			best, bestRoot, bestDmg, bestD = m, root, h.def.DefenderDamage, (root.Position - position).Magnitude
		end
	end
	return best, bestRoot, bestDmg
end

-- The standing gate of any hold near `position` (for the war band), or nil.
function RaidService:GateNear(position: Vector3, range: number)
	for _, h in holds do
		local g = h:GateNear(position, range)
		if g then
			return g
		end
	end
	return nil
end

function RaidService:DamageGate(gate, amount: number, attacker: Player?): boolean
	return gate and gate.hold and gate.hold:DamageGate(amount, attacker) or false
end

-- A player's melee blow: lands on a gate in front of them within `range`.
function RaidService:StrikeGate(position: Vector3, look: Vector3, range: number, amount: number, attacker: Player): boolean
	local g = self:GateNear(position, range)
	if not g then
		return false
	end
	-- facing the doors (from either side)
	local toward = (g.position - position) * Vector3.new(1, 0, 1)
	local facing = toward:Dot(g.out) * look:Dot(g.out) > 0 or math.abs((position - g.position):Dot(g.out)) < 2
	if not facing then
		return false
	end
	return g.hold:DamageGate(amount, attacker)
end

function RaidService:Start()
	for _, def in Config.Rivals do
		local h = newHold(def)
		table.insert(holds, h)
		task.spawn(function()
			h:Start()
		end)
	end
end

return RaidService
