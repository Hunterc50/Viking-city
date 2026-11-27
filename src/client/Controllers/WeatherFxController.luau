--[[
	WeatherFxController
	Draws the weather that WeatherService picks (workspace attributes
	Weather, FogLevel, StormLevel):
	  Storm  slanting rain around the camera, lightning flashes, thunder,
	         and a rain sound (Sounds slots Rain / Thunder)
	  Fog    low drifting mist close to the ground and water
	The haze itself is thickened on the server, so everyone sees the same sky.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local WeatherFxController = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

function WeatherFxController:Start()
	local box = Instance.new("Part")
	box.Name = "StormBox"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Transparency = 1
	box.Size = Vector3.new(140, 1, 140)
	box.Parent = workspace

	-- rain: long thin streaks, falling fast and a little sideways in the wind
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = SPARKLE
	rain.Color = ColorSequence.new(Color3.fromRGB(190, 205, 220))
	rain.Transparency = NumberSequence.new(0.35)
	rain.LightInfluence = 1
	rain.Size = NumberSequence.new(0.12)
	rain.Squash = NumberSequence.new(-3.5) -- stretched into streaks
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Lifetime = NumberRange.new(0.9, 1.2)
	rain.Speed = NumberRange.new(70, 85)
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Acceleration = Vector3.new(14, 0, 6)
	rain.Rate = 0
	rain.Parent = box

	-- fog: big soft puffs drifting low
	local mistBox = Instance.new("Part")
	mistBox.Name = "MistBox"
	mistBox.Anchored = true
	mistBox.CanCollide = false
	mistBox.CanQuery = false
	mistBox.CanTouch = false
	mistBox.Transparency = 1
	mistBox.Size = Vector3.new(220, 6, 220)
	mistBox.Parent = workspace
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.Color = ColorSequence.new(Color3.fromRGB(220, 224, 226))
	mist.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.82),
		NumberSequenceKeypoint.new(0.7, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	mist.LightInfluence = 1
	mist.Size = NumberSequence.new(28, 40)
	mist.Lifetime = NumberRange.new(10, 16)
	mist.Speed = NumberRange.new(1, 2.5)
	mist.SpreadAngle = Vector2.new(180, 10)
	mist.RotSpeed = NumberRange.new(-6, 6)
	mist.Rotation = NumberRange.new(0, 360)
	mist.Rate = 0
	mist.Parent = mistBox

	-- the flash is a brief bright grade on this screen only
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LightningFlash"
	flash.Brightness = 0
	flash.Parent = Lighting

	local rainSound = Sounds.loop("Rain", SoundService)
	if rainSound then
		rainSound.Volume = 0
	end
	local rainVolume = Sounds.Slots.Rain and Sounds.Slots.Rain.Volume or 0.5

	local function lightning()
		local seq = { 0.55, 0, 0.35, 0 }
		task.spawn(function()
			for i, b in seq do
				flash.Brightness = b
				task.wait(i % 2 == 1 and 0.06 or 0.09)
			end
			flash.Brightness = 0
			task.wait(Random.new():NextNumber(0.6, 2.4)) -- sound is slower than light
			Sounds.play("Thunder", SoundService)
		end)
	end

	local nextBolt = os.clock() + 8
	local rng = Random.new()
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera.CFrame.Position
		local storm = workspace:GetAttribute("StormLevel") or 0
		local fog = workspace:GetAttribute("FogLevel") or 0
		local season = workspace:GetAttribute("Season")

		box.CFrame = CFrame.new(cam.X - 20, cam.Y + 40, cam.Z - 8)
		-- in winter the storm falls as heavy snow (SeasonFxController), not rain
		rain.Rate = season == "Winter" and 0 or storm * 900
		if rainSound then
			rainSound.Volume = rainVolume * storm
		end

		mistBox.CFrame = CFrame.new(cam.X, math.max(2, cam.Y - 30), cam.Z)
		mist.Rate = fog * 14

		if storm > 0.6 and os.clock() > nextBolt then
			lightning()
			nextBolt = os.clock() + rng:NextNumber(6, 16)
		end
	end)

	-- fade the flash back if anything left it on
	workspace:GetAttributeChangedSignal("Weather"):Connect(function()
		TweenService:Create(flash, TweenInfo.new(0.3), { Brightness = 0 }):Play()
	end)
end

return WeatherFxController
