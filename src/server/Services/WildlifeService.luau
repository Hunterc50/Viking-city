--[[
	WildlifeService
	Deer graze in the meadow behind each plot. They wander slowly and bolt
	when a player comes close, so you hunt them with the Bow from a distance.
	A deer gives meat (Food) and Hides, then a new one wanders in later.
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

local function moveTo(deer, x: number, z: number, speed: number)
	local body = deer.body
	local from = body.Position
	local y = services.WorldService:GroundHeight(x, z) + deer.offset
	local to = Vector3.new(x, y, z)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if flat.Magnitude < 1 then
		return 0
	end
	local duration = flat.Magnitude / speed
	body.CFrame = CFrame.lookAt(from, from + flat)
	if deer.tween then
		deer.tween:Cancel()
	end
	deer.tween = TweenService:Create(body, TweenInfo.new(duration, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + flat) })
	deer.tween:Play()
	return duration
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

	while true do
		task.wait(0.4)
		local now = os.clock()
		for _, deer in herd do
			local pos = deer.body.Position
			local threat, dist = nearestPlayer(pos)
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
