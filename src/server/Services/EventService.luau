--[[
	EventService
	Small happenings that keep a village's life going: a skald visits, a
	great catch of herring, wolves at the stores, amber on the beach, a family
	asking to settle, a rich harvest, storm damage. Every few minutes one
	event that fits the season and your village happens, with a message.
	What you have built changes how some of them go: a Watchtower drives the
	wolves off, a Storehouse keeps the rats out.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Grid = require(Shared.Grid)

local EventService = {}

local services
local rng = Random.new()

local FIRST = 180 -- seconds after joining before the first event
local MIN_GAP, MAX_GAP = 240, 420

function EventService:Init(all)
	services = all
end

local function population(colony): number
	local n = 0
	for _ in colony.villagers do
		n += 1
	end
	return n
end

local function season(): string
	return workspace:GetAttribute("Season") or "Summer"
end

local function gain(colony, loot)
	for res, n in loot do
		services.ColonyService:Add(colony, res, n)
	end
	return Grid.costText(loot)
end

local function lose(colony, res: string, share: number): number
	local have = colony.resources[res] or 0
	local n = math.floor(have * share)
	if n > 0 then
		colony.resources[res] = have - n
	end
	return n
end

-- Each event: when it can happen (weight 0 = not now) and what it does.
local EVENTS = {
	{
		name = "Skald",
		weight = function()
			return 1
		end,
		run = function(colony)
			colony.happiness = math.min(100, (colony.happiness or 60) + 8)
			local text = gain(colony, { Lore = 12 })
			return "A wandering skald sings of old heroes in your hall. Your people are cheered (+" .. text .. ").", "good"
		end,
	},
	{
		name = "Herring",
		weight = function()
			return season() == "Winter" and 0.3 or 1
		end,
		run = function(colony)
			local text = gain(colony, { Food = 15 + population(colony) * 3 })
			return "The herring are running! Your people haul in nets full of fish (+" .. text .. ").", "good"
		end,
	},
	{
		name = "Wolves",
		weight = function(colony)
			return (season() == "Winter" and 1.6 or 0.6) * ((colony.resources.Food or 0) > 30 and 1 or 0)
		end,
		run = function(colony)
			if services.ColonyService:HasBuilding(colony, "Watchtower") then
				local text = gain(colony, { Hides = 6 })
				return "Wolves crept toward your stores, but your watchmen saw them and drove them off (+" .. text .. ").", "good"
			end
			local n = lose(colony, "Food", 0.15)
			return "Wolves got into your stores in the night and took " .. n .. " Food. A Watchtower would keep watch.", "bad"
		end,
	},
	{
		name = "Amber",
		weight = function()
			return season() == "Winter" and 0.4 or 0.8
		end,
		run = function(colony)
			local text = gain(colony, { Silver = rng:NextInteger(6, 12) })
			return "A storm tide washed amber up on your beach. Traders pay well for it (+" .. text .. ").", "good"
		end,
	},
	{
		name = "Newcomers",
		weight = function(colony)
			local free = services.ColonyService:Housing(colony) - population(colony)
			local cap = services.RankService:PopCap(colony) - population(colony)
			return (free >= 2 and cap >= 2) and 1.2 or 0
		end,
		run = function(colony)
			local VillagerService = services.VillagerService
			local a = VillagerService:Add(colony, false)
			local b = VillagerService:Add(colony, false)
			return a.name .. " and " .. b.name .. " left a feuding jarl in the south and ask to live under your roof. You take them in.", "good"
		end,
	},
	{
		name = "Harvest",
		weight = function(colony)
			return (season() == "Autumn" and services.ColonyService:HasBuilding(colony, "Farm")) and 1.5 or 0
		end,
		run = function(colony)
			local text = gain(colony, { Food = 30 + population(colony) * 2 })
			return "A rich harvest! The barley stands tall and heavy this year (+" .. text .. ").", "good"
		end,
	},
	{
		name = "Rats",
		weight = function(colony)
			return ((colony.resources.Food or 0) > 60 and not services.ColonyService:HasBuilding(colony, "Storehouse")) and 0.7 or 0
		end,
		run = function(colony)
			local n = lose(colony, "Food", 0.1)
			return "Rats got into the grain and spoiled " .. n .. " Food. A Storehouse keeps them out.", "bad"
		end,
	},
	{
		name = "StormDamage",
		weight = function(colony)
			return ((workspace:GetAttribute("StormLevel") or 0) > 0.3 and (colony.resources.Wood or 0) > 20) and 2 or 0
		end,
		run = function(colony)
			local n = lose(colony, "Wood", 0.12)
			return "The storm tore at your roofs. Repairs took " .. n .. " Wood.", "bad"
		end,
	},
}

local function pick(colony)
	local total = 0
	local weights = {}
	for i, e in EVENTS do
		local ok, w = pcall(e.weight, colony)
		w = ok and w or 0
		weights[i] = w
		total += w
	end
	if total <= 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	for i, e in EVENTS do
		r -= weights[i]
		if r <= 0 then
			return e
		end
	end
	return nil
end

function EventService:Start()
	local nextAt = {}
	Players.PlayerRemoving:Connect(function(player)
		nextAt[player] = nil
	end)
	while true do
		task.wait(5)
		local now = os.clock()
		for _, colony in services.ColonyService:All() do
			local player = colony.player
			if not nextAt[player] then
				nextAt[player] = now + FIRST
			elseif now >= nextAt[player] then
				nextAt[player] = now + rng:NextNumber(MIN_GAP, MAX_GAP)
				local event = pick(colony)
				if event then
					local ok, text, kind = pcall(event.run, colony)
					if ok and text then
						services.ColonyService:Notify(colony, text, kind)
						services.ColonyService:Sync(colony)
					elseif not ok then
						warn("[EventService] " .. event.name .. ": " .. tostring(text))
					end
				end
			end
		end
	end
end

return EventService
