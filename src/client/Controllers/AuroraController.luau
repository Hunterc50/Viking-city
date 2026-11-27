--[[
	AuroraController
	Northern lights over the mountains on clear nights in autumn and winter:
	tall green and violet curtains that ripple slowly across the sky.
	Drawn only on your own screen.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local AuroraController = {}

local BANDS = 3
local STRIPS = 46 -- narrow upright strips per band: together they ripple

local function strength(): number
	local clock = Lighting.ClockTime
	local night = 0
	if clock >= 20 or clock < 5 then
		local h = clock >= 20 and clock - 20 or clock + 4
		night = math.clamp(math.min(h, 9 - h) / 1.2, 0, 1)
	end
	local season = workspace:GetAttribute("Season")
	local seasonal = (season == "Winter" and 1) or (season == "Autumn" and 0.6) or (season == "Spring" and 0.25) or 0
	-- clouds and storms hide it
	local fog = workspace:GetAttribute("FogLevel") or 0
	local storm = workspace:GetAttribute("StormLevel") or 0
	return night * seasonal * (1 - math.max(fog, storm))
end

function AuroraController:Start()
	local folder = Instance.new("Folder")
	folder.Name = "Aurora"
	local strips = {}
	for b = 1, BANDS do
		local band = {
			z = 820 + b * 120, -- just behind the mountains
			x0 = -700 + b * 200,
			width = 3000 - b * 300,
			height = 220 + b * 50,
			base = 330 + b * 50,
			phase = b * 1.7,
			color = (b == 2) and Color3.fromRGB(150, 110, 255) or Color3.fromRGB(90, 255, 160),
			strips = {},
		}
		for s = 1, STRIPS do
			local p = Instance.new("Part")
			p.Name = "AuroraStrip"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = band.color
			p.Transparency = 1
			p.Size = Vector3.new(band.width / STRIPS + 6, band.height, 0.4)
			p.Parent = folder
			table.insert(band.strips, { part = p, u = (s - 0.5) / STRIPS })
		end
		table.insert(strips, band)
	end
	folder.Parent = workspace.CurrentCamera

	local shown = 0
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then
			return
		end
		acc = 0
		local target = strength()
		shown += (target - shown) * 0.02
		local t = os.clock()
		for _, band in strips do
			for _, s in band.strips do
				local p = s.part
				if shown < 0.02 then
					if p.Transparency < 1 then
						p.Transparency = 1
					end
				else
					local u = s.u
					local x = band.x0 + u * band.width
					local wave = math.sin(u * 7 + t * 0.15 + band.phase) * 140 + math.sin(u * 17 - t * 0.27) * 40
					local glow = (0.5 + 0.5 * math.sin(u * 11 + t * 0.4 + band.phase)) * (0.6 + 0.4 * math.sin(u * 3.1 - t * 0.2))
					local y = band.base + math.sin(u * 5 + t * 0.2) * 30
					p.CFrame = CFrame.new(x, y, band.z + wave) * CFrame.Angles(0, math.sin(u * 9 + t * 0.1) * 0.35, 0)
					p.Transparency = 1 - math.clamp(shown * glow * 0.55, 0, 0.55)
				end
			end
		end
	end)
end

return AuroraController
