--[[
	TownRaidService
	Raid other players' villages, Clash-of-Clans style. Each plot has a war
	horn post on its west edge. Another player can hold E on it to start a
	raid:
	  - the village calls up its militia (half its adults, 2 to 6 fighters)
	  - beat every militia within Config.TownRaid.Duration seconds
	  - then plunder the chest by their longhouse: you take a share of their
	    stores (20%, at most 150 of each resource)
	Villages are never destroyed and no buildings are harmed. A raided
	village gets a shield so it can't be raided again for a while, new
	villages are protected for their first days, and raiders have a cooldown.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)

local TownRaidService = {}

local T = Config.TownRaid
local services
local folder: Folder
local raids = {} -- [targetPlayer] = raid
local shields = {} -- [userId] = os.clock() until which a village is shielded
local cooldowns = {} -- [userId] = os.clock() until which a player can't raid
local WALK_ANIM = "rbxassetid://507777826"

function TownRaidService:Init(allServices)
	services = allServices
	folder = Instance.new("Folder")
	folder.Name = "TownRaids"
	folder.Parent = workspace
end

local function notify(player: Player?, text: string, kind: string?)
	local colony = player and services.ColonyService:Get(player)
	if colony then
		services.ColonyService:Notify(colony, text, kind)
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function villageCentre(colony): Vector3
	for _, b in colony.buildings do
		if Config.Buildings[b.type].Housing then
			return b.center
		end
	end
	return colony.origin + Vector3.new(Grid.PLOT_SIZE / 2, 0, Grid.PLOT_SIZE / 2)
end

-- Militia ---------------------------------------------------------------------

local function spawnMilitia(raid, pos: Vector3, ownerName: string)
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(226, 186, 150)
	desc.HeadColor = skin
	desc.LeftArmColor = skin
	desc.RightArmColor = skin
	desc.TorsoColor = Color3.fromRGB(120, 50, 40)
	desc.LeftLegColor = Color3.fromRGB(70, 56, 44)
	desc.RightLegColor = Color3.fromRGB(70, 56, 44)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[TownRaidService] could not create militia: " .. tostring(model))
		return
	end
	model.Name = ownerName .. "'s Militia"
	model:SetAttribute("Militia", true)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayName = ownerName .. "'s Militia"
	humanoid.MaxHealth = T.MilitiaHealth
	humanoid.Health = T.MilitiaHealth
	humanoid.WalkSpeed = 14
	local rightHand = model:FindFirstChild("RightHand")
	if rightHand then
		local spear = Instance.new("Part")
		spear.Name = "Spear"
		spear.Size = Vector3.new(0.25, 0.25, 6)
		spear.Color = Color3.fromRGB(110, 76, 46)
		spear.Material = Enum.Material.Wood
		spear.CanCollide = false
		spear.Massless = true
		spear.CFrame = rightHand.CFrame * CFrame.new(0, 0, -1.5)
		spear.Parent = model
		local w = Instance.new("WeldConstraint")
		w.Part0 = rightHand
		w.Part1 = spear
		w.Parent = spear
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
	local m = { model = model, humanoid = humanoid, root = root, lastHit = 0 }
	humanoid.Died:Connect(function()
		m.dead = true
		task.delay(5, function()
			model:Destroy()
		end)
		TownRaidService:CheckWon(raid)
	end)
	table.insert(raid.militia, m)
end

-- Raids -----------------------------------------------------------------------

local function endRaid(raid, won: boolean, reason: string?)
	if raid.over then
		return
	end
	raid.over = true
	raids[raid.target] = nil
	for _, m in raid.militia do
		if m.model.Parent then
			m.model:Destroy()
		end
	end
	if raid.chest then
		raid.chest:Destroy()
	end
	if raid.diedConn then
		raid.diedConn:Disconnect()
	end
	local now = os.clock()
	cooldowns[raid.attacker.UserId] = now + T.AttackerCooldown
	shields[raid.target.UserId] = now + (won and T.ShieldSeconds or T.FailedShieldSeconds)
	if not won then
		notify(raid.attacker, "The raid on " .. raid.target.DisplayName .. "'s village failed" .. (reason and (": " .. reason) or "."), "bad")
		notify(raid.target, "Your militia drove off " .. raid.attacker.DisplayName .. "! Your stores are safe.", "good")
	end
end

local function plunder(raid, player: Player)
	if raid.over or player ~= raid.attacker or not raid.won then
		return
	end
	local ColonyService = services.ColonyService
	local attacker = ColonyService:Get(raid.attacker)
	local target = ColonyService:Get(raid.target)
	if not attacker or not target then
		endRaid(raid, false, "the village is gone")
		return
	end
	local mult = 1
	if ColonyService:Has(attacker, "SeaRaiders") then
		mult *= 1.25
	end
	local taken = {}
	for _, res in Config.ResourceOrder do
		if res ~= "Lore" then
			local amount = math.floor(math.min((target.resources[res] or 0) * T.LootShare * mult, T.LootCap))
			if amount > 0 then
				target.resources[res] -= amount
				ColonyService:Add(attacker, res, amount)
				taken[res] = amount
			end
		end
	end
	local text = next(taken) and Grid.costText(taken) or "nothing (their stores were empty)"
	ColonyService:Notify(attacker, "Victory! You carried off " .. text .. " from " .. raid.target.DisplayName .. ".", "raid")
	ColonyService:Notify(target, raid.attacker.DisplayName .. " plundered " .. text .. ". Your village is shielded for " .. math.floor(T.ShieldSeconds / 60) .. " minutes.", "bad")
	ColonyService:Sync(attacker)
	ColonyService:Sync(target)
	endRaid(raid, true)
end

function TownRaidService:CheckWon(raid)
	if raid.over or raid.won then
		return
	end
	for _, m in raid.militia do
		if not m.dead then
			return
		end
	end
	raid.won = true
	notify(raid.attacker, "The militia has fallen! Plunder the chest by their longhouse (hold E).", "raid")
	notify(raid.target, "Your militia has fallen! " .. raid.attacker.DisplayName .. " is going for your stores.", "bad")

	local centre = villageCentre(services.ColonyService:Get(raid.target))
	local chest = Instance.new("Model")
	chest.Name = "RaidChest"
	local add = ModelFactory.addPart
	local cf = CFrame.new(centre + Vector3.new(0, 0, -12))
	local box = add(chest, { Name = "Box", Size = Vector3.new(4, 2.2, 2.6), CFrame = cf * CFrame.new(0, 1.1, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks })
	add(chest, { Name = "Silver", Size = Vector3.new(3, 0.4, 1.8), CFrame = cf * CFrame.new(0, 2.4, 0), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Foil })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Range = 10
	light.Parent = box
	chest.Parent = folder
	raid.chest = chest
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Plunder"
	prompt.ObjectText = raid.target.DisplayName .. "'s stores"
	prompt.HoldDuration = 2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = box
	prompt.Triggered:Connect(function(player)
		plunder(raid, player)
	end)
end

local function canRaid(attacker: Player, target: Player): (boolean, string?)
	local ColonyService = services.ColonyService
	local a, t = ColonyService:Get(attacker), ColonyService:Get(target)
	if attacker == target then
		return false, "This is your own village's war horn."
	end
	if not a or not t then
		return false, "That village isn't ready."
	end
	local now = os.clock()
	if raids[target] then
		return false, target.DisplayName .. "'s village is already under attack."
	end
	for _, r in raids do
		if r.attacker == attacker then
			return false, "You're already raiding someone."
		end
	end
	if (shields[target.UserId] or 0) > now then
		return false, target.DisplayName .. "'s village is shielded for " .. math.ceil((shields[target.UserId] - now) / 60) .. " more minute(s)."
	end
	if (cooldowns[attacker.UserId] or 0) > now then
		return false, "Your warriors are resting. Raid again in " .. math.ceil(cooldowns[attacker.UserId] - now) .. "s."
	end
	if a.day < T.MinDay then
		return false, "Your village must reach day " .. T.MinDay .. " before raiding others."
	end
	if t.day < T.MinDay then
		return false, target.DisplayName .. "'s village is too new to raid (protected until day " .. T.MinDay .. ")."
	end
	return true, nil
end

local function startRaid(attacker: Player, target: Player)
	local ok, reason = canRaid(attacker, target)
	if not ok then
		notify(attacker, reason, "bad")
		return
	end
	local colony = services.ColonyService:Get(target)
	local adults = 0
	for _, v in colony.villagers do
		if not v.isChild then
			adults += 1
		end
	end
	local count = math.clamp(math.floor(adults * T.MilitiaPerAdult), T.MinMilitia, T.MaxMilitia)
	local raid = { attacker = attacker, target = target, militia = {}, endsAt = os.clock() + T.Duration }
	raids[target] = raid
	local centre = villageCentre(colony)
	for i = 1, count do
		local a = i / count * math.pi * 2
		local p = centre + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)
		local y = services.WorldService:GroundHeight(p.X, p.Z)
		spawnMilitia(raid, Vector3.new(p.X, y, p.Z), target.DisplayName)
	end
	local hum = attacker.Character and attacker.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		raid.diedConn = hum.Died:Connect(function()
			endRaid(raid, false, "you fell in battle")
		end)
	end
	notify(attacker, "RAID on " .. target.DisplayName .. "'s village! Defeat " .. count .. " militia in " .. T.Duration .. "s.", "raid")
	notify(target, attacker.DisplayName .. " sounds the war horn! Your militia (" .. count .. ") takes up arms.", "raid")
end

-- Combat hooks used by ToolService -----------------------------------------------

function TownRaidService:FindMilitia(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("Militia") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

function TownRaidService:MilitiaNear(position: Vector3, look: Vector3, range: number)
	local found = {}
	for _, raid in raids do
		for _, m in raid.militia do
			if not m.dead and m.root then
				local offset = flat(m.root.Position - position)
				if offset.Magnitude <= range and (offset.Magnitude < 2 or offset.Unit:Dot(flat(look).Unit) > 0.2) then
					table.insert(found, m.model)
				end
			end
		end
	end
	return found
end

function TownRaidService:DamageMilitia(model: Model, amount: number, attacker: Player)
	local raid
	for _, r in raids do
		for _, m in r.militia do
			if m.model == model then
				raid = r
			end
		end
	end
	if not raid or raid.attacker ~= attacker then
		return -- only the raider fights the militia
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

-- Loop ------------------------------------------------------------------------

function TownRaidService:Start()
	-- a war horn post on the west edge of every plot
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		local x, z = o.X - 6, o.Z + Grid.PLOT_SIZE / 2
		local y = services.WorldService:GroundHeight(x, z)
		local post = Instance.new("Part")
		post.Name = "WarHornPost"
		post.Anchored = true
		post.Size = Vector3.new(0.8, 6, 0.8)
		post.Position = Vector3.new(x, y + 3, z)
		post.Color = Color3.fromRGB(96, 70, 48)
		post.Material = Enum.Material.Wood
		post.Parent = folder
		local horn = Instance.new("Part")
		horn.Name = "Horn"
		horn.Anchored = true
		horn.CanCollide = false
		horn.Shape = Enum.PartType.Cylinder
		horn.Size = Vector3.new(2.4, 0.6, 0.6)
		horn.CFrame = CFrame.new(x, y + 5.6, z) * CFrame.Angles(0, 0, math.rad(20))
		horn.Color = Color3.fromRGB(226, 214, 186)
		horn.Material = Enum.Material.SmoothPlastic
		horn.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Raid this village"
		prompt.ObjectText = "War horn"
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = post
		prompt.Triggered:Connect(function(player)
			for _, target in Players:GetPlayers() do
				local colony = services.ColonyService:Get(target)
				if colony and colony.plotIndex == i then
					startRaid(player, target)
					return
				end
			end
			notify(player, "Nobody lives here yet.", "info")
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, raid in raids do
			if raid.attacker == player or raid.target == player then
				endRaid(raid, false, "a chieftain left")
			end
		end
	end)

	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, raid in raids do
			if now > raid.endsAt and not raid.over then
				endRaid(raid, false, "time ran out")
				continue
			end
			local character = raid.attacker.Character
			local troot = character and character:FindFirstChild("HumanoidRootPart")
			local thum = character and character:FindFirstChildOfClass("Humanoid")
			for _, m in raid.militia do
				if not m.dead and m.root and troot and thum and thum.Health > 0 then
					local dist = (troot.Position - m.root.Position).Magnitude
					m.humanoid:MoveTo(troot.Position)
					if dist < 6.5 and now - m.lastHit > 1.2 then
						m.lastHit = now
						thum:TakeDamage(T.MilitiaDamage)
					end
				end
			end
		end
	end
end

return TownRaidService
