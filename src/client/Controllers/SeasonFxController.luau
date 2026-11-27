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

	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera.CFrame.Position
		-- hover above the camera's focus area so the weather surrounds you
		box.CFrame = CFrame.new(cam.X, cam.Y + 35, cam.Z)
	end)
end

return SeasonFxController
