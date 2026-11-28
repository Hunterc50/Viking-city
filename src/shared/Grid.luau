--[[
	Grid
	Pure math helpers for the building grid. Cells are addressed by integer
	(x, z) starting at 0 in the plot's corner. A building is placed by its
	minimum corner cell plus a rotation (0 = default, 1 = turned 90 degrees).
]]

local Config = require(script.Parent.Config)

local Grid = {}

local CELL = Config.CELL
local N = Config.PLOT_CELLS

Grid.PLOT_SIZE = CELL * N

function Grid.key(x: number, z: number): string
	return x .. "," .. z
end

-- World-space corner (min x, min z, ground top) of plot number `index` (1-based).
function Grid.plotOrigin(index: number): Vector3
	return Vector3.new((index - 1) * (Grid.PLOT_SIZE + Config.PLOT_GAP), Config.GROUND_Y, 0)
end

-- Footprint in cells after rotation.
function Grid.footprint(buildingType: string, rot: number): (number, number)
	local def = Config.Buildings[buildingType]
	local sx, sz = def.Size[1], def.Size[2]
	if rot % 2 == 1 then
		return sz, sx
	end
	return sx, sz
end

-- The cell bounds of a plot at land stage `land` (1 = starting size):
-- minX, minZ, maxX, maxZ, with max exclusive. Cells may be negative
-- (minZ < 0 is the beach in front of the plot).
function Grid.bounds(land: number?): (number, number, number, number)
	local stage = Config.LandStages[land or 1] or Config.LandStages[1]
	return stage.MinX, stage.MinZ or 0, stage.MaxX, stage.MaxZ
end

-- The world-space box of the land: min corner and size (studs).
function Grid.landRect(origin: Vector3, land: number?): (Vector3, Vector3)
	local minX, minZ, maxX, maxZ = Grid.bounds(land)
	return origin + Vector3.new(minX * CELL, 0, minZ * CELL), Vector3.new((maxX - minX) * CELL, 0, (maxZ - minZ) * CELL)
end

-- The largest the land can ever grow (used to keep scenery off it).
function Grid.maxBounds(): (number, number, number, number)
	local a, b, c, d = 0, 0, N, N
	for _, stage in Config.LandStages do
		a, b = math.min(a, stage.MinX), math.min(b, stage.MinZ or 0)
		c, d = math.max(c, stage.MaxX), math.max(d, stage.MaxZ)
	end
	return a, b, c, d
end

function Grid.inBounds(cx: number, cz: number, sx: number, sz: number, land: number?): boolean
	local minX, minZ, maxX, maxZ = Grid.bounds(land)
	return cx >= minX and cz >= minZ and cx + sx <= maxX and cz + sz <= maxZ
end

-- Calls fn(x, z) for every cell covered by the rectangle.
function Grid.eachCell(cx: number, cz: number, sx: number, sz: number, fn: (number, number) -> ())
	for x = cx, cx + sx - 1 do
		for z = cz, cz + sz - 1 do
			fn(x, z)
		end
	end
end

-- `blocked` is a set: { ["x,z"] = true/anything }.
-- `buildingType` (optional) adds that building's own rules, like a jetty's
-- place at the water's edge.
function Grid.canPlace(blocked, cx: number, cz: number, sx: number, sz: number, land: number?, buildingType: string?): (boolean, string?)
	if not Grid.inBounds(cx, cz, sx, sz, land) then
		return false, "Outside your land"
	end
	local def = buildingType and Config.Buildings[buildingType]
	if def and def.Shore then
		local _, minZ = Grid.bounds(land)
		if cz ~= minZ then
			return false, "A jetty goes on the front row of your beach, by the water"
		end
	end
	local free = true
	Grid.eachCell(cx, cz, sx, sz, function(x, z)
		if blocked[Grid.key(x, z)] then
			free = false
		end
	end)
	if not free then
		return false, "Something is in the way (clear trees and rocks first)"
	end
	return true, nil
end

-- World position of the centre of a rectangle of cells, at ground level.
function Grid.rectCenter(origin: Vector3, cx: number, cz: number, sx: number, sz: number): Vector3
	return origin + Vector3.new((cx + sx / 2) * CELL, 0, (cz + sz / 2) * CELL)
end

-- The CFrame a building model should be pivoted to.
function Grid.buildingCFrame(origin: Vector3, cx: number, cz: number, sx: number, sz: number, rot: number): CFrame
	return CFrame.new(Grid.rectCenter(origin, cx, cz, sx, sz)) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

-- Converts a world point to the min-corner cell of a footprint centred on it.
function Grid.worldToCell(origin: Vector3, pos: Vector3, sx: number, sz: number): (number, number)
	local local_ = pos - origin
	local cx = math.floor(local_.X / CELL - sx / 2 + 0.5)
	local cz = math.floor(local_.Z / CELL - sz / 2 + 0.5)
	return cx, cz
end

function Grid.canAfford(resources, cost): boolean
	for name, amount in cost do
		if (resources[name] or 0) < amount then
			return false
		end
	end
	return true
end

function Grid.costText(cost): string
	local parts = {}
	for _, name in Config.ResourceOrder do
		if cost[name] then
			table.insert(parts, cost[name] .. " " .. name)
		end
	end
	return table.concat(parts, "  ")
end

return Grid
