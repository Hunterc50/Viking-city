--[[
	BuildingService
	Validates and performs building placement and demolition requested by
	clients. The server always re-checks everything (cost, bounds, overlap)
	because clients can't be trusted.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local BuildingService = {}

local services

function BuildingService:Init(allServices)
	services = allServices
end

-- Construction effect: the building rises out of the ground in a puff of dust.
local function raiseUp(model: Model, finalCFrame: CFrame)
	local _, size = model:GetBoundingBox()
	local depth = size.Y + 1
	local dust = Instance.new("Part")
	dust.Anchored = true
	dust.CanCollide = false
	dust.CanQuery = false
	dust.Transparency = 1
	dust.Size = Vector3.new(size.X, 1, size.Z)
	dust.CFrame = finalCFrame
	dust.Parent = model.Parent
	local puff = Instance.new("Smoke")
	puff.Color = Color3.fromRGB(150, 130, 100)
	puff.Opacity = 0.25
	puff.RiseVelocity = 2
	puff.Size = math.max(size.X, size.Z) / 3
	puff.Parent = dust
	task.spawn(function()
		local duration = 1.2
		local start = os.clock()
		while model.Parent do
			local t = math.min((os.clock() - start) / duration, 1)
			local e = 1 - (1 - t) ^ 3 -- ease out
			model:PivotTo(finalCFrame * CFrame.new(0, -depth * (1 - e), 0))
			if t >= 1 then
				break
			end
			task.wait()
		end
		puff.Enabled = false
		task.wait(2)
		dust:Destroy()
	end)
end

-- Creates the building without any checks or cost. Returns the building record.
function BuildingService:Create(colony, buildingType: string, cx: number, cz: number, rot: number, animate: boolean?)
	local ColonyService = services.ColonyService
	local sx, sz = Grid.footprint(buildingType, rot)
	local id = ColonyService:NewId(colony)

	local model = ModelFactory.building(buildingType)
	model.Name = buildingType .. "_" .. id
	model:SetAttribute("BuildingId", id)
	model:SetAttribute("BuildingType", buildingType)
	model:SetAttribute("OwnerUserId", colony.player.UserId)
	local finalCFrame = Grid.buildingCFrame(colony.origin, cx, cz, sx, sz, rot)
	model:PivotTo(finalCFrame)
	services.SeasonService:ApplyTo(model) -- e.g. snow on the roof in winter
	model.Parent = colony.plot.Buildings
	if animate then
		raiseUp(model, finalCFrame)
	end

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
	if def.Rank and services.RankService:Rank(colony) < def.Rank then
		return false, "Become a " .. Config.Ranks[def.Rank].Name .. " first (grow your village)"
	end
	if def.Requires and not ColonyService:Has(colony, def.Requires) then
		return false, "Research " .. Config.Tech[def.Requires].Name .. " first (press T)"
	end
	local sx, sz = Grid.footprint(buildingType, rot)
	local ok, reason = Grid.canPlace(colony.blocked, cx, cz, sx, sz, colony.land)
	if not ok then
		return false, reason
	end
	if not ColonyService:Spend(colony, def.Cost) then
		return false, "Not enough resources (" .. Grid.costText(def.Cost) .. ")"
	end

	local building = self:Create(colony, buildingType, cx, cz, rot, true)
	Sounds.play("Build", building.center)
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
