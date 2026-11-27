--[[
	WarbandService
	Hire grown villagers as warriors (Config.Warband). A warrior stops working
	and joins your war band. The band has three orders:
	  home    they drill around the village and fight raiders who come
	  follow  they walk with you, fight whatever you fight, and crew your
	          longship (faster rowing, more arrows per volley)
	  away    an expedition: they march (or sail) off to a rival hold on their
	          own and come back with loot and a report, so you can stay home
	          and build
	Warriors are villagers with v.warrior = true, so they are saved with
	everyone else and still eat. A warrior who falls is gone for good.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local ModelFactory = require(Shared.ModelFactory)

local WarbandService = {}

local W = Config.Warband
local services
local rng = Random.new()

function WarbandService:Init(all)
	services = all
end

local function band(colony)
	colony.warband = colony.warband or { mode = "home" }
	return colony.warband
end

local function warriors(colony)
	local list = {}
	for _, v in colony.villagers do
		if v.warrior then
			table.insert(list, v)
		end
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end
WarbandService.Warriors = function(_, colony)
	return warriors(colony)
end

function WarbandService:Max(colony): number
	return W.MaxByRank[services.RankService:Rank(colony)] or W.MaxByRank[#W.MaxByRank]
end

local function maxHealth(colony): number
	return W.Health + (services.ColonyService:Has(colony, "ChainMail") and 40 or 0)
end

local function blowDamage(colony): number
	local ColonyService = services.ColonyService
	return W.Damage + (ColonyService:Has(colony, "SteelEdges") and 8 or (ColonyService:Has(colony, "IronAxes") and 4 or 0))
end

-- How strong one warrior is on an expedition.
function WarbandService:WarriorPower(colony): number
	local ColonyService = services.ColonyService
	local p = W.WarriorPower
	for _, t in { "ChainMail", "IronAxes", "SteelEdges" } do
		if ColonyService:Has(colony, t) then
			p += 1
		end
	end
	return p
end

-- The whole band's strength (counted whether home or following).
function WarbandService:Power(colony): number
	local n = 0
	for _, v in warriors(colony) do
		if not v.away then
			n += 1
		end
	end
	return n * self:WarriorPower(colony)
end

-- A hold's strength, to weigh an expedition (or a tribute demand) against.
function WarbandService:HoldPower(def): number
	return def.Defenders * 2 + def.Archers * 2
end

local function holdNamed(name: string)
	for _, def in Config.Rivals do
		if def.Name == name then
			return def
		end
	end
	return nil
end

local function relabel(colony, v)
	services.VillagerService:RefreshLabel(colony, v)
end

-- Hiring and dismissing --------------------------------------------------------

function WarbandService:Hire(colony): (boolean, string)
	local ColonyService = services.ColonyService
	local list = warriors(colony)
	if #list >= self:Max(colony) then
		return false, "Your rank allows " .. self:Max(colony) .. " warriors. Rise in rank for more."
	end
	if band(colony).mode == "away" then
		return false, "Wait until the war band is home."
	end
	-- the youngest grown villager without a family to look after is keenest
	local pick
	for _, v in colony.villagers do
		if not v.isChild and not v.warrior and v.stage ~= "elder" then
			if not pick or (v.job == nil and pick.job ~= nil) or ((v.job == nil) == (pick.job == nil) and v.age < pick.age) then
				pick = v
			end
		end
	end
	if not pick then
		return false, "No grown villager is free to take up arms."
	end
	if not ColonyService:Spend(colony, W.HireCost) then
		return false, "Needs " .. Grid.costText(W.HireCost) .. "."
	end
	pick.warrior = true
	pick.job = nil
	pick.hp = maxHealth(colony)
	if pick.model then
		ModelFactory.armWarrior(pick.model)
	end
	relabel(colony, pick)
	Sounds.play("QuestDone", pick.body and pick.body.Position or nil)
	ColonyService:Notify(colony, pick.name .. " takes up axe and shield and joins your war band!", "good")
	ColonyService:Sync(colony)
	return true, pick.name .. " joined"
end

function WarbandService:Dismiss(colony): (boolean, string)
	if band(colony).mode == "away" then
		return false, "Wait until the war band is home."
	end
	local list = warriors(colony)
	local v = list[#list]
	if not v then
		return false, "You have no warriors."
	end
	v.warrior = nil
	v.hp = nil
	-- a fresh figure without the gear
	services.VillagerService:Rebuild(colony, v)
	services.ColonyService:Notify(colony, v.name .. " hangs up the axe and goes back to work.", "info")
	services.ColonyService:Sync(colony)
	return true, v.name .. " went back to work"
end

function WarbandService:SetMode(colony, mode: string): (boolean, string)
	if mode ~= "home" and mode ~= "follow" then
		return false, "Unknown order."
	end
	local b = band(colony)
	if b.mode == "away" then
		return false, "The war band is away on an expedition."
	end
	if #warriors(colony) == 0 then
		return false, "Hire some warriors first."
	end
	b.mode = mode
	for _, v in warriors(colony) do
		if v.model then
			v.model:SetAttribute("Guard", (mode == "follow" and b.formation == "wall") or nil)
		end
	end
	services.ColonyService:Notify(colony, mode == "follow" and "Your war band falls in behind you." or "Your war band stays to guard the village.", "info")
	services.ColonyService:Sync(colony)
	return true, mode
end

local FORMATIONS = { "loose", "wall", "wedge" }
local formationSpot, assaultGate
local F = Config.Formations

function WarbandService:SetFormation(colony, formation: string?): (boolean, string)
	local b = band(colony)
	if b.mode == "away" then
		return false, "The war band is away on an expedition."
	end
	if #warriors(colony) == 0 then
		return false, "Hire some warriors first."
	end
	if formation == nil or formation == "next" then
		-- cycle to the next one (the G key)
		local i = table.find(FORMATIONS, b.formation or "loose") or 1
		formation = FORMATIONS[i % #FORMATIONS + 1]
	end
	if not F[formation] then
		return false, "Unknown formation."
	end
	b.formation = formation
	if formation ~= "loose" then
		services.QuestService:Count(colony, "formation")
	end
	if b.mode ~= "follow" then
		b.mode = "follow"
	end
	for _, v in warriors(colony) do
		if v.model then
			v.model:SetAttribute("Guard", formation == "wall" or nil)
		end
	end
	Sounds.play("WarHorn", colony.player.Character and colony.player.Character:FindFirstChild("HumanoidRootPart") and colony.player.Character.HumanoidRootPart.Position or nil)
	local text = F[formation].Label .. "! Your war band forms " .. F[formation].Text .. "."
	services.ColonyService:Notify(colony, text, "info")
	services.ColonyService:Sync(colony)
	return true, F[formation].Label
end

-- Following and fighting ---------------------------------------------------------

local function groundY(x: number, z: number): number
	return services.WorldService:GroundHeight(x, z)
end

local function moveTo(v, target: Vector3, speed: number, dt: number)
	local from = v.body.Position
	local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 0.6 then
		return
	end
	local stepLen = math.min(dist, speed * dt)
	local nx, nz = from.X + flat.Unit.X * stepLen, from.Z + flat.Unit.Z * stepLen
	local to = Vector3.new(nx, math.max(groundY(nx, nz), 0.5) + v.height, nz)
	-- a short tween so the motion is smooth between our updates
	TweenService:Create(v.body, TweenInfo.new(dt, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + flat) }):Play()
end

local function swing(v)
	for _, arm in v.model:GetChildren() do
		if arm.Name == "Arm" and arm:GetAttribute("Side") == 1 then
			local joint = arm:FindFirstChild("Joint")
			if joint and joint:IsA("Weld") then
				local rest = joint.C0
				local hip = arm:GetAttribute("Hip")
				local half = arm:GetAttribute("HalfLen") or 0.7
				if typeof(hip) == "CFrame" then
					joint.C0 = hip * CFrame.Angles(math.rad(-120), 0, 0) * CFrame.new(0, -half, 0)
					task.delay(0.2, function()
						if joint.Parent then
							joint.C0 = rest
						end
					end)
				end
			end
		end
	end
end

-- The nearest enemy of this colony to `pos`: rival guards, raiders attacking
-- the village, or militia in a town raid you started.
local function nearestEnemy(colony, pos: Vector3, range: number)
	local best, bestRoot, bestDmg = services.RaidService:NearestDefender(pos, range)
	local bestD = bestRoot and (bestRoot.Position - pos).Magnitude or range
	local kind = best and "defender"
	local m, root = services.VillageDefenseService:NearestRaider(colony, pos, bestD)
	if m and root then
		best, bestRoot, bestDmg, kind = m, root, Config.VillageRaids.RaiderDamage, "raider"
		bestD = (root.Position - pos).Magnitude
	end
	m, root = services.TownRaidService:NearestMilitia(colony.player, pos, bestD)
	if m and root then
		best, bestRoot, bestDmg, kind = m, root, Config.TownRaid.MilitiaDamage or 8, "militia"
	end
	return best, bestRoot, bestDmg, kind
end

local function hit(colony, kind: string, model: Model, amount: number)
	if kind == "defender" then
		services.RaidService:DamageDefender(model, amount, colony.player)
	elseif kind == "raider" then
		services.VillageDefenseService:DamageRaider(model, amount)
	elseif kind == "militia" then
		services.TownRaidService:DamageMilitia(model, amount, colony.player)
	end
end

local function fall(colony, v)
	services.ColonyService:Notify(colony, v.name .. " fell in battle. Their name will be sung in the hall.", "bad")
	services.VillagerService:Remove(colony, v)
end

-- One fighting step for a warrior near an enemy. Returns true if it fought.
-- `f` is the formation's settings: Sight, Speed, Damage, DamageTaken, and
-- Leash (how far from `anchor` they may chase; a shield wall holds its line).
local function fight(colony, v, now: number, dt: number, anchor: Vector3, f): boolean
	f = f or {}
	local sight = W.Sight * (f.Sight or 1)
	local leash = f.Leash or sight * 1.5
	local enemy, root, dmg, kind = nearestEnemy(colony, v.body.Position, sight)
	if not enemy or not root or (root.Position - anchor).Magnitude > leash then
		return false
	end
	local d = (root.Position - v.body.Position) * Vector3.new(1, 0, 1)
	if d.Magnitude > W.Reach then
		moveTo(v, root.Position - d.Unit * (W.Reach - 1.5), Config.Villagers.WalkSpeed * 2.4 * (f.Speed or 1), dt)
	else
		v.body.CFrame = CFrame.lookAt(v.body.Position, v.body.Position + d)
		if now - (v.lastBlow or 0) >= W.HitCooldown then
			v.lastBlow = now
			swing(v)
			Sounds.play("Swing", v.body.Position)
			hit(colony, kind, enemy, blowDamage(colony) * (f.Damage or 1))
		end
		-- the enemy hits back now and then
		if now - (v.lastHurt or 0) >= W.HitCooldown * 1.3 then
			v.lastHurt = now
			if rng:NextNumber() < 0.5 then
				v.hp = (v.hp or maxHealth(colony)) - (dmg or 10) * 0.6 * (f.DamageTaken or 1)
				if v.hp <= 0 then
					fall(colony, v)
				end
			end
		end
	end
	v.fighting = now
	return true
end

-- Places for the band on the deck of the player's longship.
local function deckSpot(ship, i: number): CFrame
	local side = (i % 2 == 0) and 1 or -1
	local row = math.floor((i - 1) / 2)
	local z = -ship.length * 0.28 + row * 4.5
	return ship.seat.CFrame * CFrame.new(side * 2.4, -0.2, z - ship.length * 0.32)
end

function WarbandService:CrewCount(player: Player): number
	local colony = services.ColonyService:Get(player)
	if not colony or band(colony).mode ~= "follow" then
		return 0
	end
	if not services.BoatService:ShipOf(player) then
		return 0
	end
	local n = 0
	for _, v in warriors(colony) do
		if not v.away then
			n += 1
		end
	end
	return n
end

function WarbandService:CrewBonus(player: Player): number
	return math.min(self:CrewCount(player) * W.CrewSpeed, W.CrewSpeedMax)
end

-- Where warrior i of n stands, around the player at `anchor` facing `look`.
formationSpot = function(formation: string, i: number, n: number, anchor: Vector3, look: Vector3, right: Vector3): Vector3
	if formation == "wall" then
		-- two ranks of shields in front of you, the second rank staggered
		local perRank = math.max(2, math.ceil(n / 2))
		local rank = (i - 1) // perRank
		local inRank = math.min(perRank, n - rank * perRank)
		local k = (i - 1) % perRank
		local offset = (k - (inRank - 1) / 2) * 3 + rank * 1.5
		return anchor + look * (5 - rank * 2.8) + right * offset
	elseif formation == "wedge" then
		-- the boar's snout: a point ahead of you, widening back
		local row = math.ceil(i / 2)
		local side = (i % 2 == 0) and 1 or -1
		return anchor + look * (5.5 - row * 2.6) + right * side * (1.2 + row * 2.2)
	end
	-- loose: a crowd at your back
	local row = math.ceil(i / 2)
	return anchor - look * (3 + row * 3) + right * ((i % 2 == 0) and 2.5 or -2.5) * row * 0.8
end

-- Near a rival gate with no one to fight: hack at the doors beside you.
assaultGate = function(colony, v, i: number, now: number, dt: number, root: BasePart, formation: string): boolean
	if formation == "wall" then
		return false
	end
	local gate = services.RaidService:GateNear(root.Position, 30)
	if not gate then
		return false
	end
	-- spread along the outside of the doors
	local sideOf = (root.Position - gate.position):Dot(gate.out) >= 0 and 1 or -1
	local slot = ((i - 1) % 6 - 2.5) / 2.5 * (gate.half - 1.5)
	local spot = gate.position + gate.out * (3 * sideOf) + gate.side * slot
	local d = (spot - v.body.Position) * Vector3.new(1, 0, 1)
	if d.Magnitude > 1.5 then
		moveTo(v, spot, Config.Villagers.WalkSpeed * 2.4 * (formation == "wedge" and Config.Formations.wedge.Speed or 1), dt)
	else
		v.body.CFrame = CFrame.lookAt(v.body.Position, v.body.Position - gate.out * sideOf)
		if now - (v.lastBlow or 0) >= W.HitCooldown then
			v.lastBlow = now
			swing(v)
			local ram = formation == "wedge" and Config.Siege.WedgeRam or 1
			services.RaidService:DamageGate(gate, blowDamage(colony) * ram, colony.player)
		end
	end
	v.fighting = now
	return true
end

local function stepColony(colony, now: number, dt: number)
	local b = band(colony)
	if b.mode == "away" then
		return
	end
	local list = warriors(colony)
	if #list == 0 then
		return
	end
	local player = colony.player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ship = b.mode == "follow" and services.BoatService:ShipOf(player)
	local heal = maxHealth(colony)

	for i, v in list do
		if not v.body or not v.model or not v.model.Parent then
			continue
		end
		local guard = (b.mode == "follow" and b.formation == "wall" and not ship) or nil
		if v.model:GetAttribute("Guard") ~= guard then
			v.model:SetAttribute("Guard", guard)
		end
		if now - (v.fighting or 0) > 4 and (v.hp or heal) < heal then
			v.hp = math.min(heal, (v.hp or heal) + W.HealPerSecond * dt)
		end
		if b.mode == "follow" and root then
			if ship then
				-- aboard: stand at the oars, riding with the ship
				v.body.CFrame = deckSpot(ship, i) * CFrame.new(0, v.height, 0)
				continue
			end
			local anchor = root.Position
			local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
			look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, 1)
			local right = Vector3.new(-look.Z, 0, look.X)
			local formation = b.formation or "loose"
			local spot = formationSpot(formation, i, #list, anchor, look, right)
			local f = F[formation]
			local opts = { Sight = f.Sight, Speed = f.Speed, Damage = f.Damage, DamageTaken = f.DamageTaken }
			if formation == "wall" then
				-- hold the line: only strike what comes close to their place in it
				opts.Sight = (W.Reach + 6) / W.Sight
				opts.Leash = W.Reach + 8
			end
			if not fight(colony, v, now, dt, formation == "wall" and spot or anchor, opts) and not assaultGate(colony, v, i, now, dt, root, formation) then
				local far = (spot - v.body.Position).Magnitude
				if far > 120 then
					-- left far behind (you sailed off or respawned): catch up at once
					local y = math.max(groundY(spot.X, spot.Z), 0.5)
					v.body.CFrame = CFrame.new(spot.X, y + v.height, spot.Z)
				elseif far > 1.2 then
					moveTo(v, spot, (root.AssemblyLinearVelocity.Magnitude > 10 and 20 or Config.Villagers.WalkSpeed * 2) * (f.Speed or 1), dt)
				elseif formation == "wall" then
					-- shields to the front
					v.body.CFrame = CFrame.lookAt(v.body.Position, v.body.Position + look)
				end
			end
		else
			-- at home: guard the village, fight raiders who come in
			local corner, size = Grid.landRect(colony.origin, colony.land)
			local middle = corner + size / 2
			if not fight(colony, v, now, dt, middle) then
				v.homeWalk = v.homeWalk or 0
				if now > v.homeWalk then
					v.homeWalk = now + rng:NextNumber(4, 9)
					v.homeSpot = middle + Vector3.new(rng:NextNumber(-size.X * 0.4, size.X * 0.4), 0, rng:NextNumber(-size.Z * 0.45, -size.Z * 0.2))
				end
				if v.homeSpot and (v.homeSpot - v.body.Position).Magnitude > 120 then
					v.body.CFrame = CFrame.new(v.homeSpot + Vector3.new(0, v.height, 0))
				elseif v.homeSpot then
					moveTo(v, v.homeSpot, Config.Villagers.WalkSpeed, dt)
				end
			end
		end
	end
end

-- Expeditions ------------------------------------------------------------------

function WarbandService:Expedition(colony, holdName: string): (boolean, string)
	local ColonyService = services.ColonyService
	local b = band(colony)
	if b.mode == "away" then
		return false, "The war band is already away."
	end
	local def = typeof(holdName) == "string" and holdNamed(holdName)
	if not def then
		return false, "Pick a hold to raid."
	end
	local list = warriors(colony)
	if #list == 0 then
		return false, "Hire some warriors first."
	end
	if def.Sea and not ColonyService:Has(colony, "Karve") then
		return false, def.Name .. " is across the water: research Karve first."
	end
	if services.DiplomacyService and services.DiplomacyService:IsAllied(colony, def.Name) then
		return false, def.Name .. " is your ally."
	end
	local seconds = def.Sea and W.SeaExpeditionSeconds or W.ExpeditionSeconds
	b.mode = "away"
	b.target = def.Name
	b.returnAt = os.clock() + seconds
	b.seconds = seconds
	b.power = #list * self:WarriorPower(colony)
	for _, v in list do
		v.away = true
		if v.model then
			v.model.Parent = nil
		end
	end
	-- raiding them sours the mood straight away
	if services.DiplomacyService then
		services.DiplomacyService:OnHostile(colony, def.Name)
	end
	Sounds.play("WarHorn", colony.origin + Vector3.new(Grid.PLOT_SIZE / 2, 0, 0))
	ColonyService:Notify(colony, "Your war band of " .. #list .. " " .. (def.Sea and "sails" or "marches") .. " for " .. def.Name .. ". Back in about " .. math.floor(seconds / 60 + 0.5) .. " minutes.", "raid")
	ColonyService:Sync(colony)
	return true, "Off they go"
end

local function finishExpedition(colony)
	local ColonyService = services.ColonyService
	local b = band(colony)
	local def = holdNamed(b.target or "") or Config.Rival
	local list = {}
	for _, v in warriors(colony) do
		if v.away then
			table.insert(list, v)
		end
	end
	local ratio = (b.power or 0) / WarbandService:HoldPower(def)
	local won = rng:NextNumber() < math.clamp(ratio * 0.75, 0.05, 0.95)

	-- losses
	local deathChance = math.clamp(0.3 - 0.2 * ratio, 0.03, 0.3) * (won and 1 or 2)
	local fallen, wounded = {}, {}
	local heal = maxHealth(colony)
	for _, v in list do
		v.away = nil
		if rng:NextNumber() < deathChance then
			table.insert(fallen, v.name)
			services.VillagerService:Remove(colony, v)
		else
			if rng:NextNumber() < 0.4 then
				v.hp = heal * rng:NextNumber(0.3, 0.7)
				table.insert(wounded, v.name)
			end
			if v.model then
				v.model.Parent = colony.plot.Villagers
				local arrive = colony.origin + Vector3.new(Grid.PLOT_SIZE / 2 + rng:NextNumber(-8, 8), 0, -6)
				v.body.CFrame = CFrame.new(arrive + Vector3.new(0, v.height, 0))
			end
		end
	end

	-- loot
	local loot = {}
	local share = won and W.LootShare * math.clamp(ratio, 0.6, 1.25) or 0.2
	if #list - #fallen <= 0 then
		share = 0 -- nobody came back to carry it
	end
	if ColonyService:Has(colony, "SeaRaiders") and def.Sea then
		share *= 1.5
	end
	for res, base in def.ChestLoot do
		local n = math.floor(base * share)
		if n > 0 then
			loot[res] = n
			ColonyService:Add(colony, res, n)
		end
	end
	if won then
		services.QuestService:Count(colony, "plunder")
	end

	b.mode = "home"
	b.target = nil
	b.returnAt = nil
	local report = {
		hold = def.Name,
		won = won,
		sent = #list,
		loot = loot,
		fallen = fallen,
		wounded = wounded,
	}
	Remotes.WarReport:FireClient(colony.player, report)
	local lootText = next(loot) and Grid.costText(loot) or "nothing"
	ColonyService:Notify(colony, (won and "Victory! " or "Beaten back! ") .. "Your war band is home from " .. def.Name .. " with " .. lootText .. ".", won and "good" or "bad")
	ColonyService:Sync(colony)
end

function WarbandService:State(colony)
	local b = band(colony)
	local list = warriors(colony)
	local heal = maxHealth(colony)
	local members = {}
	for _, v in list do
		table.insert(members, { name = v.name, hp = math.floor(((v.hp or heal) / heal) * 100 + 0.5), away = v.away == true })
	end
	local targets = {}
	for _, def in Config.Rivals do
		local hp = self:HoldPower(def)
		table.insert(targets, {
			name = def.Name,
			sea = def.Sea == true,
			power = hp,
			chance = math.floor(math.clamp((#list * self:WarriorPower(colony)) / hp * 0.75, 0.05, 0.95) * 100),
			allied = services.DiplomacyService and services.DiplomacyService:IsAllied(colony, def.Name) or false,
		})
	end
	return {
		mode = b.mode,
		formation = b.formation or "loose",
		target = b.target,
		secondsLeft = b.returnAt and math.max(0, math.floor(b.returnAt - os.clock())) or nil,
		count = #list,
		max = self:Max(colony),
		power = #list * self:WarriorPower(colony),
		members = members,
		targets = targets,
		hireCost = W.HireCost,
	}
end

function WarbandService:Start()
	Players.PlayerRemoving:Connect(function(player)
		local colony = services.ColonyService:Get(player)
		if colony and band(colony).mode == "away" then
			-- they come home safe (and empty-handed) so the save keeps them
			for _, v in warriors(colony) do
				v.away = nil
			end
			band(colony).mode = "home"
		end
	end)

	local last = os.clock()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			-- on a ship they need to ride smoothly, every frame
			for _, colony in services.ColonyService:All() do
				local b = colony.warband
				if b and b.mode == "follow" then
					local ship = services.BoatService:ShipOf(colony.player)
					if ship then
						for i, v in warriors(colony) do
							if v.body and not v.away then
								v.body.CFrame = deckSpot(ship, i) * CFrame.new(0, v.height, 0)
							end
						end
					end
				end
			end
			return
		end
		local now = os.clock()
		local step = now - last
		last = now
		acc = 0
		for _, colony in services.ColonyService:All() do
			local ok, err = pcall(function()
				local b = band(colony)
				if b.mode == "away" and b.returnAt and now >= b.returnAt then
					finishExpedition(colony)
				else
					stepColony(colony, now, step)
				end
			end)
			if not ok then
				warn("[WarbandService] " .. tostring(err))
			end
		end
	end)
end

return WarbandService
