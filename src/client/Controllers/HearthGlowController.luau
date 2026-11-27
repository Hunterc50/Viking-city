--[[
	HearthGlowController
	At dusk the homes light up: a soft, flickering firelight shines from every
	house in every village (Longhouse, Cottage, Great Hall), and goes out at
	dawn. Done on the client, so it costs the server nothing.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local HearthGlowController = {}

local function isNight(): boolean
	local t = Lighting.ClockTime
	return t >= 18.2 or t <= 6.2
end

local function isHome(model: Instance): boolean
	local kind = model:GetAttribute("BuildingType")
	local def = kind and Config.Buildings[kind]
	return def ~= nil and (def.Housing or 0) > 0
end

function HearthGlowController:Start()
	local lights = {} -- [model] = PointLight
	local phase = {} -- [PointLight] = flicker offset
	local timer = 0
	local flicker = 0

	local function refresh()
		local night = isNight()
		local plots = workspace:FindFirstChild("Plots")
		local seen = {}
		if plots then
			for _, plot in plots:GetChildren() do
				local buildings = plot:FindFirstChild("Buildings")
				if buildings then
					for _, model in buildings:GetChildren() do
						if model:IsA("Model") and isHome(model) then
							seen[model] = true
							local light = lights[model]
							if not light or not light.Parent then
								local anchor = Instance.new("Attachment")
								anchor.Name = "HearthGlow"
								local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
								if root then
									anchor.Parent = root
									anchor.WorldPosition = model:GetPivot().Position + Vector3.new(0, 3.5, 0)
									light = Instance.new("PointLight")
									light.Color = Color3.fromRGB(255, 164, 86)
									light.Range = 20
									light.Shadows = false
									light.Parent = anchor
									lights[model] = light
									phase[light] = math.random() * 10
								end
							end
							if light then
								light.Enabled = night
							end
						end
					end
				end
			end
		end
		for model, light in lights do
			if not seen[model] then
				lights[model] = nil
				phase[light] = nil
				if light.Parent then
					light.Parent:Destroy()
				end
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		timer += dt
		if timer >= 2 then
			timer = 0
			refresh()
		end
		-- a gentle flicker, as from a fire inside
		flicker += dt
		if flicker >= 0.12 then
			flicker = 0
			local t = os.clock()
			for _, light in lights do
				if light.Enabled then
					light.Brightness = 1.1 + math.sin(t * 7 + (phase[light] or 0)) * 0.12 + math.random() * 0.15
				end
			end
		end
	end)
end

return HearthGlowController
