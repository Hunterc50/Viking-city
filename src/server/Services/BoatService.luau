--[[
	BoatService
	Sailing and sea battles.

	Research Karve (needs a Shipyard) and walk to the end of the jetty in
	front of your plot: hold E to launch a boat and take the helm.
	  W/S  row forward and back      A/D  steer
	  F    loose a volley of arrows at the nearest enemy ship
	  Space jump off
	Ram an enemy at speed to smash its hull. Every ship has a hull bar; at
	zero it sinks and the crew swims for it. Sink a ship and you take its
	cargo. Research Longship for a bigger, faster, tougher war ship.

	A Greywater raider longship patrols the fjord and attacks player ships
	that come close. It comes back a few minutes after you sink it.
	Boats stay on the water: land, sand and ice stop them, so you can beach
	one near Greywater Hold for a raid.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local Grid = require(Shared.Grid)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local BoatService = {}

local N = Config.Naval
local services
local ships = {} -- [ship] = true, every ship afloat (players' and raiders)
local boats = {} -- [player] = ship
local inputs = {} -- [player] = { throttle, steer }
local rng = Random.new()

local KINDS = {
	Karve = { length = 26, speed = 24, turn = 0.9, sail = Color3.fromRGB(200, 190, 170), hull = N.KarveHull, ram = 1 },
	Longship = { length = 44, speed = 38, turn = 0.6, sail = Color3.fromRGB(160, 40, 36), hull = N.LongshipHull, ram = 1.5 },
	Raider = { length = 40, speed = N.RaiderSpeed, turn = 0.55, sail = Color3.fromRGB(40, 50, 70), hull = N.RaiderHull, ram = 1.3 },
}

function BoatService:Init(allServices)
	services = allServices
end

local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Include
waterParams.IgnoreWater = false

local function isWater(pos: Vector3): boolean
	waterParams.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), waterParams)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

-- Hull bar ------------------------------------------------------------------

local function makeHullBar(ship)
	local anchor = ship.model.PrimaryPart or ship.model:FindFirstChildWhichIsA("BasePart", true)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HullBar"
	gui.Size = UDim2.fromOffset(150, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 260
	gui.Adornee = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 16)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = ship.owner and Color3.fromRGB(245, 235, 215) or Color3.fromRGB(240, 120, 100)
	title.TextStrokeTransparency = 0.4
	title.Text = ship.title
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(10, 18)
	back.Size = UDim2.new(1, -20, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 22, 18)
	back.BorderSizePixel = 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 100)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = ship.model
	ship.bar = fill
end

local function updateBar(ship)
	if ship.bar then
		local t = math.clamp(ship.hp / ship.maxHp, 0, 1)
		ship.bar.Size = UDim2.fromScale(t, 1)
		ship.bar.BackgroundColor3 = Color3.fromRGB(230, 90, 70):Lerp(Color3.fromRGB(120, 200, 100), t)
	end
end

-- Ships ---------------------------------------------------------------------

local function newShip(kindName: string, start: CFrame, owner: Player?, title: string)
	local kind = KINDS[kindName]
	local model = ModelFactory.longship(kind.length, kind.sail)
	model.Name = title
	model:SetAttribute("Ship", true)
	model:SetAttribute("OwnerUserId", owner and owner.UserId or 0)
	if not owner then
		-- raiders crew their own ship, in war gear
		ModelFactory.addCrew(model, 8, rng, 4)
	end
	if owner then
		local colony = services.ColonyService:Get(owner)
		if colony then
			services.ClanService:Apply(colony, model) -- the sail in the clan's colours
		end
	end
	model:PivotTo(start)
	model.Parent = workspace
	local ship = {
		kind = kindName,
		model = model,
		owner = owner,
		title = title,
		cf = start,
		speed = 0,
		maxSpeed = kind.speed,
		turn = kind.turn,
		length = kind.length,
		ramPower = kind.ram,
		hp = kind.hull,
		maxHp = kind.hull,
		idle = 0,
		lastVolley = 0,
		lastRam = 0,
	}
	makeHullBar(ship)
	ships[ship] = true
	return ship
end

local function destroyShip(ship)
	ships[ship] = nil
	if ship.owner and boats[ship.owner] == ship then
		boats[ship.owner] = nil
	end
	if ship.model then
		ship.model:Destroy()
	end
end

local function removeBoat(player: Player)
	local ship = boats[player]
	if ship then
		destroyShip(ship)
	end
end

local function notify(player: Player?, text: string, kind: string)
	if player then
		local colony = services.ColonyService:Get(player)
		if colony then
			services.ColonyService:Notify(colony, text, kind)
		end
	end
end

local function jettyCFrame(player: Player): CFrame?
	local colony = services.ColonyService:Get(player)
	if not colony then
		return nil
	end
	local o = Grid.plotOrigin(colony.plotIndex)
	return CFrame.new(o.X + Grid.PLOT_SIZE * 0.25, 4, -70)
end

local function sink(ship, attacker: Player?)
	if ship.sinking then
		return
	end
	ship.sinking = true
	ships[ship] = nil
	if ship.owner and boats[ship.owner] == ship then
		boats[ship.owner] = nil
	end

	-- the crew jumps clear and is fished out at their jetty
	local seat = ship.seat
	local occupant = seat and seat.Occupant
	if occupant then
		occupant.Sit = false
		occupant.Jump = true
		local player = Players:GetPlayerFromCharacter(occupant.Parent)
		task.delay(2.5, function()
			local cf = player and jettyCFrame(player)
			if cf and player.Character then
				player.Character:PivotTo(cf)
			end
		end)
	end

	if ship.owner then
		notify(ship.owner, "Your ship has been sunk! Build another at the jetty.", "bad")
	end
	if attacker then
		local colony = services.ColonyService:Get(attacker)
		if colony and ship.owner ~= attacker then
			local loot = ship.owner and { Silver = 8, Food = 15 } or N.RaiderLoot
			for res, amount in loot do
				services.ColonyService:Add(colony, res, amount)
			end
			services.QuestService:Count(colony, "sunk")
			services.ColonyService:Notify(colony, ship.title .. " sinks beneath the waves! Plundered " .. Grid.costText(loot), "raid")
		end
	end

	Sounds.play("Splash", ship.cf.Position)
	-- list, settle and slip under
	local model = ship.model
	local startCf = ship.cf
	local tilt = rng:NextNumber(-1, 1) > 0 and 1 or -1
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and os.clock() - t0 < 6 do
			local t = (os.clock() - t0) / 6
			model:PivotTo(startCf * CFrame.new(0, -t * t * 22, 0) * CFrame.Angles(t * 0.5, 0, tilt * t * 0.9))
			task.wait()
		end
		model:Destroy()
	end)
	if ship.kind == "Raider" then
		task.delay(N.RaiderRespawn, function()
			BoatService:SpawnRaider()
		end)
	end
end

local function damage(ship, amount: number, attacker: Player?)
	if ship.sinking or not ships[ship] then
		return
	end
	ship.hp -= amount
	updateBar(ship)
	if ship.hp <= 0 then
		sink(ship, attacker)
	end
end

-- Combat --------------------------------------------------------------------

-- An arrow from a player's bow landed on `inst`: if it's part of an enemy ship, hurt it.
-- The player's own ship while they are at its helm (nil otherwise).
function BoatService:ShipOf(player: Player)
	local ship = boats[player]
	if ship and ships[ship] and not ship.sinking and ship.seat and ship.seat.Occupant and ship.seat.Occupant.Parent == player.Character then
		return ship
	end
	return nil
end

function BoatService:ArrowHit(inst: Instance, player: Player)
	for ship in ships do
		if ship.owner ~= player and inst:IsDescendantOf(ship.model) then
			damage(ship, N.VolleyDamage * 0.6, player)
			return
		end
	end
end

-- Distance from a point to a ship's keel line (so long ships are hit along their length).
local function distanceToShip(ship, point: Vector3): number
	local half = ship.length / 2
	local rel = ship.cf:PointToObjectSpace(point)
	local z = math.clamp(rel.Z, -half, half)
	return (Vector3.new(rel.X, 0, rel.Z - z)).Magnitude
end

local function isEnemy(a, b): boolean
	if a == b or b.sinking then
		return false
	end
	if a.owner == nil and b.owner == nil then
		return false -- raiders don't fight each other
	end
	return a.owner ~= b.owner
end

local function nearestEnemy(ship, range: number)
	local best, bestDist = nil, range
	for other in ships do
		-- raiders leave you alone in your own harbour
		local safe = ship.owner == nil and other.dock ~= nil and (other.cf.Position - other.dock).Magnitude < 50
		if isEnemy(ship, other) and not safe then
			local d = (other.cf.Position - ship.cf.Position).Magnitude
			if d < bestDist then
				best, bestDist = other, d
			end
		end
	end
	return best
end

local function volley(ship)
	local now = os.clock()
	local cooldown = ship.owner and N.VolleyCooldown or N.VolleyCooldown * 1.7
	if ship.sinking or now - ship.lastVolley < cooldown then
		return false
	end
	local target = nearestEnemy(ship, N.VolleyRange)
	if not target then
		return false
	end
	ship.lastVolley = now
	Sounds.play("Bow", ship.cf.Position)
	local attacker = ship.owner
	local hits = 0
	local accuracy = attacker and 0.75 or 0.55
	if attacker and services.ColonyService:Has(services.ColonyService:Get(attacker), "Longbows") then
		accuracy = 0.9
	end
	-- every warrior aboard looses one more arrow
	local arrows = N.VolleyArrows + (attacker and services.WarbandService and services.WarbandService:CrewCount(attacker) or 0)
	for i = 1, arrows do
		local from = ship.cf * CFrame.new(rng:NextNumber(-2, 2), 4, (i - arrows / 2) * ship.length / (arrows + 1))
		local hit = rng:NextNumber() < accuracy
		local aim = target.cf * CFrame.new(rng:NextNumber(-2, 2), 3, rng:NextNumber(-target.length / 2.5, target.length / 2.5))
		local to = hit and aim.Position or (aim.Position + Vector3.new(rng:NextNumber(-10, 10), -3, rng:NextNumber(-10, 10)))
		if hit then
			hits += 1
		end
		task.delay(i * 0.08, function()
			local arrow = ModelFactory.arrow()
			local mid = (from.Position + to) / 2 + Vector3.new(0, (to - from.Position).Magnitude * 0.15, 0)
			arrow.CFrame = CFrame.lookAt(from.Position, mid)
			arrow.Parent = workspace
			local flight = (to - from.Position).Magnitude / 120
			TweenService:Create(arrow, TweenInfo.new(flight / 2, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(mid, to) }):Play()
			task.delay(flight / 2, function()
				if arrow.Parent then
					TweenService:Create(arrow, TweenInfo.new(flight / 2, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - mid).Unit) }):Play()
				end
			end)
			Debris:AddItem(arrow, flight + 2)
		end)
	end
	local flight = (target.cf.Position - ship.cf.Position).Magnitude / 120
	task.delay(flight, function()
		damage(target, hits * N.VolleyDamage, attacker)
	end)
	return true
end

local function checkRam(ship, now: number)
	if ship.sinking or now - ship.lastRam < 1.5 or ship.speed < ship.maxSpeed * 0.45 then
		return
	end
	local bow = ship.cf.Position + ship.cf.LookVector * ship.length / 2
	for other in ships do
		if other ~= ship and not other.sinking and distanceToShip(other, bow) < 5.5 then
			ship.lastRam = now
			local force = ship.speed / ship.maxSpeed
			if isEnemy(ship, other) then
				damage(other, N.RamDamage * ship.ramPower * force, ship.owner)
			end
			damage(ship, N.RamSelfDamage * force, other.owner)
			other.cf += ship.cf.LookVector * 4
			ship.speed = -ship.speed * 0.3
			notify(ship.owner, "RAM! Timber splinters!", "gain")
			notify(other.owner, "You've been rammed!", "bad")
			return
		end
	end
end

-- Movement shared by every ship. Returns the turn rate used (for the roll).
local function steerShip(ship, throttle: number, steerInput: number, step: number): number
	local weather = services.WeatherService
	-- warriors at the oars row faster (WarbandService)
	local crew = ship.owner and services.WarbandService and services.WarbandService:CrewBonus(ship.owner) or 0
	local target = throttle * ship.maxSpeed * (throttle < 0 and 0.4 or 1) * (weather and weather:ShipSpeed() or 1) * (1 + crew)
	ship.speed += (target - ship.speed) * math.min(1, step * 0.8)
	local turnRate = steerInput * ship.turn * math.clamp(math.abs(ship.speed) / 10, 0.25, 1)
	local heading = ship.cf * CFrame.Angles(0, -turnRate * step, 0)
	local nextPos = heading.Position + heading.LookVector * ship.speed * step
	if isWater(nextPos + heading.LookVector * 8 * math.sign(ship.speed)) then
		ship.cf = CFrame.new(nextPos) * heading.Rotation
	else
		ship.speed = 0 -- ran aground
		ship.cf = heading
	end
	return turnRate
end

-- The raider's brain: patrol, then close in, keep broadside on, and loose volleys.
local function raiderThink(ship): (number, number)
	local target = nearestEnemy(ship, N.RaiderAggro * (services.WeatherService and services.WeatherService:Sight() or 1))
	local goal
	if target then
		local d = (target.cf.Position - ship.cf.Position).Magnitude
		if d > 45 then
			goal = target.cf.Position
		else
			-- circle the target so the archers have a clear line
			local side = ship.cf.RightVector
			goal = ship.cf.Position + ship.cf.LookVector * 30 + side * 10
		end
		volley(ship)
	else
		if not ship.waypoint or (ship.waypoint - ship.cf.Position).Magnitude < 20 then
			for _ = 1, 12 do
				local p = Vector3.new(rng:NextNumber(-320, 520), 0, rng:NextNumber(-230, -120))
				if isWater(p) then
					ship.waypoint = p
					break
				end
			end
		end
		goal = ship.waypoint or ship.cf.Position
	end
	local localGoal = ship.cf:PointToObjectSpace(goal)
	local steer = math.clamp(localGoal.X / 20, -1, 1)
	local throttle = target and 1 or 0.6
	if ship.speed < 1 and ship.stuckSince and os.clock() - ship.stuckSince > 3 then
		ship.waypoint = nil
		steer = 1
		throttle = -1
	end
	if math.abs(ship.speed) < 1 then
		ship.stuckSince = ship.stuckSince or os.clock()
	else
		ship.stuckSince = nil
	end
	return throttle, steer
end

function BoatService:SpawnRaider()
	for _ = 1, 30 do
		local p = Vector3.new(rng:NextNumber(-250, 400), 0, rng:NextNumber(-220, -140))
		if isWater(p) then
			newShip("Raider", CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), nil, "Greywater Raider")
			return
		end
	end
	task.delay(30, function()
		self:SpawnRaider()
	end)
end

-- Launching -----------------------------------------------------------------

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

	local o = Grid.plotOrigin(dockIndex)
	local start = CFrame.new(o.X + Grid.PLOT_SIZE * 0.25 - 16, 0, -100)
	local ship = newShip(kindName, start, player, player.DisplayName .. "'s " .. kindName)
	local seat = Instance.new("Seat")
	seat.Name = "Helm"
	seat.Anchored = true
	seat.Size = Vector3.new(2, 0.6, 2)
	seat.Color = Color3.fromRGB(90, 64, 44)
	seat.Material = Enum.Material.Wood
	-- on the deck: a mesh hull rides higher than the block-built one
	local deckY = ship.model:FindFirstChildWhichIsA("MeshPart", true) and 1.1 or 0.2
	seat.CFrame = start * CFrame.new(0, deckY, kind.length * 0.32)
	seat:SetAttribute("Boat", true)
	seat.Parent = ship.model
	ship.seat = seat
	ship.dock = start.Position
	boats[player] = ship
	Sounds.play("Splash", start.Position)
	services.QuestService:Count(colony, "launch")

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
		task.wait(0.1)
		seat:Sit(humanoid)
	end
	ColonyService:Notify(colony, "Your " .. kindName .. " is in the water! W/S row, A/D steer, F volley of arrows, ram enemies at speed.", "good")
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
	Remotes.BoatFire.OnServerEvent:Connect(function(player)
		local ship = boats[player]
		if ship and ship.seat and ship.seat.Occupant and ship.seat.Occupant.Parent == player.Character then
			if not volley(ship) and os.clock() - ship.lastVolley >= N.VolleyCooldown then
				notify(player, "No enemy ship in bow range (" .. N.VolleyRange .. " studs).", "info")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		removeBoat(player)
		inputs[player] = nil
	end)

	self:SpawnRaider()

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		local step = accumulator
		accumulator = 0
		local now = os.clock()
		for ship in ships do
			local throttle, steer = 0, 0
			if ship.owner then
				local occupied = ship.seat.Occupant ~= nil
				if occupied then
					ship.idle = 0
					local input = inputs[ship.owner] or { 0, 0 }
					throttle, steer = input[1], input[2]
				else
					ship.idle += step
					if ship.idle > 90 then
						destroyShip(ship)
						continue
					end
				end
				-- moored near your own jetty: the shipwrights patch the hull
				if ship.hp < ship.maxHp and (ship.cf.Position - ship.dock).Magnitude < 40 then
					ship.hp = math.min(ship.maxHp, ship.hp + N.RepairPerSecond * step)
					updateBar(ship)
				end
			else
				throttle, steer = raiderThink(ship)
			end
			local turnRate = steerShip(ship, throttle, steer, step)
			checkRam(ship, now)
			if ships[ship] then
				-- storms toss the ships about
				local storm = 1 + (workspace:GetAttribute("StormLevel") or 0) * 3
				local bob = math.sin(now * 1.3 + ship.length) * 0.25 * storm
				local roll = math.sin(now * 0.9) * math.rad(2) * storm - turnRate * 0.08
				local pitch = math.sin(now * 1.1 + ship.length) * math.rad(1) * storm
				ship.model:PivotTo(ship.cf * CFrame.new(0, bob, 0) * CFrame.Angles(pitch, 0, roll))
			end
		end
	end)
end

return BoatService
