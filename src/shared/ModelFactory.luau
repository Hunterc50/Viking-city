--[[
	ModelFactory
	Builds every model in the game out of plain Parts, so the game needs no
	imported assets. Every model is built around (0, 0, 0) = centre of its
	footprint at ground level, and its WorldPivot is set there, so callers just
	do model:PivotTo(cframe).

	MESH SWAP: put a model (or Tool) in ReplicatedStorage > Assets with one of
	the slot names in ModelFactory.Slots and the game uses it instead of the
	part-built version. Buildings are scaled to fit their footprint.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local SettlerRig = require(script.Parent.SettlerRig)

local ModelFactory = {}

local CELL = Config.CELL
local V3 = Vector3.new

local Colors = {
	Wood = Color3.fromRGB(128, 90, 58),
	DarkWood = Color3.fromRGB(74, 52, 36),
	Weathered = Color3.fromRGB(104, 92, 78),
	Thatch = Color3.fromRGB(176, 146, 88),
	Shingle = Color3.fromRGB(86, 62, 44),
	Turf = Color3.fromRGB(88, 112, 58),
	Stone = Color3.fromRGB(124, 124, 120),
	Soil = Color3.fromRGB(92, 66, 44),
	Barley = Color3.fromRGB(206, 178, 92),
	Pine = Color3.fromRGB(38, 70, 44),
	PineLight = Color3.fromRGB(52, 86, 50),
	Leaf = Color3.fromRGB(70, 112, 56),
	Birch = Color3.fromRGB(222, 218, 205),
	Berry = Color3.fromRGB(170, 34, 46),
	Skin = Color3.fromRGB(234, 196, 160),
	Lantern = Color3.fromRGB(255, 170, 80),
	Iron = Color3.fromRGB(90, 92, 98),
}
ModelFactory.Colors = Colors

local Hair = {
	Color3.fromRGB(196, 150, 80),
	Color3.fromRGB(150, 74, 40),
	Color3.fromRGB(80, 56, 38),
	Color3.fromRGB(220, 200, 150),
}

local function addPart(model: Instance, props)
	local p = Instance.new(props.Class or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size
	p.CFrame = props.CFrame or CFrame.new(props.Position or Vector3.zero)
	p.Color = props.Color or Colors.Wood
	p.Material = props.Material or Enum.Material.Wood
	p.Name = props.Name or "Part"
	if props.CanCollide == false then
		p.CanCollide = false
	end
	p.Parent = model
	return p
end
ModelFactory.addPart = addPart

-- A steady random source for small details (log shades, stones, shingles),
-- so the same building looks the same every time it is built.
local detail = Random.new(1066)

-- `color` a little lighter or darker, for weathered, hand-made variety.
local function vary(color: Color3, amount: number?): Color3
	local a = amount or 0.08
	local k = 1 + detail:NextNumber(-a, a)
	return Color3.new(math.clamp(color.R * k, 0, 1), math.clamp(color.G * k, 0, 1), math.clamp(color.B * k, 0, 1))
end
ModelFactory.vary = vary

-- Small details don't need to cast shadows: much cheaper to draw.
local function noShadow(p: BasePart)
	p.CastShadow = false
	return p
end

-- A vertical log (cylinder) standing at `pos` (its bottom on pos.Y).
local function post(model, pos: Vector3, height: number, diameter: number, color: Color3?)
	return addPart(model, {
		Shape = Enum.PartType.Cylinder,
		Size = V3(height, diameter, diameter),
		CFrame = CFrame.new(pos + V3(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = color or Colors.DarkWood,
	})
end

local function lantern(model, cf: CFrame)
	local l = addPart(model, {
		Name = "Lantern",
		Size = V3(0.6, 0.8, 0.6),
		CFrame = cf,
		Color = Colors.Lantern,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = Colors.Lantern
	light.Range = 16
	light.Brightness = 1.4
	light.Shadows = true
	light.Parent = l
end

local function smoke(model, cf: CFrame)
	local hole = addPart(model, {
		Name = "SmokeHole",
		Size = V3(1.6, 0.8, 1.6),
		CFrame = cf,
		Color = Colors.DarkWood,
	})
	local s = Instance.new("Smoke")
	s.Color = Color3.fromRGB(210, 205, 200)
	s.Opacity = 0.12
	s.RiseVelocity = 3
	s.Size = 1.5
	s.Parent = hole
end

--[[
	A timber hall: stone footing, plank walls with log banding, a pitched
	roof (ridge along local X), filled gable ends, crossed carved boards at
	both gables, a door on the -Z side, a lantern and optional chimney smoke.
	o = { w, d, wallH, roof = "thatch" | "shingle" | "turf", pitch, smoke, lantern }
]]
local function hall(model, cf: CFrame, o)
	local w, d, wallH = o.w, o.d, o.wallH
	local base = 1
	addPart(model, {
		Name = "Foundation",
		Size = V3(w + 1.2, 1, d + 1.2),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Colors.Stone,
		Material = Enum.Material.Cobblestone,
	})
	-- a solid core (what you bump into), dark where it shows between logs
	addPart(model, {
		Name = "Walls",
		Size = V3(w - 0.3, wallH, d - 0.3),
		CFrame = cf * CFrame.new(0, base + wallH / 2, 0),
		Color = Color3.fromRGB(58, 42, 30),
		Material = Enum.Material.WoodPlanks,
	})
	-- log walls: courses of round logs, notched at the corners so the log
	-- ends stick out, each log a slightly different shade of weathered wood
	local courses = math.max(4, math.floor(wallH / 0.85))
	local dia = wallH / courses * 1.12
	for i = 1, courses do
		local y = base + (i - 0.5) * (wallH / courses)
		local longOut = (i % 2 == 1) and 1.5 or 0.5
		local shortOut = (i % 2 == 1) and 0.5 or 1.5
		for _, side in { 1, -1 } do
			addPart(model, {
				Name = "Log",
				Shape = Enum.PartType.Cylinder,
				Size = V3(w + longOut, dia, dia),
				CFrame = cf * CFrame.new(detail:NextNumber(-0.15, 0.15), y, side * d / 2),
				Color = vary(Colors.Wood, 0.14),
				Material = Enum.Material.Wood,
			})
			addPart(model, {
				Name = "Log",
				Shape = Enum.PartType.Cylinder,
				Size = V3(d + shortOut, dia, dia),
				CFrame = cf * CFrame.new(side * w / 2, y, detail:NextNumber(-0.15, 0.15)) * CFrame.Angles(0, math.pi / 2, 0),
				Color = vary(Colors.Weathered, 0.14),
				Material = Enum.Material.Wood,
			})
		end
	end
	-- a footing of rough fieldstones along the base of the walls
	local function stoneRow(from: Vector3, to: Vector3)
		local len = (to - from).Magnitude
		local n = math.max(2, math.floor(len / 2.3))
		for k = 0, n do
			local p = from:Lerp(to, k / n)
			noShadow(addPart(model, {
				Name = "FootingStone",
				Size = V3(detail:NextNumber(1.4, 2.1), detail:NextNumber(0.7, 1.1), detail:NextNumber(1, 1.5)),
				CFrame = cf * CFrame.new(p) * CFrame.Angles(detail:NextNumber(-0.15, 0.15), detail:NextNumber(0, math.pi), detail:NextNumber(-0.15, 0.15)),
				Color = vary(Colors.Stone, 0.16),
				Material = (k % 3 == 0) and Enum.Material.Rock or Enum.Material.Slate,
			}))
		end
	end
	local fx, fz = w / 2 + 0.55, d / 2 + 0.55
	stoneRow(V3(-fx, 0.45, -fz), V3(fx, 0.45, -fz))
	stoneRow(V3(-fx, 0.45, fz), V3(fx, 0.45, fz))
	stoneRow(V3(-fx, 0.45, -fz), V3(-fx, 0.45, fz))
	stoneRow(V3(fx, 0.45, -fz), V3(fx, 0.45, fz))

	-- roof
	local roofColor = Colors.Thatch
	local roofMaterial = Enum.Material.Grass
	if o.roof == "shingle" then
		roofColor, roofMaterial = Colors.Shingle, Enum.Material.WoodPlanks
	elseif o.roof == "turf" then
		roofColor, roofMaterial = Colors.Turf, Enum.Material.Grass
	end
	local wallTop = base + wallH
	local angle = math.rad(o.pitch or 38)
	local halfD = d / 2 + 1.6
	local rise = halfD * math.tan(angle)
	local slope = halfD / math.cos(angle) + 0.6
	local ridgeY = wallTop + rise
	for _, side in { 1, -1 } do
		local slab = addPart(model, {
			Name = "Roof",
			Size = V3(w + 2.6, 1, slope),
			CFrame = cf * CFrame.new(0, wallTop + rise / 2, side * halfD / 2) * CFrame.Angles(side * angle, 0, 0),
			Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = roofMaterial,
		})
		-- overlapping courses laid on top, each a touch different, the lower
		-- edge lifted like real shingles or bundles of thatch
		local rows = math.max(3, math.floor(slope / 1.7))
		local rowLen = slope / rows
		local thick = o.roof == "shingle" and 0.3 or 0.55
		for r = 1, rows do
			local z = -side * (slope / 2 - (r - 0.5) * rowLen)
			noShadow(addPart(model, {
				Name = "RoofCourse",
				Size = V3(w + 2.7 + detail:NextNumber(-0.1, 0.1), thick, rowLen + 0.5),
				CFrame = slab.CFrame * CFrame.new(0, 0.5 + thick / 2 + 0.02 * r, z) * CFrame.Angles(side * math.rad(4), 0, 0),
				Color = vary(roofColor, 0.1),
				Material = roofMaterial,
				CanCollide = false,
			}))
		end
		-- patches of moss and grass on thatch and turf
		if o.roof ~= "shingle" then
			for _ = 1, math.max(2, math.floor(w / 7)) do
				noShadow(addPart(model, {
					Name = "Moss",
					Size = V3(detail:NextNumber(1.5, 3.5), 0.2, detail:NextNumber(1, 2.4)),
					CFrame = slab.CFrame * CFrame.new(detail:NextNumber(-w / 2, w / 2), 0.5 + thick + 0.12, detail:NextNumber(-slope / 2.5, slope / 2.5)),
					Color = vary(Color3.fromRGB(86, 108, 52), 0.12),
					Material = Enum.Material.LeafyGrass,
					CanCollide = false,
				}))
			end
		end
	end
	addPart(model, {
		Name = "Ridge",
		Size = V3(w + 3, 0.9, 0.9),
		CFrame = cf * CFrame.new(0, ridgeY + 0.2, 0),
		Color = Colors.DarkWood,
	})

	-- gable ends: stepped planks filling the triangle under the roof
	local steps = 5
	local stepH = rise / steps
	for _, sx in { 1, -1 } do
		for k = 1, steps do
			local hw = math.min(d / 2, halfD * (1 - (k - 0.5) / steps))
			if hw > 0.3 then
				addPart(model, {
					Name = "Gable",
					Size = V3(0.6, stepH + 0.05, hw * 2),
					CFrame = cf * CFrame.new(sx * w / 2, wallTop + (k - 0.5) * stepH, 0),
					Color = Colors.Weathered,
					Material = Enum.Material.WoodPlanks,
				})
			end
		end
		-- crossed carved boards that stick up past the ridge like horns
		for _, side in { 1, -1 } do
			addPart(model, {
				Name = "GableBoard",
				Size = V3(0.5, 0.7, slope + 3.2),
				CFrame = cf
					* CFrame.new(sx * (w / 2 + 1.2), ridgeY + 0.3, 0)
					* CFrame.Angles(side * angle, 0, 0)
					* CFrame.new(0, 0, side * (slope / 2 - 1.6)),
				Color = Colors.DarkWood,
			})
		end
	end

	-- door with frame
	addPart(model, {
		Name = "DoorFrame",
		Size = V3(4, 5.8, 0.4),
		CFrame = cf * CFrame.new(0, base + 2.9, -d / 2 - 0.55),
		Color = Colors.DarkWood,
	})
	addPart(model, {
		Name = "Door",
		Size = V3(3, 5, 0.3),
		CFrame = cf * CFrame.new(0, base + 2.5, -d / 2 - 0.75),
		Color = Color3.fromRGB(60, 40, 28),
		Material = Enum.Material.WoodPlanks,
	})
	-- iron straps across the door
	for _, y in { 1.2, 3.8 } do
		noShadow(addPart(model, { Name = "DoorStrap", Size = V3(2.8, 0.25, 0.1), CFrame = cf * CFrame.new(0, base + y, -d / 2 - 0.92), Color = Colors.Iron, Material = Enum.Material.Metal, CanCollide = false }))
	end
	-- small windows with warm light behind them and open shutters
	if w >= 12 then
		for _, x in { -w / 4 - 1, w / 4 + 1 } do
			local at = cf * CFrame.new(x, base + wallH * 0.55, -d / 2 - 0.5)
			noShadow(addPart(model, { Name = "WindowFrame", Size = V3(1.9, 1.6, 0.3), CFrame = at, Color = Colors.DarkWood, CanCollide = false }))
			local glow = noShadow(addPart(model, { Name = "WindowGlow", Size = V3(1.3, 1.05, 0.12), CFrame = at * CFrame.new(0, 0, -0.12), Color = Color3.fromRGB(255, 168, 86), Material = Enum.Material.Neon, CanCollide = false }))
			glow.Transparency = 0.25
			for _, sx in { -1, 1 } do
				noShadow(addPart(model, { Name = "Shutter", Size = V3(0.8, 1.4, 0.12), CFrame = at * CFrame.new(sx * 1.2, 0, -0.35) * CFrame.Angles(0, sx * math.rad(-50), 0), Color = vary(Color3.fromRGB(96, 50, 38), 0.1), Material = Enum.Material.WoodPlanks, CanCollide = false }))
			end
		end
	end
	if o.lantern ~= false then
		lantern(model, cf * CFrame.new(2.8, base + 4.6, -d / 2 - 0.6))
	end

	-- dark eave trim where the roof overhangs the walls
	for _, side in { 1, -1 } do
		addPart(model, {
			Name = "Eave",
			Size = V3(w + 2.7, 0.35, 0.5),
			CFrame = cf * CFrame.new(0, wallTop + 0.05, side * (halfD - 0.1)),
			Color = Colors.DarkWood,
			CanCollide = false,
		})
	end

	-- carved dragon heads rising from both ends of the ridge
	if o.dragons ~= false and w >= 12 then
		for _, sx in { 1, -1 } do
			local root = cf * CFrame.new(sx * (w / 2 + 1.5), ridgeY + 0.4, 0)
			local neck = root
			for _ = 1, 3 do
				neck = neck * CFrame.Angles(0, 0, sx * math.rad(-18)) * CFrame.new(sx * 0.55, 0.7, 0)
				addPart(model, { Name = "Dragon", Size = V3(0.55, 1.5, 0.5), CFrame = neck, Color = Colors.DarkWood, CanCollide = false })
			end
			local head = neck * CFrame.new(sx * 0.5, 0.9, 0)
			addPart(model, { Name = "Dragon", Size = V3(1.5, 0.7, 0.6), CFrame = head, Color = Colors.DarkWood, CanCollide = false })
			addPart(model, { Name = "Dragon", Size = V3(0.5, 0.5, 0.15), CFrame = head * CFrame.new(-sx * 0.3, 0.5, 0) * CFrame.Angles(0, 0, sx * 0.5), Color = Colors.DarkWood, CanCollide = false })
			for _, ez in { 0.32, -0.32 } do
				addPart(model, { Name = "DragonEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.16, CFrame = head * CFrame.new(sx * 0.35, 0.12, ez), Color = Color3.fromRGB(220, 160, 60), Material = Enum.Material.Neon, CanCollide = false })
			end
		end
	end

	-- painted round shields hung along both long walls
	if o.shields ~= false then
		local palette = { Color3.fromRGB(150, 40, 36), Color3.fromRGB(226, 214, 186), Color3.fromRGB(46, 70, 120), Color3.fromRGB(196, 150, 60) }
		local count = math.max(2, math.floor(w / 7))
		for _, side in { 1, -1 } do
			for k = 1, count do
				local x = -w / 2 + (k - 0.5) * (w / count)
				if side == 1 or math.abs(x) > 3 then -- keep the door clear
					local at = cf * CFrame.new(x, base + wallH * 0.62, side * (d / 2 + 0.7)) * CFrame.Angles(0, math.pi / 2, 0)
					addPart(model, { Name = "Shield", Shape = Enum.PartType.Cylinder, Size = V3(0.25, 2.2, 2.2), CFrame = at, Color = palette[(k + (side == 1 and 0 or 2)) % #palette + 1], Material = Enum.Material.Wood, CanCollide = false })
					addPart(model, { Name = "ShieldBoss", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, CFrame = at * CFrame.new(side * 0.15, 0, 0), Color = Colors.Iron, Material = Enum.Material.Metal, CanCollide = false })
				end
			end
		end
	end
	if o.smoke then
		smoke(model, cf * CFrame.new(w * 0.22, ridgeY + 0.6, 0))
	end
end

local function logPile(model, cf: CFrame)
	local offsets = { V3(0, 0.6, -1.3), V3(0, 0.6, 0), V3(0, 0.6, 1.3), V3(0, 1.7, -0.65), V3(0, 1.7, 0.65), V3(0, 2.8, 0) }
	for i, offset in offsets do
		addPart(model, {
			Name = "Log" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = V3(6, 1.2, 1.2),
			CFrame = cf * CFrame.new(offset),
			Color = i % 2 == 0 and Colors.Wood or Colors.DarkWood,
		})
	end
end

local function fence(model, w: number, d: number, gapSide: boolean?)
	-- posts every ~4 studs with two rails, leaving a gap on the -Z side
	local hw, hd = w / 2 - 0.6, d / 2 - 0.6
	local corners = { V3(-hw, 0, -hd), V3(hw, 0, -hd), V3(hw, 0, hd), V3(-hw, 0, hd) }
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		local len = (b - a).Magnitude
		local mid = (a + b) / 2
		local isGap = gapSide and i == 1
		local n = math.max(1, math.floor(len / 4))
		for j = 0, n do
			local p = a:Lerp(b, j / n)
			post(model, p, 2.6, 0.45)
		end
		if not isGap then
			for _, y in { 1, 2.1 } do
				addPart(model, {
					Name = "Rail",
					Size = V3(len, 0.25, 0.25),
					CFrame = CFrame.lookAt(mid + V3(0, y, 0), b + V3(0, y, 0)) * CFrame.Angles(0, math.pi / 2, 0),
					Color = Colors.Weathered,
				})
			end
		end
	end
end

local Builders = {}

local function campfire(model, pos: Vector3)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		addPart(model, {
			Name = "FireStone",
			Size = V3(0.9, 0.6, 0.9),
			CFrame = CFrame.new(pos + V3(math.cos(a) * 1.5, 0.3, math.sin(a) * 1.5)) * CFrame.Angles(0, a, 0),
			Color = Colors.Stone,
			Material = Enum.Material.Slate,
		})
	end
	for i = 1, 3 do
		addPart(model, {
			Name = "FireLog",
			Size = V3(0.4, 0.4, 2.2),
			CFrame = CFrame.new(pos + V3(0, 0.4, 0)) * CFrame.Angles(0, i * math.pi / 3, 0.15),
			Color = Colors.DarkWood,
			CanCollide = false,
		})
	end
	local core = addPart(model, {
		Name = "Embers",
		Size = V3(1, 0.3, 1),
		Position = pos + V3(0, 0.3, 0),
		Color = Color3.fromRGB(255, 110, 40),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 50)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = core
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 22
	light.Brightness = 2
	light.Shadows = true
	light.Parent = core
end
ModelFactory.campfire = campfire

function Builders.Longhouse(model, w, d)
	hall(model, CFrame.new(), { w = w - 4, d = d - 5, wallH = 7, roof = "thatch", smoke = true })
	campfire(model, V3(-w / 2 + 4, 0, -d / 2 + 1.2))
	-- a carved post with a banner by the door
	post(model, V3(w / 2 - 4, 0, -d / 2 + 1), 9, 0.5)
	addPart(model, { Name = "Banner", Size = V3(0.15, 3.6, 2), Position = V3(w / 2 - 4, 6.6, -d / 2 + 2.1), Color = Color3.fromRGB(150, 40, 36), Material = Enum.Material.Fabric, CanCollide = false })
	-- barrels and a chopping block by the door
	for i, x in { 3.4, 4.6 } do
		addPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = V3(1.8, 1.4, 1.4), CFrame = CFrame.new(x, 1.9, -d / 2 + 2.2 + i * 0.2) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(120, 84, 52) })
	end
	addPart(model, { Name = "Block", Shape = Enum.PartType.Cylinder, Size = V3(1.2, 1.6, 1.6), CFrame = CFrame.new(-4.5, 1.6, -d / 2 + 2.4) * CFrame.Angles(0, 0, math.pi / 2), Color = Colors.Wood })
end

function Builders.Cottage(model, w, d)
	-- A steep A-frame: the roof reaches the ground, ridge runs along local Z.
	local base = 0.8
	addPart(model, {
		Name = "Foundation",
		Size = V3(w - 2, base, d - 2),
		Position = V3(0, base / 2, 0),
		Color = Colors.Stone,
		Material = Enum.Material.Cobblestone,
	})
	local depth = d - 3
	local halfW = (w - 3) / 2
	local angle = math.rad(62)
	local rise = halfW * math.tan(angle)
	local slope = halfW / math.cos(angle) + 0.4
	for _, side in { 1, -1 } do
		local slab = addPart(model, {
			Name = "Roof",
			Size = V3(slope, 0.9, depth + 1.6),
			CFrame = CFrame.new(side * halfW / 2, base + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			Color = Colors.Shingle:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = Enum.Material.WoodPlanks,
		})
		local rows = math.max(4, math.floor(slope / 1.5))
		local rowLen = slope / rows
		for r = 1, rows do
			noShadow(addPart(model, {
				Name = "RoofCourse",
				Size = V3(rowLen + 0.45, 0.28, depth + 1.7),
				CFrame = slab.CFrame * CFrame.new(side * (slope / 2 - (r - 0.5) * rowLen), 0.6 + 0.02 * r, 0) * CFrame.Angles(0, 0, side * math.rad(-4)),
				Color = vary(Colors.Shingle, 0.12),
				Material = Enum.Material.WoodPlanks,
				CanCollide = false,
			}))
		end
	end
	local steps = 7
	local stepH = rise / steps
	for _, sz in { 1, -1 } do
		for k = 1, steps do
			local hw = halfW * (1 - (k - 0.5) / steps)
			addPart(model, {
				Name = "Gable",
				Size = V3(hw * 2, stepH + 0.05, 0.6),
				Position = V3(0, base + (k - 0.5) * stepH, sz * depth / 2),
				Color = Colors.Wood,
				Material = Enum.Material.WoodPlanks,
			})
		end
	end
	-- crossed boards on the front gable
	for _, side in { 1, -1 } do
		addPart(model, {
			Name = "GableBoard",
			Size = V3(slope + 3, 0.6, 0.5),
			CFrame = CFrame.new(0, base + rise, -depth / 2 - 0.9) * CFrame.Angles(0, 0, -side * angle) * CFrame.new(side * (slope / 2 - 1.5), 0, 0),
			Color = Colors.DarkWood,
		})
	end
	addPart(model, { Name = "Door", Size = V3(2.6, 4.4, 0.3), Position = V3(0, base + 2.2, -depth / 2 - 0.4), Color = Color3.fromRGB(60, 40, 28), Material = Enum.Material.WoodPlanks })
	addPart(model, { Name = "Window", Size = V3(1.2, 1.2, 0.2), Position = V3(0, base + 6.5, -depth / 2 - 0.35), Color = Colors.Lantern, Material = Enum.Material.Neon })
	lantern(model, CFrame.new(2.2, base + 3.6, -depth / 2 - 0.8))
	smoke(model, CFrame.new(0, base + rise + 0.3, depth / 4))
end

function Builders.Woodcutter(model, w, d)
	hall(model, CFrame.new(-2, 0, 2.5), { w = 9, d = 7, wallH = 5, roof = "shingle", smoke = false })
	logPile(model, CFrame.new(3, 0, -4.5))
	addPart(model, {
		Name = "Stump",
		Shape = Enum.PartType.Cylinder,
		Size = V3(1.4, 2.2, 2.2),
		CFrame = CFrame.new(5, 0.7, 3) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Colors.Wood,
	})
	-- an axe stuck in the stump
	addPart(model, { Size = V3(0.25, 2.2, 0.25), CFrame = CFrame.new(5, 2.4, 3) * CFrame.Angles(0, 0, 0.5), Color = Colors.Wood })
	addPart(model, { Size = V3(0.9, 0.7, 0.15), CFrame = CFrame.new(5.3, 1.6, 3), Color = Colors.Iron, Material = Enum.Material.Metal })
end

function Builders.Quarry(model, w, d)
	addPart(model, {
		Size = V3(w - 1, 0.4, d - 1),
		Position = V3(0, 0.2, 0),
		Color = Color3.fromRGB(110, 108, 104),
		Material = Enum.Material.Slate,
	})
	local blocks = {
		{ V3(-3, 1.5, -3), V3(4, 2.6, 3) },
		{ V3(3, 1.2, -2), V3(3, 2, 3) },
		{ V3(-2.5, 2.2, 3), V3(5, 4, 4) },
		{ V3(4, 0.9, 4), V3(2, 1.4, 2) },
		{ V3(0.5, 0.8, 0), V3(2.4, 1.2, 1.6) },
	}
	for _, b in blocks do
		addPart(model, { Size = b[2], Position = b[1], Color = Colors.Stone, Material = Enum.Material.Slate })
	end
	-- wooden lifting crane
	post(model, V3(5.5, 0, -5.5), 8, 0.7)
	addPart(model, { Size = V3(0.5, 0.5, 7), Position = V3(5.5, 7.8, -2.5), Color = Colors.DarkWood })
	addPart(model, { Size = V3(0.12, 4, 0.12), Position = V3(5.5, 5.8, 0.6), Color = Colors.Thatch, Material = Enum.Material.Fabric })
	addPart(model, { Size = V3(1.2, 1, 1.2), Position = V3(5.5, 3.3, 0.6), Color = Colors.Stone, Material = Enum.Material.Slate })
end

function Builders.Farm(model, w, d)
	addPart(model, {
		Size = V3(w - 1, 0.3, d - 1),
		Position = V3(0, 0.15, 0),
		Color = Colors.Soil,
		Material = Enum.Material.Ground,
	})
	local rows = 8
	for i = 1, rows do
		local z = -d / 2 + 2.2 + (i - 1) * ((d - 4.4) / (rows - 1))
		addPart(model, {
			Name = "Barley",
			Size = V3(w - 4, 1.2, 1.5),
			Position = V3(0, 0.9, z),
			Color = i % 2 == 0 and Colors.Barley or Color3.fromRGB(184, 168, 84),
			Material = Enum.Material.Grass,
		})
	end
	fence(model, w, d, true)
	-- scarecrow
	post(model, V3(w / 4, 0, d / 4 - 1), 5, 0.3, Colors.Wood)
	addPart(model, { Size = V3(3, 0.3, 0.3), Position = V3(w / 4, 4, d / 4 - 1), Color = Colors.Wood })
	addPart(model, { Size = V3(1.3, 1.8, 0.6), Position = V3(w / 4, 3.4, d / 4 - 1), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.Fabric })
	addPart(model, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Position = V3(w / 4, 5.1, d / 4 - 1), Color = Colors.Thatch, Material = Enum.Material.Fabric })
end

function Builders.Storehouse(model, w, d)
	-- raised on stilts to keep goods dry; ridge along the long Z side
	for _, x in { -1, 1 } do
		for _, z in { -1, 0, 1 } do
			post(model, V3(x * (w / 2 - 2.5), 0, z * (d / 2 - 3)), 2, 1)
		end
	end
	hall(model, CFrame.new(0, 1, 0) * CFrame.Angles(0, math.pi / 2, 0), { w = d - 5, d = w - 5, wallH = 6, roof = "shingle", smoke = false })
	for i, pos in { V3(-4, 1, -10.3), V3(-1.6, 1, -10.3), V3(4.5, 1, -10.3) } do
		addPart(model, {
			Name = "Crate" .. i,
			Size = V3(2, 2, 2),
			Position = pos,
			Color = Colors.Wood,
			Material = Enum.Material.WoodPlanks,
		})
	end
	addPart(model, {
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = V3(2.2, 1.8, 1.8),
		CFrame = CFrame.new(5.5, 1.1, 9.5) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Colors.Wood,
	})
end

function Builders.Palisade(model, w, d)
	-- five sharpened logs in a row along local X, tied with a beam
	local n = 5
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * (w / n)
		local h = 8 + ((i * 37) % 7) / 6
		post(model, V3(x, 0, 0), h, 1.55, i % 2 == 0 and Colors.Wood or Colors.Weathered)
		addPart(model, {
			Name = "Point",
			Size = V3(1.05, 1.05, 1.05),
			CFrame = CFrame.new(x, h, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4),
			Color = Colors.Weathered,
		})
	end
	addPart(model, { Name = "Beam", Size = V3(w, 0.5, 0.4), Position = V3(0, 3, 0.9), Color = Colors.DarkWood })
	addPart(model, { Name = "Beam", Size = V3(w, 0.5, 0.4), Position = V3(0, 6, 0.9), Color = Colors.DarkWood })
end

function Builders.Watchtower(model, w, d)
	-- four tall legs, a plank deck with a railing and a little shingle roof
	local h = 14
	local hw, hd = w / 2 - 2, d / 2 - 2
	for _, c in { V3(-hw, 0, -hd), V3(hw, 0, -hd), V3(-hw, 0, hd), V3(hw, 0, hd) } do
		post(model, c, h + 4, 0.9)
	end
	for _, y in { 4, 9 } do
		for _, side in { 1, -1 } do
			addPart(model, { Name = "Brace", Size = V3(hw * 2, 0.4, 0.4), Position = V3(0, y, side * hd), Color = Colors.DarkWood })
			addPart(model, { Name = "Brace", Size = V3(0.4, 0.4, hd * 2), Position = V3(side * hw, y, 0), Color = Colors.DarkWood })
		end
	end
	addPart(model, { Name = "Deck", Size = V3(hw * 2 + 3, 0.6, hd * 2 + 3), Position = V3(0, h, 0), Color = Colors.Wood, Material = Enum.Material.WoodPlanks })
	for _, side in { 1, -1 } do
		addPart(model, { Name = "Rail", Size = V3(hw * 2 + 3, 1.2, 0.3), Position = V3(0, h + 0.9, side * (hd + 1.4)), Color = Colors.DarkWood })
		addPart(model, { Name = "Rail", Size = V3(0.3, 1.2, hd * 2 + 3), Position = V3(side * (hw + 1.4), h + 0.9, 0), Color = Colors.DarkWood })
	end
	for _, side in { 1, -1 } do
		addPart(model, {
			Name = "Roof",
			Size = V3(hw * 2 + 4, 0.5, hd + 2.6),
			CFrame = CFrame.new(0, h + 4.9, side * (hd / 2 + 0.9)) * CFrame.Angles(side * math.rad(32), 0, 0),
			Color = Colors.Shingle,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- a ladder up the front
	for y = 1, h - 1, 1.5 do
		addPart(model, { Name = "Rung", Size = V3(1.8, 0.25, 0.25), Position = V3(0, y, -hd - 0.6), Color = Colors.Wood })
	end
	lantern(model, CFrame.new(hw + 1, h + 2.5, -hd - 1))
	model:SetAttribute("ArcherPost", V3(0, h + 0.4, 0))
end

local function runestone(model, pos: Vector3, h: number, turn: number)
	local stone = addPart(model, {
		Name = "Runestone",
		Size = V3(2.4, h, 0.9),
		CFrame = CFrame.new(pos + V3(0, h / 2, 0)) * CFrame.Angles(0, turn, 0.04),
		Color = Color3.fromRGB(120, 120, 116),
		Material = Enum.Material.Slate,
	})
	-- carved band of runes, faintly glowing
	addPart(model, {
		Name = "Runes",
		Size = V3(0.25, h * 0.8, 0.95),
		CFrame = stone.CFrame * CFrame.new(-0.6, 0, 0),
		Color = Color3.fromRGB(110, 170, 230),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Transparency = 0.55
	return stone
end

function Builders.LoreHall(model, w, d)
	hall(model, CFrame.new(0, 0, 2), { w = w - 4, d = d - 7, wallH = 6, roof = "turf", smoke = true })
	runestone(model, V3(-6, 0, -d / 2 + 2), 5, 0.2)
	runestone(model, V3(6, 0, -d / 2 + 2), 4.2, -0.25)
	-- carved story pole by the door
	post(model, V3(0, 0, -d / 2 + 1.4), 7, 0.6, Colors.Weathered)
	addPart(model, { Name = "Carving", Size = V3(0.9, 1.2, 0.9), Position = V3(0, 7.2, -d / 2 + 1.4), Color = Color3.fromRGB(150, 40, 36), Material = Enum.Material.Wood })
end

function Builders.Smithy(model, w, d)
	-- an open-sided forge shed: four posts and a shingle roof
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			post(model, V3(x * (w / 2 - 1.5), 0, z * (d / 2 - 1.5)), 7, 0.8)
		end
	end
	addPart(model, { Name = "Floor", Size = V3(w - 1, 0.4, d - 1), Position = V3(0, 0.2, 0), Color = Color3.fromRGB(80, 74, 66), Material = Enum.Material.Cobblestone })
	for _, side in { 1, -1 } do
		addPart(model, {
			Name = "Roof",
			Size = V3(w + 1, 0.8, d / 2 + 2),
			CFrame = CFrame.new(0, 8.6, side * (d / 4)) * CFrame.Angles(side * math.rad(24), 0, 0),
			Color = Colors.Shingle,
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- stone forge with glowing coals
	addPart(model, { Name = "Forge", Size = V3(4, 3, 3.5), Position = V3(-3, 1.5, 2.5), Color = Colors.Stone, Material = Enum.Material.Cobblestone })
	local coals = addPart(model, { Name = "Coals", Size = V3(3, 0.4, 2.4), Position = V3(-3, 3.1, 2.5), Color = Color3.fromRGB(255, 100, 30), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 8
	fire.Parent = coals
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Range = 20
	light.Brightness = 2.5
	light.Shadows = true
	light.Parent = coals
	smoke(model, CFrame.new(-3, 9.6, 2.5))
	-- anvil on a stump
	addPart(model, { Shape = Enum.PartType.Cylinder, Size = V3(1.8, 1.8, 1.8), CFrame = CFrame.new(3, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Colors.Wood })
	addPart(model, { Name = "Anvil", Size = V3(2.2, 0.9, 1), Position = V3(3, 2.25, 0), Color = Colors.Iron, Material = Enum.Material.Metal })
	addPart(model, { Size = V3(0.8, 0.5, 0.6), Position = V3(4.3, 2.45, 0), Color = Colors.Iron, Material = Enum.Material.Metal })
	-- quenching barrel
	addPart(model, { Shape = Enum.PartType.Cylinder, Size = V3(2.4, 2, 2), CFrame = CFrame.new(4, 1.2, 4.5) * CFrame.Angles(0, 0, math.pi / 2), Color = Colors.Wood })
end

function Builders.Shrine(model, w, d)
	-- a ring of standing stones around a carved idol, with two fire bowls
	addPart(model, { Name = "Floor", Size = V3(w - 2, 0.3, d - 2), Position = V3(0, 0.15, 0), Color = Color3.fromRGB(110, 100, 86), Material = Enum.Material.Pebble })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local h = 4 + (i % 3) * 0.8
		addPart(model, {
			Name = "StandingStone",
			Size = V3(1.3, h, 0.8),
			CFrame = CFrame.new(math.cos(a) * 5.6, h / 2, math.sin(a) * 5.6) * CFrame.Angles(0, -a, 0.05),
			Color = Color3.fromRGB(116, 118, 114),
			Material = Enum.Material.Slate,
		})
	end
	post(model, V3(0, 0, 0), 8, 1, Colors.Weathered)
	addPart(model, { Name = "IdolFace", Size = V3(1.3, 1.6, 1.3), Position = V3(0, 6.6, 0), Color = Color3.fromRGB(96, 70, 48), Material = Enum.Material.Wood })
	for _, x in { -1, 1 } do
		addPart(model, { Size = V3(0.5, 3, 0.5), Position = V3(x * 1.1, 8.6, 0), CFrame = CFrame.new(x * 1.1, 8.4, 0) * CFrame.Angles(0, 0, -x * 0.5), Color = Color3.fromRGB(220, 205, 180) })
		local bowl = addPart(model, { Name = "FireBowl", Size = V3(1.4, 0.6, 1.4), Position = V3(x * 2.6, 2.3, -2.6), Color = Colors.Iron, Material = Enum.Material.Metal })
		post(model, V3(x * 2.6, 0, -2.6), 2, 0.3, Colors.Iron)
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 6
		fire.Parent = bowl
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 140, 60)
		light.Range = 14
		light.Brightness = 1.6
		light.Parent = bowl
	end
end

function Builders.Shipyard(model, w, d)
	-- a slipway with a longship hull taking shape on it, plus timber stacks
	addPart(model, { Name = "Slipway", Size = V3(10, 0.6, d - 2), Position = V3(-3, 0.3, 0), Color = Colors.Weathered, Material = Enum.Material.WoodPlanks })
	addPart(model, { Name = "Keel", Size = V3(1, 0.8, d - 6), Position = V3(-3, 1, 0), Color = Colors.Wood })
	for i = 1, 7 do
		local z = -d / 2 + 4 + (i - 1) * ((d - 8) / 6)
		local width = 3.5 + math.sin(i / 8 * math.pi) * 3
		for _, side in { 1, -1 } do
			addPart(model, {
				Name = "Rib",
				Size = V3(0.4, 4.5, 0.4),
				CFrame = CFrame.new(-3 + side * width / 2, 3, z) * CFrame.Angles(0, 0, side * 0.45),
				Color = Colors.Wood,
			})
		end
	end
	for _, side in { 1, -1 } do
		addPart(model, { Name = "Strake", Size = V3(0.35, 0.9, d - 10), CFrame = CFrame.new(-3 + side * 4.3, 1.6, 0) * CFrame.Angles(0, 0, side * 0.45), Color = Color3.fromRGB(96, 68, 46), Material = Enum.Material.WoodPlanks })
	end
	-- prow post rising at one end
	for k = 0, 4 do
		addPart(model, { Name = "Prow", Size = V3(0.5, 1.4, 0.8), CFrame = CFrame.new(-3, 2 + k * 1.2, -d / 2 + 2.5 - math.sin(k * 0.4) * 1.2) * CFrame.Angles(-k * 0.2, 0, 0), Color = Colors.DarkWood })
	end
	logPile(model, CFrame.new(w / 2 - 4, 0, 6) * CFrame.Angles(0, math.pi / 2, 0))
	logPile(model, CFrame.new(w / 2 - 4, 0, -6) * CFrame.Angles(0, math.pi / 2, 0))
	-- lifting frame
	post(model, V3(w / 2 - 3, 0, -d / 2 + 2), 10, 0.7)
	post(model, V3(-w / 2 + 1, 0, -d / 2 + 2), 10, 0.7)
	addPart(model, { Name = "Beam", Size = V3(w - 2, 0.6, 0.6), Position = V3(1, 10, -d / 2 + 2), Color = Colors.DarkWood })
end

function Builders.HuntingLodge(model, w, d)
	hall(model, CFrame.new(-1.5, 0, 2.5), { w = 9, d = 7, wallH = 5, roof = "thatch", smoke = true })
	-- hide drying rack
	post(model, V3(2, 0, -5), 5, 0.4)
	post(model, V3(6.5, 0, -5), 5, 0.4)
	addPart(model, { Size = V3(5, 0.3, 0.3), Position = V3(4.25, 4.8, -5), Color = Colors.DarkWood })
	for i = 1, 2 do
		addPart(model, { Name = "Hide", Size = V3(1.8, 3, 0.15), Position = V3(2.9 + (i - 1) * 2.4, 3.2, -5), Color = Color3.fromRGB(160, 116, 80), Material = Enum.Material.Fabric, CanCollide = false })
	end
	-- antlers over the door
	for _, x in { -1, 1 } do
		addPart(model, { Size = V3(0.2, 1.8, 0.2), CFrame = CFrame.new(-1.5 + x * 0.8, 6.8, -1.2) * CFrame.Angles(0, 0, -x * 0.6), Color = Color3.fromRGB(220, 205, 180) })
	end
end

function Builders.GreatHall(model, w, d)
	hall(model, CFrame.new(), { w = w - 4, d = d - 6, wallH = 9, roof = "shingle", pitch = 42, smoke = true })
	-- tall carved pillars at the entrance and a pair of braziers
	for _, x in { -5, 5 } do
		post(model, V3(x, 0, -d / 2 + 2), 12, 1.1, Colors.DarkWood)
		addPart(model, { Name = "Carving", Size = V3(1.4, 1.4, 1.4), Position = V3(x, 12.4, -d / 2 + 2), Color = Color3.fromRGB(170, 130, 50), Material = Enum.Material.Wood })
	end
	campfire(model, V3(-w / 2 + 4, 0, -d / 2 + 2))
	campfire(model, V3(w / 2 - 4, 0, -d / 2 + 2))
	-- red and gold banners along the long wall
	for i = -2, 2 do
		addPart(model, { Name = "Banner", Size = V3(1.8, 3.4, 0.12), Position = V3(i * 6, 6.5, -(d - 6) / 2 - 0.5), Color = i % 2 == 0 and Color3.fromRGB(150, 40, 36) or Color3.fromRGB(190, 150, 60), Material = Enum.Material.Fabric, CanCollide = false })
	end
end

-- Builds a building model for `buildingType` in its unrotated orientation.
function ModelFactory.building(buildingType: string): Model
	local def = Config.Buildings[buildingType]
	local w, d = def.Size[1] * CELL, def.Size[2] * CELL
	local model = Instance.new("Model")
	model.Name = buildingType
	local builder = Builders[buildingType]
	if builder then
		builder(model, w, d)
	else
		addPart(model, { Size = V3(w - 1, 4, d - 1), Position = V3(0, 2, 0) })
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Makes a model see-through and non-solid, for the placement preview.
function ModelFactory.makeGhost(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0.45
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Smoke") or d:IsA("Light") then
			d.Enabled = false
		end
	end
end

-- Trees ----------------------------------------------------------------------

-- A layered pine. Returns model, trunk.
function ModelFactory.pine(rng: Random, scale: number?): (Model, BasePart)
	local s = scale or rng:NextNumber(0.85, 1.5)
	local model = Instance.new("Model")
	model.Name = "Pine"
	local trunk = post(model, Vector3.zero, 7 * s, 1.2 * s)
	trunk.Name = "Trunk"
	-- a flared root at the base
	noShadow(addPart(model, { Name = "Root", Shape = Enum.PartType.Cylinder, Size = V3(0.9 * s, 1.9 * s, 1.9 * s), CFrame = CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = vary(Colors.DarkWood, 0.1), CanCollide = false }))
	local tiers = 5
	local twist = rng:NextNumber(0, math.pi)
	local tint = rng:NextNumber(-0.08, 0.08)
	local function shade(c: Color3, i: number)
		local k = 1 + tint + (i / tiers) * 0.12 + rng:NextNumber(-0.05, 0.05) -- lighter toward the sunlit top
		return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
	end
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local width = (7.5 - 5.6 * t) * s
		-- two crossed, drooping layers per tier give a ragged star of boughs
		for layer = 0, 1 do
			addPart(model, {
				Name = "Needles",
				Size = V3(width * (1 - layer * 0.12), (2.4 - layer * 0.5) * s, width * (1 - layer * 0.12)),
				CFrame = CFrame.new(0, (3.6 + i * 2.5 + layer * 0.5) * s, 0) * CFrame.Angles(0, twist + i * math.pi / 4 + layer * math.pi / 4, 0) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)),
				Color = shade(layer == 0 and Colors.Pine or Colors.PineLight, i),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
	addPart(model, {
		Name = "Tip",
		Size = V3(1.2 * s, 2.4 * s, 1.2 * s),
		Position = V3(0, (3.6 + tiers * 2.5 + 2) * s, 0),
		Color = Colors.Pine,
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	model.WorldPivot = CFrame.new()
	return model, trunk
end

-- A round-crowned birch. Returns model, trunk.
function ModelFactory.birch(rng: Random, scale: number?): (Model, BasePart)
	local s = scale or rng:NextNumber(0.85, 1.3)
	local model = Instance.new("Model")
	model.Name = "Birch"
	local trunk = post(model, Vector3.zero, 9 * s, 1 * s, Colors.Birch)
	trunk.Name = "Trunk"
	-- dark bark marks up the white trunk
	for i = 1, 5 do
		noShadow(addPart(model, {
			Name = "Bark",
			Size = V3(0.5 * s, 0.18 * s, 1.04 * s),
			CFrame = CFrame.new(0, (1 + i * 1.5 + rng:NextNumber(-0.4, 0.4)) * s, 0) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.new(0.3 * s, 0, 0),
			Color = Color3.fromRGB(40, 38, 36),
			Material = Enum.Material.Wood,
			CanCollide = false,
		}))
	end
	-- a few branches reaching into the crown
	for i = 1, 3 do
		local a = i * 2.1
		noShadow(addPart(model, { Name = "Branch", Size = V3(0.35 * s, 3 * s, 0.35 * s), CFrame = CFrame.new(0, 7.5 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, 0.7) * CFrame.new(0, 1.3 * s, 0), Color = Colors.Birch, CanCollide = false }))
	end
	local greens = { Color3.fromRGB(96, 134, 64), Colors.Leaf, Color3.fromRGB(112, 146, 70), Color3.fromRGB(84, 120, 56) }
	for i = 1, 6 do
		local a = i * 2.4 + rng:NextNumber(0, 1)
		local r = (i == 6) and 0 or rng:NextNumber(1.2, 2.4)
		addPart(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(3.6, 5.6) * s,
			Position = V3(math.cos(a) * r * s, (8.2 + (i % 3) * 1 + (i == 6 and 1.8 or 0)) * s, math.sin(a) * r * s),
			Color = vary(greens[(i % #greens) + 1], 0.06),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model, trunk
end

-- A tall, narrow spruce with drooping tiers. Returns model, trunk.
function ModelFactory.spruce(rng: Random, scale: number?): (Model, BasePart)
	local s = scale or rng:NextNumber(1, 1.6)
	local model = Instance.new("Model")
	model.Name = "Spruce"
	local trunk = post(model, Vector3.zero, 6 * s, 1 * s)
	trunk.Name = "Trunk"
	local tiers = 8
	local twist = rng:NextNumber(0, math.pi)
	noShadow(addPart(model, { Name = "Root", Shape = Enum.PartType.Cylinder, Size = V3(0.8 * s, 1.6 * s, 1.6 * s), CFrame = CFrame.new(0, 0.3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = vary(Colors.DarkWood, 0.1), CanCollide = false }))
	local tint = rng:NextNumber(-0.1, 0.06)
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local width = (5.4 - 4.4 * t) * s
		local k = 1 + tint + t * 0.15 + rng:NextNumber(-0.05, 0.05)
		local base = i % 2 == 0 and Color3.fromRGB(34, 60, 42) or Color3.fromRGB(28, 52, 38)
		for layer = 0, 1 do
			addPart(model, {
				Name = "Needles",
				Size = V3(width * (1 - layer * 0.15), (1.9 - layer * 0.4) * s, width * (1 - layer * 0.15)),
				CFrame = CFrame.new(0, (2.6 + i * 1.75 + layer * 0.35) * s, 0) * CFrame.Angles(0, twist + i * 0.7 + layer * math.pi / 4, 0) * CFrame.Angles(0.12, 0, 0.12),
				Color = Color3.new(math.clamp(base.R * k, 0, 1), math.clamp(base.G * k * (1 + layer * 0.08), 0, 1), math.clamp(base.B * k, 0, 1)),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
	addPart(model, {
		Name = "Tip",
		Size = V3(0.8 * s, 2.6 * s, 0.8 * s),
		Position = V3(0, (2.6 + tiers * 1.75 + 1.8) * s, 0),
		Color = Color3.fromRGB(30, 56, 40),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
	model.WorldPivot = CFrame.new()
	return model, trunk
end

-- A low, dense juniper shrub.
function ModelFactory.juniper(rng: Random, scale: number?): Model
	local s = scale or rng:NextNumber(0.7, 1.3)
	local model = Instance.new("Model")
	model.Name = "Juniper"
	for i = 1, 4 do
		local h = rng:NextNumber(1.6, 3.2) * s
		addPart(model, {
			Name = "Juniper",
			Size = V3(rng:NextNumber(1.4, 2.2) * s, h, rng:NextNumber(1.4, 2.2) * s),
			CFrame = CFrame.new(rng:NextNumber(-1, 1) * s, h / 2, rng:NextNumber(-1, 1) * s) * CFrame.Angles(0, rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)),
			Color = Color3.fromRGB(48, 76, 56),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A fern: a fan of fronds close to the ground.
function ModelFactory.fern(rng: Random, scale: number?): Model
	local s = scale or rng:NextNumber(0.8, 1.4)
	local model = Instance.new("Model")
	model.Name = "Fern"
	local n = 6
	local turn = rng:NextNumber(0, math.pi)
	for i = 1, n do
		local a = turn + i / n * math.pi * 2
		addPart(model, {
			Name = "Fern",
			Size = V3(0.7 * s, 0.08, 2.6 * s),
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7 * s, -1.1 * s) * CFrame.Angles(math.rad(28), 0, 0),
			Color = Color3.fromRGB(70, 112, 48),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- A boulder cluster. Returns model, main part.
function ModelFactory.boulder(rng: Random, scale: number?): (Model, BasePart)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Boulder"
	local main
	for i = 1, 5 do
		local size = V3(rng:NextNumber(2.5, 5), rng:NextNumber(1.8, 3.5), rng:NextNumber(2.5, 5)) * s * (i == 1 and 1.2 or (i <= 3 and 0.8 or 0.45))
		local p = addPart(model, {
			Name = i == 1 and "Rock" or "RockBit",
			Size = size,
			CFrame = CFrame.new(rng:NextNumber(-1.5, 1.5) * s * (i - 1), size.Y / 2 - 0.4, rng:NextNumber(-1.5, 1.5) * s * (i - 1))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Color = vary(i == 1 and Colors.Stone or Color3.fromRGB(108, 110, 106), 0.1),
			Material = (i % 2 == 0) and Enum.Material.Rock or Enum.Material.Slate,
		})
		if i > 3 then
			p.CastShadow = false
		end
		main = main or p
	end
	if rng:NextNumber() < 0.6 then
		-- a cap of moss on top of the biggest stone
		local top = main.CFrame * CFrame.new(0, main.Size.Y / 2 - 0.15, 0)
		addPart(model, {
			Name = "Moss",
			Size = V3(main.Size.X * 0.85, 0.45, main.Size.Z * 0.85),
			CFrame = top,
			Color = Color3.fromRGB(84, 110, 56),
			Material = Enum.Material.LeafyGrass,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model, main
end

-- Wild resource nodes. Returns the model and the part the prompt goes on.
function ModelFactory.node(kind: string, rng: Random): (Model, BasePart)
	if kind == "Tree" then
		local r = rng:NextNumber()
		if r < 0.45 then
			return ModelFactory.pine(rng)
		elseif r < 0.75 then
			return ModelFactory.spruce(rng)
		end
		return ModelFactory.birch(rng)
	elseif kind == "Rock" then
		return ModelFactory.boulder(rng)
	end
	-- Bush
	local model = Instance.new("Model")
	model.Name = "Bush"
	local main = addPart(model, {
		Name = "Bush",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 3.6,
		Position = V3(0, 1.4, 0),
		Color = Colors.Leaf,
		Material = Enum.Material.Grass,
	})
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		addPart(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.6,
			Position = V3(math.cos(a) * 1.55, 1.6 + (i % 2) * 0.6, math.sin(a) * 1.55),
			Color = Colors.Berry,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model, main
end

-- A wooden jetty running along local -Z from (0,0,0), `length` studs long.
function ModelFactory.dock(length: number): Model
	local model = Instance.new("Model")
	model.Name = "Dock"
	-- plank by plank, sun-bleached and uneven
	local plank = 1.15
	for z = plank / 2, length - plank / 2, plank + 0.08 do
		addPart(model, {
			Name = "Plank",
			Size = V3(6 + detail:NextNumber(-0.2, 0.3), 0.45, plank),
			CFrame = CFrame.new(detail:NextNumber(-0.1, 0.1), 1.2 + detail:NextNumber(-0.04, 0.04), -z) * CFrame.Angles(0, detail:NextNumber(-0.015, 0.015), 0),
			Color = vary(Colors.Weathered, 0.12),
			Material = Enum.Material.WoodPlanks,
		})
	end
	-- stringers under the planks
	for _, x in { -2.2, 2.2 } do
		noShadow(addPart(model, { Name = "Stringer", Size = V3(0.5, 0.5, length), Position = V3(x, 0.8, -length / 2), Color = Colors.DarkWood }))
	end
	for z = 0, length, 6 do
		for _, x in { -2.8, 2.8 } do
			local pile = post(model, V3(x, -8, -z), 10.2, 0.8, vary(Colors.DarkWood, 0.1))
			pile.Name = "Pile"
			-- a band of rope near the top
			noShadow(addPart(model, { Name = "Rope", Shape = Enum.PartType.Cylinder, Size = V3(0.35, 0.95, 0.95), CFrame = CFrame.new(x, 1.7, -z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(176, 150, 104), Material = Enum.Material.Fabric, CanCollide = false }))
		end
	end
	-- crates, a barrel and a coil of rope on the deck
	for i, at in { V3(1.6, 2.4, -6), V3(1.6, 2.4, -8.1), V3(1.7, 4.3, -7) } do
		addPart(model, { Name = "Crate" .. i, Size = V3(1.9, 1.9, 1.9), CFrame = CFrame.new(at) * CFrame.Angles(0, detail:NextNumber(-0.3, 0.3), 0), Color = vary(Colors.Wood, 0.1), Material = Enum.Material.WoodPlanks })
	end
	addPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = V3(1.8, 1.5, 1.5), CFrame = CFrame.new(-1.8, 2.35, -10) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(116, 80, 50) })
	noShadow(addPart(model, { Name = "RopeCoil", Shape = Enum.PartType.Cylinder, Size = V3(0.4, 1.4, 1.4), CFrame = CFrame.new(-1.8, 1.65, -length + 3) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(176, 150, 104), Material = Enum.Material.Fabric, CanCollide = false }))
	-- a little rowing boat tied up at the end
	addPart(model, { Name = "Boat", Size = V3(3, 1.2, 9), Position = V3(-5.5, 0.1, -length + 4), Color = Colors.Wood, Material = Enum.Material.WoodPlanks })
	addPart(model, { Size = V3(2.2, 0.3, 7.6), Position = V3(-5.5, 0.6, -length + 4), Color = Colors.DarkWood })
	model.WorldPivot = CFrame.new()
	return model
end

-- A longship, bow toward local -Z, pivot at the waterline in the middle.
function ModelFactory.longship(length: number?, sailColor: Color3?): Model
	local L = length or 44
	local model = Instance.new("Model")
	model.Name = "Longship"
	local maxW = L * 0.2
	local segs = 12
	local segLen = L / segs
	local hullColor = Color3.fromRGB(96, 68, 46)
	for i = 1, segs do
		local t = (i - 0.5) / segs
		local width = maxW * math.sin(math.pi * t) ^ 0.55
		local z = -L / 2 + (i - 0.5) * segLen
		local rise = (math.abs(t - 0.5) * 2) ^ 3 * 2.5 -- the hull sweeps up at both ends
		addPart(model, {
			Name = "Keel",
			Size = V3(math.max(width * 0.55, 0.8), 0.5, segLen + 0.2),
			Position = V3(0, -1.2 + rise * 0.5, z),
			Color = hullColor,
			Material = Enum.Material.WoodPlanks,
		})
		for _, side in { 1, -1 } do
			for strake = 0, 1 do
				addPart(model, {
					Name = "Strake",
					Size = V3(0.35, 1.3, segLen + 0.3),
					CFrame = CFrame.new(side * (width / 2 - 0.3 + strake * 0.45), -0.4 + strake * 1.15 + rise, z) * CFrame.Angles(0, 0, side * math.rad(22 + strake * 10)),
					Color = strake == 0 and hullColor or Color3.fromRGB(80, 56, 38),
					Material = Enum.Material.WoodPlanks,
				})
			end
		end
	end
	-- curling prow and stern posts
	for _, dir in { -1, 1 } do
		for k = 0, 6 do
			local a = k / 6 * math.pi * 0.9
			addPart(model, {
				Name = dir < 0 and "Prow" or "Stern",
				Size = V3(0.5, 1.4, 0.9),
				CFrame = CFrame.new(0, 1.5 + math.sin(a) * 3.2 + k * 0.35, dir * (L / 2 + math.cos(a) * 0.2 - 0.8 + math.sin(a) * 1.4)) * CFrame.Angles(dir * a * 0.7, 0, 0),
				Color = Color3.fromRGB(74, 52, 36),
			})
		end
	end
	-- a carved dragon head on the prow, with glowing eyes
	local head = CFrame.new(0, 1.5 + 3.2 * math.sin(math.pi * 0.9) + 2.9, -L / 2 - 0.6)
	addPart(model, { Name = "DragonHead", Size = V3(0.9, 1.3, 2.4), CFrame = head * CFrame.Angles(math.rad(-15), 0, 0), Color = Color3.fromRGB(74, 52, 36), CanCollide = false })
	addPart(model, { Name = "DragonJaw", Size = V3(0.7, 0.4, 1.6), CFrame = head * CFrame.new(0, -0.7, -0.6) * CFrame.Angles(math.rad(12), 0, 0), Color = Color3.fromRGB(64, 44, 30), CanCollide = false })
	for _, x in { -0.5, 0.5 } do
		noShadow(addPart(model, { Name = "DragonEye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.28, CFrame = head * CFrame.new(x, 0.25, -0.5), Color = Color3.fromRGB(240, 180, 60), Material = Enum.Material.Neon, CanCollide = false }))
		noShadow(addPart(model, { Name = "DragonHorn", Size = V3(0.2, 1.1, 0.2), CFrame = head * CFrame.new(x * 0.8, 0.9, 0.6) * CFrame.Angles(math.rad(-35), 0, x * 0.6), Color = Color3.fromRGB(210, 196, 168), CanCollide = false }))
	end
	-- rigging: stays from the masthead to bow and stern
	local top = V3(0, 19, -1)
	for _, to in { V3(0, 2.6, -L / 2 + 2), V3(0, 2.6, L / 2 - 2), V3(maxW * 0.45, 1.2, 2), V3(-maxW * 0.45, 1.2, 2) } do
		local mid = (top + to) / 2
		noShadow(addPart(model, { Name = "Stay", Size = V3(0.12, 0.12, (to - top).Magnitude), CFrame = CFrame.lookAt(mid, to), Color = Color3.fromRGB(150, 128, 92), Material = Enum.Material.Fabric, CanCollide = false }))
	end
	-- deck, mast, yard and striped sail
	addPart(model, { Name = "Deck", Size = V3(maxW * 0.8, 0.3, L * 0.72), Position = V3(0, -0.3, 0), Color = Colors.Weathered, Material = Enum.Material.WoodPlanks })
	post(model, V3(0, -0.3, -1), 20, 0.7)
	addPart(model, { Name = "Yard", Size = V3(16, 0.5, 0.5), Position = V3(0, 18, -1.3), Color = Colors.DarkWood })
	local stripeColor = sailColor or Color3.fromRGB(160, 40, 36)
	for i = 1, 5 do
		addPart(model, {
			Name = "Sail",
			Size = V3(3, 11, 0.2),
			Position = V3(-6 + (i - 1) * 3, 12.3, -1.6),
			Color = i % 2 == 0 and Color3.fromRGB(236, 228, 210) or stripeColor,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	-- round shields along both sides
	local shieldColors = { Color3.fromRGB(200, 160, 50), Color3.fromRGB(160, 44, 40), Color3.fromRGB(50, 80, 130), Color3.fromRGB(230, 225, 210) }
	for _, side in { 1, -1 } do
		for i = 1, 8 do
			local z = -L * 0.3 + (i - 1) * (L * 0.6 / 7)
			local t = (z + L / 2) / L
			local width = maxW * math.sin(math.pi * t) ^ 0.55
			addPart(model, {
				Name = "Shield",
				Shape = Enum.PartType.Cylinder,
				Size = V3(0.3, 2, 2),
				Position = V3(side * (width / 2 + 0.6), 1.3, z),
				Color = shieldColors[(i + (side > 0 and 0 or 1)) % 4 + 1],
				Material = Enum.Material.Wood,
				CanCollide = false,
			})
			addPart(model, {
				Name = "Oar",
				Size = V3(7, 0.25, 0.25),
				CFrame = CFrame.new(side * (width / 2 + 3), 0, z + 0.9) * CFrame.Angles(0, 0, side * math.rad(-25)),
				Color = Colors.Wood,
				CanCollide = false,
			})
		end
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Village props ---------------------------------------------------------------
-- Little things that make the valley feel lived in. ModelFactory.prop(kind)
-- builds one; kinds: Cart, Haystack, FishRack, Barrels, Woodpile, Banner,
-- BoatUpturned, FenceRun. Pivot = centre of the base, at ground level.
local Props = {}

local function barrel(model, at: Vector3, upright: boolean)
	local cf = upright and CFrame.new(at + V3(0, 0.95, 0)) * CFrame.Angles(0, 0, math.pi / 2) or CFrame.new(at + V3(0, 0.75, 0))
	addPart(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = V3(1.9, 1.5, 1.5), CFrame = cf, Color = vary(Color3.fromRGB(118, 82, 50), 0.1) })
	for _, off in { -0.6, 0.6 } do
		noShadow(addPart(model, { Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = V3(0.14, 1.56, 1.56), CFrame = cf * CFrame.new(off, 0, 0), Color = Colors.Iron, Material = Enum.Material.Metal, CanCollide = false }))
	end
end

function Props.Barrels(model)
	barrel(model, V3(0, 0, 0), true)
	barrel(model, V3(1.6, 0, 0.4), true)
	barrel(model, V3(0.7, 0, -1.6), false)
	addPart(model, { Name = "Crate", Size = V3(1.8, 1.8, 1.8), CFrame = CFrame.new(-1.8, 0.9, -0.6) * CFrame.Angles(0, 0.3, 0), Color = vary(Colors.Wood, 0.1), Material = Enum.Material.WoodPlanks })
end

function Props.Cart(model)
	addPart(model, { Name = "Bed", Size = V3(3.2, 0.35, 5), CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color = vary(Colors.Wood, 0.08), Material = Enum.Material.WoodPlanks })
	for _, x in { -1.6, 1.6 } do
		noShadow(addPart(model, { Name = "Side", Size = V3(0.25, 0.9, 5), CFrame = CFrame.new(x, 2.55, 0) * CFrame.Angles(math.rad(-6), 0, 0), Color = Colors.Weathered, Material = Enum.Material.WoodPlanks }))
		addPart(model, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = V3(0.35, 3, 3), CFrame = CFrame.new(x * 1.12, 1.5, 0.8), Color = Colors.DarkWood })
		noShadow(addPart(model, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = V3(0.5, 0.7, 0.7), CFrame = CFrame.new(x * 1.18, 1.5, 0.8), Color = Colors.Iron, Material = Enum.Material.Metal }))
	end
	for _, x in { -0.6, 0.6 } do
		noShadow(addPart(model, { Name = "Shaft", Size = V3(0.25, 0.25, 4.5), CFrame = CFrame.new(x, 1.1, -4.2) * CFrame.Angles(math.rad(14), 0, 0), Color = Colors.Wood }))
	end
	-- a load of hay
	addPart(model, { Name = "Load", Size = V3(2.8, 1.3, 3.6), CFrame = CFrame.new(0, 2.9, 0.3) * CFrame.Angles(math.rad(-6), 0, 0), Color = vary(Colors.Thatch, 0.08), Material = Enum.Material.Grass, CanCollide = false })
end

function Props.Haystack(model)
	addPart(model, { Name = "Hay", Shape = Enum.PartType.Ball, Size = Vector3.one * 6, CFrame = CFrame.new(0, 1.6, 0), Color = vary(Colors.Thatch, 0.06), Material = Enum.Material.Grass })
	addPart(model, { Name = "Hay", Shape = Enum.PartType.Ball, Size = Vector3.one * 4.2, CFrame = CFrame.new(0, 4, 0), Color = vary(Colors.Thatch, 0.06), Material = Enum.Material.Grass, CanCollide = false })
	post(model, V3(0, 3, 0), 4.2, 0.3, Colors.Weathered)
	noShadow(addPart(model, { Name = "Fork", Size = V3(0.15, 4, 0.15), CFrame = CFrame.new(2.6, 2.2, 1) * CFrame.Angles(0.3, 0, -0.35), Color = Colors.Wood, CanCollide = false }))
end

function Props.FishRack(model)
	-- a rack of stockfish drying in the wind off the fjord
	for _, x in { -3, 3 } do
		for _, z in { -0.8, 0.8 } do
			addPart(model, { Name = "Leg", Size = V3(0.35, 4.6, 0.35), CFrame = CFrame.new(x, 2.2, z) * CFrame.Angles(z > 0 and -0.25 or 0.25, 0, 0), Color = Colors.Weathered })
		end
	end
	noShadow(addPart(model, { Name = "Pole", Shape = Enum.PartType.Cylinder, Size = V3(7, 0.3, 0.3), CFrame = CFrame.new(0, 4.3, 0), Color = Colors.DarkWood }))
	for i = 1, 9 do
		local x = -2.8 + i * 0.6
		noShadow(addPart(model, { Name = "Fish", Size = V3(0.3, 1.6 + detail:NextNumber(-0.3, 0.3), 0.1), CFrame = CFrame.new(x, 3.4, (i % 2 == 0) and 0.1 or -0.1) * CFrame.Angles(0, 0, detail:NextNumber(-0.1, 0.1)), Color = vary(Color3.fromRGB(190, 176, 150), 0.1), Material = Enum.Material.Fabric, CanCollide = false }))
	end
end

function Props.Woodpile(model)
	for row = 0, 2 do
		for i = 0, 4 - row do
			addPart(model, {
				Name = "Log",
				Shape = Enum.PartType.Cylinder,
				Size = V3(5 + detail:NextNumber(-0.3, 0.3), 1, 1),
				CFrame = CFrame.new(detail:NextNumber(-0.2, 0.2), 0.5 + row * 0.86, (i - (4 - row) / 2) * 1.02),
				Color = vary(Colors.Wood, 0.14),
			})
		end
	end
	noShadow(addPart(model, { Name = "Cover", Size = V3(6, 0.3, 6), CFrame = CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(8)), Color = Colors.Shingle, Material = Enum.Material.WoodPlanks, CanCollide = false }))
end

function Props.Banner(model)
	post(model, V3(0, 0, 0), 11, 0.5, Colors.DarkWood)
	noShadow(addPart(model, { Name = "Crossbar", Size = V3(3.2, 0.3, 0.3), Position = V3(0, 10.4, 0), Color = Colors.DarkWood }))
	local red = Color3.fromRGB(150, 40, 36)
	addPart(model, { Name = "Cloth", Size = V3(2.8, 5, 0.1), Position = V3(0, 7.6, 0), Color = red, Material = Enum.Material.Fabric, CanCollide = false })
	noShadow(addPart(model, { Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = V3(0.12, 1.6, 1.6), CFrame = CFrame.new(0, 8, -0.08) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(214, 176, 96), Material = Enum.Material.Fabric, CanCollide = false }))
	for i = 0, 2 do
		noShadow(addPart(model, { Name = "Tail", Size = V3(0.8, 1, 0.1), CFrame = CFrame.new(-1 + i, 4.7, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = red, Material = Enum.Material.Fabric, CanCollide = false }))
	end
end

function Props.BoatUpturned(model)
	-- a small boat pulled up the beach, upside down on two trestles
	for _, z in { -2, 2 } do
		addPart(model, { Name = "Trestle", Size = V3(3.4, 1.4, 0.4), Position = V3(0, 0.7, z), Color = Colors.Weathered })
	end
	for i = -3, 3 do
		local t = 1 - math.abs(i) / 4
		addPart(model, { Name = "Hull", Size = V3(3 * t + 0.6, 0.9, 1.25), CFrame = CFrame.new(0, 1.85 + (1 - t) * 0.5, i * 1.2), Color = vary(Color3.fromRGB(96, 68, 46), 0.08), Material = Enum.Material.WoodPlanks })
	end
	noShadow(addPart(model, { Name = "KeelLine", Size = V3(0.3, 0.3, 8.6), Position = V3(0, 2.4, 0), Color = Colors.DarkWood }))
end

function Props.FenceRun(model)
	-- a split-rail fence 190 studs long along X
	local length = 190
	local step = 5
	for x = -length / 2, length / 2, step do
		post(model, V3(x, 0, detail:NextNumber(-0.2, 0.2)), 3.2, 0.45, vary(Colors.Weathered, 0.12))
	end
	for x = -length / 2, length / 2 - 20, 20 do
		for _, y in { 1.2, 2.4 } do
			noShadow(addPart(model, { Name = "Rail", Size = V3(20.4, 0.3, 0.3), Position = V3(x + 10, y + detail:NextNumber(-0.1, 0.1), 0), Color = vary(Colors.Weathered, 0.1) }))
		end
	end
end

function ModelFactory.prop(kind: string, _rng: Random?): Model
	local custom = ModelFactory.customAsset and ModelFactory.customAsset("Prop_" .. kind)
	if custom and ModelFactory.prepareProp then
		return ModelFactory.prepareProp(custom, kind)
	end
	local model = Instance.new("Model")
	model.Name = kind
	local builder = Props[kind]
	if builder then
		builder(model)
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Wildlife --------------------------------------------------------------------

-- A deer. The Body is anchored and moved by the server; other parts are
-- welded to it. GroundOffset attribute = body centre height above ground.
function ModelFactory.deer(rng: Random): Model
	local model = Instance.new("Model")
	model.Name = "Deer"
	local coat = Color3.fromRGB(140 + rng:NextInteger(-12, 12), 98, 60)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = V3(1.6, 1.6, 3.6)
	body.Color = coat
	body.Material = Enum.Material.Fabric
	body.CFrame = CFrame.new(0, 3, 0)
	body.Parent = model

	local function attach(name, size, offset: CFrame, color, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color or coat
		p.Material = Enum.Material.Fabric
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.CFrame = body.CFrame * offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	for _, x in { -0.55, 0.55 } do
		for _, z in { -1.3, 1.3 } do
			attach("Leg", V3(0.35, 2.3, 0.35), CFrame.new(x, -1.9, z), Color3.fromRGB(110, 78, 50))
		end
	end
	attach("Neck", V3(0.7, 1.8, 0.7), CFrame.new(0, 1.1, -1.7) * CFrame.Angles(math.rad(-25), 0, 0))
	attach("Head", V3(0.8, 0.8, 1.5), CFrame.new(0, 2, -2.3))
	attach("Tail", V3(0.4, 0.5, 0.3), CFrame.new(0, 0.5, 1.9), Color3.fromRGB(235, 225, 210))
	for _, x in { -0.4, 0.4 } do
		attach("Antler", V3(0.15, 1.4, 0.15), CFrame.new(x, 2.9, -2.1) * CFrame.Angles(0, 0, x * 0.9), Color3.fromRGB(220, 205, 180))
	end
	model.PrimaryPart = body
	model:SetAttribute("GroundOffset", 3)
	return model
end

-- A flying arrow (visual only).
function ModelFactory.arrow(): BasePart
	local shaft = Instance.new("Part")
	shaft.Name = "Arrow"
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.Size = V3(0.12, 0.12, 2.6)
	shaft.Color = Colors.Wood
	shaft.Material = Enum.Material.Wood
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Anchored = false
	tip.Massless = true
	tip.CanCollide = false
	tip.CanQuery = false
	tip.Size = V3(0.25, 0.25, 0.4)
	tip.Color = Colors.Iron
	tip.Material = Enum.Material.Metal
	tip.CFrame = shaft.CFrame * CFrame.new(0, 0, -1.4)
	tip.Parent = shaft
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shaft
	weld.Part1 = tip
	weld.Parent = tip
	return shaft
end

-- Villagers -------------------------------------------------------------------

-- A small villager figure. The body is anchored and moved by the server;
-- the head, hair and legs are welded to it so they follow.
-- GroundOffset attribute = body centre height above ground.
-- stage: "baby", "child", "adult" or "elder" (defaults from isChild).
-- Arms and legs hang from Welds whose C0 the client swings while walking
-- (attributes Hip = joint CFrame, HalfLen = half the limb length).
--[[
	Villagers are blocky Roblox-style figures (head, torso, two arms, two
	legs). `gear` (1-5, the village's rank) dresses the grown-ups:
	  1 Settler    wool tunic, leather belt and shoes
	  2 Chieftain  + fur mantle and leather boots
	  3 Hersir     + leather jerkin with straps, iron cap, bracers
	  4 Jarl       + mail shirt, helmet with nose guard, cloak, shield on the back
	  5 King       + gold-trimmed mail, crested helmet, red cloak, arm rings
	Children wear plain tunics; babies are swaddled.
]]
local Skins = {
	Color3.fromRGB(234, 196, 160),
	Color3.fromRGB(224, 180, 142),
	Color3.fromRGB(240, 206, 176),
	Color3.fromRGB(204, 160, 122),
}
local Wool = {
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(60, 86, 130),
	Color3.fromRGB(86, 110, 66),
	Color3.fromRGB(168, 138, 82),
	Color3.fromRGB(122, 112, 100),
	Color3.fromRGB(196, 184, 160),
}
local LEATHER = Color3.fromRGB(110, 74, 46)
local DARK_LEATHER = Color3.fromRGB(72, 50, 34)
local FUR = Color3.fromRGB(128, 104, 80)
local MAIL = Color3.fromRGB(128, 132, 138)
local STEEL = Color3.fromRGB(162, 166, 172)
local GOLD = Color3.fromRGB(214, 172, 84)

-- Women's names are every other one in Config.Names (Astrid, Sigrid, ...).
local womenNames = {}
for i, n in Config.Names do
	if i % 2 == 1 then
		womenNames[n] = true
	end
end
function ModelFactory.isWoman(name: string): boolean
	return womenNames[string.match(name, "^(%S+)") or name] == true
end

local RIG_PARTS = { Body = true, Head = true, Arm = true, Leg = true }

-- Swaps a villager's blocks for the settler mesh pieces (Settler_<Man|Woman>_<gear>
-- in the imported pack). The blocky rig stays, invisible, so walking and
-- working animations still move the arms and legs.
local function dressWithMesh(model: Model, pack: Instance, rig, s: number): boolean
	local function pieceOf(piece: string): BasePart?
		for _, d in pack:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == piece or d.Name == piece .. "_Node") then
				return d
			end
		end
		return nil
	end
	local sources = {}
	for piece in RIG_PARTS do
		sources[piece] = pieceOf(piece)
		if not sources[piece] or not rig[piece] then
			return false
		end
	end
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and not RIG_PARTS[d.Name] then
			d:Destroy()
		end
	end
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and RIG_PARTS[part.Name] then
			local info = rig[part.Name]
			local mesh = sources[part.Name]:Clone()
			mesh.Name = "Mesh" .. part.Name
			mesh.Anchored = false
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.Massless = true
			mesh.Size = info.size * s
			mesh.CFrame = part.CFrame * CFrame.new(info.centre * s)
			for _, c in mesh:GetChildren() do
				if c:IsA("JointInstance") or c:IsA("WeldConstraint") then
					c:Destroy()
				end
			end
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = mesh
			weld.Parent = mesh
			mesh.Parent = model
			part.Transparency = 1
			for _, c in part:GetChildren() do
				if c:IsA("Decal") then
					c:Destroy()
				end
			end
		end
	end
	return true
end

function ModelFactory.villager(name: string, isChild: boolean, rng: Random, stage: string?, gear: number?): Model
	stage = stage or (isChild and "child" or "adult")
	gear = (stage == "adult" or stage == "elder") and math.clamp(gear or 1, 1, 5) or 0
	local s = ({ baby = 0.45, child = 0.65, adult = 0.85, elder = 0.82 })[stage] or 0.85
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Villager", true)
	model:SetAttribute("Stage", stage)
	model:SetAttribute("Gear", gear)

	local skin = Skins[rng:NextInteger(1, #Skins)]
	local tunic = stage == "baby" and Color3.fromRGB(226, 216, 196) or Wool[rng:NextInteger(1, #Wool)]
	local trousers = Color3.fromRGB(70, 62, 54):Lerp(tunic, 0.15)
	local torsoColor, torsoMat = tunic, Enum.Material.Fabric
	if gear >= 4 then
		torsoColor, torsoMat = MAIL, Enum.Material.DiamondPlate
	elseif gear == 3 then
		torsoColor, torsoMat = LEATHER, Enum.Material.Leather
	end

	local legH = 2 * s
	local bodyH = 2 * s
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = V3(2 * s, bodyH, 1 * s)
	body.Color = torsoColor
	body.Material = torsoMat
	body.CFrame = CFrame.new(0, legH + bodyH / 2, 0)
	body.Parent = model

	local function weldTo(p: BasePart, to: BasePart)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = to
		weld.Part1 = p
		weld.Parent = p
	end

	local function piece(partName, size, cf: CFrame, color, material, shape, to: BasePart?)
		local p = Instance.new("Part")
		p.Name = partName
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.Fabric
		p.CFrame = cf
		p.Parent = model
		weldTo(p, to or body)
		return p
	end
	local function attach(partName, size, offset: CFrame, color, material, shape)
		return piece(partName, size, body.CFrame * offset, color, material, shape)
	end

	-- a limb hanging from `hip` (in body space), swung by its Weld
	local function limb(partName, size: Vector3, hip: CFrame, color, side: number)
		local p = Instance.new("Part")
		p.Name = partName
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.CFrame = body.CFrame * hip * CFrame.new(0, -size.Y / 2, 0)
		p.Parent = model
		local weld = Instance.new("Weld")
		weld.Name = "Joint"
		weld.Part0 = body
		weld.Part1 = p
		weld.C0 = hip * CFrame.new(0, -size.Y / 2, 0)
		weld.Parent = p
		p:SetAttribute("Hip", hip)
		p:SetAttribute("HalfLen", size.Y / 2)
		p:SetAttribute("Side", side)
		return p
	end

	-- head: the classic Roblox head shape with a face
	local head = attach("Head", V3(2, 1, 1) * s * (stage == "baby" and 1.2 or 1), CFrame.new(0, bodyH / 2 + 0.5 * s, 0), skin, Enum.Material.SmoothPlastic)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = V3(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local hs = 1.25 * s -- how big the head looks
	model:SetAttribute("HeadSize", hs)

	local hairColor = stage == "elder" and Color3.fromRGB(210, 210, 214) or Hair[rng:NextInteger(1, #Hair)]
	local helmet = gear >= 3 and stage == "adult"
	if stage ~= "baby" and not helmet then
		piece("Hair", V3(hs * 1.02, hs * 0.32, hs * 1.02), head.CFrame * CFrame.new(0, hs * 0.38, hs * 0.04), hairColor, Enum.Material.Fabric, nil, head)
		piece("Hair", V3(hs * 1.0, hs * 0.75, hs * 0.22), head.CFrame * CFrame.new(0, hs * 0.05, hs * 0.44), hairColor, Enum.Material.Fabric, nil, head)
	elseif helmet then
		-- hair showing under the helmet at the back
		piece("Hair", V3(hs * 0.9, hs * 0.5, hs * 0.2), head.CFrame * CFrame.new(0, -hs * 0.05, hs * 0.46), hairColor, Enum.Material.Fabric, nil, head)
	end
	if stage == "elder" or (stage == "adult" and gear >= 2 and rng:NextNumber() < 0.5) then
		piece("Beard", V3(hs * 0.8, hs * 0.5, hs * 0.3), head.CFrame * CFrame.new(0, -hs * 0.35, -hs * 0.42), hairColor, Enum.Material.Fabric, nil, head)
	end

	-- arms and legs
	local sleeve = gear >= 4 and MAIL or (gear == 3 and LEATHER or tunic:Lerp(Color3.new(0, 0, 0), 0.12))
	local legs = {}
	for i, x in { -0.5, 0.5 } do
		legs[i] = limb("Leg", V3(1 * s, legH, 1 * s), CFrame.new(x * s, -bodyH / 2, 0), trousers, i == 1 and 1 or -1)
	end
	local arms = {}
	for i, x in { -1.5, 1.5 } do
		arms[i] = limb("Arm", V3(1 * s, bodyH, 1 * s), CFrame.new(x * s, bodyH / 2, 0), sleeve, i == 1 and -1 or 1)
		-- bare hands
		piece("Hand", V3(1.02 * s, 0.45 * s, 1.02 * s), arms[i].CFrame * CFrame.new(0, -bodyH / 2 + 0.22 * s, 0), skin, Enum.Material.SmoothPlastic, nil, arms[i])
	end
	if stage == "baby" then
		attach("Swaddle", V3(2.1 * s, bodyH * 0.9, 1.1 * s), CFrame.new(0, -0.1 * s, 0), Color3.fromRGB(226, 216, 196))
	end

	-- shoes and boots
	for _, leg in legs do
		local h = gear >= 2 and 0.9 or 0.4
		piece("Boot", V3(1.04 * s, h * s, 1.1 * s), leg.CFrame * CFrame.new(0, -legH / 2 + h * s / 2, -0.03 * s), gear >= 2 and DARK_LEATHER or LEATHER, Enum.Material.Leather, nil, leg)
		if gear >= 2 then
			piece("BootFur", V3(1.12 * s, 0.22 * s, 1.16 * s), leg.CFrame * CFrame.new(0, -legH / 2 + h * s, 0), FUR, Enum.Material.Fabric, nil, leg)
		end
	end

	-- the tunic skirt below the belt
	if stage ~= "baby" then
		attach("Hem", V3(2.04 * s, 0.6 * s, 1.04 * s), CFrame.new(0, -bodyH / 2 - 0.2 * s, 0), gear >= 3 and tunic or tunic:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.Fabric)
		attach("Belt", V3(2.08 * s, 0.28 * s, 1.08 * s), CFrame.new(0, -bodyH * 0.3, 0), DARK_LEATHER, Enum.Material.Leather)
		attach("Buckle", V3(0.36 * s, 0.32 * s, 0.1 * s), CFrame.new(0, -bodyH * 0.3, -0.56 * s), gear >= 5 and GOLD or STEEL, Enum.Material.Metal)
	end

	if gear >= 2 then
		-- fur mantle over the shoulders
		attach("Mantle", V3(2.3 * s, 0.45 * s, 1.25 * s), CFrame.new(0, bodyH / 2 - 0.1 * s, 0), FUR, Enum.Material.Fabric)
	end
	if gear == 3 then
		-- leather jerkin: crossed straps and stitched panels
		attach("Strap", V3(0.25 * s, bodyH * 1.1, 0.06 * s), CFrame.new(0, 0, -0.52 * s) * CFrame.Angles(0, 0, math.rad(35)), DARK_LEATHER, Enum.Material.Leather)
		attach("Strap", V3(0.25 * s, bodyH * 1.1, 0.06 * s), CFrame.new(0, 0, -0.52 * s) * CFrame.Angles(0, 0, math.rad(-35)), DARK_LEATHER, Enum.Material.Leather)
	end
	if gear >= 3 then
		for _, arm in arms do
			piece("Bracer", V3(1.06 * s, 0.7 * s, 1.06 * s), arm.CFrame * CFrame.new(0, -bodyH / 2 + 0.85 * s, 0), gear >= 5 and GOLD or DARK_LEATHER, gear >= 5 and Enum.Material.Metal or Enum.Material.Leather, nil, arm)
		end
	end
	if gear >= 4 then
		-- a cloak down the back, pinned at the shoulder
		local cloak = gear >= 5 and Color3.fromRGB(150, 36, 34) or Color3.fromRGB(52, 70, 104)
		attach("Cloak", V3(2.1 * s, bodyH * 1.35, 0.14 * s), CFrame.new(0, -0.3 * s, 0.6 * s), cloak, Enum.Material.Fabric)
		attach("Brooch", V3(0.35 * s, 0.35 * s, 0.12 * s), CFrame.new(0.7 * s, bodyH / 2 - 0.25 * s, -0.56 * s), gear >= 5 and GOLD or STEEL, Enum.Material.Metal)
		if stage == "adult" then
			local paint = ({ Color3.fromRGB(168, 44, 38), Color3.fromRGB(214, 176, 96), Color3.fromRGB(46, 74, 120) })[rng:NextInteger(1, 3)]
			attach("BackShield", V3(0.2 * s, 2.2 * s, 2.2 * s), CFrame.new(0, 0.1 * s, 0.8 * s) * CFrame.Angles(0, math.pi / 2, 0), paint, Enum.Material.Wood, Enum.PartType.Cylinder)
			attach("BackBoss", V3(0.3 * s, 0.5 * s, 0.5 * s), CFrame.new(0, 0.1 * s, 0.92 * s) * CFrame.Angles(0, math.pi / 2, 0), STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	if gear >= 5 then
		attach("Trim", V3(2.06 * s, 0.14 * s, 1.06 * s), CFrame.new(0, -bodyH / 2 + 0.07 * s, 0), GOLD, Enum.Material.Metal)
		attach("Trim", V3(2.06 * s, 0.14 * s, 1.06 * s), CFrame.new(0, bodyH / 2 - 0.4 * s, 0), GOLD, Enum.Material.Metal)
	end
	if helmet then
		local steel = gear >= 5 and STEEL or Color3.fromRGB(118, 122, 128)
		piece("Helmet", V3(hs * 1.08, hs * 0.7, hs * 1.08), head.CFrame * CFrame.new(0, hs * 0.3, 0), steel, Enum.Material.Metal, Enum.PartType.Ball, head)
		piece("HelmetRim", V3(hs * 1.1, hs * 0.12, hs * 1.1), head.CFrame * CFrame.new(0, hs * 0.2, 0), gear >= 5 and GOLD or DARK_LEATHER, Enum.Material.Metal, nil, head)
		if gear >= 4 then
			piece("Nasal", V3(hs * 0.12, hs * 0.45, hs * 0.1), head.CFrame * CFrame.new(0, hs * 0.02, -hs * 0.55), steel, Enum.Material.Metal, nil, head)
		end
		if gear >= 5 then
			-- spectacle guard and a crest
			for _, x in { -0.22, 0.22 } do
				piece("Spectacle", V3(hs * 0.3, hs * 0.08, hs * 0.08), head.CFrame * CFrame.new(x * hs, hs * 0.12, -hs * 0.55), GOLD, Enum.Material.Metal, nil, head)
			end
			piece("Crest", V3(hs * 0.12, hs * 0.3, hs * 0.8), head.CFrame * CFrame.new(0, hs * 0.68, 0), GOLD, Enum.Material.Metal, nil, head)
			for _, arm in arms do
				piece("ArmRing", V3(1.12 * s, 0.16 * s, 1.12 * s), arm.CFrame * CFrame.new(0, bodyH * 0.15, 0), GOLD, Enum.Material.Metal, nil, arm)
			end
		end
	elseif gear >= 2 and stage == "adult" then
		-- a fur-lined leather cap
		piece("Cap", V3(hs * 1.06, hs * 0.4, hs * 1.06), head.CFrame * CFrame.new(0, hs * 0.42, 0), LEATHER, Enum.Material.Leather, nil, head)
		piece("CapFur", V3(hs * 1.12, hs * 0.16, hs * 1.12), head.CFrame * CFrame.new(0, hs * 0.24, 0), FUR, Enum.Material.Fabric, nil, head)
	end

	-- the settler meshes, when the pack is imported (grown-ups only)
	if (stage == "adult" or stage == "elder") and ModelFactory.customAsset then
		local woman = ModelFactory.isWoman(name)
		local slot = "Settler_" .. (woman and "Woman" or "Man") .. "_" .. math.max(gear, 1)
		local rig = SettlerRig[slot]
		local pack = rig and ModelFactory.customAsset(slot)
		if pack then
			if dressWithMesh(model, pack, rig, s) then
				model:SetAttribute("Helmeted", not woman and gear >= 3)
				model:SetAttribute("Meshed", true)
			end
			pack:Destroy()
		end
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 22)
	tag.StudsOffset = V3(0, bodyH / 2 + 1.9 * s, 0)
	tag.MaxDistance = 60
	tag.Adornee = body
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = name
	label.Parent = tag
	tag.Parent = body

	model.PrimaryPart = body
	model:SetAttribute("GroundOffset", legH + bodyH / 2)
	return model
end

-- Puts a crew on a longship: rowers on both sides facing the stern, a
-- helmsman at the steering oar and a lookout at the bow. Works for the
-- built-in ship and for an imported mesh (it reads the ship's size).
function ModelFactory.addCrew(ship: Model, rowers: number, rng: Random, gear: number?)
	local pivot = ship:GetPivot()
	local cf, size = ship:GetBoundingBox()
	local centre = pivot:PointToObjectSpace(cf.Position)
	local bottom = centre.Y - size.Y / 2
	local L = math.max(size.Z, 20) * 0.9
	local beam = L * 0.2
	local seat = bottom + 1.55 -- hips on the rowing benches
	local crew = Instance.new("Model")
	crew.Name = "Crew"
	local function place(fig: Model, local_: CFrame)
		local body = fig.PrimaryPart
		local half = body and body.Size.Y / 2 or 1
		fig:PivotTo(pivot * local_ * CFrame.new(0, half, 0))
		fig.Parent = crew
	end
	local pairs_ = math.max(1, math.floor(rowers / 2))
	for i = 1, pairs_ do
		local z = -L * 0.28 + (i - 1) * (L * 0.56 / math.max(1, pairs_ - 1))
		for _, side in { -1, 1 } do
			place(ModelFactory.figure(rng, gear, true), CFrame.new(side * beam * 0.24, seat, z) * CFrame.Angles(0, math.pi, 0))
		end
	end
	-- helmsman (standing) and lookout
	local legs = 1.7
	place(ModelFactory.figure(rng, gear), CFrame.new(beam * 0.15, seat - 0.4 + legs, L * 0.4))
	place(ModelFactory.figure(rng, gear), CFrame.new(0, seat - 0.4 + legs, -L * 0.38))
	crew.Parent = ship
	return crew
end

-- A still figure for decoration (ship crews): everything anchored, no name tag.
function ModelFactory.figure(rng: Random, gear: number?, seated: boolean?): Model
	local model = ModelFactory.villager("Crew", false, rng, "adult", gear)
	model:SetAttribute("Villager", nil) -- not walked or swung by the villager animator
	local tag = model.PrimaryPart and model.PrimaryPart:FindFirstChild("NameTag")
	if tag then
		tag:Destroy()
	end
	if seated then
		for _, leg in model:GetChildren() do
			if leg.Name == "Leg" and leg:IsA("BasePart") then
				local joint = leg:FindFirstChild("Joint") :: Weld
				if joint then
					joint.C0 = leg:GetAttribute("Hip") * CFrame.Angles(math.rad(90), 0, 0) * CFrame.new(0, -leg:GetAttribute("HalfLen"), 0)
				end
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CastShadow = false
		end
	end
	return model
end

-- Gives a villager figure a helmet, a round shield on the left arm and an axe
-- in the right hand, for the war band. Safe to call twice.
function ModelFactory.armWarrior(model: Model)
	if model:GetAttribute("Warrior") then
		return
	end
	local body = model.PrimaryPart
	if not body then
		return
	end
	model:SetAttribute("Warrior", true)
	local function piece(name, size, cf: CFrame, color, material, shape, to: BasePart?)
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Size = size
		p.Color = color
		p.Material = material
		p.CFrame = cf
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = to or body
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and not model:FindFirstChild("Helmet") and not model:GetAttribute("Helmeted") then
		local r = model:GetAttribute("HeadSize") or head.Size.X
		piece("Helmet", Vector3.new(r * 1.08, r * 0.6, r * 1.08), head.CFrame * CFrame.new(0, r * 0.22, 0), Color3.fromRGB(120, 124, 130), Enum.Material.Metal, Enum.PartType.Ball, head)
		piece("Nasal", Vector3.new(r * 0.12, r * 0.45, r * 0.12), head.CFrame * CFrame.new(0, 0, -r * 0.5), Color3.fromRGB(120, 124, 130), Enum.Material.Metal, nil, head)
	end
	local left, right
	for _, arm in model:GetChildren() do
		if arm.Name == "Arm" and arm:IsA("BasePart") then
			if arm:GetAttribute("Side") == -1 then
				left = arm
			else
				right = arm
			end
		end
	end
	local paint = ({ Color3.fromRGB(168, 44, 38), Color3.fromRGB(214, 176, 96), Color3.fromRGB(46, 74, 120) })[math.random(1, 3)]
	if left then
		local cf = left.CFrame * CFrame.new(-left.Size.X / 2 - 0.15, -0.1, 0) -- a cylinder lies along X: a disc on the arm
		piece("Shield", Vector3.new(0.2, 2.4, 2.4), cf, paint, Enum.Material.Wood, Enum.PartType.Cylinder, left)
		piece("ShieldBoss", Vector3.new(0.35, 0.6, 0.6), cf * CFrame.new(-0.15, 0, 0), Color3.fromRGB(150, 150, 156), Enum.Material.Metal, Enum.PartType.Cylinder, left)
	end
	if right then
		local hand = right.CFrame * CFrame.new(0, -right.Size.Y / 2, 0)
		piece("AxeHaft", Vector3.new(0.18, 2.6, 0.18), hand * CFrame.Angles(math.rad(-80), 0, 0) * CFrame.new(0, 0.9, 0), Color3.fromRGB(92, 66, 42), Enum.Material.Wood, nil, right)
		piece("AxeHead", Vector3.new(0.12, 0.7, 0.8), hand * CFrame.Angles(math.rad(-80), 0, 0) * CFrame.new(0, 2, -0.3), Color3.fromRGB(150, 152, 158), Enum.Material.Metal, nil, right)
	end
end

-- Tools -----------------------------------------------------------------------

-- Builds a hand tool ("Axe", "Pickaxe", "Bow" or "Torch") that players hold.
function ModelFactory.tool(kind: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = kind
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = ({ Axe = "Chop trees, fight", Pickaxe = "Mine rocks", Bow = "Shoot deer and enemies", Torch = "Set enemy buildings alight (F)", Sword = "Your weapon: click to fight" })[kind] or kind

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = V3(0.3, 3.6, 0.3)
	handle.Color = Colors.Wood
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local function head(size, offset: CFrame)
		local p = Instance.new("Part")
		p.Name = "Head"
		p.Size = size
		p.Color = Colors.Iron
		p.Material = Enum.Material.Metal
		p.CanCollide = false
		p.Massless = true
		p.CFrame = handle.CFrame * offset
		p.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end
	if kind == "Torch" then
		handle.Size = V3(0.35, 3, 0.35)
		local flame = Instance.new("Part")
		flame.Name = "Flame"
		flame.Size = V3(0.6, 0.7, 0.6)
		flame.Color = Color3.fromRGB(255, 150, 60)
		flame.Material = Enum.Material.Neon
		flame.CanCollide = false
		flame.Massless = true
		flame.CFrame = handle.CFrame * CFrame.new(0, 1.7, 0)
		flame.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = flame
		weld.Parent = flame
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 7
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Color = Colors.Lantern
		light.Range = 18
		light.Brightness = 2
		light.Parent = flame
		tool.Grip = CFrame.new(0, -0.8, 0)
		return tool
	elseif kind == "Bow" then
		-- the handle is the grip; two angled limbs and a string make the bow
		handle.Size = V3(0.3, 1, 0.3)
		local function limb(size, offset: CFrame, color, material)
			local p = Instance.new("Part")
			p.Name = "Limb"
			p.Size = size
			p.Color = color
			p.Material = material
			p.CanCollide = false
			p.Massless = true
			p.CFrame = handle.CFrame * offset
			p.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
		limb(V3(0.25, 2.2, 0.25), CFrame.new(0, 1.4, 0.3) * CFrame.Angles(math.rad(-15), 0, 0), Colors.DarkWood, Enum.Material.Wood)
		limb(V3(0.25, 2.2, 0.25), CFrame.new(0, -1.4, 0.3) * CFrame.Angles(math.rad(15), 0, 0), Colors.DarkWood, Enum.Material.Wood)
		limb(V3(0.06, 4.9, 0.06), CFrame.new(0, 0, 0.9), Color3.fromRGB(230, 225, 210), Enum.Material.Fabric)
		tool.Grip = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
		return tool
	elseif kind == "Sword" then
		-- a short grip, a crossguard and a long double-edged blade
		handle.Size = V3(0.3, 1.2, 0.3)
		handle.Color = Colors.DarkWood
		head(V3(0.35, 0.35, 0.35), CFrame.new(0, -0.7, 0)) -- pommel
		head(V3(0.25, 0.25, 1.6), CFrame.new(0, 0.7, 0)) -- crossguard
		head(V3(0.12, 3.8, 0.4), CFrame.new(0, 2.7, 0)) -- blade
		tool.Grip = CFrame.new(0, -0.2, 0)
		return tool
	elseif kind == "Axe" then
		head(V3(0.25, 1, 1.3), CFrame.new(0, 1.4, -0.7))
	else
		head(V3(0.25, 0.4, 3), CFrame.new(0, 1.6, 0))
		head(V3(0.2, 0.3, 0.6), CFrame.new(0, 1.5, -1.6) * CFrame.Angles(math.rad(25), 0, 0))
		head(V3(0.2, 0.3, 0.6), CFrame.new(0, 1.5, 1.6) * CFrame.Angles(math.rad(-25), 0, 0))
	end
	-- hold it near the bottom of the shaft
	tool.Grip = CFrame.new(0, -1.2, 0)
	return tool
end

-- Mesh swap ---------------------------------------------------------------------
--[[
	If ReplicatedStorage.Assets has a child named after a slot below, that
	model is used instead of the part-built one. Its pivot is moved to the
	bottom-centre of the model automatically, so it sits on the ground.
]]
ModelFactory.Slots = {
	"Longhouse", "Cottage", "Woodcutter", "Quarry", "Farm", "Storehouse", "Palisade",
	"LoreHall", "Smithy", "Shrine", "Shipyard", "HuntingLodge", "GreatHall", "Watchtower",
	"Tree_Pine", "Tree_Spruce", "Tree_Birch", "Rock", "Bush", "Dock", "Deer",
	"Axe", "Pickaxe", "Bow", "Torch", "Sword", "Longship",
	"Prop_Cart", "Prop_Haystack", "Prop_FishRack", "Prop_Barrels", "Prop_Woodpile", "Prop_Banner", "Prop_BoatUpturned",
}

-- Models laid out in Workspace > ModelWorkshop (see bakeTemplates) are
-- looked at first, so edits made there in Studio are used straight away.
--
-- The ready-made meshes (meshes/VikingAssets.glb) import as one model named
-- VikingAssets holding every slot. It works dropped straight into Assets, or
-- even left in the Workspace where Studio's importer puts it: the server
-- tucks it away into Assets when the game starts.
local slotSet = {}
for _, slot in ModelFactory.Slots do
	slotSet[slot] = true
end
for slot in SettlerRig do
	slotSet[slot] = true
end

local function assetsFolder(): Instance?
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local pack = workspace:FindFirstChild("VikingAssets")
	if pack and game:GetService("RunService"):IsServer() then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Assets"
			folder.Parent = ReplicatedStorage
		end
		-- imported parts come in loose: pin them before physics knocks them over
		-- and stand every piece upright (our meshes are modelled upright, so
		-- any turn on a part is from the importer or from tumbling)
		for _, d in pack:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				if d:IsA("MeshPart") then
					d.CFrame = CFrame.new(d.Position)
				end
			end
		end
		-- Studio's importer wraps each slot in "<Slot>_Node": drop the suffix
		for _, d in pack:GetDescendants() do
			local slot = string.match(d.Name, "^(.+)_Node$")
			if slot and slotSet[slot] then
				d.Name = slot
			end
		end
		pack.Parent = folder
	end
	return folder
end

-- Tuck the pack away as soon as the game starts, before anything is built,
-- so its models (all stacked on one spot) never show up in the village.
if game:GetService("RunService"):IsServer() then
	assetsFolder()
end

-- A slot inside a pack, however the importer nested it.
local function findInPack(pack: Instance, name: string): Instance?
	return pack:FindFirstChild(name) or pack:FindFirstChild(name .. "_Node") or pack:FindFirstChild(name, true) or pack:FindFirstChild(name .. "_Node", true)
end

local function customAsset(name: string): Instance?
	local folder = assetsFolder() -- always, so an imported pack never sits in the world
	local workshop = workspace:FindFirstChild("ModelWorkshop")
	local item = workshop and workshop:FindFirstChild(name)
	local fromPack = false
	if folder and not item then
		item = folder:FindFirstChild(name)
		if not item then
			-- one level down: a pack of slots (like VikingAssets) inside Assets
			for _, child in folder:GetChildren() do
				if not slotSet[child.Name] and (child:IsA("Model") or child:IsA("Folder")) then
					item = findInPack(child, name)
					if item then
						fromPack = true
						break
					end
				end
			end
		end
	end
	if not item then
		return nil
	end
	local clone = item:Clone()
	-- never bring along another slot that the importer nested inside this one
	if fromPack then
		for _, d in clone:GetDescendants() do
			local base = string.match(d.Name, "^(.+)_Node$") or d.Name
			if slotSet[base] and base ~= name and d.Parent then
				d:Destroy()
			end
		end
	end
	return clone
end
ModelFactory.customAsset = customAsset

local function largestPart(model: Model): BasePart?
	local best, bestVolume = nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestVolume then
				best, bestVolume = d, v
			end
		end
	end
	return best
end

-- Wraps loose parts in a Model, anchors it, optionally scales it to fit
-- `fit` (x/z), and puts its pivot at the bottom-centre at (0, 0, 0).
local function wrap(item: Instance): Model
	local model: Model
	if item:IsA("Model") then
		model = item
	else
		model = Instance.new("Model")
		model.Name = item.Name
		item.Parent = model
	end
	-- free models can hide scripts inside; never run them
	for _, d in model:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	return model
end

local function setAnchored(model: Instance, anchored: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
end

--[[
	Fits a custom model (an imported mesh or a free model) onto the built-in
	version `reference`: scaled to the same size and placed in the same spot,
	so a mesh drops in whatever units or position it was exported with.
	  mode "height"     match the height (trees, tools, deer)
	  mode "footprint"  fit inside the ground footprint (buildings, ships)
	Templates (the built-in models baked into the ModelWorkshop and edited by
	hand) are kept exactly as they are.
]]
-- Studio's 3D importer can leave imported MeshParts turned (a rotation
-- baked into each part), which made trees and halls lean. Our meshes are
-- modelled upright, so when every part is a MeshPart sharing one rotation,
-- that rotation is taken off.
local function standUp(custom: Model)
	local parts = {}
	for _, d in custom:GetDescendants() do
		if d:IsA("BasePart") then
			if not d:IsA("MeshPart") then
				return
			end
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		return
	end
	local turn = parts[1].CFrame.Rotation
	for _, part in parts do
		local diff = turn:ToObjectSpace(part.CFrame.Rotation)
		local _, angle = diff:ToAxisAngle()
		if math.abs(angle) > 0.01 then
			-- each piece knocked a different way: stand each one up where it is
			for _, p in parts do
				p.CFrame = CFrame.new(p.Position)
			end
			return
		end
	end
	local _, angle = turn:ToAxisAngle()
	if math.abs(angle) < 0.001 then
		return
	end
	local undo = turn:Inverse()
	for _, part in parts do
		part.CFrame = undo * part.CFrame
	end
end

-- `floorY` (optional) is where the bottom goes, in the built-in model's own
-- space: 0 = the ground line, so a mesh never sinks to the depth of a
-- built-in model's buried footing.
local function fitTo(custom: Model, reference: Model, mode: string, extraScale: number?, floorY: number?)
	local refCF, refSize = reference:GetBoundingBox()
	local refBottom = reference:GetPivot():PointToObjectSpace(refCF.Position - V3(0, refSize.Y / 2, 0))
	if floorY then
		refBottom = V3(refBottom.X, floorY, refBottom.Z)
	end
	if custom:GetAttribute("Template") then
		-- keep its own pivot (the built-in one), just bring it home
		custom:PivotTo(CFrame.new())
		return
	end
	standUp(custom)
	-- measure in world axes, not along a part's own turn
	custom.PrimaryPart = nil
	custom.WorldPivot = CFrame.new(custom:GetPivot().Position)
	local _, size = custom:GetBoundingBox()
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return
	end
	local factor
	if mode == "height" then
		factor = refSize.Y / size.Y
	else
		factor = math.min(refSize.X / size.X, refSize.Z / size.Z)
	end
	factor *= extraScale or 1
	if math.abs(factor - 1) > 0.005 then
		custom:ScaleTo(custom:GetScale() * factor)
	end
	local cf, newSize = custom:GetBoundingBox()
	custom.WorldPivot = CFrame.new(cf.Position - V3(0, newSize.Y / 2, 0))
	-- the same bottom-centre spot as the built-in model, relative to its pivot
	custom:PivotTo(CFrame.new(refBottom))
	custom.WorldPivot = CFrame.new()
end

-- Lights, fires and smoke from the built-in model go along with a custom
-- one (a mesh can't carry them), as do attributes like a tower's ArcherPost.
local function keepGlow(custom: Model, reference: Model)
	for _, d in reference:GetDescendants() do
		-- crop rows stay the game's own too, so fields still change with the seasons
		if d:IsA("BasePart") and (d.Name == "Barley" or d:FindFirstChildWhichIsA("Light") or d:FindFirstChildOfClass("Fire") or d:FindFirstChildOfClass("Smoke") or d:FindFirstChildOfClass("ParticleEmitter")) then
			d.Parent = custom
		end
	end
	for name, value in reference:GetAttributes() do
		if custom:GetAttribute(name) == nil then
			custom:SetAttribute(name, value)
		end
	end
end

local partBuilt = {
	building = ModelFactory.building,
	pine = ModelFactory.pine,
	spruce = ModelFactory.spruce,
	birch = ModelFactory.birch,
	boulder = ModelFactory.boulder,
	node = ModelFactory.node,
	dock = ModelFactory.dock,
	deer = ModelFactory.deer,
	tool = ModelFactory.tool,
}

function ModelFactory.building(buildingType: string): Model
	local custom = customAsset(buildingType)
	if not custom then
		return partBuilt.building(buildingType)
	end
	local reference = partBuilt.building(buildingType)
	local model = wrap(custom)
	setAnchored(model, true)
	fitTo(model, reference, "footprint", nil, 0)
	keepGlow(model, reference)
	reference:Destroy()
	model.Name = buildingType
	return model
end

-- A custom tree, rock or bush, sized like the built-in one it replaces.
local function customNature(slot: string, reference: Model, mainOf: BasePart?)
	local custom = customAsset(slot)
	if not custom then
		return nil
	end
	local model = wrap(custom)
	setAnchored(model, true)
	fitTo(model, reference, "height")
	reference:Destroy()
	model.Name = slot
	return model, largestPart(model) or mainOf
end

function ModelFactory.pine(rng: Random, scale: number?): (Model, BasePart)
	local reference, trunk = partBuilt.pine(rng, scale)
	local model, main = customNature("Tree_Pine", reference, trunk)
	if model then
		return model, main
	end
	return reference, trunk
end

function ModelFactory.birch(rng: Random, scale: number?): (Model, BasePart)
	local reference, trunk = partBuilt.birch(rng, scale)
	local model, main = customNature("Tree_Birch", reference, trunk)
	if model then
		return model, main
	end
	return reference, trunk
end

function ModelFactory.spruce(rng: Random, scale: number?): (Model, BasePart)
	local reference, trunk = partBuilt.spruce(rng, scale)
	local model, main = customNature("Tree_Spruce", reference, trunk)
	if model then
		return model, main
	end
	return reference, trunk
end

function ModelFactory.boulder(rng: Random, scale: number?): (Model, BasePart)
	local reference, rock = partBuilt.boulder(rng, scale)
	local model, main = customNature("Rock", reference, rock)
	if model then
		-- every rock turned its own way
		model:PivotTo(CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		model.WorldPivot = CFrame.new()
		return model, main
	end
	return reference, rock
end

function ModelFactory.node(kind: string, rng: Random): (Model, BasePart)
	if kind == "Bush" then
		local reference, bush = partBuilt.node(kind, rng)
		local model, main = customNature("Bush", reference, bush)
		if model then
			return model, main
		end
		return reference, bush
	end
	return partBuilt.node(kind, rng)
end

function ModelFactory.dock(length: number): Model
	local custom = customAsset("Dock")
	if not custom then
		return partBuilt.dock(length)
	end
	local reference = partBuilt.dock(length)
	local model = wrap(custom)
	setAnchored(model, true)
	fitTo(model, reference, "footprint")
	reference:Destroy()
	return model
end

function ModelFactory.deer(rng: Random): Model
	local custom = customAsset("Deer")
	if not custom then
		return partBuilt.deer(rng)
	end
	local reference = partBuilt.deer(rng)
	local model = wrap(custom)
	setAnchored(model, false)
	fitTo(model, reference, "height")
	reference:Destroy()
	model.Name = "Deer"
	local body = model.PrimaryPart or largestPart(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			if d ~= body then
				d.Massless = true
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	body.Anchored = true
	model.PrimaryPart = body
	model:SetAttribute("GroundOffset", body.Position.Y)
	return model
end

local partLongship = ModelFactory.longship
function ModelFactory.longship(length: number?, sailColor: Color3?): Model
	local custom = customAsset("Longship")
	if not custom then
		return partLongship(length, sailColor)
	end
	local reference = partLongship(length, sailColor)
	local model = wrap(custom)
	setAnchored(model, true)
	-- same length as the built-in ship, riding a little higher: a mesh hull
	-- is solid all the way down, so it looked swamped at the keel's depth
	local _, refSize = reference:GetBoundingBox()
	local keel = reference:GetPivot():PointToObjectSpace(reference:GetBoundingBox().Position).Y - refSize.Y / 2
	fitTo(model, reference, "footprint", nil, keel + 0.9)
	reference:Destroy()
	return model
end

-- Village props (Prop_Cart, Prop_Haystack, ...): sized like the built-in prop.
function ModelFactory.prepareProp(custom: Instance, kind: string): Model
	local reference = Instance.new("Model")
	if Props[kind] then
		Props[kind](reference)
	end
	reference.WorldPivot = CFrame.new()
	local model = wrap(custom)
	setAnchored(model, true)
	if #reference:GetChildren() > 0 then
		fitTo(model, reference, "footprint", nil, 0)
	end
	reference:Destroy()
	model.Name = kind
	return model
end

--[[
	Tools: a slot can hold a ready-made Tool (used as it is), or just a model
	or mesh. A model is fitted over the built-in tool, whose own parts are
	hidden, so the grip, swing and fire all keep working.
]]
function ModelFactory.tool(kind: string): Tool
	local custom = customAsset(kind)
	if not custom then
		return partBuilt.tool(kind)
	end
	if custom:IsA("Tool") then
		custom.Name = kind
		for _, d in custom:GetDescendants() do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- the game drives its tools itself
			end
		end
		return custom
	end
	local tool = partBuilt.tool(kind)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local model = wrap(custom)
	setAnchored(model, false)
	-- fit over the built-in tool (measured with its handle at the origin)
	local reference = Instance.new("Model")
	for _, d in tool:GetChildren() do
		if d:IsA("BasePart") then
			d:Clone().Parent = reference
		end
	end
	reference.WorldPivot = handle.CFrame
	fitTo(model, reference, "height")
	reference:Destroy()
	for _, d in tool:GetChildren() do
		if d:IsA("BasePart") and not d:FindFirstChildOfClass("Fire") and not d:FindFirstChildWhichIsA("Light") then
			d.Transparency = 1
		end
	end
	model:PivotTo(handle.CFrame * model:GetPivot())
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = d
			weld.Parent = d
			d.Parent = tool
		end
	end
	model:Destroy()
	return tool
end

-- Editing models in Studio ------------------------------------------------------
--[[
	bakeTemplates() is run once from Studio's Command Bar (in edit mode, not
	while playing):
	    require(game.ServerScriptService.Server.EditTools).Setup()
	It puts a copy of every built-in model into Workspace > ModelWorkshop, in
	a row you can see and edit. When the game starts, the server moves them
	into ReplicatedStorage > Assets and uses them everywhere. Delete one to go
	back to the built-in version (which has more random variety for trees).
]]
local function moveBy(item: Instance, offset: CFrame)
	if item:IsA("PVInstance") then
		item:PivotTo(offset * item:GetPivot())
		return
	end
	for _, d in item:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = offset * d.CFrame
		end
	end
end

function ModelFactory.bakeTemplates(): number
	local workshop = workspace:FindFirstChild("ModelWorkshop")
	if not workshop then
		workshop = Instance.new("Folder")
		workshop.Name = "ModelWorkshop"
		workshop.Parent = workspace
	end
	local rng = Random.new(7)
	local makers = {
		Tree_Pine = function()
			return partBuilt.pine(rng, 1)
		end,
		Tree_Spruce = function()
			return partBuilt.spruce(rng, 1)
		end,
		Tree_Birch = function()
			return partBuilt.birch(rng, 1)
		end,
		Rock = function()
			return partBuilt.boulder(rng, 1)
		end,
		Bush = function()
			return partBuilt.node("Bush", rng)
		end,
		Dock = function()
			return partBuilt.dock(48)
		end,
		Deer = function()
			return partBuilt.deer(rng)
		end,
	}
	for _, kind in Config.Tools do
		makers[kind] = function()
			return partBuilt.tool(kind)
		end
	end
	for b in Config.Buildings do
		makers[b] = function()
			return partBuilt.building(b)
		end
	end
	for kind, build in Props do
		makers["Prop_" .. kind] = function()
			local m = Instance.new("Model")
			m.Name = kind
			build(m)
			m.WorldPivot = CFrame.new()
			return m
		end
	end

	-- Lay them out in a row in the meadow behind the first plot.
	local x, z, made = -20, 200, 0
	for _, slot in ModelFactory.Slots do
		local make = makers[slot]
		if make and not workshop:FindFirstChild(slot) then
			-- Start from your own model if one is already in Assets.
			local own = customAsset(slot)
			local item = own or make()
			item.Name = slot
			if not own then
				item:SetAttribute("Template", true)
			end
			local width = 8
			if item:IsA("Model") then
				local _, size = item:GetBoundingBox()
				width = math.max(size.X, size.Z, 6)
			end
			x += width / 2 + 6
			local hit = workspace:Raycast(V3(x, 400, z), V3(0, -800, 0))
			local y = hit and hit.Position.Y or 1
			if item:IsA("Tool") then
				local handle = item:FindFirstChild("Handle")
				if handle then
					moveBy(item, CFrame.new(V3(x, y + 2.5, z) - handle.Position))
				end
			else
				item:PivotTo(CFrame.new(x, y, z))
			end
			item.Parent = workshop
			x += width / 2
			made += 1
		end
	end
	return made
end

-- Called by the server as the game starts: hands the workshop models to the
-- game (ReplicatedStorage > Assets) and clears them out of the world.
function ModelFactory.collectWorkshop()
	local workshop = workspace:FindFirstChild("ModelWorkshop")
	if not workshop then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	for _, item in workshop:GetChildren() do
		local handle = item:IsA("Tool") and item:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CanTouch = true
		end
		local old = assets:FindFirstChild(item.Name)
		if old then
			old:Destroy()
		end
		item.Parent = assets
	end
	workshop:Destroy()
end

return ModelFactory
