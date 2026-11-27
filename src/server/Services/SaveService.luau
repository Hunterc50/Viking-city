--[[
	SaveService
	Saves each player's village with a DataStore, so it's still there next
	time: buildings (type and spot), resources, research, villagers (name,
	age, child or adult), happiness and the day count.

	Saves every Config.AutosaveSeconds, when the player leaves, and when the
	server shuts down. Loading happens in ColonyService:Create.

	DataStores only work in a PUBLISHED place with API access turned on
	(Studio: File > Publish to Roblox, then Game Settings > Security >
	"Enable Studio Access to API Services"). Without that, the game runs
	normally and simply tells the player that saving is off.

	If loading fails (DataStores down), saving is switched off for that
	player for the session, so a fresh village can never overwrite a good save.
]]

local DataStoreService = game:GetService("DataStoreService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local SaveService = {}

local services
local store = nil
local storeError = nil
local SAVE_VERSION = 1

function SaveService:Init(allServices)
	services = allServices
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("VikingCity_Villages_v1")
	end)
	if ok then
		store = result
	else
		storeError = tostring(result)
	end
end

local function keyFor(player: Player): string
	return "village_" .. player.UserId
end

-- Loads a player's saved village. Returns data or nil, and whether saving is safe.
function SaveService:Load(player: Player): (any, boolean)
	if not store then
		return nil, false
	end
	local data
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			data = store:GetAsync(keyFor(player))
		end)
		if ok then
			break
		end
		task.wait(attempt)
	end
	if not ok then
		warn("[SaveService] couldn't load " .. player.Name .. ": " .. tostring(err))
		storeError = tostring(err)
		return nil, false
	end
	if type(data) ~= "table" or data.version ~= SAVE_VERSION then
		return nil, true
	end
	return data, true
end

-- Turns a colony into plain data a DataStore can hold.
function SaveService:Snapshot(colony)
	local buildings = {}
	for _, b in colony.buildings do
		table.insert(buildings, { t = b.type, x = b.cx, z = b.cz, r = b.rot })
	end
	local villagers = {}
	local index = {}
	for _, v in colony.villagers do
		table.insert(villagers, v)
		index[v.id] = #villagers
	end
	for i, v in villagers do
		local parents = {}
		for _, pid in v.parents or {} do
			table.insert(parents, index[pid])
		end
		villagers[i] = { n = v.name, c = v.isChild, a = v.age, p = v.partner and index[v.partner], f = parents, w = v.warrior or nil }
	end
	local resources = {}
	for name, amount in colony.resources do
		resources[name] = math.floor(amount)
	end
	local tech = {}
	for id in colony.tech do
		table.insert(tech, id)
	end
	return {
		version = SAVE_VERSION,
		savedAt = os.time(),
		resources = resources,
		tech = tech,
		buildings = buildings,
		villagers = villagers,
		happiness = colony.happiness,
		day = colony.day,
		quest = colony.quest,
		rank = colony.rank,
		stats = colony.stats,
		land = colony.land,
		relations = colony.relations,
		rites = colony.rites,
		warbandMode = colony.warband and colony.warband.mode == "follow" and "follow" or nil,
	}
end

-- Rebuilds a colony from saved data (called on a fresh, empty colony).
function SaveService:Restore(colony, data)
	for name, amount in data.resources or {} do
		if type(amount) == "number" then
			colony.resources[name] = amount
		end
	end
	for _, id in data.tech or {} do
		if Config.Tech[id] then
			colony.tech[id] = true
		end
	end
	colony.happiness = tonumber(data.happiness) or colony.happiness
	colony.day = tonumber(data.day) or colony.day
	colony.quest = tonumber(data.quest) or 1
	colony.rank = tonumber(data.rank) or 1
	-- land first, so buildings out on the bought ground fit
	local land = tonumber(data.land)
	if land and Config.LandStages[math.floor(land)] then
		colony.land = math.floor(land)
		services.PlotService:ApplyLand(colony)
	end
	if type(data.relations) == "table" then
		colony.relations = {}
		for name, rel in data.relations do
			if type(name) == "string" and type(rel) == "table" then
				colony.relations[name] = {
					mood = tonumber(rel.mood) or 0,
					allied = rel.allied == true,
					deal = rel.deal == true,
					tributeDays = tonumber(rel.tributeDays) or 0,
				}
			end
		end
	end
	if type(data.rites) == "table" then
		colony.rites = {
			feastUntil = tonumber(data.rites.feastUntil) or 0,
			feastReady = tonumber(data.rites.feastReady) or 0,
		}
	end
	if type(data.stats) == "table" then
		for k, n in data.stats do
			if type(k) == "string" and type(n) == "number" then
				colony.stats[k] = n
			end
		end
	end

	local placed = 0
	for _, b in data.buildings or {} do
		if Config.Buildings[b.t] then
			local ok, err = pcall(function()
				services.BuildingService:Create(colony, b.t, b.x, b.z, b.r)
			end)
			if ok then
				placed += 1
			else
				warn("[SaveService] skipped a " .. tostring(b.t) .. ": " .. tostring(err))
			end
		end
	end
	if placed == 0 then
		services.BuildingService:PlaceStarting(colony)
	end

	local villagers = data.villagers or {}
	local made = {}
	for i, saved in villagers do
		made[i] = services.VillagerService:Add(colony, saved.c == true, nil, type(saved.n) == "string" and saved.n or nil, tonumber(saved.a) or 0)
		if saved.w == true and saved.c ~= true then
			made[i].warrior = true
			services.VillagerService:Rebuild(colony, made[i])
		end
	end
	if data.warbandMode == "follow" then
		colony.warband = { mode = "follow" }
	end
	-- re-link families
	for i, saved in villagers do
		local v = made[i]
		local partner = saved.p and made[saved.p]
		if partner then
			v.partner = partner.id
		end
		if type(saved.f) == "table" then
			v.parents = {}
			for _, pi in saved.f do
				if made[pi] then
					table.insert(v.parents, made[pi].id)
				end
			end
		end
	end
	for _, v in made do
		services.VillagerService:RefreshLabel(colony, v)
	end
	if #villagers == 0 then
		services.VillagerService:SpawnStarting(colony)
	end
	task.defer(function()
		services.ToolService:ApplyArmor(colony.player)
	end)
end

function SaveService:Save(colony)
	if not store or not colony.canSave then
		return
	end
	local data = self:Snapshot(colony)
	local key = keyFor(colony.player)
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(key, data)
		end)
		if not ok then
			warn("[SaveService] save failed: " .. tostring(err))
		end
	end)
end

-- Explains in the message feed why saving is off.
function SaveService:WhyOff(): string
	local e = (storeError or ""):lower()
	if e:find("403") or e:find("publish") or e:find("api") then
		return "Saving is off: publish the game and turn on API access in Game Settings > Security (see README)."
	end
	return "Saving is off right now (DataStores unavailable). Your village won't be saved this time."
end

function SaveService:Start()
	game:BindToClose(function()
		for _, colony in services.ColonyService:All() do
			if colony.canSave then
				pcall(function()
					store:SetAsync(keyFor(colony.player), self:Snapshot(colony))
				end)
			end
		end
	end)

	while true do
		task.wait(Config.AutosaveSeconds)
		for _, colony in services.ColonyService:All() do
			self:Save(colony)
		end
	end
end

return SaveService
