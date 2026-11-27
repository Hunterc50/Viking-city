--[[
	RiteService
	Feasts and seasonal blóts (Config.Rites), held from the Jarl's Table.
	  Feast  at a Longhouse or Great Hall: costs food, lifts happiness for a
	         day, then needs a rest before the next one
	  Blót   once each season at the Shrine; the season decides the blessing
	         (faster farms in spring, joy and newcomers in summer, faster wood
	         and stone in autumn, joy and less hunger at Yule)
	A bonfire burns while the rite lasts and the villagers gather round it.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Sounds = require(Shared.Sounds)

local RiteService = {}

local R = Config.Rites
local services

function RiteService:Init(all)
	services = all
end

local function rites(colony)
	colony.rites = colony.rites or { feastUntil = 0, feastReady = 0 }
	return colony.rites
end

local function findBuilding(colony, types)
	for _, b in colony.buildings do
		if table.find(types, b.type) then
			return b
		end
	end
	return nil
end

-- A crackling bonfire beside the building, for `seconds`.
local function bonfire(colony, building, seconds: number)
	local at = building.center + Vector3.new(0, 0, -(building.sz * Config.CELL / 2 + 6))
	local model = Instance.new("Model")
	model.Name = "RiteFire"
	for i = 1, 6 do
		local log = Instance.new("Part")
		log.Anchored = true
		log.CanCollide = false
		log.Size = Vector3.new(0.6, 0.6, 3.2)
		log.Color = Color3.fromRGB(70, 48, 30)
		log.Material = Enum.Material.Wood
		log.CFrame = CFrame.new(at + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, i * math.pi / 3, math.rad(18))
		log.Parent = model
	end
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Anchored = true
	core.CanCollide = false
	core.Transparency = 1
	core.Size = Vector3.new(2, 1, 2)
	core.Position = at + Vector3.new(0, 1, 0)
	core.Parent = model
	local fire = Instance.new("Fire")
	fire.Size = 9
	fire.Heat = 14
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 30
	light.Brightness = 2.5
	light.Parent = core
	Sounds.loop("Fire", core)
	model.Parent = colony.plot
	task.delay(seconds, function()
		model:Destroy()
	end)
	-- everyone comes to warm their hands
	for _, v in colony.villagers do
		if v.body and not v.warrior and not v.away then
			local a = math.random() * math.pi * 2
			local r = 6 + math.random() * 5
			local spot = at + Vector3.new(math.cos(a) * r, v.height, math.sin(a) * r)
			v.body.CFrame = CFrame.lookAt(spot, Vector3.new(at.X, spot.Y, at.Z))
			v.busyUntil = os.clock() + 25
		end
	end
end

-- Feast ------------------------------------------------------------------------

function RiteService:Feast(colony): (boolean, string)
	local F = R.Feast
	local r = rites(colony)
	local hall = findBuilding(colony, { "GreatHall", F.Needs })
	if not hall then
		return false, "You need a " .. Config.Buildings[F.Needs].Display .. " to feast in."
	end
	if colony.day < r.feastReady then
		return false, "Your people are still full from the last feast (ready on day " .. r.feastReady .. ")."
	end
	if not services.ColonyService:Spend(colony, F.Cost) then
		return false, "A feast needs " .. Grid.costText(F.Cost) .. "."
	end
	-- with your own Brewhouse the mead lasts, and so does the feast
	local brewed = services.ColonyService:HasBuilding(colony, "Brewhouse")
	local days = F.Days + (brewed and 1 or 0)
	r.feastUntil = colony.day + days
	r.feastReady = math.max(colony.day + F.CooldownDays, r.feastUntil)
	bonfire(colony, hall, 60)
	Sounds.play("QuestDone", hall.center)
	services.ColonyService:Notify(colony, "Skål! Mead flows and the hall roars with song. +" .. F.Happiness .. " happiness for " .. (days == 1 and "a day." or days .. " days (your own mead)."), "quest")
	services.ColonyService:Sync(colony)
	return true, "Feast held"
end

function RiteService:FeastBonus(colony): number
	local r = colony.rites
	if r and colony.day < (r.feastUntil or 0) then
		return R.Feast.Happiness
	end
	return 0
end

-- Blót -------------------------------------------------------------------------

local function seasonName(): string
	return workspace:GetAttribute("Season") or "Summer"
end

local function seasonTurn(): number
	return workspace:GetAttribute("SeasonTurn") or 1
end

-- The blessing active this season, or nil.
function RiteService:Blessing(colony)
	local r = colony.rites
	if r and r.blotTurn == seasonTurn() then
		return R.Blot[seasonName()]
	end
	return nil
end

function RiteService:Blot(colony): (boolean, string)
	local r = rites(colony)
	local def = R.Blot[seasonName()]
	if not def then
		return false, "No rite for this season."
	end
	local shrine = findBuilding(colony, { R.Blot.Needs })
	if not shrine then
		return false, "Build a Shrine to hold a blót."
	end
	if r.blotTurn == seasonTurn() then
		return false, "You already held the " .. def.Name .. " this season."
	end
	if not services.ColonyService:Spend(colony, def.Cost) then
		return false, "The " .. def.Name .. " needs " .. Grid.costText(def.Cost) .. "."
	end
	r.blotTurn = seasonTurn()
	bonfire(colony, shrine, 60)
	Sounds.play("QuestDone", shrine.center)
	services.ColonyService:Notify(colony, "The " .. def.Name .. " is held at the shrine. " .. def.Text, "quest")
	services.QuestService:Count(colony, "blot")
	services.ColonyService:Sync(colony)
	return true, "Blót held"
end

function RiteService:State(colony)
	local r = rites(colony)
	local def = R.Blot[seasonName()]
	local hall = findBuilding(colony, { "GreatHall", R.Feast.Needs }) ~= nil
	local shrine = findBuilding(colony, { R.Blot.Needs }) ~= nil
	return {
		feastCost = R.Feast.Cost,
		feastHappiness = R.Feast.Happiness,
		feastActive = colony.day < (r.feastUntil or 0),
		feastReadyDay = r.feastReady or 0,
		hasHall = hall,
		blotName = def and def.Name,
		blotText = def and def.Text,
		blotCost = def and def.Cost,
		blotDone = r.blotTurn == seasonTurn(),
		hasShrine = shrine,
		season = seasonName(),
	}
end

return RiteService
