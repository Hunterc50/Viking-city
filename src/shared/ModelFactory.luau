--[[
	ModelFactory
	Builds simple placeholder models out of Parts so the game is playable with
	no imported assets. Every model is built around (0, 0, 0) = centre of its
	footprint at ground level, and its WorldPivot is set there, so callers just
	do model:PivotTo(cframe).

	Later you can swap any of these for real meshes made in Studio or Blender:
	put a model in ReplicatedStorage and clone it here instead.
]]

local Config = require(script.Parent.Config)

local ModelFactory = {}

local CELL = Config.CELL

local Colors = {
	Wood = Color3.fromRGB(122, 84, 52),
	DarkWood = Color3.fromRGB(78, 54, 36),
	Thatch = Color3.fromRGB(178, 150, 92),
	Turf = Color3.fromRGB(92, 120, 64),
	Stone = Color3.fromRGB(128, 128, 132),
	Soil = Color3.fromRGB(96, 68, 44),
	Barley = Color3.fromRGB(214, 188, 96),
	Leaf = Color3.fromRGB(46, 92, 52),
	LeafLight = Color3.fromRGB(64, 116, 64),
	Berry = Color3.fromRGB(170, 34, 46),
	Skin = Color3.fromRGB(234, 196, 160),
}
ModelFactory.Colors = Colors

local Tunics = {
	Color3.fromRGB(150, 60, 50),
	Color3.fromRGB(60, 90, 140),
	Color3.fromRGB(90, 120, 70),
	Color3.fromRGB(170, 140, 80),
	Color3.fromRGB(110, 80, 120),
	Color3.fromRGB(120, 110, 100),
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
	p.Parent = model
	return p
end

-- A walled hut with a pitched roof whose ridge runs along local X.
local function hut(model, cf: CFrame, w: number, d: number, wallH: number, roofColor: Color3, roofMaterial)
	local wallTop = 0.6 + wallH
	addPart(model, {
		Size = Vector3.new(w + 1, 0.6, d + 1),
		CFrame = cf * CFrame.new(0, 0.3, 0),
		Color = Colors.DarkWood,
	})
	addPart(model, {
		Name = "Walls",
		Size = Vector3.new(w, wallH, d),
		CFrame = cf * CFrame.new(0, 0.6 + wallH / 2, 0),
		Color = Colors.Wood,
		Material = Enum.Material.WoodPlanks,
	})

	local angle = math.rad(35)
	local halfD = d / 2 + 1.2
	local rise = halfD * math.tan(angle)
	local slope = halfD / math.cos(angle) + 0.6
	for _, side in { 1, -1 } do
		addPart(model, {
			Name = "Roof",
			Size = Vector3.new(w + 2, 0.6, slope),
			CFrame = cf * CFrame.new(0, wallTop + rise / 2, side * halfD / 2) * CFrame.Angles(side * angle, 0, 0),
			Color = roofColor,
			Material = roofMaterial or Enum.Material.Grass,
		})
	end
	addPart(model, {
		Name = "Ridge",
		Size = Vector3.new(w + 2.6, 0.8, 0.8),
		CFrame = cf * CFrame.new(0, wallTop + rise + 0.1, 0),
		Color = Colors.DarkWood,
	})
	addPart(model, {
		Name = "Door",
		Size = Vector3.new(2.6, 4.5, 0.3),
		CFrame = cf * CFrame.new(0, 0.6 + 2.25, -d / 2 - 0.15),
		Color = Colors.DarkWood,
	})
end

local function logPile(model, cf: CFrame)
	for i, offset in { Vector3.new(0, 0.6, -1.3), Vector3.new(0, 0.6, 0), Vector3.new(0, 0.6, 1.3), Vector3.new(0, 1.7, -0.65), Vector3.new(0, 1.7, 0.65) } do
		addPart(model, {
			Name = "Log" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6, 1.2, 1.2),
			CFrame = cf * CFrame.new(offset),
			Color = Colors.Wood,
		})
	end
end

local Builders = {}

function Builders.Longhouse(model, w, d)
	hut(model, CFrame.new(), w - 3, d - 4, 7, Colors.Turf, Enum.Material.Grass)
	-- carved posts at the corners
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(model, {
				Size = Vector3.new(1, 9, 1),
				Position = Vector3.new(x * (w - 3) / 2, 4.5, z * (d - 4) / 2),
				Color = Colors.DarkWood,
			})
		end
	end
end

function Builders.Woodcutter(model, w, d)
	hut(model, CFrame.new(-2.5, 0, 2), 8, 7, 5, Colors.Thatch, Enum.Material.Fabric)
	logPile(model, CFrame.new(3, 0, -4))
	addPart(model, {
		Name = "Stump",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.4, 2, 2),
		CFrame = CFrame.new(4.5, 0.7, 3) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Colors.Wood,
	})
end

function Builders.Quarry(model, w, d)
	addPart(model, {
		Size = Vector3.new(w - 1, 0.4, d - 1),
		Position = Vector3.new(0, 0.2, 0),
		Color = Colors.Stone,
		Material = Enum.Material.Slate,
	})
	local blocks = {
		{ Vector3.new(-3, 1.5, -3), Vector3.new(4, 2.6, 3) },
		{ Vector3.new(3, 1.2, -2), Vector3.new(3, 2, 3) },
		{ Vector3.new(-2, 2.2, 3), Vector3.new(5, 4, 4) },
		{ Vector3.new(4, 0.9, 4), Vector3.new(2, 1.4, 2) },
	}
	for _, b in blocks do
		addPart(model, { Size = b[2], Position = b[1], Color = Colors.Stone, Material = Enum.Material.Slate })
	end
	-- a simple wooden lifting frame
	addPart(model, { Size = Vector3.new(0.6, 7, 0.6), Position = Vector3.new(5.5, 3.5, -5.5), Color = Colors.DarkWood })
	addPart(model, { Size = Vector3.new(0.6, 0.6, 6), Position = Vector3.new(5.5, 7, -3), Color = Colors.DarkWood })
end

function Builders.Farm(model, w, d)
	addPart(model, {
		Size = Vector3.new(w - 1, 0.3, d - 1),
		Position = Vector3.new(0, 0.15, 0),
		Color = Colors.Soil,
		Material = Enum.Material.Ground,
	})
	local rows = 6
	for i = 1, rows do
		local z = -d / 2 + 2 + (i - 1) * ((d - 4) / (rows - 1))
		addPart(model, {
			Name = "Barley",
			Size = Vector3.new(w - 4, 1.4, 1.6),
			Position = Vector3.new(0, 1, z),
			Color = Colors.Barley,
			Material = Enum.Material.Grass,
		})
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			addPart(model, {
				Size = Vector3.new(0.6, 2.5, 0.6),
				Position = Vector3.new(x * (w / 2 - 0.8), 1.25, z * (d / 2 - 0.8)),
				Color = Colors.DarkWood,
			})
		end
	end
end

function Builders.Storehouse(model, w, d)
	addPart(model, {
		Size = Vector3.new(w - 2, 1.2, d - 2),
		Position = Vector3.new(0, 0.6, 0),
		Color = Colors.Stone,
		Material = Enum.Material.Cobblestone,
	})
	-- the hut ridge runs along local X, so rotate it to run along the long Z side
	hut(model, CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.pi / 2, 0), d - 6, w - 5, 6, Colors.Thatch, Enum.Material.Fabric)
	for i, pos in { Vector3.new(-4, 2.2, -10.3), Vector3.new(-1.6, 2.2, -10.3), Vector3.new(4.5, 2.2, -10.3) } do
		addPart(model, {
			Name = "Crate" .. i,
			Size = Vector3.new(2, 2, 2),
			Position = pos,
			Color = Colors.Wood,
			Material = Enum.Material.WoodPlanks,
		})
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
		addPart(model, { Size = Vector3.new(w - 1, 4, d - 1), Position = Vector3.new(0, 2, 0) })
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
		end
	end
end

-- Wild resource nodes. Returns the model and the part the prompt goes on.
function ModelFactory.node(kind: string, rng: Random): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = kind
	local main
	if kind == "Tree" then
		local s = rng:NextNumber(0.85, 1.3)
		main = addPart(model, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(6 * s, 1.3 * s, 1.3 * s),
			CFrame = CFrame.new(0, 3 * s, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Colors.DarkWood,
		})
		addPart(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 6 * s,
			Position = Vector3.new(0, 7.5 * s, 0),
			Color = Colors.Leaf,
			Material = Enum.Material.Grass,
		})
		addPart(model, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 4.2 * s,
			Position = Vector3.new(0, 10.5 * s, 0),
			Color = Colors.LeafLight,
			Material = Enum.Material.Grass,
		})
	elseif kind == "Rock" then
		local size = Vector3.new(rng:NextNumber(3, 5.5), rng:NextNumber(2, 3.5), rng:NextNumber(3, 5.5))
		main = addPart(model, {
			Name = "Rock",
			Size = size,
			CFrame = CFrame.new(0, size.Y / 2 - 0.3, 0) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2)),
			Color = Colors.Stone,
			Material = Enum.Material.Slate,
		})
	else -- Bush
		main = addPart(model, {
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 3.6,
			Position = Vector3.new(0, 1.4, 0),
			Color = Colors.LeafLight,
			Material = Enum.Material.Grass,
		})
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			addPart(model, {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * 0.6,
				Position = Vector3.new(math.cos(a) * 1.5, 1.7 + (i % 2) * 0.5, math.sin(a) * 1.5),
				Color = Colors.Berry,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end
	model.WorldPivot = CFrame.new()
	return model, main
end

-- A tiny villager figure. The body is anchored and moved by the server;
-- the head is welded to it so it follows.
function ModelFactory.villager(name: string, isChild: boolean, rng: Random): Model
	local s = isChild and 0.65 or 1
	local model = Instance.new("Model")
	model.Name = name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.Size = Vector3.new(1.4, 2.2, 0.9) * s
	body.Color = Tunics[rng:NextInteger(1, #Tunics)]
	body.Material = Enum.Material.Fabric
	body.CFrame = CFrame.new(0, 1.1 * s, 0)
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Anchored = false
	head.CanCollide = false
	head.Massless = true
	head.Size = Vector3.one * 1.1 * s
	head.Color = Colors.Skin
	head.Material = Enum.Material.SmoothPlastic
	head.CFrame = body.CFrame * CFrame.new(0, 1.65 * s, 0)
	head.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = head
	weld.Parent = body

	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(120, 22)
	tag.StudsOffset = Vector3.new(0, 2.8 * s, 0)
	tag.MaxDistance = 60
	tag.AlwaysOnTop = false
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
	return model
end

return ModelFactory
