--[[
	SeasonService
	Turns the year: Summer -> Autumn -> Winter -> Spring, each lasting
	Config.SeasonSeconds. A season changes how the world looks:
	  Spring  fresh light-green leaves, young green barley
	  Summer  full green, golden barley
	  Autumn  birches turn gold and orange, ferns go rust-red, grass yellows
	  Winter  snow on the ground, roofs and trees, birches bare, the fjord's
	          edges freeze, and snow falls (the snowfall is drawn on clients)
	and how the colony works (Config.Seasons): farms stop in winter and
	everyone eats more.

	The current season is stored as workspace attributes "Season" (name) and
	"SeasonIndex" so the client can react (snowfall, falling leaves, HUD).
]]

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local SeasonService = {}

local services
local Terrain = Workspace.Terrain
local M = Enum.Material
local currentIndex = 1
local turn = 0 -- how many seasons have begun since the server started

local SNOW = Color3.fromRGB(236, 240, 246)

-- Terrain colours per season, by material.
local TERRAIN = {
	Summer = { Grass = Color3.fromRGB(88, 118, 58), LeafyGrass = Color3.fromRGB(78, 106, 52), Ground = Color3.fromRGB(104, 88, 64) },
	Autumn = { Grass = Color3.fromRGB(126, 118, 62), LeafyGrass = Color3.fromRGB(132, 96, 52), Ground = Color3.fromRGB(110, 86, 60) },
	Winter = { Grass = Color3.fromRGB(226, 230, 238), LeafyGrass = Color3.fromRGB(214, 220, 228), Ground = Color3.fromRGB(190, 190, 196) },
	Spring = { Grass = Color3.fromRGB(100, 136, 62), LeafyGrass = Color3.fromRGB(90, 128, 58), Ground = Color3.fromRGB(100, 84, 62) },
}

function SeasonService:Init(allServices)
	services = allServices
end

function SeasonService:Current()
	return Config.Seasons[currentIndex]
end

-- A stable pseudo-random 0..1 per part, so a birch keeps its autumn colour.
local function hash(part: BasePart): number
	local p = part.Position
	return (math.sin(p.X * 12.9898 + p.Z * 78.233) * 43758.5453) % 1
end

local function base(part: BasePart): Color3
	local c = part:GetAttribute("BaseColor")
	if not c then
		c = part.Color
		part:SetAttribute("BaseColor", c)
	end
	return c
end

-- Imported mesh pieces are named Mat_<Material>_<rrggbb> (see ModelFactory):
-- leaves on a birch fall like Leaves, conifer needles frost like Needles,
-- and thatch and turf roofs take snow like Roof.
local function meshRole(part: BasePart): string?
	local kind = string.match(part.Name, "^Mat_(%a+)_")
	if not kind then
		return nil
	end
	local model = part:FindFirstAncestorOfClass("Model")
	local owner = model and model.Name or ""
	if kind == "Leaves" then
		if string.find(owner, "Birch") then
			return "Leaves"
		elseif string.find(owner, "Tree") or string.find(owner, "Bush") then
			return "Needles"
		end
		return "Moss" -- turf on roofs
	elseif kind == "Thatch" and not string.find(owner, "Ship") then
		return "Roof"
	end
	return nil
end

local function paint(part: BasePart, season: string)
	local name = meshRole(part) or part.Name
	if name == "Needles" or name == "Tip" then
		local c = base(part)
		if season == "Winter" then
			part.Color = c:Lerp(SNOW, 0.5)
		elseif season == "Spring" then
			part.Color = c:Lerp(Color3.fromRGB(70, 110, 60), 0.2)
		else
			part.Color = c
		end
	elseif name == "Leaves" then
		local c = base(part)
		part.Transparency = 0
		if season == "Spring" then
			part.Color = Color3.fromRGB(128, 176, 84)
		elseif season == "Autumn" then
			local golds = { Color3.fromRGB(222, 176, 58), Color3.fromRGB(206, 120, 42), Color3.fromRGB(190, 150, 50), Color3.fromRGB(170, 70, 36) }
			part.Color = golds[math.floor(hash(part) * #golds) + 1]
		elseif season == "Winter" then
			part.Transparency = 1 -- bare branches
		else
			part.Color = c
		end
	elseif name == "Fern" then
		local c = base(part)
		if season == "Autumn" then
			part.Color = Color3.fromRGB(150, 70, 38)
		elseif season == "Winter" then
			part.Color = Color3.fromRGB(170, 150, 120):Lerp(SNOW, 0.6)
		else
			part.Color = c
		end
	elseif name == "Juniper" or name == "Bush" then
		local c = base(part)
		part.Color = season == "Winter" and c:Lerp(SNOW, 0.45) or c
	elseif name == "Moss" then
		local c = base(part)
		part.Color = season == "Winter" and c:Lerp(SNOW, 0.8) or (season == "Autumn" and c:Lerp(Color3.fromRGB(130, 110, 60), 0.4) or c)
	elseif name == "Roof" then
		local c = base(part)
		part.Color = season == "Winter" and c:Lerp(SNOW, 0.8) or c
		if string.sub(part.Name, 1, 4) == "Mat_" then
			part.Material = season == "Winter" and Enum.Material.Snow or Enum.Material.Fabric
		end
	elseif name == "Barley" then
		local c = base(part)
		if season == "Spring" then
			part.Color = Color3.fromRGB(104, 146, 66)
		elseif season == "Autumn" then
			part.Color = c:Lerp(Color3.fromRGB(170, 130, 70), 0.4)
		elseif season == "Winter" then
			part.Color = Color3.fromRGB(110, 92, 70):Lerp(SNOW, 0.6) -- fallow and frosted
		else
			part.Color = c
		end
	end
end

-- Paints every part inside `root` for the current season. Called for the
-- whole world on a season change, and for each new building or tree.
function SeasonService:ApplyTo(root: Instance)
	local season = self:Current().Name
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			paint(d, season)
		end
	end
end

-- Ice floes drifting out on the open fjord in winter.
local floes
local function makeFloes(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "IceFloes"
	local rng = Random.new(1203)
	local avoid = {}
	for _, rival in Config.Rivals do
		if rival.Sea then
			table.insert(avoid, rival)
		end
	end
	local made, tries = 0, 0
	while made < 90 and tries < 600 do
		tries += 1
		local x = rng:NextNumber(-900, 2900)
		local z = rng:NextNumber(-500, -130)
		local clear = math.abs(z + 300) > 45 -- leave the trading ship's lane open
		for _, rival in avoid do
			if (Vector3.new(x, 0, z) - Vector3.new(rival.Center.X, 0, rival.Center.Z)).Magnitude < rival.Radius + 90 then
				clear = false
			end
		end
		if clear then
			made += 1
			local w, d = rng:NextNumber(6, 24), rng:NextNumber(5, 18)
			local spin = CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local floe = Instance.new("Part")
			floe.Name = "IceFloe"
			floe.Anchored = true
			floe.CanCollide = false
			floe.CanQuery = false
			floe.Size = Vector3.new(w, 1.4, d)
			floe.CFrame = CFrame.new(x, 0.15, z) * spin * CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04))
			floe.Material = M.Glacier
			floe.Color = Color3.fromRGB(206, 226, 238)
			floe.Parent = folder
			-- a crust of snow and a broken chunk or two on top
			local crust = floe:Clone()
			crust.Name = "IceSnow"
			crust.Size = Vector3.new(w * rng:NextNumber(0.5, 0.85), 0.5, d * rng:NextNumber(0.5, 0.85))
			crust.CFrame = floe.CFrame * CFrame.new(rng:NextNumber(-w, w) * 0.1, 0.9, rng:NextNumber(-d, d) * 0.1)
			crust.Material = M.Snow
			crust.Color = Color3.fromRGB(240, 244, 250)
			crust.Parent = folder
			if rng:NextNumber() < 0.4 then
				local chunk = floe:Clone()
				chunk.Name = "IceChunk"
				chunk.Size = Vector3.new(rng:NextNumber(2, 5), rng:NextNumber(1.5, 3.5), rng:NextNumber(2, 5))
				chunk.CFrame = floe.CFrame * CFrame.new(rng:NextNumber(-w, w) * 0.3, 1.4, rng:NextNumber(-d, d) * 0.3) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5))
				chunk.Parent = folder
			end
		end
	end
	return folder
end

local frozen = false
local function setIce(on: boolean)
	if on == frozen then
		return
	end
	frozen = on
	floes = floes or makeFloes()
	floes.Parent = on and (Workspace:FindFirstChild("Scenery") or Workspace) or nil
	-- freeze a band of shallow water along both shores
	local from, to = M.Water, M.Glacier
	if not on then
		from, to = M.Glacier, M.Water
	end
	local bands = {
		Region3.new(Vector3.new(-1200, -12, -112), Vector3.new(3200, 0, -36)),
		Region3.new(Vector3.new(-1200, -12, -640), Vector3.new(3200, 0, -520)),
	}
	for _, region in bands do
		Terrain:ReplaceMaterial(region:ExpandToGrid(4), 4, from, to)
	end
end

local function apply(index: number, announce: boolean)
	currentIndex = index
	local season = Config.Seasons[index]
	Workspace:SetAttribute("Season", season.Name)
	Workspace:SetAttribute("SeasonIndex", index)
	turn += 1
	Workspace:SetAttribute("SeasonTurn", turn)

	for material, color in TERRAIN[season.Name] do
		Terrain:SetMaterialColor(M[material], color)
	end
	Terrain:SetMaterialColor(M.Glacier, Color3.fromRGB(196, 222, 236))
	setIce(season.Name == "Winter")
	SeasonService:ApplyTo(Workspace)

	if announce then
		local lines = {
			Summer = "Summer is here. Long days and golden fields.",
			Autumn = "Autumn has come. Fill your stores with food, and stack firewood: homes burn Wood all winter.",
			Winter = "Winter has come! Farms lie frozen, your people eat more, homes burn Wood, and wolves prowl the meadow.",
			Spring = "Spring thaw. The fields can be sown again.",
		}
		local ColonyService = services.ColonyService
		for _, colony in ColonyService:All() do
			ColonyService:Notify(colony, lines[season.Name], season.Name == "Winter" and "bad" or "good")
		end
	end
end

function SeasonService:Start()
	-- WorldService builds the world during Init, so it is ready here.
	apply(1, false)
	while true do
		task.wait(Config.SeasonSeconds)
		apply(currentIndex % #Config.Seasons + 1, true)
	end
end

return SeasonService
