--[[
	LandService
	Buying bigger land (Config.LandStages). The next stage costs resources and
	may need a rank. The plot's borders, the build grid and where trees and
	rocks can grow all follow colony.land.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local LandService = {}

local services

function LandService:Init(all)
	services = all
end

-- Why the next stage can't be bought yet, or nil if it can.
function LandService:Blocker(colony): string?
	local nextStage = Config.LandStages[(colony.land or 1) + 1]
	if not nextStage then
		return "Your land is as big as it can grow."
	end
	if nextStage.Rank and services.RankService:Rank(colony) < nextStage.Rank then
		return "Needs the rank of " .. Config.Ranks[nextStage.Rank].Name .. "."
	end
	if not services.ColonyService:CanAfford(colony, nextStage.Cost) then
		return "Needs " .. Grid.costText(nextStage.Cost) .. "."
	end
	return nil
end

function LandService:Buy(colony): (boolean, string)
	local why = self:Blocker(colony)
	if why then
		return false, why
	end
	local nextIndex = (colony.land or 1) + 1
	local stage = Config.LandStages[nextIndex]
	if not services.ColonyService:Spend(colony, stage.Cost) then
		return false, "You can't afford that."
	end
	colony.land = nextIndex
	services.PlotService:ApplyLand(colony)
	-- a few new trees and rocks grow on the new ground
	for _ = 1, 4 do
		services.ResourceNodeService:Tick(colony, Config.NodeRegrowInterval)
	end
	colony.gridDirty = true
	services.ColonyService:Notify(colony, "Your land grows: " .. stage.Name .. "! New ground marked by the border stakes.", "good")
	services.ColonyService:Sync(colony)
	return true, "Bought " .. stage.Name
end

function LandService:State(colony)
	local i = colony.land or 1
	local nextStage = Config.LandStages[i + 1]
	local minX, _, maxX, maxZ = Grid.bounds(i)
	return {
		index = i,
		name = Config.LandStages[i].Name,
		size = (maxX - minX) .. " x " .. maxZ,
		nextName = nextStage and nextStage.Name,
		nextCost = nextStage and nextStage.Cost,
		nextRank = nextStage and nextStage.Rank and Config.Ranks[nextStage.Rank].Name,
		nextSize = nextStage and ((nextStage.MaxX - nextStage.MinX) .. " x " .. nextStage.MaxZ),
		blocker = self:Blocker(colony),
	}
end

return LandService
