--[[
	WorldService
	Builds the world when the server starts: a Nordic valley made of Terrain,
	generated from layered noise (a heightmap) so it looks natural, then
	painted by height and steepness: grass and meadow flowers in the valley,
	bare rock and slate on cliffs, snow above the snowline, sand and mud at
	the fjord. The build area stays perfectly flat.

	Layout (looking from the lake toward the mountains):
	  z < -44      a fjord lake, with a far shore and peaks across the water
	  z -44..0     sandy beach and docks, then a dirt path in front of each plot
	  z 0..160     the row of player plots (grass)
	  z 160..270   an open meadow where deer roam
	  z 270..470   pine forest, rolling hills and rock outcrops
	  z 480+       snow-capped mountains
	Also sets up warm afternoon light, haze, sky and colour grading.

	Everything here is decoration: change the numbers freely.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)

local WorldService = {}

local Terrain = workspace.Terrain
local M = Enum.Material
local rng = Random.new(1066) -- fixed seed: the valley looks the same every time

local PLOTS_END_X = Config.MAX_PLOTS * (Grid.PLOT_SIZE + Config.PLOT_GAP) - Config.PLOT_GAP
local TOP = Config.GROUND_Y
local VOXEL = 4

-- World bounds (multiples of 4 so they line up with the terrain voxel grid)
local MIN_X = -760
local MAX_X = math.ceil((PLOTS_END_X + 760) / VOXEL) * VOXEL
local MIN_Z, MAX_Z = -800, 840

-- The flat, buildable part of the valley
-- (extends west to hold the rival village, Config.Rival)
local FLAT_MIN_X, FLAT_MAX_X = -290, PLOTS_END_X + 40
for _, rival in Config.Rivals do
	FLAT_MIN_X = math.min(FLAT_MIN_X, rival.Center.X - rival.Radius - 30)
	FLAT_MAX_X = math.max(FLAT_MAX_X, rival.Center.X + rival.Radius + 30)
end
local FLAT_MIN_Z, FLAT_MAX_Z = -40, Grid.PLOT_SIZE + 115
local SHORE_Z = -40 -- where the beach starts to slope into the fjord
local SEED = 7.31

-- Noise helpers ---------------------------------------------------------------

local function smooth(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- fractal noise, roughly -0.5..0.5
local function fbm(x: number, z: number, freq: number, octaves: number, salt: number): number
	local amp, sum, norm = 1, 0, 0
	for o = 1, octaves do
		sum += math.noise(x * freq, z * freq, SEED + salt + o * 17.3) * amp
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

-- ridged noise, 0..1, sharp crests: good for mountain ridges
local function ridged(x: number, z: number, freq: number, octaves: number): number
	local amp, sum, norm = 1, 0, 0
	for o = 1, octaves do
		local n = 1 - math.abs(math.noise(x * freq, z * freq, SEED + 91 + o * 31.7) * 1.6)
		n = math.max(n, 0)
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		freq *= 2.1
	end
	return sum / norm
end

-- 0 outside the build zone, 1 inside, with a soft 60-stud edge
local function flatMask(x: number, z: number): number
	local fx = math.min(smooth(FLAT_MIN_X - 60, FLAT_MIN_X, x), smooth(FLAT_MAX_X + 60, FLAT_MAX_X, x))
	local fz = math.min(smooth(FLAT_MIN_Z - 70, FLAT_MIN_Z, z), smooth(FLAT_MAX_Z + 90, FLAT_MAX_Z, z))
	return math.min(fx, fz)
end

local function mountainMask(x: number, z: number): (number, number)
	local wobble = fbm(x, z, 1 / 320, 2, 5) * 160
	local back = smooth(380, 660, z + wobble)
	local far = smooth(-540, -720, z - wobble * 0.5)
	local side = math.max(smooth(FLAT_MIN_X - 220, FLAT_MIN_X - 520, x + wobble), smooth(FLAT_MAX_X + 220, FLAT_MAX_X + 520, x + wobble))
	return math.max(back, far, side), far
end

-- The height of the land at x, z
local function heightAt(x: number, z: number): number
	local m, far = mountainMask(x, z)
	local mountains = m * (40 + 210 * ridged(x, z, 1 / 380, 5))
	local hills = 26 * (fbm(x, z, 1 / 170, 4, 1) + 0.5) * smooth(200, 340, z)
	local detail = fbm(x, z, 1 / 36, 2, 3) * 2.5
	local h = TOP + hills + mountains + detail

	-- the fjord: slope down from the beach, rise again at the far shore
	if z < SHORE_Z then
		local lake = smooth(SHORE_Z, SHORE_Z - 80, z) * (1 - far)
		-- shallow near the beach, dropping into a deep dark channel
		local bed = lerp(-5, -42, smooth(SHORE_Z - 20, SHORE_Z - 260, z) * (1 - far)) + fbm(x, z, 1 / 90, 3, 7) * 6
		h = lerp(h, bed, lake)
	end

	-- islands for the sea holds: a flat top with a sandy shelf around it
	for _, rival in Config.Rivals do
		if rival.Sea then
			local dx, dz = x - rival.Center.X, z - rival.Center.Z
			local dist = math.sqrt(dx * dx + dz * dz) + fbm(x, z, 1 / 40, 2, 53) * 18
			local land = smooth(rival.Radius + 95, rival.Radius + 25, dist)
			h = lerp(h, TOP + fbm(x, z, 1 / 30, 2, 57) * 1.2 * smooth(rival.Radius + 25, rival.Radius + 60, dist), land)
			-- a rocky knoll behind the hold, away from the gate
			local back = rival.Center - Vector3.new(math.cos(rival.GateAngle or 0), 0, math.sin(rival.GateAngle or 0)) * (rival.Radius + 85)
			local kd = math.sqrt((x - back.X) ^ 2 + (z - back.Z) ^ 2)
			h += smooth(70, 10, kd) * (26 + ridged(x, z, 1 / 60, 3) * 30)
		end
	end

	return lerp(h, TOP, flatMask(x, z))
end

-- (covers the biggest the land can grow, see Config.LandStages)
local LAND_MIN_X, _, LAND_MAX_X, LAND_MAX_Z = Grid.maxBounds()
local function inPlotArea(x: number, z: number): boolean
	if z < -50 or z > LAND_MAX_Z * Config.CELL + 12 then
		return false
	end
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		if x > o.X + LAND_MIN_X * Config.CELL - 8 and x < o.X + LAND_MAX_X * Config.CELL + 8 then
			return true
		end
	end
	return false
end

-- The rival hold whose walls cover x, z (nil if none).
local function rivalAt(x: number, z: number)
	for _, rival in Config.Rivals do
		local dx, dz = x - rival.Center.X, z - rival.Center.Z
		if dx * dx + dz * dz < (rival.Radius + 22) ^ 2 then
			return rival
		end
	end
	return nil
end

local function inRivalArea(x: number, z: number): boolean
	return rivalAt(x, z) ~= nil
end

-- A cobbled path from the front of each plot down to its jetty, wandering a little.
local function inPath(x: number, z: number): boolean
	if z > 1 or z < -36 then
		return false
	end
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		local dockX = o.X + Grid.PLOT_SIZE * 0.25 + math.sin(z / 9) * 1.5
		if math.abs(x - dockX) < 3.2 + fbm(x, z, 1 / 6, 2, 71) * 1.6 then
			return true
		end
	end
	return false
end

local function inApron(x: number, z: number): boolean
	if z < -16 or z > 0 then
		return false
	end
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		if x >= o.X and x <= o.X + Grid.PLOT_SIZE then
			return true
		end
	end
	return false
end

local function groundAt(x: number, z: number): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	return workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -700, 0), params)
end

-- Picks the surface material from height, steepness and position.
local function surfaceMaterial(x: number, z: number, h: number, slope: number)
	if inPath(x, z) then
		return M.Cobblestone
	end
	if inApron(x, z) then
		return M.Ground
	end
	if inPlotArea(x, z) then
		return M.Grass
	end
	local rival = rivalAt(x, z)
	if rival then
		local dx, dz = x - rival.Center.X, z - rival.Center.Z
		return (dx * dx + dz * dz < 36 * 36 or fbm(x, z, 1 / 25, 2, 41) > 0.2) and M.Ground or M.Grass
	end
	if h < -6 then
		return M.Mud
	end
	for _, r in Config.Rivals do
		if r.Sea and h > 0.4 and h < 6 then
			local dx, dz = x - r.Center.X, z - r.Center.Z
			if dx * dx + dz * dz < (r.Radius + 48) ^ 2 then
				return fbm(x, z, 1 / 28, 2, 61) > 0.15 and M.Ground or M.LeafyGrass
			end
		end
	end
	if h < 3 and z < SHORE_Z + 12 then
		return M.Sand
	end
	local snowline = 150 + fbm(x, z, 1 / 80, 2, 11) * 50
	if h > snowline and slope < 1.3 then
		return M.Snow
	end
	if slope > 1.15 then
		return M.Rock
	end
	if slope > 0.75 then
		return M.Slate
	end
	if h > snowline - 45 then
		return fbm(x, z, 1 / 30, 2, 13) > 0 and M.Rock or M.Ground
	end
	local n = fbm(x, z, 1 / 70, 3, 17)
	if n > 0.22 then
		return M.LeafyGrass
	elseif n < -0.28 then
		return M.Ground
	end
	return M.Grass
end

local function buildTerrain()
	Terrain:Clear()

	-- Materials and water look
	Terrain:SetMaterialColor(M.Grass, Color3.fromRGB(88, 118, 58))
	Terrain:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(78, 106, 52))
	Terrain:SetMaterialColor(M.Rock, Color3.fromRGB(104, 104, 102))
	Terrain:SetMaterialColor(M.Slate, Color3.fromRGB(88, 90, 88))
	Terrain:SetMaterialColor(M.Snow, Color3.fromRGB(240, 244, 250))
	Terrain:SetMaterialColor(M.Sand, Color3.fromRGB(176, 164, 134))
	Terrain:SetMaterialColor(M.Ground, Color3.fromRGB(104, 88, 64))
	Terrain:SetMaterialColor(M.Mud, Color3.fromRGB(62, 56, 46))
	-- deep fjord teal: low transparency so depth reads as colour, full
	-- reflectance so the sky and mountains mirror in it
	Terrain.WaterColor = Color3.fromRGB(22, 50, 60)
	Terrain.WaterTransparency = 0.18
	Terrain.WaterReflectance = 1
	Terrain.WaterWaveSize = 0.16
	Terrain.WaterWaveSpeed = 9
	pcall(function()
		Terrain.Decoration = true -- animated grass blades on Grass
	end)

	-- 1. Heightmap: one height per 4x4-stud column
	local nx = (MAX_X - MIN_X) // VOXEL
	local nz = (MAX_Z - MIN_Z) // VOXEL
	local heights = table.create(nx + 2)
	local budget = os.clock()
	for i = 0, nx + 1 do
		local row = table.create(nz + 2)
		local x = MIN_X + (i - 0.5) * VOXEL
		for k = 0, nz + 1 do
			row[k] = heightAt(x, MIN_Z + (k - 0.5) * VOXEL)
		end
		heights[i] = row
		if os.clock() - budget > 0.05 then
			if RunService:IsRunning() then
				task.wait()
			end
			budget = os.clock()
		end
	end

	-- 2. Write voxels chunk by chunk
	local CHUNK = 32
	for ci = 1, nx, CHUNK do
		for ck = 1, nz, CHUNK do
			local ci2 = math.min(ci + CHUNK - 1, nx)
			local ck2 = math.min(ck + CHUNK - 1, nz)
			local lo, hi = math.huge, -math.huge
			for i = ci, ci2 do
				local row = heights[i]
				for k = ck, ck2 do
					local h = row[k]
					lo = math.min(lo, h)
					hi = math.max(hi, h)
				end
			end
			hi = math.max(hi, 0) -- room for water
			local yMin = math.floor((lo - 14) / VOXEL) * VOXEL
			local yMax = math.ceil((hi + 1) / VOXEL) * VOXEL
			local ny = (yMax - yMin) // VOXEL

			local materials = table.create(ci2 - ci + 1)
			local occupancy = table.create(ci2 - ci + 1)
			for i = ci, ci2 do
				local mx, ox = table.create(ny), table.create(ny)
				local x = MIN_X + (i - 0.5) * VOXEL
				local row, rowL, rowR = heights[i], heights[i - 1], heights[i + 1]
				for j = 1, ny do
					mx[j] = table.create(ck2 - ck + 1)
					ox[j] = table.create(ck2 - ck + 1)
				end
				for k = ck, ck2 do
					local z = MIN_Z + (k - 0.5) * VOXEL
					local h = row[k]
					local slope = math.max(math.abs(rowR[k] - rowL[k]), math.abs(row[k + 1] - row[k - 1])) / (2 * VOXEL)
					local surface = surfaceMaterial(x, z, h, slope)
					local under = (surface == M.Grass or surface == M.LeafyGrass) and M.Ground or surface
					local kk = k - ck + 1
					for j = 1, ny do
						local y0 = yMin + (j - 1) * VOXEL
						local mat, occ
						if h >= y0 + VOXEL then
							local depth = h - (y0 + VOXEL)
							occ = 1
							if depth < 3 then
								mat = surface
							elseif depth < 9 then
								mat = under
							else
								mat = M.Rock
							end
						elseif h > y0 then
							occ = (h - y0) / VOXEL
							mat = surface
						elseif y0 + VOXEL <= 0 then
							occ = 1
							mat = M.Water
						else
							occ = 0
							mat = M.Air
						end
						mx[j][kk] = mat
						ox[j][kk] = occ
					end
				end
				materials[i - ci + 1] = mx
				occupancy[i - ci + 1] = ox
			end

			local regionMin = Vector3.new(MIN_X + (ci - 1) * VOXEL, yMin, MIN_Z + (ck - 1) * VOXEL)
			local regionMax = Vector3.new(MIN_X + ci2 * VOXEL, yMax, MIN_Z + ck2 * VOXEL)
			Terrain:WriteVoxels(Region3.new(regionMin, regionMax), VOXEL, materials, occupancy)

			if os.clock() - budget > 0.05 then
				if RunService:IsRunning() then
					task.wait()
				end
				budget = os.clock()
			end
		end
	end
end

local function scatterScenery()
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = workspace

	local treeMaterials = { [M.Grass] = true, [M.LeafyGrass] = true, [M.Ground] = true }

	local function plant(x: number, z: number): boolean
		if inPlotArea(x, z) or inRivalArea(x, z) or (x > FLAT_MIN_X and x < FLAT_MAX_X and z > -60 and z < 0) then
			return false
		end
		local hit = groundAt(x, z)
		if not hit or not treeMaterials[hit.Material] or hit.Normal.Y < 0.82 then
			return false
		end
		local treeline = 125 + fbm(x, z, 1 / 80, 2, 23) * 40
		if hit.Position.Y > treeline or hit.Position.Y < 1.5 then
			return false
		end
		local model
		local s = rng:NextNumber(1, 2.1) * (1 - hit.Position.Y / 400) -- smaller trees higher up
		local r = rng:NextNumber()
		if r < 0.38 then
			model = ModelFactory.pine(rng, s)
		elseif r < 0.8 then
			model = ModelFactory.spruce(rng, s * 1.1)
		else
			model = ModelFactory.birch(rng, s * 0.8)
		end
		model:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		model.Parent = folder
		return true
	end

	-- Forests grow in patches: noise decides where the woods are dense.
	local planted, tries = 0, 0
	local budget = os.clock()
	while planted < 950 and tries < 9000 do
		tries += 1
		local x, z = rng:NextNumber(MIN_X, MAX_X), rng:NextNumber(MIN_Z + 40, 640)
		local density = fbm(x, z, 1 / 220, 3, 29) + 0.15
		if z > FLAT_MAX_Z - 30 and z < FLAT_MAX_Z + 40 and x > FLAT_MIN_X and x < FLAT_MAX_X then
			density -= 0.35 -- keep the deer meadow open
		end
		if rng:NextNumber() < density * 2 and plant(x, z) then
			planted += 1
		end
		if os.clock() - budget > 0.05 then
			if RunService:IsRunning() then
				task.wait()
			end
			budget = os.clock()
		end
	end

	-- understory: ferns and junipers where the woods are
	local under = 0
	tries = 0
	while under < 450 and tries < 4000 do
		tries += 1
		local x, z = rng:NextNumber(MIN_X, MAX_X), rng:NextNumber(-30, 560)
		if fbm(x, z, 1 / 220, 3, 29) + 0.15 > 0.05 and not inPlotArea(x, z) and not inRivalArea(x, z) then
			local hit = groundAt(x, z)
			if hit and treeMaterials[hit.Material] and hit.Normal.Y > 0.8 and hit.Position.Y < 110 and hit.Position.Y > 1.5 then
				local model = rng:NextNumber() < 0.6 and ModelFactory.fern(rng) or ModelFactory.juniper(rng)
				model:PivotTo(CFrame.new(hit.Position - Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
				model.Parent = folder
				under += 1
			end
		end
		if os.clock() - budget > 0.05 then
			if RunService:IsRunning() then
				task.wait()
			end
			budget = os.clock()
		end
	end

	-- loose boulders
	for _ = 1, 70 do
		local x, z = rng:NextNumber(MIN_X, MAX_X), rng:NextNumber(-60, 500)
		if not inPlotArea(x, z) and not inRivalArea(x, z) then
			local hit = groundAt(x, z)
			if hit and hit.Position.Y < 80 and hit.Material ~= M.Water then
				local model = ModelFactory.boulder(rng, rng:NextNumber(1, 2.6))
				model:PivotTo(CFrame.new(hit.Position) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
				model.Parent = folder
			end
		end
	end

	-- the shoreline: find where the land meets the water and line it with
	-- foam (animated on the client) and half-sunk rocks
	local foamFolder = Instance.new("Folder")
	foamFolder.Name = "ShoreFoam"
	local function shoreAt(x: number, fromZ: number, toZ: number, step: number): number?
		local wasDry = heightAt(x, fromZ) > 0.2
		for z = fromZ, toZ, step do
			local dry = heightAt(x, z) > 0.2
			if dry ~= wasDry then
				return z
			end
			wasDry = dry
		end
		return nil
	end
	for x = MIN_X + 6, MAX_X - 6, 9 do
		for _, scan in { { SHORE_Z + 10, SHORE_Z - 200, -2 }, { MIN_Z + 20, -480, 3 } } do
			local z = shoreAt(x, scan[1], scan[2], scan[3])
			if z then
				for layer = 0, 1 do
					local foam = Instance.new("Part")
					foam.Name = "Foam"
					foam.Anchored = true
					foam.CanCollide = false
					foam.CanQuery = false
					foam.CastShadow = false
					foam.Material = Enum.Material.SmoothPlastic
					foam.Color = Color3.fromRGB(236, 242, 240)
					foam.Transparency = 0.55 + layer * 0.2
					foam.Size = Vector3.new(10.5, 0.1, 1.6 + layer * 2.5)
					foam.CFrame = CFrame.new(x, 0.06 + layer * 0.02, z + (scan[3] < 0 and -1 or 1) * (1 + layer * 2.2))
						* CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0)
					foam.Parent = foamFolder
				end
				if rng:NextNumber() < 0.22 and not (x > FLAT_MIN_X and x < FLAT_MAX_X and scan[3] < 0 and rng:NextNumber() < 0.6) then
					local rock = ModelFactory.boulder(rng, rng:NextNumber(1.2, 2.8))
					rock:PivotTo(CFrame.new(x + rng:NextNumber(-4, 4), -1.2, z + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
					rock.Parent = folder
				end
			end
		end
	end
	foamFolder.Parent = workspace

	-- a jetty on the fjord in front of every plot, some with a longship
	local sails = { Color3.fromRGB(160, 40, 36), Color3.fromRGB(46, 70, 120), Color3.fromRGB(150, 120, 50) }
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		local dockX = o.X + Grid.PLOT_SIZE * 0.25
		local dock = ModelFactory.dock(48)
		dock:PivotTo(CFrame.new(dockX, 0, -34))
		dock.Parent = folder
		if i % 2 == 1 then
			local ship = ModelFactory.longship(40, sails[(i // 2) % #sails + 1])
			ship:PivotTo(CFrame.new(dockX + 9, 0, -62) * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0))
			ship.Parent = folder
		end
		-- torches lighting the path at each corner of the plot
		for _, x in { o.X + 2, o.X + Grid.PLOT_SIZE - 2 } do
			local torch = Instance.new("Model")
			torch.Name = "Torch"
			local pole = ModelFactory.addPart(torch, {
				Size = Vector3.new(0.5, 6, 0.5),
				Position = Vector3.new(x, TOP + 3, -2),
				Color = ModelFactory.Colors.DarkWood,
			})
			local flame = ModelFactory.addPart(torch, {
				Size = Vector3.new(0.7, 0.7, 0.7),
				Position = pole.Position + Vector3.new(0, 3.3, 0),
				Color = Color3.fromRGB(255, 140, 50),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local fire = Instance.new("Fire")
			fire.Size = 1.6
			fire.Heat = 5
			fire.Parent = flame
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 150, 70)
			light.Range = 18
			light.Brightness = 1.6
			light.Parent = flame
			torch.Parent = folder
		end

		-- village life on the beach and in the gaps between plots
		local function placeProp(kind: string, x: number, z: number, turn: number)
			local prop = ModelFactory.prop(kind, rng)
			local hit = groundAt(x, z)
			local y = hit and hit.Position.Y or TOP
			prop:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, turn, 0))
			prop.Parent = folder
		end
		placeProp("FishRack", dockX - 14, -24, rng:NextNumber(-0.3, 0.3))
		placeProp("Barrels", dockX + 7, -30, rng:NextNumber(0, 6))
		placeProp("BoatUpturned", dockX + 22, -30, math.rad(80) + rng:NextNumber(-0.2, 0.2))
		local gapX = o.X - Config.PLOT_GAP / 2
		do
			placeProp("Banner", gapX, -6, 0)
			placeProp("Haystack", gapX + rng:NextNumber(-3, 3), 60 + rng:NextNumber(-10, 10), rng:NextNumber(0, 6))
			placeProp("Cart", gapX + rng:NextNumber(-2, 2), 110 + rng:NextNumber(-10, 10), math.rad(90) + rng:NextNumber(-0.4, 0.4))
			placeProp("Woodpile", gapX, 170, math.rad(90))
		end
		-- a split-rail fence between the village and the deer meadow
		local fence = ModelFactory.prop("FenceRun", rng)
		fence:PivotTo(CFrame.new(o.X + Grid.PLOT_SIZE / 2, TOP, LAND_MAX_Z * Config.CELL + 6))
		fence.Parent = folder
	end
end

-- A trading longship that sails slowly up and down the fjord forever.
local function sailingShip()
	local ship = ModelFactory.longship(48, Color3.fromRGB(150, 40, 36))
	ship.Name = "TradingShip"
	ship.Parent = workspace:FindFirstChild("Scenery") or workspace
	local z = -300
	local x0, x1 = MIN_X + 200, MAX_X - 200
	task.spawn(function()
		local dir = 1
		local x = x0
		local speed = 9
		while ship.Parent do
			local dt = task.wait(1 / 20)
			x += dir * speed * dt
			if x > x1 or x < x0 then
				dir = -dir
				x = math.clamp(x, x0, x1)
			end
			local bob = math.sin(os.clock() * 0.8) * 0.25
			local roll = math.sin(os.clock() * 0.6) * math.rad(2)
			local heading = dir > 0 and -math.pi / 2 or math.pi / 2
			ship:PivotTo(CFrame.new(x, bob, z + math.sin(x / 300) * 60) * CFrame.Angles(0, heading, 0) * CFrame.Angles(0, 0, roll))
		end
	end)
end

-- Day and night: a full day takes DAY_SECONDS, nights pass faster.
local DAY_SECONDS = 480
local function dayNightCycle()
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local t = (15.6 - 6) / 14 * (DAY_SECONDS * 0.75) -- start in the afternoon
	while true do
		local dt = task.wait(0.1)
		t = (t + dt) % DAY_SECONDS
		local dayPart = DAY_SECONDS * 0.75
		local clock
		if t < dayPart then
			clock = 6 + 14 * (t / dayPart) -- 06:00 to 20:00
		else
			clock = (20 + 10 * ((t - dayPart) / (DAY_SECONDS - dayPart))) % 24 -- 20:00 to 06:00
		end
		Lighting.ClockTime = clock
		-- 0 at midday, 1 deep at night
		local night = 0
		if clock >= 18.5 or clock < 6.5 then
			local h = clock >= 18.5 and clock - 18.5 or clock + 5.5
			night = math.clamp(math.min(h, 12 - h) / 1.5, 0, 1)
		end
		local golden = math.clamp(1 - math.abs(clock - 18) / 2, 0, 1) + math.clamp(1 - math.abs(clock - 7) / 1.5, 0, 1)
		local season = workspace:GetAttribute("Season")
		local seasonTint = Color3.fromRGB(255, 244, 228)
		if season == "Winter" then
			seasonTint = Color3.fromRGB(222, 234, 255)
		elseif season == "Autumn" then
			seasonTint = Color3.fromRGB(255, 230, 196)
		elseif season == "Spring" then
			seasonTint = Color3.fromRGB(246, 255, 236)
		end
		-- weather (WeatherService): fog thickens the air, storms darken it
		local fog = workspace:GetAttribute("FogLevel") or 0
		local storm = workspace:GetAttribute("StormLevel") or 0
		golden *= 1 - math.max(fog, storm) * 0.8
		if grade then
			grade.TintColor = seasonTint:Lerp(Color3.fromRGB(255, 205, 160), golden * 0.6):Lerp(Color3.fromRGB(170, 190, 255), night):Lerp(Color3.fromRGB(196, 206, 214), storm * 0.5)
			grade.Brightness = 0.02 + night * 0.05 - storm * 0.06
			grade.Saturation = 0.08 - storm * 0.2 - fog * 0.12
		end
		if atmosphere then
			atmosphere.Color = Color3.fromRGB(200, 190, 170):Lerp(Color3.fromRGB(230, 170, 120), golden * 0.5):Lerp(Color3.fromRGB(70, 80, 110), night):Lerp(Color3.fromRGB(196, 202, 206), fog * (1 - night * 0.7)):Lerp(Color3.fromRGB(96, 104, 114), storm * (1 - night * 0.5))
			atmosphere.Decay = Color3.fromRGB(96, 106, 122):Lerp(Color3.fromRGB(150, 156, 160), fog)
			atmosphere.Haze = 1.7 + golden * 0.8 - night * 0.6 + fog * 2.4 + storm * 1.2
			atmosphere.Density = 0.38 + fog * 0.4 + storm * 0.16
		end
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 122, 114):Lerp(Color3.fromRGB(60, 66, 92), night):Lerp(Color3.fromRGB(100, 104, 110), storm * 0.6)
		Lighting.Brightness = 3 * (1 - storm * 0.45 - fog * 0.2)
	end
end

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 15.6
	Lighting.GeographicLatitude = 58
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(58, 60, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 122, 114)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1 -- wet stone, metal and water catch the light
	Lighting.ShadowSoftness = 0.25
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.38
	atmosphere.Offset = 0.3
	atmosphere.Color = Color3.fromRGB(200, 190, 170)
	atmosphere.Decay = Color3.fromRGB(96, 106, 122)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.7
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Brightness = 0.02
	grade.Contrast = 0.14
	grade.Saturation = 0.08
	grade.TintColor = Color3.fromRGB(255, 244, 228)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(245, 240, 232)
	clouds.Parent = Terrain

	-- a gentle cinematic blur on the far distance
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.12
	dof.NearIntensity = 0
	dof.FocusDistance = 140
	dof.InFocusRadius = 180
	dof.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.7
	rays.Parent = Lighting
end

-- A plank landing jetty on the beach of each island hold, so you know where
-- to bring your longship in.
local function buildLandings()
	for _, rival in Config.Rivals do
		if rival.Sea then
			local a = rival.GateAngle or 0
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local side = Vector3.new(-dir.Z, 0, dir.X)
			-- walk out from the gate until the water starts
			local startD = rival.Radius + 20
			local waterD = startD
			for d = startD, rival.Radius + 160, 2 do
				local p = rival.Center + dir * d
				if heightAt(p.X, p.Z) < -0.5 then
					waterD = d
					break
				end
			end
			local model = Instance.new("Model")
			model.Name = "Landing_" .. rival.Name
			local wood = Color3.fromRGB(104, 78, 54)
			local from, to = waterD - 10, waterD + 34
			for d = from, to, 2.2 do
				local p = rival.Center + dir * d
				local plank = ModelFactory.addPart(model, {
					Name = "Plank",
					Size = Vector3.new(9, 0.5, 2),
					Color = wood:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.15)),
					Material = M.WoodPlanks,
				})
				plank.CFrame = CFrame.lookAt(Vector3.new(p.X, 1.6, p.Z), Vector3.new(p.X, 1.6, p.Z) + dir)
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-1.5, 1.5)))
			end
			for d = from + 6, to, 9 do
				for s = -1, 1, 2 do
					local p = rival.Center + dir * d + side * s * 4.6
					local post = ModelFactory.addPart(model, { Name = "Post", Size = Vector3.new(0.9, 10, 0.9), Color = wood:Lerp(Color3.new(0, 0, 0), 0.3), Material = M.Wood })
					post.CFrame = CFrame.new(p.X, -2.5, p.Z)
				end
			end
			model.Parent = workspace:FindFirstChild("Scenery") or workspace
		end
	end
end

local function clearPlaceholders()
	-- The flat Baseplate and welcome sign are only there so the place isn't
	-- empty in edit mode; the real world replaces them.
	for _, name in { "Baseplate", "WelcomeSign" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

function WorldService:Init()
	clearPlaceholders()
	if workspace:GetAttribute("WorldBaked") then
		-- The valley was saved into the place (see Bake), so whatever you
		-- changed in Studio is kept: nothing is regenerated.
		print("[WorldService] using the saved valley")
		return
	end
	setupLighting()
	buildTerrain()
	scatterScenery()
	buildLandings()
	print("[WorldService] valley built")
end

-- Builds the valley in Studio edit mode, so it is saved in the place file
-- and can be edited by hand. Run through EditTools.Setup().
function WorldService:Bake()
	clearPlaceholders()
	for _, name in { "Scenery", "ShoreFoam" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	Terrain:Clear()
	setupLighting()
	buildTerrain()
	scatterScenery()
	buildLandings()
	workspace:SetAttribute("WorldBaked", true)
end

function WorldService:Start()
	sailingShip()
	dayNightCycle()
end

-- Height of the terrain at x, z (used by wildlife).
function WorldService:GroundHeight(x: number, z: number): number
	local hit = groundAt(x, z)
	return hit and hit.Position.Y or TOP
end

return WorldService
