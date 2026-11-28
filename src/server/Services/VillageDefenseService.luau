--[[
	VillageDefenseService
	Every few days (Config.VillageRaids) a warband from one of the rival
	holds raids YOUR village:
	  - you get a warning first, then they march in from the edge of your plot
	  - they head for your stores (Storehouse, or your Longhouse)
	  - Palisades are in the way: they have to stop and hack through (the
	    wall is down for a while, then your people put it back up)
	  - Watchtowers with an archer at work shoot them; you fight with your
	    Sword and Bow
	  - every raider who reaches the stores carries off a share and leaves
	Nothing is ever destroyed. Beat the whole warband for a reward.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)
local Sounds = require(Shared.Sounds)

local VillageDefenseService = {}

local VR = Config.VillageRaids
local services
local rng = Random.new()
local folder: Folder
local raids = {} -- [colony] = raid
local WALK_ANIM = "rbxassetid://507777826"

function VillageDefenseService:Init(allServices)
	services = allServices
	folder = Instance.new("Folder")
	folder.Name = "VillageRaiders"
	folder.Parent = workspace
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function notify(colony, text: string, kind: string?)
	services.ColonyService:Notify(colony, text, kind)
end

-- Where the raiders are going: a storehouse, else any home.
local function storesOf(colony)
	local best
	for _, b in colony.buildings do
		if b.type == "Storehouse" then
			return b
		end
		if not best and Config.Buildings[b.type].Housing then
			best = b
		end
	end
	return best
end

local function spawnRaider(raid, pos: Vector3, holdName: string)
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(220, 182, 146)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(46, 52, 70)
	desc.LeftLegColor = Color3.fromRGB(50, 44, 38)
	desc.RightLegColor = Color3.fromRGB(50, 44, 38)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[VillageDefenseService] could not create raider: " .. tostring(model))
		return
	end
	model.Name = holdName .. " Raider"
	model:SetAttribute("Raider", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = holdName .. " Raider"
	humanoid.MaxHealth = VR.RaiderHealth
	humanoid.Health = VR.RaiderHealth
	humanoid.WalkSpeed = 12
	local head = model:FindFirstChild("Head")
	local hand = model:FindFirstChild("RightHand")
	local function gear(onto, name, size, offset, color, material, shape)
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
		p.CFrame = onto.CFrame * offset
		p.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = onto
		w.Part1 = p
		w.Parent = p
	end
	if head then
		gear(head, "Helmet", Vector3.new(1.35, 0.7, 1.35), CFrame.new(0, 0.45, 0), Color3.fromRGB(70, 72, 78), Enum.Material.Metal, Enum.PartType.Ball)
	end
	if hand then
		gear(hand, "Haft", Vector3.new(0.25, 3.2, 0.25), CFrame.new(0, -0.6, -0.4) * CFrame.Angles(math.rad(90), 0, 0), Color3.fromRGB(110, 76, 46), Enum.Material.Wood)
		gear(hand, "AxeHead", Vector3.new(0.2, 1, 1.1), CFrame.new(0, 0.1, -1.9), Color3.fromRGB(120, 122, 130))
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local walkTrack
	pcall(function()
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
	local r = { model = model, humanoid = humanoid, root = root, lastHit = 0, lastPos = pos, stuckFor = 0 }
	humanoid.Died:Connect(function()
		r.dead = true
		task.delay(5, function()
			model:Destroy()
		end)
		VillageDefenseService:CheckBeaten(raid)
	end)
	table.insert(raid.raiders, r)
end

-- Raid lifecycle ----------------------------------------------------------------

local function endRaid(raid, text: string?, kind: string?)
	if raid.over then
		return
	end
	raid.over = true
	raids[raid.colony] = nil
	for _, r in raid.raiders do
		if not r.dead and r.model.Parent then
			r.model:Destroy()
		end
	end
	raid.colony.nextRaidDay = raid.colony.day + rng:NextInteger(VR.EveryDays[1], VR.EveryDays[2])
	if text then
		notify(raid.colony, text, kind)
	end
end

function VillageDefenseService:CheckBeaten(raid)
	if raid.over then
		return
	end
	local fought = 0
	for _, r in raid.raiders do
		if not r.dead and not r.fled then
			return
		end
		if r.dead then
			fought += 1
		end
	end
	local colony = raid.colony
	if fought > 0 and raid.stolen == 0 then
		for res, n in VR.Reward do
			services.ColonyService:Add(colony, res, n)
		end
		colony.happiness = math.min(100, colony.happiness + 8)
		services.QuestService:Count(colony, "defend")
		endRaid(raid, "The " .. raid.hold .. " warband is beaten! Your people cheer. +" .. Grid.costText(VR.Reward), "raid")
	elseif raid.stolen > 0 then
		endRaid(raid, "The raiders are gone, but they carried off some of your stores. Build Watchtowers and Palisades!", "bad")
	else
		endRaid(raid)
	end
end

local function steal(raid, r)
	local colony = raid.colony
	local taken = {}
	for _, res in Config.ResourceOrder do
		if res ~= "Lore" then
			local n = math.floor(math.min((colony.resources[res] or 0) * VR.StealShare, VR.StealCap))
			if n > 0 then
				colony.resources[res] -= n
				taken[res] = n
			end
		end
	end
	raid.stolen += 1
	r.fled = true
	notify(colony, "A raider reached your stores and ran off with " .. (next(taken) and Grid.costText(taken) or "nothing") .. "!", "bad")
	TweenService:Create(r.root, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	task.delay(0.6, function()
		if r.model.Parent then
			r.model:Destroy()
		end
	end)
	services.ColonyService:Sync(colony)
	VillageDefenseService:CheckBeaten(raid)
end

-- A palisade in the way gets hacked down for a while (never destroyed).
local function breach(colony, near: Vector3): boolean
	for _, b in colony.buildings do
		if Config.Buildings[b.type].Wall and not b.breached and flat(b.center - near).Magnitude < 9 then
			b.breached = true
			for _, p in b.model:GetDescendants() do
				if p:IsA("BasePart") then
					p:SetAttribute("PreBreach", p.Transparency)
					p.Transparency = 0.75
					p.CanCollide = false
				end
			end
			notify(colony, "Raiders are hacking through your palisade!", "bad")
			task.delay(30, function()
				b.breached = false
				if b.model.Parent then
					for _, p in b.model:GetDescendants() do
						if p:IsA("BasePart") then
							p.Transparency = p:GetAttribute("PreBreach") or 0
							p.CanCollide = true
						end
					end
				end
			end)
			return true
		end
	end
	return false
end

local function startRaid(colony, hold)
	local count = math.min(VR.BaseRaiders + math.floor(colony.day / 4), VR.MaxRaiders)
	local raid = { colony = colony, raiders = {}, stolen = 0, hold = hold.Name, startedAt = os.clock() }
	raids[colony] = raid
	-- they come from the side of the plot nearest their hold
	local o = colony.origin
	local fromWest = hold.Center.X < o.X
	-- the middle of the gap beside the plot, clear of even the biggest land
	local x = fromWest and (o.X - Config.PLOT_GAP / 2) or (o.X + Grid.PLOT_SIZE + Config.PLOT_GAP / 2)
	for i = 1, count do
		local z = o.Z + Grid.PLOT_SIZE * 0.3 + i * 6
		local y = services.WorldService:GroundHeight(x, z)
		spawnRaider(raid, Vector3.new(x + rng:NextNumber(-3, 3), y, z), hold.Name)
	end
	Sounds.play("WarHorn", Vector3.new(x, o.Y, o.Z + Grid.PLOT_SIZE / 2))
	notify(colony, "RAID! " .. count .. " " .. hold.Name .. " raiders storm your village!", "raid")
end

-- Warbands march overland, so only the valley holds send them.
local landHolds = {}
for _, r in Config.Rivals do
	if not r.Sea then
		table.insert(landHolds, r)
	end
end

local function warnOf(colony)
	-- allies and holds paying you tribute don't raid you (DiplomacyService)
	local hostile = {}
	for _, r in landHolds do
		if not services.DiplomacyService or services.DiplomacyService:WillRaid(colony, r.Name) then
			table.insert(hostile, r)
		end
	end
	if #hostile == 0 then
		colony.nextRaidDay = colony.day + rng:NextInteger(VR.EveryDays[1], VR.EveryDays[2])
		return
	end
	local hold = hostile[rng:NextInteger(1, #hostile)]
	colony.raidWarned = true
	notify(colony, "Scouts report a " .. hold.Name .. " warband marching on your village! They arrive in " .. VR.WarningSeconds .. " seconds.", "raid")
	task.delay(VR.WarningSeconds, function()
		colony.raidWarned = false
		if colony.player.Parent and services.ColonyService:Get(colony.player) == colony then
			startRaid(colony, hold)
		end
	end)
end

-- Tick ------------------------------------------------------------------------

local function towerArrow(from: Vector3, to: Vector3)
	local arrow = ModelFactory.arrow()
	arrow.CFrame = CFrame.lookAt(from, to)
	arrow.Parent = workspace
	local flight = (to - from).Magnitude / 150
	TweenService:Create(arrow, TweenInfo.new(flight, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }):Play()
	task.delay(flight + 2, function()
		arrow:Destroy()
	end)
	Sounds.play("Bow", from)
	return flight
end

local function tickRaid(raid, now: number, step: number)
	local colony = raid.colony
	if now - raid.startedAt > VR.LeaveAfter then
		for _, r in raid.raiders do
			r.fled = true
		end
		endRaid(raid, "The raiders lost heart and went home.", "info")
		return
	end
	local stores = storesOf(colony)
	local character = colony.player.Character
	local proot = character and character:FindFirstChild("HumanoidRootPart")
	local phum = character and character:FindFirstChildOfClass("Humanoid")

	for _, r in raid.raiders do
		if not r.dead and not r.fled and r.root then
			local pos = r.root.Position
			local goal = stores and stores.center or (colony.origin + Vector3.new(Grid.PLOT_SIZE / 2, 0, Grid.PLOT_SIZE / 2))
			local nearPlayer = proot and phum and phum.Health > 0 and (proot.Position - pos).Magnitude < 22
			if nearPlayer then
				r.humanoid:MoveTo(proot.Position)
				if (proot.Position - pos).Magnitude < 6 and now - r.lastHit > 1.2 then
					r.lastHit = now
					local dmg = VR.RaiderDamage * (services.ColonyService:Has(colony, "PathStorm") and 0.7 or 1)
					phum:TakeDamage(dmg)
				end
			else
				r.humanoid:MoveTo(goal)
				if flat(goal - pos).Magnitude < 11 then
					steal(raid, r)
					continue
				end
			end
			-- stuck against a wall? hack through it
			if (pos - r.lastPos).Magnitude < 0.6 * step * 4 then
				r.stuckFor += step
				if r.stuckFor > 2 and breach(colony, pos) then
					r.stuckFor = 0
				end
			else
				r.stuckFor = 0
			end
			r.lastPos = pos
		end
	end

	-- watchtowers with an archer at work shoot the nearest raider
	local manned = {}
	for _, v in colony.villagers do
		if v.job then
			manned[v.job] = true
		end
	end
	for id, b in colony.buildings do
		if b.type == "Watchtower" and manned[id] and now - (b.lastShot or 0) > VR.TowerCooldown then
			local top = b.center + Vector3.new(0, 15.5, 0)
			local target, best = nil, VR.TowerRange
			for _, r in raid.raiders do
				if not r.dead and not r.fled and r.root then
					local d = (r.root.Position - top).Magnitude
					if d < best then
						target, best = r, d
					end
				end
			end
			if target then
				b.lastShot = now
				local flight = towerArrow(top, target.root.Position)
				task.delay(flight, function()
					if not target.dead then
						target.humanoid:TakeDamage(VR.TowerDamage)
					end
				end)
			end
		end
	end
end

-- Combat hooks for ToolService -----------------------------------------------------

function VillageDefenseService:FindRaider(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Raider") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

function VillageDefenseService:RaidersNear(position: Vector3, look: Vector3, range: number)
	local found = {}
	for _, raid in raids do
		for _, r in raid.raiders do
			if not r.dead and not r.fled and r.root then
				local offset = flat(r.root.Position - position)
				if offset.Magnitude <= range and (offset.Magnitude < 2 or offset.Unit:Dot(flat(look).Unit) > 0.2) then
					table.insert(found, r.model)
				end
			end
		end
	end
	return found
end

-- The closest raider attacking `colony` (for the war band).
function VillageDefenseService:NearestRaider(colony, position: Vector3, range: number): (Model?, BasePart?)
	local raid = raids[colony]
	if not raid then
		return nil, nil
	end
	local best, bestRoot, bestD = nil, nil, range
	for _, r in raid.raiders do
		if not r.dead and not r.fled and r.root and r.root.Parent then
			local d = (r.root.Position - position).Magnitude
			if d < bestD then
				best, bestRoot, bestD = r.model, r.root, d
			end
		end
	end
	return best, bestRoot
end

function VillageDefenseService:DamageRaider(model: Model, amount: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

function VillageDefenseService:Start()
	if not VR.Enabled then
		return
	end
	local last = os.clock()
	while true do
		task.wait(0.25)
		local now = os.clock()
		local step = now - last
		last = now
		for _, colony in services.ColonyService:All() do
			colony.nextRaidDay = colony.nextRaidDay or math.max(VR.FirstDay, colony.day + 2)
			local raid = raids[colony]
			if raid then
				tickRaid(raid, now, step)
			elseif not colony.raidWarned and colony.day >= colony.nextRaidDay then
				warnOf(colony)
			end
		end
	end
end

return VillageDefenseService
