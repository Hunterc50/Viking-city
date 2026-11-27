--[[
	SeasonFxController
	Weather around your camera that follows the season:
	  Winter  snowfall
	  Autumn  drifting gold and red leaves
	  Spring  a few floating pollen motes
]]

local RunService = game:GetService("RunService")

local SeasonFxController = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function emitter(parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Rate = 0
	e.Parent = parent
	return e
end

function SeasonFxController:Start()
	local box = Instance.new("Part")
	box.Name = "WeatherBox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(160, 1, 160)
	box.Parent = workspace

	local snow = emitter(box)
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.35)
	snow.Lifetime = NumberRange.new(6, 9)
	snow.Speed = NumberRange.new(6, 10)
	snow.SpreadAngle = Vector2.new(12, 12)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Acceleration = Vector3.new(1.5, 0, 0.8)
	snow.RotSpeed = NumberRange.new(-60, 60)

	local leaves = emitter(box)
	leaves.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(222, 170, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 100, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 60, 36)),
	})
	leaves.Size = NumberSequence.new(0.6)
	leaves.Lifetime = NumberRange.new(7, 10)
	leaves.Speed = NumberRange.new(3, 5)
	leaves.EmissionDirection = Enum.NormalId.Bottom
	leaves.Acceleration = Vector3.new(3, 0, 1)
	leaves.RotSpeed = NumberRange.new(-180, 180)
	leaves.Rotation = NumberRange.new(0, 360)

	local pollen = emitter(box)
	pollen.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220))
	pollen.Size = NumberSequence.new(0.2)
	pollen.Transparency = NumberSequence.new(0.4)
	pollen.Lifetime = NumberRange.new(8, 12)
	pollen.Speed = NumberRange.new(0.5, 1.5)
	pollen.SpreadAngle = Vector2.new(180, 180)
	pollen.LightEmission = 0.6

	local function update()
		local season = workspace:GetAttribute("Season")
		-- a winter storm is a blizzard
		snow.Rate = season == "Winter" and (450 + (workspace:GetAttribute("StormLevel") or 0) * 1100) or 0
		leaves.Rate = season == "Autumn" and 25 or 0
		pollen.Rate = season == "Spring" and 18 or 0
	end
	workspace:GetAttributeChangedSignal("Season"):Connect(update)
	workspace:GetAttributeChangedSignal("StormLevel"):Connect(update)
	update()

	-- low morning mist that hangs over the water and the valley floor
	local mistBox = Instance.new("Part")
	mistBox.Name = "MistBox"
	mistBox.Anchored = true
	mistBox.CanCollide = false
	mistBox.CanQuery = false
	mistBox.CanTouch = false
	mistBox.Transparency = 1
	mistBox.Size = Vector3.new(220, 1, 220)
	mistBox.Parent = workspace
	local mist = emitter(mistBox)
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(214, 222, 232))
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 30) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(0.7, 0.88), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(14, 20)
	mist.Speed = NumberRange.new(0.6, 1.6)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-4, 4)
	mist.Acceleration = Vector3.new(0.4, 0, 0.2)
	mist.LightInfluence = 0.8

	local Lighting = game:GetService("Lighting")
	local mistTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local cam = workspace.CurrentCamera.CFrame.Position
		-- hover above the camera's focus area so the weather surrounds you
		box.CFrame = CFrame.new(cam.X, cam.Y + 35, cam.Z)
		-- the mist stays low, at the water and on the valley floor
		mistBox.CFrame = CFrame.new(cam.X, 2.5, cam.Z)
		mistTimer += dt
		if mistTimer > 1 then
			mistTimer = 0
			local clock = Lighting.ClockTime
			-- strongest at dawn, a little in the evening, more in fog and autumn
			local dawn = math.clamp(1 - math.abs(clock - 6.5) / 2.5, 0, 1)
			local dusk = math.clamp(1 - math.abs(clock - 20.5) / 2, 0, 1) * 0.5
			local fog = workspace:GetAttribute("FogLevel") or 0
			local autumn = workspace:GetAttribute("Season") == "Autumn" and 0.3 or 0
			local high = math.clamp((cam.Y - 60) / 120, 0, 1) -- from high up it would only blur the view
			mist.Rate = math.max(dawn, dusk, fog, autumn) * 10 * (1 - high)
		end
	end)
end

return SeasonFxController
