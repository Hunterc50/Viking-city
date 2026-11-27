--[[
	BoatService
	Sailing. Research Karve (needs a Shipyard) and walk to the end of the
	jetty in front of your plot: hold E to launch a boat and take the helm.
	W/S row forward and back, A/D steer, Space to jump off. Research
	Longship for a bigger, faster war ship. Boats stay on the water: land,
	sand and ice stop them, so you can beach one near Greywater Hold.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local BoatService = {}

local services
local boats = {} -- [player] = boat
local inputs = {} -- [player] = { throttle, steer }

local KINDS = {
	Karve = { length = 26, speed = 24, turn = 0.9, sail = Color3.fromRGB(200, 190, 170) },
	Longship = { length = 44, speed = 38, turn = 0.6, sail = Color3.fromRGB(160, 40, 36) },
}

function BoatService:Init(allServices)
	services = allServices
end

local function isWater(pos: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), params)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

local function removeBoat(player: Player)
	local boat = boats[player]
	if boat then
		boat.model:Destroy()
		boats[player] = nil
	end
end

local function launch(player: Player, dockIndex: number)
	local ColonyService = services.ColonyService
	local colony = ColonyService:Get(player)
	if not colony then
		return
	end
	if colony.plotIndex ~= dockIndex then
		ColonyService:Notify(colony, "This is someone else's jetty. Use the one in front of your plot.", "bad")
		return
	end
	local kindName = ColonyService:Has(colony, "Longship") and "Longship" or (ColonyService:Has(colony, "Karve") and "Karve")
	if not kindName then
		ColonyService:Notify(colony, "Build a Shipyard and research Karve first (press T).", "bad")
		return
	end
	local kind = KINDS[kindName]
	removeBoat(player)

	local model = ModelFactory.longship(kind.length, kind.sail)
	model.Name = player.Name .. "_" .. kindName
	local seat = Instance.new("Seat")
	seat.Name = "Helm"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Color = Color3.fromRGB(90, 64, 44)
	seat.Material = Enum.Material.Wood
	seat.CFrame = CFrame.new(0, 0.2, kind.length * 0.32)
	seat:SetAttribute("Boat", true)
	seat.Parent = model

	local o = Grid.plotOrigin(dockIndex)
	local start = CFrame.new(o.X + Grid.PLOT_SIZE * 0.25 - 16, 0, -100)
	model:PivotTo(start)
	model.Parent = workspace

	boats[player] = { model = model, seat = seat, cf = start, speed = 0, maxSpeed = kind.speed, turn = kind.turn, idle = 0 }

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
		task.wait(0.1)
		seat:Sit(humanoid)
	end
	ColonyService:Notify(colony, "Your " .. kindName .. " is in the water! W/S to row, A/D to steer, Space to jump off.", "good")
end

function BoatService:Start()
	-- a launch prompt at the end of every plot's jetty
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		local anchor = Instance.new("Part")
		anchor.Name = "LaunchPoint"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = Vector3.new(o.X + Grid.PLOT_SIZE * 0.25, 3, -76)
		anchor.Parent = workspace
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Launch boat"
		prompt.ObjectText = "Jetty"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(player)
			launch(player, i)
		end)
	end

	Remotes.BoatInput.OnServerEvent:Connect(function(player, throttle, steer)
		if typeof(throttle) ~= "number" or typeof(steer) ~= "number" or throttle ~= throttle or steer ~= steer then
			return
		end
		inputs[player] = { math.clamp(throttle, -1, 1), math.clamp(steer, -1, 1) }
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		inputs[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for player, boat in boats do
			local occupied = boat.seat.Occupant ~= nil
			local input = occupied and inputs[player] or { 0, 0 }
			if occupied then
				boat.idle = 0
			else
				boat.idle += step
				if boat.idle > 90 then
					removeBoat(player)
					continue
				end
			end
			local target = input[1] * boat.maxSpeed * (input[1] < 0 and 0.4 or 1)
			boat.speed += (target - boat.speed) * math.min(1, step * 0.8)
			local turnRate = input[2] * boat.turn * math.clamp(math.abs(boat.speed) / 10, 0.25, 1)
			local heading = boat.cf * CFrame.Angles(0, -turnRate * step, 0)
			local nextPos = heading.Position + heading.LookVector * boat.speed * step
			if isWater(nextPos + heading.LookVector * 8 * math.sign(boat.speed)) then
				boat.cf = CFrame.new(nextPos) * heading.Rotation
			else
				boat.speed = 0 -- ran aground
				boat.cf = heading
			end
			local bob = math.sin(now * 1.3) * 0.25
			local roll = math.sin(now * 0.9) * math.rad(2) - turnRate * 0.08
			local pitch = math.sin(now * 1.1) * math.rad(1)
			boat.model:PivotTo(boat.cf * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll))
		end
	end)
end

return BoatService
