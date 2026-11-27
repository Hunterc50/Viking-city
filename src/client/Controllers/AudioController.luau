--[[
	AudioController
	Background sound on your own screen: music, wind, birds by day and the
	sea getting louder as you walk down to the fjord. Which sounds play is
	set in ReplicatedStorage > Shared > Sounds.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)

local AudioController = {}

-- The game's theme, "Over the Fjord" (music/VikingTheme.ogg in the project).
-- Once it's imported into Studio it shows up as a Sound named VikingTheme;
-- otherwise the Music slot in Sounds is used, if it has an ID.
local function themeId(): string?
	for _, root in { workspace, game:GetService("ReplicatedStorage"), SoundService } do
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") and string.find(d.Name, "VikingTheme") and d.SoundId ~= "" then
				return d.SoundId
			end
		end
	end
	local slot = Sounds.Slots.Music
	return slot and slot.Id ~= "" and slot.Id or nil
end

local theme: Sound?
local themeStarted = false

-- Plays the theme now (the title screen), then again now and then: a quiet
-- stretch of wind and birds between plays keeps it from wearing thin.
function AudioController:PlayTheme()
	if themeStarted then
		return
	end
	local id = themeId()
	if not id then
		return
	end
	themeStarted = true
	theme = Instance.new("Sound")
	theme.Name = "Theme"
	theme.SoundId = id
	theme.Volume = (Sounds.Slots.Music and Sounds.Slots.Music.Volume) or 0.3
	theme.Parent = SoundService
	task.spawn(function()
		while theme and theme.Parent do
			theme:Play()
			theme.Ended:Wait()
			task.wait(math.random(70, 150))
		end
	end)
end

function AudioController:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = SoundService
	task.delay(8, function()
		AudioController:PlayTheme() -- in case the title screen didn't start it
	end)
	local wind = Sounds.loop("Wind", folder)
	local birds = Sounds.loop("Birds", folder)
	local waves = Sounds.loop("Waves", folder)
	local base = {}
	for _, s in { wind, birds, waves } do
		if s then
			base[s] = s.Volume
		end
	end

	local camera = workspace.CurrentCamera
	RunService.Heartbeat:Connect(function()
		local pos = camera and camera.CFrame.Position or Vector3.zero
		if waves then
			-- the shore starts around z = -40; full volume out on the water
			local t = math.clamp((40 - pos.Z) / 120, 0.1, 1)
			waves.Volume = base[waves] * t
		end
		if birds then
			local hour = Lighting.ClockTime
			local day = (hour > 6 and hour < 19) and 1 or 0
			if workspace:GetAttribute("Season") == "Winter" then
				day *= 0.2
			end
			birds.Volume += (base[birds] * day - birds.Volume) * 0.02
		end
		if wind then
			-- windier up high and in winter
			local t = math.clamp(0.6 + pos.Y / 200, 0.6, 1.6) * (workspace:GetAttribute("Season") == "Winter" and 1.4 or 1)
			wind.Volume = base[wind] * t
		end
	end)
end

return AudioController
