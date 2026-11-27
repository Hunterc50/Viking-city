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

local Tunics = {
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(60, 86, 130),
	Color3.fromRGB(86, 110, 66),
	Color3.fromRGB(168, 138, 82),
	Color3.fromRGB(108, 78, 112),
	Color3.fromRGB(122, 112, 100),
}
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
	addPart(model, {
		Name = "Walls",
		Size = V3(w, wallH, d),
		CFrame = cf * CFrame.new(0, base + wallH / 2, 0),
		Color = Colors.Wood,
		Material = Enum.Material.WoodPlanks,
	})
	-- horizontal log banding on the long sides
	local bands = math.floor(wallH / 1.5)
	for i = 1, bands do
		for _, side in { 1, -1 } do
			addPart(model, {
				Name = "Log",
				Size = V3(w + 0.8, 0.4, 0.4),
				CFrame = cf * CFrame.new(0, base + i * 1.5 - 0.3, side * (d / 2 + 0.15)),
				Color = Colors.DarkWood,
			})
		end
	end
	-- corner posts
	for _, sx in { 1, -1 } do
		for _, sz in { 1, -1 } do
			addPart(model, {
				Size = V3(0.9, wallH, 0.9),
				CFrame = cf * CFrame.new(sx * w / 2, base + wallH / 2, sz * d / 2),
				Color = Colors.DarkWood,
			})
		end
	end

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
		addPart(model, {
			Name = "Roof",
			Size = V3(w + 2.6, 1, slope),
			CFrame = cf * CFrame.new(0, wallTop + rise / 2, side * halfD / 2) * CFrame.Angles(side * angle, 0, 0),
			Color = roofColor,
			Material = roofMaterial,
		})
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
		Size = V3(4, 5.8, 0.3),
		CFrame = cf * CFrame.new(0, base + 2.9, -d / 2 - 0.1),
		Color = Colors.DarkWood,
	})
	addPart(model, {
		Name = "Door",
		Size = V3(3, 5, 0.3),
		CFrame = cf * CFrame.new(0, base + 2.5, -d / 2 - 0.25),
		Color = Color3.fromRGB(60, 40, 28),
		Material = Enum.Material.WoodPlanks,
	})
	if o.lantern ~= false then
		lantern(model, cf * CFrame.new(2.8, base + 4.6, -d / 2 - 0.6))
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

function Builders.Longhouse(model, w, d)
	hall(model, CFrame.new(), { w = w - 4, d = d - 5, wallH = 7, roof = "thatch", smoke = true })
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
		addPart(model, {
			Name = "Roof",
			Size = V3(slope, 0.9, depth + 1.6),
			CFrame = CFrame.new(side * halfW / 2, base + rise / 2, 0) * CFrame.Angles(0, 0, -side * angle),
			Color = Colors.Shingle,
			Material = Enum.Material.WoodPlanks,
		})
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
	local tiers = 5
	local twist = rng:NextNumber(0, math.pi)
	for i = 1, tiers do
		local t = (i - 1) / (tiers - 1)
		local width = (7.5 - 5.6 * t) * s
		addPart(model, {
			Name = "Needles",
			Size = V3(width, 2.4 * s, width),
			CFrame = CFrame.new(0, (3.6 + i * 2.5) * s, 0) * CFrame.Angles(0, twist + i * math.pi / 4, 0),
			Color = i % 2 == 0 and Colors.PineLight or Colors.Pine,
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
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
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(0, 1)
		addPart(model, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(4.5, 6.5) * s,
			Position = V3(math.cos(a) * 1.6 * s, (8.5 + i * 0.8) * s, math.sin(a) * 1.6 * s),
			Color = i == 2 and Colors.Leaf or Color3.fromRGB(96, 134, 64),
			Material = Enum.Material.Grass,
			CanCollide = false,
		})
	end
	model.WorldPivot = CFrame.new()
	return model, trunk
end

-- A boulder cluster. Returns model, main part.
function ModelFactory.boulder(rng: Random, scale: number?): (Model, BasePart)
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Boulder"
	local main
	for i = 1, 3 do
		local size = V3(rng:NextNumber(2.5, 5), rng:NextNumber(1.8, 3.5), rng:NextNumber(2.5, 5)) * s * (i == 1 and 1.2 or 0.8)
		local p = addPart(model, {
			Name = i == 1 and "Rock" or "RockBit",
			Size = size,
			CFrame = CFrame.new(rng:NextNumber(-1.5, 1.5) * s * (i - 1), size.Y / 2 - 0.4, rng:NextNumber(-1.5, 1.5) * s * (i - 1))
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25)),
			Color = i == 1 and Colors.Stone or Color3.fromRGB(108, 110, 106),
			Material = Enum.Material.Slate,
		})
		main = main or p
	end
	model.WorldPivot = CFrame.new()
	return model, main
end

-- Wild resource nodes. Returns the model and the part the prompt goes on.
function ModelFactory.node(kind: string, rng: Random): (Model, BasePart)
	if kind == "Tree" then
		if rng:NextNumber() < 0.75 then
			return ModelFactory.pine(rng)
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
	addPart(model, {
		Name = "Deck",
		Size = V3(6, 0.5, length),
		Position = V3(0, 1.2, -length / 2),
		Color = Colors.Weathered,
		Material = Enum.Material.WoodPlanks,
	})
	for z = 0, length, 6 do
		for _, x in { -2.8, 2.8 } do
			post(model, V3(x, -8, -z), 10, 0.7)
		end
	end
	-- a little rowing boat tied up at the end
	addPart(model, { Name = "Boat", Size = V3(3, 1.2, 9), Position = V3(-5.5, 0.1, -length + 4), Color = Colors.Wood, Material = Enum.Material.WoodPlanks })
	addPart(model, { Size = V3(2.2, 0.3, 7.6), Position = V3(-5.5, 0.6, -length + 4), Color = Colors.DarkWood })
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
function ModelFactory.villager(name: string, isChild: boolean, rng: Random): Model
	local s = isChild and 0.65 or 1
	local model = Instance.new("Model")
	model.Name = name

	local legH = 1.1 * s
	local bodyH = 1.8 * s
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = V3(1.5, bodyH, 0.95) * V3(s, 1, s)
	body.Color = Tunics[rng:NextInteger(1, #Tunics)]
	body.Material = Enum.Material.Fabric
	body.CFrame = CFrame.new(0, legH + bodyH / 2, 0)
	body.Parent = model

	local function attach(partName, size, offset: CFrame, color, material, shape)
		local p = Instance.new("Part")
		p.Name = partName
		if shape then
			p.Shape = shape
		end
		p.Anchored = false
		p.CanCollide = false
		p.Massless = true
		p.Size = size
		p.Color = color
		p.Material = material
		p.CFrame = body.CFrame * offset
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	attach("Head", Vector3.one * 1.1 * s, CFrame.new(0, bodyH / 2 + 0.55 * s, 0), Colors.Skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	attach("Hair", V3(1.15, 0.5, 1.15) * s, CFrame.new(0, bodyH / 2 + 0.95 * s, 0.1 * s), Hair[rng:NextInteger(1, #Hair)], Enum.Material.Fabric)
	attach("Belt", V3(1.55 * s, 0.25 * s, 1 * s), CFrame.new(0, -bodyH * 0.15, 0), Colors.DarkWood, Enum.Material.Fabric)
	for _, x in { -0.35, 0.35 } do
		attach("Leg", V3(0.5, legH, 0.6) * V3(s, 1, s), CFrame.new(x * s, -bodyH / 2 - legH / 2, 0), Color3.fromRGB(70, 62, 54), Enum.Material.Fabric)
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(140, 22)
	tag.StudsOffset = V3(0, bodyH / 2 + 1.8 * s, 0)
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

-- Tools -----------------------------------------------------------------------

-- Builds a hand tool ("Axe", "Pickaxe" or "Bow") that players hold.
function ModelFactory.tool(kind: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = kind
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = ({ Axe = "Chop trees", Pickaxe = "Mine rocks", Bow = "Click to shoot deer for meat and hides" })[kind] or kind

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
	if kind == "Bow" then
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
	"Tree_Pine", "Tree_Birch", "Rock", "Bush", "Dock", "Deer",
	"Axe", "Pickaxe", "Bow", "Longship",
}

local function customAsset(name: string): Instance?
	local folder = ReplicatedStorage:FindFirstChild("Assets")
	local item = folder and folder:FindFirstChild(name)
	return item and item:Clone() or nil
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
local function prepare(item: Instance, anchored: boolean, fit: Vector3?, scale: number?): Model
	local model: Model
	if item:IsA("Model") then
		model = item
	else
		model = Instance.new("Model")
		model.Name = item.Name
		item.Parent = model
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = anchored
		end
	end
	local _, size = model:GetBoundingBox()
	local factor = scale or 1
	if fit and size.X > 0 and size.Z > 0 then
		factor *= math.min(fit.X / size.X, fit.Z / size.Z)
	end
	if math.abs(factor - 1) > 0.01 then
		model:ScaleTo(model:GetScale() * factor)
	end
	local cf, newSize = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, newSize.Y / 2, 0))
	model:PivotTo(CFrame.new())
	return model
end

local partBuilt = {
	building = ModelFactory.building,
	pine = ModelFactory.pine,
	birch = ModelFactory.birch,
	boulder = ModelFactory.boulder,
	node = ModelFactory.node,
	dock = ModelFactory.dock,
	deer = ModelFactory.deer,
	tool = ModelFactory.tool,
}

function ModelFactory.building(buildingType: string): Model
	local custom = customAsset(buildingType)
	if custom then
		local def = Config.Buildings[buildingType]
		local model = prepare(custom, true, V3(def.Size[1] * CELL * 0.96, 0, def.Size[2] * CELL * 0.96))
		model.Name = buildingType
		return model
	end
	return partBuilt.building(buildingType)
end

local function customTree(slot: string, rng: Random, scale: number?)
	local custom = customAsset(slot)
	if not custom then
		return nil
	end
	local model = prepare(custom, true, nil, scale or rng:NextNumber(0.85, 1.4))
	return model, largestPart(model)
end

function ModelFactory.pine(rng: Random, scale: number?): (Model, BasePart)
	local model, main = customTree("Tree_Pine", rng, scale)
	if model then
		return model, main
	end
	return partBuilt.pine(rng, scale)
end

function ModelFactory.birch(rng: Random, scale: number?): (Model, BasePart)
	local model, main = customTree("Tree_Birch", rng, scale)
	if model then
		return model, main
	end
	return partBuilt.birch(rng, scale)
end

function ModelFactory.boulder(rng: Random, scale: number?): (Model, BasePart)
	local model, main = customTree("Rock", rng, scale)
	if model then
		return model, main
	end
	return partBuilt.boulder(rng, scale)
end

function ModelFactory.node(kind: string, rng: Random): (Model, BasePart)
	if kind == "Bush" then
		local model, main = customTree("Bush", rng, 1)
		if model then
			return model, main
		end
	end
	return partBuilt.node(kind, rng)
end

function ModelFactory.dock(length: number): Model
	local custom = customAsset("Dock")
	if custom then
		return prepare(custom, true)
	end
	return partBuilt.dock(length)
end

function ModelFactory.deer(rng: Random): Model
	local custom = customAsset("Deer")
	if not custom then
		return partBuilt.deer(rng)
	end
	local model = prepare(custom, false)
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

function ModelFactory.tool(kind: string): Tool
	local custom = customAsset(kind)
	if custom and custom:IsA("Tool") then
		custom.Name = kind
		return custom
	end
	return partBuilt.tool(kind)
end

return ModelFactory
