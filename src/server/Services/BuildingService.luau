--[[
	BuildingService
	Validates and performs building placement and demolition requested by
	clients. The server always re-checks everything (cost, bounds, overlap)
	because clients can't be trusted.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local BuildingService = {}

local services

function BuildingService:Init(allServices)
	services = allServices
end

-- Creates the building without any checks or cost. Returns the building record.
function BuildingService:Create(colony, buildingType: string, cx: number, cz: number, rot: number)
	local ColonyService = services.ColonyService
	local sx, sz = Grid.footprint(buildingType, rot)
	local id = ColonyService:NewId(colony)

	local model = ModelFactory.building(buildingType)
	model.Name = buildingType .. "_" .. id
	model:SetAttribute("BuildingId", id)
	model:SetAttribute("BuildingType", buildingType)
	model:SetAttribute("OwnerUserId", colony.player.UserId)
	model:PivotTo(Grid.buildingCFrame(colony.origin, cx, cz, sx, sz, rot))
	model.Parent = colony.plot.Buildings

	local building = {
		id = id,
		type = buildingType,
		cx = cx,
		cz = cz,
		rot = rot,
		sx = sx,
		sz = sz,
		model = model,
		center = Grid.rectCenter(colony.origin, cx, cz, sx, sz),
	}
	colony.buildings[id] = building

	Grid.eachCell(cx, cz, sx, sz, function(x, z)
		ColonyService:Block(colony, x, z, "building")
	end)
	return building
end

function BuildingService:PlaceStarting(colony)
	local sx, sz = Grid.footprint("Longhouse", 0)
	local cx = math.floor((Config.PLOT_CELLS - sx) / 2)
	local cz = math.floor((Config.PLOT_CELLS - sz) / 2)
	self:Create(colony, "Longhouse", cx, cz, 0)
end

function BuildingService:TryPlace(player: Player, buildingType, cx, cz, rot)
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony then
		return false, "Your colony isn't ready yet"
	end
	-- Validate the types of everything the client sent.
	if typeof(buildingType) ~= "string" or not Config.Buildings[buildingType] then
		return false, "Unknown building"
	end
	if typeof(cx) ~= "number" or typeof(cz) ~= "number" or typeof(rot) ~= "number" then
		return false, "Bad position"
	end
	cx, cz, rot = math.floor(cx), math.floor(cz), math.floor(rot) % 4
	if rot ~= rot or cx ~= cx or cz ~= cz then -- NaN / infinity guard
		return false, "Bad position"
	end

	local def = Config.Buildings[buildingType]
	local sx, sz = Grid.footprint(buildingType, rot)
	local ok, reason = Grid.canPlace(colony.blocked, cx, cz, sx, sz)
	if not ok then
		return false, reason
	end
	if not ColonyService:Spend(colony, def.Cost) then
		return false, "Not enough resources (" .. Grid.costText(def.Cost) .. ")"
	end

	self:Create(colony, buildingType, cx, cz, rot)
	ColonyService:Sync(colony)
	return true, def.Display .. " built"
end

function BuildingService:TryDemolish(player: Player, id)
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony or typeof(id) ~= "number" then
		return false, "Nothing to demolish"
	end
	local building = colony.buildings[id]
	if not building then
		return false, "That isn't yours"
	end
	local def = Config.Buildings[building.type]
	if def.Housing then
		local homes = 0
		for _, b in colony.buildings do
			if Config.Buildings[b.type].Housing then
				homes += 1
			end
		end
		if homes <= 1 then
			return false, "You can't tear down your last home"
		end
	end

	colony.buildings[id] = nil
	building.model:Destroy()
	Grid.eachCell(building.cx, building.cz, building.sx, building.sz, function(x, z)
		ColonyService:Unblock(colony, x, z)
	end)
	for name, amount in def.Cost do
		ColonyService:Add(colony, name, math.floor(amount * Config.DemolishRefund))
	end
	services.VillagerService:OnBuildingRemoved(colony, id)
	ColonyService:Sync(colony)
	return true, def.Display .. " demolished"
end

function BuildingService:Start()
	Remotes.PlaceBuilding.OnServerInvoke = function(player, buildingType, cx, cz, rot)
		return self:TryPlace(player, buildingType, cx, cz, rot)
	end
	Remotes.DemolishBuilding.OnServerInvoke = function(player, id)
		return self:TryDemolish(player, id)
	end
end

return BuildingService
