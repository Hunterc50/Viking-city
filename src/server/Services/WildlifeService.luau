--[[
	WildlifeService
	Deer graze in the meadow behind each plot. They wander slowly and bolt
	when a player comes close, so you hunt them with the Bow from a distance.
	A deer gives meat (Food) and Hides, then a new one wanders in later.
	In winter a wolf pack prowls the meadow behind each settled plot. Wolves
	slink closer when you are near and circle you at a distance; shoot one
	for its pelt (Hides). They leave when winter ends.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local ModelFactory = require(Shared.ModelFactory)

local WildlifeService = {}

local W = Config.Wildlife
local services
local rng = Random.new()
local folder: Folder
local herd = {} -- [model] = deer record
local nextId = 0

local _, _, _, LAND_MAX_Z = Grid.maxBounds()
local MEADOW_MIN_Z, MEADOW_MAX_Z = LAND_MAX_Z * Config.CELL + 16, Grid.PLOT_SIZE + 105

function WildlifeService:Init(allServices)
	services = allServices
end

local function areaFor(index: number)
	local o = Grid.plotOrigin(index)
	return { minX = o.X - 16, maxX = o.X + Grid.PLOT_SIZE + 16, minZ = MEADOW_MIN_Z, maxZ = MEADOW_MAX_Z, plot = index }
end

local function clampToArea(area, x: number, z: number): (number, number)
	return math.clamp(x, area.minX, area.maxX), math.clamp(z, area.minZ, area.maxZ)
end

local STEP = 5 -- studs per leg of a walk, so the deer follows hills and dips

-- Walks the deer to (x, z) in short legs, each one set on the ground, so it
-- never cuts through a hill or floats over a hollow. Returns the total time.
local function moveTo(deer, x: number, z: number, speed: number)
	local body = deer.body
	local from = body.Position
	local flat = Vector3.new(x - from.X, 0, z - from.Z)
	if flat.Magnitude < 1 then
		return 0
	end
	local legs = math.max(1, math.ceil(flat.Magnitude / STEP))
	local legTime = flat.Magnitude / legs / speed
	if deer.tween then
		deer.tween:Cancel()
	end
	deer.walk = (deer.walk or 0) + 1
	local walk = deer.walk
	local dir = flat.Unit
	task.spawn(function()
		for i = 1, legs do
			if deer.walk ~= walk or not body.Parent then
				return
			end
			local p = Vector3.new(from.X, 0, from.Z) + flat * (i / legs)
			local y = services.WorldService:GroundHeight(p.X, p.Z) + deer.offset
			local to = Vector3.new(p.X, y, p.Z)
			deer.tween = TweenService:Create(body, TweenInfo.new(legTime, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + dir) })
			deer.tween:Play()
			task.wait(legTime)
		end
	end)
	return legTime * legs
end

function WildlifeService:Spawn(area)
	nextId += 1
	local model = ModelFactory.deer(rng)
	model:SetAttribute("DeerId", nextId)
	local x = rng:NextNumber(area.minX, area.maxX)
	local z = rng:NextNumber(area.minZ, area.maxZ)
	local offset = model:GetAttribute("GroundOffset")
	model:PivotTo(CFrame.new(x, services.WorldService:GroundHeight(x, z) + offset, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder

	herd[model] = {
		model = model,
		body = model.PrimaryPart,
		offset = offset,
		area = area,
		busyUntil = 0,
	}
end

-- Called by ToolService when an arrow hits a deer.
function WildlifeService:Kill(model: Model, hunter: Player)
	local deer = herd[model]
	if not deer then
		return
	end
	herd[model] = nil
	deer.walk = (deer.walk or 0) + 1
	if deer.tween then
		deer.tween:Cancel()
	end
	-- topple over, then vanish
	deer.body.CFrame = deer.body.CFrame * CFrame.new(0, -1.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	task.delay(2, function()
		model:Destroy()
	end)

	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(hunter)
	if deer.wolf then
		if colony then
			ColonyService:Add(colony, "Hides", W.WolfHides)
			services.QuestService:Count(colony, "wolf")
			ColonyService:Notify(colony, "A wolf brought down! +" .. W.WolfHides .. " Hides", "gain")
			ColonyService:Sync(colony)
		end
		return
	end
	if colony then
		local mult = ColonyService:Has(colony, "PathWoods") and 2 or 1
		ColonyService:Add(colony, "Food", W.Meat * mult)
		ColonyService:Add(colony, "Hides", W.Hides * mult)
		services.QuestService:Count(colony, "deer")
		ColonyService:Notify(colony, "Deer hunted! +" .. W.Meat * mult .. " Food, +" .. W.Hides * mult .. " Hides", "gain")
		ColonyService:Sync(colony)
	end

	task.delay(W.RespawnSeconds, function()
		self:Spawn(deer.area)
	end)
end

local function spawnWolf(area)
	nextId += 1
	local model = ModelFactory.wolf(rng)
	model:SetAttribute("DeerId", nextId) -- so arrows find it like a deer
	model:SetAttribute("Wolf", true)
	local x = rng:NextNumber(area.minX, area.maxX)
	local z = area.maxZ - rng:NextNumber(0, 20) -- they come down from the woods
	local offset = model:GetAttribute("GroundOffset")
	model:PivotTo(CFrame.new(x, services.WorldService:GroundHeight(x, z) + offset, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = folder
	herd[model] = { model = model, body = model.PrimaryPart, offset = offset, area = area, busyUntil = 0, wolf = true }
end

local lastPack = {} -- [plot index] = os.clock() of the last wolf that came in

-- Keeps a pack behind every settled plot in winter, and sends them off after.
local function tendPacks()
	local winter = workspace:GetAttribute("Season") == "Winter"
	local counts = {}
	for model, rec in herd do
		if rec.wolf then
			if not winter then
				herd[model] = nil
				rec.walk = (rec.walk or 0) + 1
				model:Destroy()
			else
				counts[rec.area.plot] = (counts[rec.area.plot] or 0) + 1
			end
		end
	end
	if not winter then
		return
	end
	local settled = {}
	for _, player in Players:GetPlayers() do
		local index = player:GetAttribute("PlotIndex")
		if typeof(index) == "number" then
			settled[index] = true
		end
	end
	local now = os.clock()
	for index in settled do
		local have = counts[index] or 0
		if have < W.WolvesPerPack and (have == 0 or now - (lastPack[index] or 0) > W.WolfRespawnSeconds) then
			lastPack[index] = now
			local area = areaFor(index)
			for _ = have + 1, (have == 0 and W.WolvesPerPack or have + 1) do
				spawnWolf(area)
			end
		end
	end
end

local function nearestPlayer(pos: Vector3): (Vector3?, number)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local d = (root.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = root.Position, d
			end
		end
	end
	return best, bestDist
end

function WildlifeService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Wildlife"
	folder.Parent = workspace

	for i = 1, Config.MAX_PLOTS do
		local area = areaFor(i)
		for _ = 1, W.DeerPerPlot do
			self:Spawn(area)
		end
	end

	local packTimer = 0
	while true do
		task.wait(0.4)
		local now = os.clock()
		packTimer += 0.4
		if packTimer >= 5 then
			packTimer = 0
			tendPacks()
		end
		for _, deer in herd do
			local pos = deer.body.Position
			local threat, dist = nearestPlayer(pos)
			if deer.wolf then
				if threat and dist < W.WolfStalk and now >= deer.busyUntil then
					-- slink to a spot on a ring around you, a little further round each time
					local from = Vector3.new(pos.X - threat.X, 0, pos.Z - threat.Z)
					local angle = math.atan2(from.Z, from.X) + rng:NextNumber(0.3, 0.9) * (deer.side or 1)
					local x, z = clampToArea(deer.area, threat.X + math.cos(angle) * W.WolfKeepAway, threat.Z + math.sin(angle) * W.WolfKeepAway)
					local t = moveTo(deer, x, z, W.WolfSpeed * rng:NextNumber(0.6, 1))
					deer.busyUntil = now + t + rng:NextNumber(0.5, 2)
				elseif now >= deer.busyUntil then
					deer.side = rng:NextNumber() < 0.5 and -1 or 1
					local x, z = clampToArea(deer.area, pos.X + rng:NextNumber(-30, 30), pos.Z + rng:NextNumber(-30, 30))
					local t = moveTo(deer, x, z, W.WolfSpeed * rng:NextNumber(0.3, 0.6))
					deer.busyUntil = now + t + rng:NextNumber(2, 6)
				end
				continue
			end
			if threat and dist < W.FleeDistance and not deer.fleeing then
				-- bolt directly away
				local away = Vector3.new(pos.X - threat.X, 0, pos.Z - threat.Z)
				away = away.Magnitude > 0.1 and away.Unit or Vector3.new(0, 0, 1)
				local x, z = clampToArea(deer.area, pos.X + away.X * 40, pos.Z + away.Z * 40)
				local t = moveTo(deer, x, z, W.FleeSpeed)
				deer.fleeing = true
				deer.busyUntil = now + t + 1
			elseif now >= deer.busyUntil then
				deer.fleeing = false
				local x, z = clampToArea(deer.area, pos.X + rng:NextNumber(-25, 25), pos.Z + rng:NextNumber(-25, 25))
				local t = moveTo(deer, x, z, W.Speed * rng:NextNumber(0.4, 1))
				deer.busyUntil = now + t + rng:NextNumber(3, 9) -- graze a while
			end
		end
	end
end

return WildlifeService
