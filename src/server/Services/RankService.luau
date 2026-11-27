--[[
	RankService
	Your title: Settler -> Chieftain -> Hersir -> Jarl -> King (Config.Ranks).
	You rise as soon as your village meets the next rank's needs (people,
	buildings, research). Each rank raises the population cap and unlocks
	bigger buildings (Config.Buildings[...].Rank).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local RankService = {}

local services

function RankService:Init(allServices)
	services = allServices
end

local function counts(colony)
	local pop, buildings, tech = 0, 0, 0
	for _ in colony.villagers do
		pop += 1
	end
	for _, b in colony.buildings do
		if b.type ~= "Palisade" then
			buildings += 1
		end
	end
	for _ in colony.tech do
		tech += 1
	end
	return { Population = pop, Buildings = buildings, Tech = tech }
end

function RankService:Rank(colony): number
	return colony.rank or 1
end

function RankService:PopCap(colony): number
	return Config.Ranks[self:Rank(colony)].PopCap
end

-- What the HUD shows about your rank and the next one.
function RankService:State(colony)
	local r = self:Rank(colony)
	local nextRank = Config.Ranks[r + 1]
	local state = { index = r, name = Config.Ranks[r].Name, cap = Config.Ranks[r].PopCap }
	if nextRank then
		local have = counts(colony)
		local bits = {}
		for _, key in { "Population", "Buildings", "Tech" } do
			local need = nextRank.Needs[key]
			if need then
				local word = ({ Population = "people", Buildings = "buildings", Tech = "research" })[key]
				table.insert(bits, math.min(have[key], need) .. "/" .. need .. " " .. word)
			end
		end
		state.nextName = nextRank.Name
		state.nextText = table.concat(bits, ", ")
	end
	return state
end

function RankService:Check(colony)
	local r = self:Rank(colony)
	local nextRank = Config.Ranks[r + 1]
	if not nextRank then
		return
	end
	local have = counts(colony)
	for key, need in nextRank.Needs do
		if (have[key] or 0) < need then
			return
		end
	end
	colony.rank = r + 1
	for res, n in nextRank.Reward or {} do
		services.ColonyService:Add(colony, res, n)
	end
	local unlocked = {}
	for _, id in Config.BuildOrder do
		if Config.Buildings[id].Rank == colony.rank then
			table.insert(unlocked, Config.Buildings[id].Display)
		end
	end
	local extra = #unlocked > 0 and (" Unlocked: " .. table.concat(unlocked, ", ") .. ".") or ""
	services.ColonyService:Notify(colony, "You are now " .. nextRank.Name .. "!", "raid")
	services.ColonyService:Notify(colony, "Room for " .. nextRank.PopCap .. " people. +" .. Grid.costText(nextRank.Reward or {}) .. "." .. extra, "good")
	self:Check(colony)
end

function RankService:Start()
	while true do
		task.wait(2)
		for _, colony in services.ColonyService:All() do
			self:Check(colony)
		end
	end
end

return RankService
