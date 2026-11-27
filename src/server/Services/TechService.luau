--[[
	TechService
	Research. Players spend Lore (made in a Lore Hall) and sometimes other
	resources to unlock techs from Config.Tech. Some techs need a building
	(Smithy, Shipyard, Shrine) or other techs first, and patron paths are
	exclusive: a settlement follows only one.

	Effects are read where they matter through ColonyService:Has(colony, id).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)

local TechService = {}

local services

function TechService:Init(allServices)
	services = allServices
end

-- Returns ok, reason for whether `colony` can research `id` right now.
function TechService:CanResearch(colony, id: string): (boolean, string?)
	local tech = Config.Tech[id]
	if not tech then
		return false, "Unknown research"
	end
	local ColonyService = services.ColonyService
	if colony.tech[id] then
		return false, "Already known"
	end
	for _, req in tech.Requires or {} do
		if not colony.tech[req] then
			return false, "Needs " .. Config.Tech[req].Name
		end
	end
	if tech.Building and not ColonyService:HasBuilding(colony, tech.Building) then
		return false, "Build a " .. Config.Buildings[tech.Building].Display .. " first"
	end
	if tech.Group then
		for known in colony.tech do
			if Config.Tech[known].Group == tech.Group then
				return false, "You already follow " .. Config.Tech[known].Name
			end
		end
	end
	if not Grid.canAfford(colony.resources, tech.Cost) then
		return false, "Needs " .. Grid.costText(tech.Cost)
	end
	return true, nil
end

function TechService:Research(player: Player, id)
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony or typeof(id) ~= "string" then
		return false, "Not ready"
	end
	local ok, reason = self:CanResearch(colony, id)
	if not ok then
		return false, reason
	end
	ColonyService:Spend(colony, Config.Tech[id].Cost)
	colony.tech[id] = true
	if id == "ChainMail" or id == "IronAxes" or id == "SteelEdges" then
		services.ToolService:ApplyArmor(player)
	end
	ColonyService:Notify(colony, "Researched " .. Config.Tech[id].Name .. "! " .. Config.Tech[id].Description, "good")
	ColonyService:Sync(colony)
	return true, Config.Tech[id].Name .. " researched"
end

function TechService:Start()
	Remotes.Research.OnServerInvoke = function(player, id)
		return self:Research(player, id)
	end
end

return TechService
