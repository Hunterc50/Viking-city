--[[
	AmbienceController
	Little touches of life that only need to run on your screen:
	  - shoreline foam gently washes in and out
	  - gulls circle lazily over the fjord
]]

local RunService = game:GetService("RunService")

local AmbienceController = {}

local GULLS = 14

local function makeGull(): Model
	local model = Instance.new("Model")
	model.Name = "Gull"
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CastShadow = false
	body.Size = Vector3.new(0.5, 0.45, 1.4)
	body.Color = Color3.fromRGB(240, 240, 236)
	body.Parent = model
	for _, side in { -1, 1 } do
		local wing = Instance.new("Part")
		wing.Name = side < 0 and "WingL" or "WingR"
		wing.Anchored = true
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CastShadow = false
		wing.Size = Vector3.new(2.2, 0.08, 0.7)
		wing.Color = Color3.fromRGB(225, 228, 230)
		wing.Parent = model
	end
	model.PrimaryPart = body
	return model
end

function AmbienceController:Start()
	-- Wait for the server to finish building the shore.
	local foamFolder = workspace:WaitForChild("ShoreFoam", 120)
	local foam = {}
	if foamFolder then
		for _, part in foamFolder:GetChildren() do
			if part:IsA("BasePart") then
				table.insert(foam, { part = part, base = part.CFrame, alpha = part.Transparency, phase = math.random() * math.pi * 2 })
			end
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Gulls"
	folder.Parent = workspace
	local gulls = {}
	for i = 1, GULLS do
		local model = makeGull()
		model.Parent = folder
		gulls[i] = {
			model = model,
			center = Vector3.new(math.random(-200, 1800), math.random(28, 60), math.random(-360, -90)),
			radius = math.random(30, 90),
			speed = (math.random() * 0.15 + 0.1) * (math.random() < 0.5 and -1 or 1),
			angle = math.random() * math.pi * 2,
			flap = math.random() * 10,
		}
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()

		for _, g in gulls do
			g.angle += g.speed * dt
			local pos = g.center + Vector3.new(math.cos(g.angle) * g.radius, math.sin(now * 0.4 + g.flap) * 3, math.sin(g.angle) * g.radius)
			local ahead = g.center + Vector3.new(math.cos(g.angle + 0.05 * math.sign(g.speed)) * g.radius, 0, math.sin(g.angle + 0.05 * math.sign(g.speed)) * g.radius)
			local cf = CFrame.lookAt(pos, Vector3.new(ahead.X, pos.Y, ahead.Z)) * CFrame.Angles(0, 0, math.sign(g.speed) * 0.35)
			local flap = math.sin(now * 6 + g.flap) * 0.5
			local model = g.model
			model.Body.CFrame = cf
			model.WingL.CFrame = cf * CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-1.1, 0, 0)
			model.WingR.CFrame = cf * CFrame.new(0.25, 0, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(1.1, 0, 0)
		end

		-- foam only needs ~15 updates a second
		accumulator += dt
		if accumulator < 1 / 15 then
			return
		end
		accumulator = 0
		local camPos = workspace.CurrentCamera.CFrame.Position
		for _, f in foam do
			if (f.base.Position - camPos).Magnitude > 450 then
				continue -- too far away to notice
			end
			local wave = math.sin(now * 0.9 + f.phase)
			f.part.Transparency = math.clamp(f.alpha + wave * 0.18, 0, 0.97)
			f.part.CFrame = f.base * CFrame.new(0, 0, wave * 0.6)
		end
	end)
end

return AmbienceController
