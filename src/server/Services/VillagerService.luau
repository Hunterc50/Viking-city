--[[
	VillagerService
	Your people. Each villager is a record plus a small figure that walks
	around the plot. Every tick this service:
	  1. gives idle adults a job at a building with a free slot
	  2. lets workers produce resources
	  3. feeds everyone (and notices starvation)
	  4. moves happiness toward a target based on food and shelter
	  5. once per in-game day: children grow up, babies are born, immigrants
	     arrive from neighbouring tribes, or unhappy villagers leave
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
	local o = colony.origin
	local size = Grid.PLOT_SIZE
	return Vector3.new(math.clamp(pos.X, o.X + 2, o.X + size - 2), o.Y, math.clamp(pos.Z, o.Z + 2, o.Z + size - 2))
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

local function updateLabel(colony, v)
	local label = v.model:FindFirstChild("NameTag", true)
	label = label and label:FindFirstChild("Label")
	if not label then
		return
	end
	if v.isChild then
		label.Text = v.name .. " (child)"
	elseif v.job and colony.buildings[v.job] then
		label.Text = v.name .. " (" .. Config.Buildings[colony.buildings[v.job].type].Display .. ")"
	else
		label.Text = v.name
	end
end

local function makeModel(colony, v, groundPos: Vector3)
	if v.model then
		v.model:Destroy()
	end
	v.model = ModelFactory.villager(v.name, v.isChild, rng)
	v.body = v.model.PrimaryPart
	v.height = v.model:GetAttribute("GroundOffset") or v.body.Size.Y / 2
	v.model:PivotTo(CFrame.new(groundPos + Vector3.new(0, v.height, 0)))
	v.model.Parent = colony.plot.Villagers
	v.busyUntil = 0
	updateLabel(colony, v)
end

-- Adding / removing ---------------------------------------------------------

function VillagerService:Add(colony, isChild: boolean, groundPos: Vector3?)
	local id = services.ColonyService:NewId(colony)
	local v = {
		id = id,
		name = Config.Names[rng:NextInteger(1, #Config.Names)],
		isChild = isChild,
		age = 0,
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
	if v.model then
		v.model:Destroy()
	end
end

function VillagerService:SpawnStarting(colony)
	for _ = 1, V.Starting do
		self:Add(colony, false)
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
		if not v.isChild and not v.job then
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
	for id, b in colony.buildings do
		local produces = Config.Buildings[b.type].Produces
		local n = workers[id]
		if produces and n then
			for resource, rate in produces do
				-- crops only grow outside winter
				local seasonal = b.type == "Farm" and season.FarmRate or 1
				ColonyService:Add(colony, resource, rate * n * dt * efficiency * seasonal)
			end
		end
	end
end

local function eat(colony, dt: number)
	local adults, children = counts(colony)
	local need = (adults * V.FoodPerAdultPerSecond + children * V.FoodPerChildPerSecond) * dt * services.SeasonService:Current().FoodUse
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
		services.ColonyService:Notify(colony, "Your people are starving! Build farms or forage berries.", "bad")
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
	target = math.clamp(target, 0, 100)

	colony.happiness += (target - colony.happiness) * math.min(1, 0.05 * dt)
	colony.homeless = homeless
end

local function newDay(self, colony)
	local ColonyService = services.ColonyService
	colony.day += 1

	-- Children grow up.
	for _, v in colony.villagers do
		v.age += 1
		if v.isChild and v.age >= V.DaysToAdulthood then
			v.isChild = false
			makeModel(colony, v, v.body.Position - Vector3.new(0, v.height, 0))
			ColonyService:Notify(colony, v.name .. " has come of age and can now work.", "good")
		end
	end

	local adults, children = counts(colony)
	local free = ColonyService:Housing(colony) - adults - children
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

	-- Births.
	if adults >= 2 and free > 0 and not colony.starving and h >= V.BirthMinHappiness and rng:NextNumber() < V.BirthChancePerDay then
		local v = self:Add(colony, true)
		free -= 1
		ColonyService:Notify(colony, "A child named " .. v.name .. " was born!", "good")
	end

	-- Immigration from neighbouring tribes.
	if free > 0 and not colony.starving and h >= V.ImmigrationMinHappiness and rng:NextNumber() < V.ImmigrationChancePerDay then
		local n = rng:NextInteger(1, math.min(V.ImmigrationMaxGroup, free))
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

local function walk(colony, v, now: number)
	if now < v.busyUntil or not v.body then
		return
	end
	local target
	local job = v.job and colony.buildings[v.job]
	if job and rng:NextNumber() < 0.85 then
		target = pointNear(colony, job)
	else
		local home = randomHome(colony)
		if home and rng:NextNumber() < 0.7 then
			target = pointNear(colony, home)
		else
			target = clampToPlot(colony, v.body.Position + Vector3.new(rng:NextNumber(-20, 20), 0, rng:NextNumber(-20, 20)))
		end
	end

	local from = v.body.Position
	local to = Vector3.new(target.X, colony.origin.Y + v.height, target.Z)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < 1 then
		v.busyUntil = now + 2
		return
	end
	local speed = V.WalkSpeed * (v.isChild and 1.2 or 1)
	local duration = dist / speed
	v.body.CFrame = CFrame.lookAt(from, from + flat)
	TweenService:Create(v.body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + flat) }):Play()
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
		walk(colony, v, now)
	end
end

return VillagerService
