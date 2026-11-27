--[[
	ColonyService
	Owns each player's colony: resources, the grid of blocked cells, and the
	main simulation loop. Other services read and change the colony table
	through the helpers here, and ColonyService sends a snapshot to the
	player's HUD every tick.

	colony = {
		player, plotIndex, origin, plot,
		resources = { Wood = n, Stone = n, Food = n },
		blocked = { ["x,z"] = "building" | "node" },
		buildings = { [id] = building },
		villagers = { [id] = villager },
		nodes = { [key] = node },
		happiness, day, dayTimer, starving, nextId, gridDirty,
	}
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)

local ColonyService = {}

local services
local colonies = {} -- [player] = colony

function ColonyService:Init(allServices)
	services = allServices
end

function ColonyService:Get(player: Player)
	return colonies[player]
end

function ColonyService:All()
	return colonies
end

function ColonyService:NewId(colony): number
	colony.nextId += 1
	return colony.nextId
end

-- Resources -----------------------------------------------------------------

function ColonyService:Storage(colony): number
	local total = Config.BaseStorage
	for _, b in colony.buildings do
		total += Config.Buildings[b.type].Storage or 0
	end
	return total
end

function ColonyService:Housing(colony): number
	local total = 0
	for _, b in colony.buildings do
		total += Config.Buildings[b.type].Housing or 0
	end
	return total
end

function ColonyService:Add(colony, resource: string, amount: number)
	local cap = self:Storage(colony)
	colony.resources[resource] = math.clamp((colony.resources[resource] or 0) + amount, 0, cap)
end

function ColonyService:CanAfford(colony, cost): boolean
	return Grid.canAfford(colony.resources, cost)
end

function ColonyService:Spend(colony, cost): boolean
	if not self:CanAfford(colony, cost) then
		return false
	end
	for name, amount in cost do
		colony.resources[name] -= amount
	end
	return true
end

-- Grid ----------------------------------------------------------------------

function ColonyService:Block(colony, x: number, z: number, what: string)
	colony.blocked[Grid.key(x, z)] = what
	colony.gridDirty = true
end

function ColonyService:Unblock(colony, x: number, z: number)
	colony.blocked[Grid.key(x, z)] = nil
	colony.gridDirty = true
end

-- Messages ------------------------------------------------------------------

function ColonyService:Notify(colony, text: string, kind: string?)
	Remotes.Notify:FireClient(colony.player, text, kind or "info")
end

-- Sync ----------------------------------------------------------------------

function ColonyService:Sync(colony)
	local adults, children, workers = 0, 0, 0
	for _, v in colony.villagers do
		if v.isChild then
			children += 1
		else
			adults += 1
			if v.job then
				workers += 1
			end
		end
	end

	local resources = {}
	for _, name in Config.ResourceOrder do
		resources[name] = math.floor(colony.resources[name] or 0)
	end

	local state = {
		resources = resources,
		storage = self:Storage(colony),
		population = adults + children,
		adults = adults,
		children = children,
		workers = workers,
		idle = adults - workers,
		housing = self:Housing(colony),
		happiness = math.floor(colony.happiness + 0.5),
		starving = colony.starving,
		day = colony.day,
		season = workspace:GetAttribute("Season") or "Summer",
		dayProgress = colony.dayTimer / Config.DAY_LENGTH,
	}

	if colony.gridDirty then
		local blocked = {}
		for key in colony.blocked do
			table.insert(blocked, key)
		end
		state.blocked = blocked
		colony.gridDirty = false
	end

	Remotes.ColonyState:FireClient(colony.player, state)
end

-- Lifecycle -----------------------------------------------------------------

function ColonyService:Create(player: Player)
	local index, origin, plot = services.PlotService:Assign(player)
	if not index then
		return
	end

	local colony = {
		player = player,
		plotIndex = index,
		origin = origin,
		plot = plot,
		resources = table.clone(Config.StartingResources),
		blocked = {},
		buildings = {},
		villagers = {},
		nodes = {},
		happiness = 60,
		day = 1,
		dayTimer = 0,
		starving = false,
		nextId = 0,
		gridDirty = true,
	}
	colonies[player] = colony

	services.BuildingService:PlaceStarting(colony)
	services.ResourceNodeService:SpawnInitial(colony)
	services.VillagerService:SpawnStarting(colony)

	self:Notify(colony, "Your people have landed. Build a farm and a woodcutter to get started!", "good")
	self:Sync(colony)
end

function ColonyService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:Create(player)
	end)
	for _, player in Players:GetPlayers() do
		if not colonies[player] then
			self:Create(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		local colony = colonies[player]
		if colony then
			services.VillagerService:Cleanup(colony)
		end
		colonies[player] = nil
	end)

	-- Main simulation loop.
	while true do
		local dt = task.wait(Config.TICK)
		for _, colony in colonies do
			local ok, err = pcall(function()
				services.VillagerService:Tick(colony, dt)
				services.ResourceNodeService:Tick(colony, dt)
				self:Sync(colony)
			end)
			if not ok then
				warn("[ColonyService] tick error: " .. tostring(err))
			end
		end
	end
end

return ColonyService
