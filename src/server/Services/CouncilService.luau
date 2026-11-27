--[[
	CouncilService
	The Jarl's Table (J): one remote, "Council", for buying land, the war
	band, diplomacy and rites. Each action checks everything on the server.
	Also builds the table's state that goes out with every colony sync.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local CouncilService = {}

local services
local lastCall = {} -- [player] = os.clock(), a small guard against spam

function CouncilService:Init(all)
	services = all
end

function CouncilService:State(colony)
	return {
		land = services.LandService:State(colony),
		warband = services.WarbandService:State(colony),
		diplomacy = services.DiplomacyService:State(colony),
		rites = services.RiteService:State(colony),
	}
end

local function handle(colony, action: string, arg)
	if action == "BuyLand" then
		return services.LandService:Buy(colony)
	elseif action == "Hire" then
		return services.WarbandService:Hire(colony)
	elseif action == "Dismiss" then
		return services.WarbandService:Dismiss(colony)
	elseif action == "Follow" then
		return services.WarbandService:SetMode(colony, "follow")
	elseif action == "StayHome" then
		return services.WarbandService:SetMode(colony, "home")
	elseif action == "Expedition" then
		return services.WarbandService:Expedition(colony, arg)
	elseif action == "Gift" then
		return services.DiplomacyService:Gift(colony, arg)
	elseif action == "Demand" then
		return services.DiplomacyService:Demand(colony, arg)
	elseif action == "Ally" then
		return services.DiplomacyService:Ally(colony, arg)
	elseif action == "Deal" then
		return services.DiplomacyService:Deal(colony, arg)
	elseif action == "Feast" then
		return services.RiteService:Feast(colony)
	elseif action == "Blot" then
		return services.RiteService:Blot(colony)
	end
	return false, "Unknown action."
end

function CouncilService:Start()
	Remotes.Council.OnServerInvoke = function(player, action, arg)
		if typeof(action) ~= "string" or (arg ~= nil and typeof(arg) ~= "string") then
			return false, "Bad request."
		end
		local now = os.clock()
		if now - (lastCall[player] or 0) < 0.25 then
			return false, "Slow down."
		end
		lastCall[player] = now
		local colony = services.ColonyService:Get(player)
		if not colony then
			return false, "Your village isn't ready yet."
		end
		local ok, a, b = pcall(handle, colony, action, arg)
		if not ok then
			warn("[CouncilService] " .. action .. ": " .. tostring(a))
			return false, "Something went wrong."
		end
		services.ColonyService:Sync(colony)
		return a, b
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return CouncilService
