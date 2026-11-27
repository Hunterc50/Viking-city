--[[
	VillagerService
	Your people. Each villager is a record plus a small figure that walks
	around the plot. Every tick this service:
	  1. gives idle adults a job at a building with a free slot
	  2. lets workers produce resources
	  3. feeds everyone (and notices starvation)
	  4. moves happiness toward a target based on food and shelter
	  5. once per in-game day: villagers age (baby -> child -> adult ->
	     elder), single adults may marry and share a home, married couples
	     have babies, immigrants arrive from neighbouring tribes, or unhappy
	     villagers leave
	Families: a child is named after a parent (Astrid Bjornsdottir), keeps
	close to its parents while small, and lives in the family home.
	  6. moves the little figures around
]]

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)

local VillagerService = {}

local services
local rng = Random.new()
local V = Config.Villagers

function VillagerService:Init(allServices)
	services = allServices
end

-- Helpers -------------------------------------------------------------------

local function counts(colony)
	local adults, children = 0, 0
	for _, v in colony.villagers do
		if v.isChild then
			children += 1
		else
			adults += 1
		end
	end
	return adults, children
end

local function clampToPlot(colony, pos: Vector3): Vector3
	local o, size = Grid.landRect(colony.origin, colony.land)
	return Vector3.new(math.clamp(pos.X, o.X + 2, o.X + size.X - 2), o.Y, math.clamp(pos.Z, o.Z + 2, o.Z + size.Z - 2))
end

-- A random spot just outside the edge of a building.
local function pointNear(colony, building): Vector3
	local hx = building.sx * Config.CELL / 2 + 2
	local hz = building.sz * Config.CELL / 2 + 2
	local p
	if rng:NextNumber() < 0.5 then
		p = building.center + Vector3.new(rng:NextNumber(-hx, hx), 0, (rng:NextNumber() < 0.5 and -hz or hz))
	else
		p = building.center + Vector3.new((rng:NextNumber() < 0.5 and -hx or hx), 0, rng:NextNumber(-hz, hz))
	end
	return clampToPlot(colony, p)
end

local function randomHome(colony)
	local homes = {}
	for _, b in colony.buildings do
		if Config.Buildings[b.type].Housing then
			table.insert(homes, b)
		end
	end
	if #homes == 0 then
		return nil
	end
	return homes[rng:NextInteger(1, #homes)]
end

local function stageOf(v): string
	if v.isChild then
		return (v.age < V.BabyDays) and "baby" or "child"
	end
	return (v.age >= V.ElderAge) and "elder" or "adult"
end

-- The villager's home building (kept with their family), picking one if needed.
local function homeOf(colony, v)
	local home = v.home and colony.buildings[v.home]
	if home then
		return home
	end
	local partner = v.partner and colony.villagers[v.partner]
	home = partner and partner.home and colony.buildings[partner.home]
	if not home and v.parents then
		for _, pid in v.parents do
			local parent = colony.villagers[pid]
			home = parent and parent.home and colony.buildings[parent.home]
			if home then
				break
			end
		end
	end
	home = home or randomHome(colony)
	v.home = home and home.id or nil
	return home
end

local function firstName(v): string
	return (string.split(v.name, " "))[1]
end

local function updateLabel(colony, v)
	local label = v.model:FindFirstChild("NameTag", true)
	label = label and label:FindFirstChild("Label")
	if not label then
		return
	end
	local stage = stageOf(v)
	local heart = v.partner and colony.villagers[v.partner] and " ♥" or ""
	if stage == "baby" or stage == "child" then
		label.Text = v.name .. " (" .. stage .. ")"
	elseif v.warrior then
		label.Text = v.name .. heart .. " (Warrior)"
	elseif v.job and colony.buildings[v.job] then
		label.Text = v.name .. heart .. " (" .. Config.Buildings[colony.buildings[v.job].type].Display .. ")"
	else
		label.Text = v.name .. heart .. (stage == "elder" and " (elder)" or "")
	end
end

local function makeModel(colony, v, groundPos: Vector3)
	if v.model then
		v.model:Destroy()
	end
	v.stage = stageOf(v)
	v.model = ModelFactory.villager(v.name, v.isChild, rng, v.stage, services.RankService:Rank(colony))
	v.body = v.model.PrimaryPart
	v.height = v.model:GetAttribute("GroundOffset") or v.body.Size.Y / 2
	v.model:PivotTo(CFrame.new(groundPos + Vector3.new(0, v.height, 0)))
	if v.warrior then
		ModelFactory.armWarrior(v.model)
	end
	-- away on an expedition: the figure waits until they come home
	v.model.Parent = (not v.away) and colony.plot.Villagers or nil
	v.busyUntil = 0
	updateLabel(colony, v)
end

-- Builds a fresh figure for `v` where they stand (e.g. after leaving the war band).
function VillagerService:Rebuild(colony, v)
	local pos = v.body and (v.body.Position - Vector3.new(0, v.height or 0, 0)) or colony.origin
	makeModel(colony, v, pos)
end

-- Redraws the name tag (after a name or age is restored from a save).
function VillagerService:RefreshLabel(colony, v)
	updateLabel(colony, v)
end

-- Adding / removing ---------------------------------------------------------

function VillagerService:Add(colony, isChild: boolean, groundPos: Vector3?, name: string?, age: number?)
	local id = services.ColonyService:NewId(colony)
	local v = {
		id = id,
		name = name or Config.Names[rng:NextInteger(1, #Config.Names)],
		isChild = isChild,
		-- days lived here; newcomers arrive as grown adults
		age = age or (isChild and 0 or rng:NextInteger(4, 12)),
		job = nil,
	}
	if not groundPos then
		local home = randomHome(colony)
		groundPos = home and pointNear(colony, home) or colony.origin + Vector3.new(Grid.PLOT_SIZE / 2, 0, Grid.PLOT_SIZE / 2)
	end
	makeModel(colony, v, groundPos)
	colony.villagers[id] = v
	return v
end

function VillagerService:Remove(colony, v)
	colony.villagers[v.id] = nil
	local partner = v.partner and colony.villagers[v.partner]
	if partner then
		partner.partner = nil
		updateLabel(colony, partner)
	end
	if v.model then
		v.model:Destroy()
	end
end

function VillagerService:SpawnStarting(colony)
	local first = {}
	for i = 1, V.Starting do
		first[i] = self:Add(colony, false)
	end
	-- the first two settlers are a married couple
	if first[1] and first[2] then
		first[1].partner, first[2].partner = first[2].id, first[1].id
		local home = homeOf(colony, first[1])
		first[2].home = home and home.id or nil
		updateLabel(colony, first[1])
		updateLabel(colony, first[2])
	end
end

function VillagerService:OnBuildingRemoved(colony, buildingId: number)
	for _, v in colony.villagers do
		if v.job == buildingId then
			v.job = nil
			updateLabel(colony, v)
		end
	end
end

function VillagerService:Cleanup(colony)
	-- Models live inside the plot, which PlotService destroys.
	colony.villagers = {}
end

-- Simulation steps ------------------------------------------------------------

local function assignJobs(colony)
	local filled = {}
	for _, v in colony.villagers do
		if v.job and v.warrior then
			v.job = nil
		end
		if v.job then
			if colony.buildings[v.job] then
				filled[v.job] = (filled[v.job] or 0) + 1
			else
				v.job = nil
			end
		end
	end

	local openings = {}
	for id, b in colony.buildings do
		local slots = Config.Buildings[b.type].Workers or 0
		for _ = 1, slots - (filled[id] or 0) do
			table.insert(openings, id)
		end
	end
	table.sort(openings)

	for _, v in colony.villagers do
		if #openings == 0 then
			break
		end
		if not v.isChild and not v.job and not v.warrior then
			v.job = table.remove(openings, 1)
			v.busyUntil = 0 -- walk to work right away
			updateLabel(colony, v)
		end
	end
end

local function produce(colony, dt: number)
	local ColonyService = services.ColonyService
	local efficiency = 0.5 + colony.happiness / 200
	if colony.starving then
		efficiency *= 0.5
	end
	local workers = {}
	for _, v in colony.villagers do
		if v.job then
			workers[v.job] = (workers[v.job] or 0) + 1
		end
	end
	local season = services.SeasonService:Current()
	local blessing = services.RiteService and services.RiteService:Blessing(colony) or nil
	for id, b in colony.buildings do
		local produces = Config.Buildings[b.type].Produces
		local n = workers[id]
		if produces and n then
			for resource, rate in produces do
				-- crops only grow outside winter
				local seasonal = b.type == "Farm" and season.FarmRate or 1
				local bonus = 1
				if b.type == "Farm" and ColonyService:Has(colony, "CropRotation") then
					bonus *= 1.25
				elseif b.type == "Quarry" and ColonyService:Has(colony, "Masonry") then
					bonus *= 1.3
				elseif b.type == "Woodcutter" and ColonyService:Has(colony, "Woodcraft") then
					bonus *= 1.3
				elseif b.type == "LoreHall" and ColonyService:Has(colony, "SagaTellers") then
					bonus *= 1.5
				end
				if blessing then
					if b.type == "Farm" and blessing.Farm then
						bonus *= blessing.Farm
					elseif (b.type == "Woodcutter" or b.type == "Quarry") and blessing.Work then
						bonus *= blessing.Work
					end
				end
				ColonyService:Add(colony, resource, rate * n * dt * efficiency * seasonal * bonus)
			end
		end
	end
end

local function eat(colony, dt: number)
	local adults, children = counts(colony)
	local foodUse = services.SeasonService:Current().FoodUse
	if services.ColonyService:Has(colony, "MidwinterRite") then
		foodUse = 1
	end
	local blessing = services.RiteService and services.RiteService:Blessing(colony)
	if blessing and blessing.FoodUse then
		foodUse *= blessing.FoodUse
	end
	local need = (adults * V.FoodPerAdultPerSecond + children * V.FoodPerChildPerSecond) * dt * foodUse
	local food = colony.resources.Food or 0
	local wasStarving = colony.starving
	if food >= need then
		colony.resources.Food = food - need
		colony.starving = false
	else
		colony.resources.Food = 0
		colony.starving = need > 0
	end
	if colony.starving and not wasStarving then
		services.ColonyService:Notify(colony, "Your people are starving! Hold E on red berry bushes, hunt deer with the Bow (3), and build Barley Farms.", "bad")
	end
end

local function updateHappiness(colony, dt: number)
	local adults, children = counts(colony)
	local pop = adults + children
	local housing = services.ColonyService:Housing(colony)
	local dailyFood = adults * V.FoodPerAdultPerSecond * Config.DAY_LENGTH

	local target = 55
	if colony.starving then
		target -= 45
	elseif (colony.resources.Food or 0) >= dailyFood * 2 then
		target += 15 -- two days of food in store
	end
	local homeless = math.max(0, pop - housing)
	target -= homeless * 8
	-- buildings and traits that cheer people up (each building type counts once)
	local cheered = {}
	for _, b in colony.buildings do
		local bonus = Config.Buildings[b.type].Happiness
		if bonus and not cheered[b.type] then
			cheered[b.type] = true
			target += bonus
		end
	end
	local ColonyService = services.ColonyService
	if ColonyService:Has(colony, "Feasting") then
		target += 10
	end
	if ColonyService:Has(colony, "PathHearth") then
		target += 10
	end
	-- feasts and blóts (RiteService)
	local Rites = services.RiteService
	if Rites then
		target += Rites:FeastBonus(colony)
		local blessing = Rites:Blessing(colony)
		if blessing and blessing.Happiness then
			target += blessing.Happiness
		end
	end
	target = math.clamp(target, 0, 100)

	colony.happiness += (target - colony.happiness) * math.min(1, 0.05 * dt)
	colony.homeless = homeless
end

local function blessingOf(colony)
	return (services.RiteService and services.RiteService:Blessing(colony)) or {}
end

local function newDay(self, colony)
	local ColonyService = services.ColonyService
	colony.day += 1

	-- Everyone ages: babies start walking, children come of age, adults grey.
	for _, v in colony.villagers do
		v.age += 1
		if v.isChild and v.age >= V.DaysToAdulthood then
			v.isChild = false
		end
		local stage = stageOf(v)
		if stage ~= v.stage then
			makeModel(colony, v, v.body.Position - Vector3.new(0, v.height, 0))
			if stage == "child" then
				ColonyService:Notify(colony, v.name .. " is toddling about on their own now.", "info")
			elseif stage == "adult" then
				ColonyService:Notify(colony, v.name .. " has come of age and can now work.", "good")
			elseif stage == "elder" then
				ColonyService:Notify(colony, v.name .. " is now one of the village elders.", "info")
			end
		end
	end

	-- Two single adults may marry and move into one home.
	if rng:NextNumber() < V.MarriageChancePerDay then
		local singles = {}
		for _, v in colony.villagers do
			if not v.isChild and not (v.partner and colony.villagers[v.partner]) then
				v.partner = nil
				table.insert(singles, v)
			end
		end
		if #singles >= 2 then
			local a = table.remove(singles, rng:NextInteger(1, #singles))
			local b = table.remove(singles, rng:NextInteger(1, #singles))
			a.partner, b.partner = b.id, a.id
			local home = homeOf(colony, a)
			b.home = home and home.id or nil
			updateLabel(colony, a)
			updateLabel(colony, b)
			ColonyService:Notify(colony, a.name .. " and " .. b.name .. " were wed! They share a home now.", "good")
		end
	end

	local adults, children = counts(colony)
	-- free beds, but never past the population cap of your rank
	local free = math.min(ColonyService:Housing(colony), services.RankService:PopCap(colony)) - adults - children
	local h = colony.happiness

	-- Unhappy people leave first.
	if h < V.LeaveBelowHappiness and adults > 1 then
		for _, v in colony.villagers do
			if not v.isChild then
				ColonyService:Notify(colony, v.name .. " was unhappy and left the settlement.", "bad")
				self:Remove(colony, v)
				break
			end
		end
		return
	end

	-- Births: a married couple has a baby, named after one of them.
	local couples = {}
	for _, v in colony.villagers do
		local partner = v.partner and colony.villagers[v.partner]
		if partner and v.id < partner.id and not v.isChild then
			table.insert(couples, { v, partner })
		end
	end
	if #couples > 0 and free > 0 and not colony.starving and h >= V.BirthMinHappiness and rng:NextNumber() < V.BirthChancePerDay * (ColonyService:Has(colony, "PathHearth") and 2 or 1) then
		local couple = couples[rng:NextInteger(1, #couples)]
		local namesake = couple[rng:NextInteger(1, 2)]
		local daughter = rng:NextNumber() < 0.5
		-- names alternate: odd ones are girls' names, even ones boys'
		local pick = rng:NextInteger(0, #Config.Names // 2 - 1) * 2 + (daughter and 1 or 2)
		local name = Config.Names[pick] .. " " .. firstName(namesake) .. (daughter and "sdottir" or "sson")
		local home = homeOf(colony, couple[1])
		local spawnAt = couple[1].body and (couple[1].body.Position - Vector3.new(0, couple[1].height, 0)) or nil
		local v = self:Add(colony, true, spawnAt, name)
		v.parents = { couple[1].id, couple[2].id }
		v.home = home and home.id or nil
		free -= 1
		ColonyService:Notify(colony, couple[1].name .. " and " .. couple[2].name .. " had a baby: " .. name .. "!", "good")
	end

	-- Immigration from neighbouring tribes.
	if free > 0 and not colony.starving and h >= V.ImmigrationMinHappiness and rng:NextNumber() < V.ImmigrationChancePerDay * (blessingOf(colony).Immigration or 1) then
		local maxGroup = V.ImmigrationMaxGroup * (ColonyService:Has(colony, "OpenArms") and 2 or 1)
		local n = rng:NextInteger(1, math.min(maxGroup, free))
		local tribe = Config.Tribes[rng:NextInteger(1, #Config.Tribes)]
		local arrival = colony.origin + Vector3.new(rng:NextNumber(10, Grid.PLOT_SIZE - 10), 0, -4)
		for _ = 1, n do
			self:Add(colony, false, arrival + Vector3.new(rng:NextNumber(-3, 3), 0, 0))
		end
		ColonyService:Notify(colony, n .. (n == 1 and " settler" or " settlers") .. " from the " .. tribe .. " joined you.", "good")
	elseif free <= 0 and h >= V.ImmigrationMinHappiness then
		ColonyService:Notify(colony, "Travellers passed by, but you had no free housing. Build a longhouse!", "info")
	end
end

-- What a worker visibly does at each workplace, and what they carry away.
local WORK = {
	Woodcutter = { task = "Chop", carry = "Log" },
	Quarry = { task = "Mine", carry = "Stone" },
	Farm = { task = "Farm", carry = "Sack" },
	Smithy = { task = "Hammer" },
	Shipyard = { task = "Hammer", carry = "Log" },
	HuntingLodge = { task = "Hammer", carry = "Hide" },
}

-- Where goods are taken: the storehouse, or else the biggest hall.
local function storeOf(colony)
	local best
	for _, b in colony.buildings do
		if b.type == "Storehouse" then
			return b
		elseif (b.type == "GreatHall" or b.type == "Longhouse") and not best then
			best = b
		end
	end
	return best
end

local function walk(colony, v, now: number)
	if now < v.busyUntil or not v.body then
		return
	end
	local target
	local facing -- where to look on arrival
	local work, carry
	local job = v.job and colony.buildings[v.job]
	local stage = v.stage or stageOf(v)
	-- little ones stay close to a parent
	local parent
	if stage == "baby" or stage == "child" then
		for _, pid in v.parents or {} do
			local p = colony.villagers[pid]
			if p and p.body and (not parent or rng:NextNumber() < 0.5) then
				parent = p
			end
		end
	end
	if parent and rng:NextNumber() < (stage == "baby" and 0.9 or 0.55) then
		target = clampToPlot(colony, parent.body.Position + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)))
	elseif job and v.atJob and WORK[job.type] and WORK[job.type].carry and storeOf(colony) and rng:NextNumber() < 0.45 then
		-- haul what they made to the store
		target = pointNear(colony, storeOf(colony))
		carry = WORK[job.type].carry
	elseif job and rng:NextNumber() < 0.85 then
		if job.type == "Farm" then
			-- out among the crop rows
			local h = job.sx * Config.CELL / 2 - 2.5
			target = job.center + Vector3.new(rng:NextNumber(-h, h), 0, rng:NextNumber(-h, h))
		else
			target = pointNear(colony, job)
		end
		facing = job.center
		work = WORK[job.type] and WORK[job.type].task
	else
		local home = homeOf(colony, v)
		local wander = stage == "child" and 30 or (stage == "baby" and 6 or 20)
		if home and rng:NextNumber() < 0.7 then
			target = pointNear(colony, home)
		else
			target = clampToPlot(colony, v.body.Position + Vector3.new(rng:NextNumber(-wander, wander), 0, rng:NextNumber(-wander, wander)))
		end
	end

	-- the client animates these: working while standing, carrying while walking
	v.atJob = work ~= nil
	if v.model then
		v.model:SetAttribute("Task", work)
		v.model:SetAttribute("Carry", carry)
	end

	local from = v.body.Position
	local to = Vector3.new(target.X, colony.origin.Y + v.height, target.Z)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 1 then
		v.busyUntil = now + 2
		return
	end
	local speed = V.WalkSpeed * (({ baby = 0.45, child = 1.25, elder = 0.7 })[stage] or 1)
	local duration = dist / speed
	local look = flat
	if facing then
		local toward = Vector3.new(facing.X - to.X, 0, facing.Z - to.Z)
		if toward.Magnitude > 0.5 then
			look = toward
		end
	end
	v.body.CFrame = CFrame.lookAt(from, from + flat)
	local tween = TweenService:Create(v.body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + flat) })
	tween:Play()
	if look ~= flat then
		-- turn to face the work once there
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and v.body and v.body.Parent then
				TweenService:Create(v.body, TweenInfo.new(0.4), { CFrame = CFrame.lookAt(to, to + look) }):Play()
			end
		end)
	end
	-- workers linger at their job; others idle a while
	v.busyUntil = now + duration + rng:NextNumber(job and 3 or 2, job and 8 or 6)
end

function VillagerService:Tick(colony, dt: number)
	assignJobs(colony)
	produce(colony, dt)
	eat(colony, dt)
	updateHappiness(colony, dt)

	colony.dayTimer += dt
	if colony.dayTimer >= Config.DAY_LENGTH then
		colony.dayTimer -= Config.DAY_LENGTH
		newDay(self, colony)
	end

	local now = os.clock()
	for _, v in colony.villagers do
		if not v.warrior then -- the war band moves itself (WarbandService)
			walk(colony, v, now)
		end
	end
end

return VillagerService
