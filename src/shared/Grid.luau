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

function Grid.inBounds(cx: number, cz: number, sx: number, sz: number): boolean
	return cx >= 0 and cz >= 0 and cx + sx <= N and cz + sz <= N
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
function Grid.canPlace(blocked, cx: number, cz: number, sx: number, sz: number): (boolean, string?)
	if not Grid.inBounds(cx, cz, sx, sz) then
		return false, "Outside your land"
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
