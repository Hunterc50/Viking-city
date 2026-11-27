--[[
	QuestService
	The saga: Config.Quests is a chain of goals that walks a new player
	through the game (chop, farm, hunt, build, research, raid, sail...).
	One goal is active at a time; finishing it pays its reward and opens
	the next. Progress is sent to the HUD with the colony snapshot and
	saved with the village.

	Other services report things the player did with
	QuestService:Count(colony, "chop" | "mine" | "deer" | "plunder" | ...).
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local QuestService = {}

local services

function QuestService:Init(allServices)
	services = allServices
end

function QuestService:Count(colony, stat: string, amount: number?)
	if not colony then
		return
	end
	colony.stats = colony.stats or {}
	colony.stats[stat] = (colony.stats[stat] or 0) + (amount or 1)
	self:Check(colony)
end

local function progress(colony, quest): number
	if quest.Kind == "stat" then
		-- things you did before the goal opened count too
		return colony.stats and colony.stats[quest.Stat] or 0
	elseif quest.Kind == "building" then
		local n = 0
		for _, b in colony.buildings do
			if b.type == quest.Building then
				n += 1
			end
		end
		return n
	elseif quest.Kind == "population" then
		local n = 0
		for _ in colony.villagers do
			n += 1
		end
		return n
	elseif quest.Kind == "tech" then
		local n = 0
		for _ in colony.tech do
			n += 1
		end
		return n
	end
	return 0
end

function QuestService:Check(colony)
	colony.quest = colony.quest or 1
	local quest = Config.Quests[colony.quest]
	if not quest then
		return
	end
	if progress(colony, quest) >= quest.Goal then
		local ColonyService = services.ColonyService
		for res, amount in quest.Reward or {} do
			ColonyService:Add(colony, res, amount)
		end
		ColonyService:Notify(colony, "Saga: \"" .. quest.Title .. "\" done! +" .. Grid.costText(quest.Reward or {}), "quest")
		colony.quest += 1
		self:Check(colony) -- the next one may already be done
	end
end

-- What the HUD shows.
function QuestService:State(colony)
	local index = colony.quest or 1
	local quest = Config.Quests[index]
	if not quest then
		return { done = true, index = index, total = #Config.Quests }
	end
	return {
		index = index,
		total = #Config.Quests,
		title = quest.Title,
		text = quest.Text,
		have = math.min(progress(colony, quest), quest.Goal),
		goal = quest.Goal,
		reward = Grid.costText(quest.Reward or {}),
	}
end

function QuestService:Start()
	-- buildings, population and research are checked once a second
	while true do
		task.wait(1)
		for _, colony in services.ColonyService:All() do
			self:Check(colony)
		end
	end
end

return QuestService
