--[[
	DiplomacyService
	Each rival hold has a mood toward each village (Config.Diplomacy),
	from -100 (blood feud) to 100 (sworn allies). Instead of raiding them you can:
	  Gift      pay silver to warm their mood
	  Demand    a strong war band can force them to pay tribute for a few days
	  Ally      at a high mood: allied guards leave you alone, and allies never
	            send warbands against your village
	  Deal      at a friendly mood: a daily trade caravan swaps goods with you
	Attacking a hold (striking its guards, looting its chests, sending the war
	band) breaks any alliance, deal or tribute, and sours the mood.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local DiplomacyService = {}

local D = Config.Diplomacy
local services
local rng = Random.new()

function DiplomacyService:Init(all)
	services = all
end

local function holdNamed(name)
	if typeof(name) ~= "string" then
		return nil
	end
	for _, def in Config.Rivals do
		if def.Name == name then
			return def
		end
	end
	return nil
end

local function rel(colony, name: string)
	colony.relations = colony.relations or {}
	local r = colony.relations[name]
	if not r then
		r = { mood = 0, allied = false, deal = false, tributeDays = 0 }
		colony.relations[name] = r
	end
	return r
end

local function notify(colony, text, kind)
	services.ColonyService:Notify(colony, text, kind)
end

function DiplomacyService:IsAllied(colony, name: string): boolean
	local r = colony.relations and colony.relations[name]
	return r ~= nil and r.allied == true
end

-- Will this hold send warbands against the village? Not if allied or paying tribute.
function DiplomacyService:WillRaid(colony, name: string): boolean
	local r = colony.relations and colony.relations[name]
	if not r then
		return true
	end
	return not r.allied and (r.tributeDays or 0) <= 0 and r.mood < D.DealMood
end

-- Is the player at peace with this hold (its guards leave them alone)?
function DiplomacyService:IsAlliedPlayer(player: Player, name: string): boolean
	local colony = services.ColonyService:Get(player)
	return colony ~= nil and self:IsAllied(colony, name)
end

function DiplomacyService:OnHostile(colony, name: string)
	if not holdNamed(name) then
		return
	end
	local r = rel(colony, name)
	local was = r.allied or r.deal or r.tributeDays > 0
	r.allied = false
	r.deal = false
	r.tributeDays = 0
	r.mood = math.min(r.mood, D.AttackMood)
	if was then
		notify(colony, name .. " will remember this. Your pact with them is broken.", "bad")
	end
end

function DiplomacyService:Gift(colony, name: string): (boolean, string)
	local def = holdNamed(name)
	if not def then
		return false, "Pick a hold."
	end
	if not services.ColonyService:Spend(colony, D.GiftCost) then
		return false, "A fitting gift costs " .. Grid.costText(D.GiftCost) .. "."
	end
	local r = rel(colony, name)
	r.mood = math.min(100, r.mood + D.GiftGain)
	notify(colony, name .. " accepts your gift. (Mood " .. r.mood .. ")", "good")
	return true, "Gift sent"
end

function DiplomacyService:Demand(colony, name: string): (boolean, string)
	local def = holdNamed(name)
	if not def then
		return false, "Pick a hold."
	end
	local r = rel(colony, name)
	if r.allied then
		return false, "You don't demand tribute from an ally."
	end
	if r.tributeDays > 0 then
		return false, name .. " is already paying you tribute."
	end
	local Warband = services.WarbandService
	local ratio = Warband:Power(colony) / Warband:HoldPower(def)
	if ratio < D.DemandMinPower then
		return false, "Your war band is too weak to frighten them (" .. math.floor(ratio * 100) .. "% of what's needed: " .. math.floor(D.DemandMinPower * 100) .. "%)."
	end
	-- the stronger you are, the likelier they bend the knee
	if rng:NextNumber() < math.clamp(ratio * 0.8, 0.2, 0.9) then
		r.tributeDays = D.TributeDays
		r.mood = math.max(-100, r.mood - 15)
		notify(colony, name .. " bends the knee and will pay " .. Grid.costText(D.TributePerDay) .. " a day for " .. D.TributeDays .. " days.", "good")
		return true, "They pay"
	end
	r.mood = math.max(-100, r.mood - 30)
	-- an insult: they send a warband soon
	colony.nextRaidDay = math.min(colony.nextRaidDay or math.huge, colony.day + 1)
	notify(colony, name .. " laughs at your demand. Expect their warband!", "bad")
	return false, "They refused"
end

function DiplomacyService:Ally(colony, name: string): (boolean, string)
	local def = holdNamed(name)
	if not def then
		return false, "Pick a hold."
	end
	local r = rel(colony, name)
	if r.allied then
		return false, "Already allies."
	end
	if r.mood < D.AllianceMood then
		return false, name .. " needs a mood of " .. D.AllianceMood .. " to swear an alliance (now " .. r.mood .. "). Send gifts."
	end
	if not services.ColonyService:Spend(colony, D.AllianceCost) then
		return false, "The oath feast costs " .. Grid.costText(D.AllianceCost) .. "."
	end
	r.allied = true
	r.tributeDays = 0
	notify(colony, "You and " .. name .. " swear an alliance! Their guards are friends now and they will never raid you.", "good")
	services.QuestService:Count(colony, "ally")
	return true, "Allied"
end

function DiplomacyService:Deal(colony, name: string): (boolean, string)
	local def = holdNamed(name)
	local deal = def and D.Deals[name]
	if not deal then
		return false, "No trade with them."
	end
	local r = rel(colony, name)
	if r.deal then
		r.deal = false
		notify(colony, "You end the trade deal with " .. name .. ".", "info")
		return true, "Deal ended"
	end
	if r.mood < D.DealMood and not r.allied then
		return false, name .. " needs a mood of " .. D.DealMood .. " to trade (now " .. r.mood .. ")."
	end
	r.deal = true
	notify(colony, "Trade deal with " .. name .. ": each day you send " .. Grid.costText(deal.Give) .. " and get " .. Grid.costText(deal.Get) .. ".", "good")
	return true, "Deal made"
end

-- Once a day: caravans, tribute, and moods drifting back toward 0.
local function newDay(colony)
	local ColonyService = services.ColonyService
	for _, def in Config.Rivals do
		local r = colony.relations and colony.relations[def.Name]
		if r then
			if r.deal then
				local deal = D.Deals[def.Name]
				if deal and ColonyService:Spend(colony, deal.Give) then
					for res, n in deal.Get do
						ColonyService:Add(colony, res, n)
					end
					notify(colony, def.Name .. "'s caravan: +" .. Grid.costText(deal.Get), "gain")
				elseif deal then
					notify(colony, "You couldn't pay " .. def.Name .. "'s caravan (" .. Grid.costText(deal.Give) .. ").", "bad")
				end
			end
			if r.tributeDays > 0 then
				r.tributeDays -= 1
				for res, n in D.TributePerDay do
					ColonyService:Add(colony, res, n)
				end
				notify(colony, def.Name .. " pays tribute: +" .. Grid.costText(D.TributePerDay), "gain")
			end
			if not r.allied then
				if r.mood > 0 then
					r.mood = math.max(0, r.mood - D.DriftPerDay)
				elseif r.mood < 0 then
					r.mood = math.min(0, r.mood + D.DriftPerDay)
				end
			end
		end
	end
end

function DiplomacyService:State(colony)
	local list = {}
	local Warband = services.WarbandService
	local power = Warband:Power(colony)
	for _, def in Config.Rivals do
		local r = (colony.relations and colony.relations[def.Name]) or { mood = 0, allied = false, deal = false, tributeDays = 0 }
		local deal = D.Deals[def.Name]
		table.insert(list, {
			name = def.Name,
			mood = r.mood,
			allied = r.allied,
			deal = r.deal,
			tributeDays = r.tributeDays,
			dealText = deal and ("Send " .. Grid.costText(deal.Give) .. ", get " .. Grid.costText(deal.Get) .. " each day") or nil,
			fear = math.floor(power / Warband:HoldPower(def) * 100),
		})
	end
	return {
		holds = list,
		giftCost = D.GiftCost,
		allianceCost = D.AllianceCost,
		allianceMood = D.AllianceMood,
		dealMood = D.DealMood,
		demandNeed = math.floor(D.DemandMinPower * 100),
	}
end

function DiplomacyService:Start()
	while true do
		task.wait(1)
		for _, colony in services.ColonyService:All() do
			if colony.dipDay == nil then
				colony.dipDay = colony.day
			elseif colony.day > colony.dipDay then
				colony.dipDay = colony.day
				local ok, err = pcall(newDay, colony)
				if not ok then
					warn("[DiplomacyService] " .. tostring(err))
				end
			end
		end
	end
end

return DiplomacyService
