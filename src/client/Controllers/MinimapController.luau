--[[
	MinimapController
	A round-cornered map in the top right that turns with your camera:
	your plot (gold), other plots, rival holds (red), Ottar's stalls
	(yellow), ships (blue = yours, red = enemy), other players (white) and
	you (the arrow in the middle). Press M to make it bigger or smaller.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local MinimapController = {}

local player = Players.LocalPlayer
local SIZES = { 200, 320 }
local RANGE = 360 -- studs from the centre to the edge

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

function MinimapController:Start()
	local gui = new("ScreenGui", { Name = "Minimap", ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	local sizeIndex = 1
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 216),
		Size = UDim2.fromOffset(SIZES[1], SIZES[1]),
		BackgroundColor3 = Color3.fromRGB(58, 72, 46),
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Parent = gui,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = frame })
	new("UIStroke", { Color = Color3.fromRGB(214, 170, 92), Thickness = 2, Transparency = 0.35, Parent = frame })
	local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = frame })
	new("TextLabel", {
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(230, 220, 200),
		TextStrokeTransparency = 0.5,
		Text = "M: bigger map",
		ZIndex = 5,
		Parent = frame,
	})

	-- fixed things in the world: plots, holds, stalls, the shoreline
	local fixed = {}
	local function addFixed(pos: Vector3, size: Vector2, color: Color3, label: string?, round: boolean?, z: number?)
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z or 2, Parent = layer })
		if round then
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
		end
		local text
		if label then
			text = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 0, -2),
				Size = UDim2.fromOffset(120, 14),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.3,
				Text = label,
				ZIndex = 4,
				Parent = f,
			})
		end
		table.insert(fixed, { frame = f, pos = pos, size = size, text = text })
		return f
	end

	-- the fjord: a wide band of water beyond the beach
	local water = addFixed(Vector3.new(800, 0, -40 - 400), Vector2.new(4000, 800), Color3.fromRGB(56, 88, 112), nil, false, 1)
	water.BackgroundTransparency = 0.1
	local plotFrames = {}
	for i = 1, Config.MAX_PLOTS do
		local o = Grid.plotOrigin(i)
		local centre = o + Vector3.new(Grid.PLOT_SIZE / 2, 0, Grid.PLOT_SIZE / 2)
		local f = addFixed(centre, Vector2.new(Grid.PLOT_SIZE, Grid.PLOT_SIZE), Color3.fromRGB(110, 120, 80))
		f.BackgroundTransparency = 0.45
		plotFrames[i] = f
		addFixed(Vector3.new(o.X + 100, 0, -16), Vector2.new(10, 10), Color3.fromRGB(240, 200, 80), nil, true, 3)
	end
	for _, rival in Config.Rivals do
		local f = addFixed(rival.Center, Vector2.new(rival.Radius * 2, rival.Radius * 2), Color3.fromRGB(170, 60, 50), rival.Name, true)
		f.BackgroundTransparency = 0.35
	end

	-- moving markers (pooled)
	local pool = {}
	local function dot(i: number): Frame
		local f = pool[i]
		if not f then
			f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, ZIndex = 6, Parent = layer })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
			new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.4, Parent = f })
			pool[i] = f
		end
		f.Visible = true
		return f
	end

	-- you: an arrow in the middle, always pointing up (the map turns instead)
	new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 230, 150),
		TextStrokeTransparency = 0.2,
		Text = "▲",
		ZIndex = 8,
		Parent = frame,
	})
	MinimapController.Toggle = function()
		sizeIndex = sizeIndex % #SIZES + 1
		frame.Size = UDim2.fromOffset(SIZES[sizeIndex], SIZES[sizeIndex])
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			MinimapController:Toggle()
		end
	end)

	local camera = workspace.CurrentCamera
	local timer = 0
	RunService.RenderStepped:Connect(function(dt)
		timer += dt
		if timer < 1 / 20 then
			return
		end
		timer = 0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local centre = root and root.Position or camera.Focus.Position
		local look = camera.CFrame.LookVector
		local fwd = Vector3.new(look.X, 0, look.Z)
		fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, 1)
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local px = SIZES[sizeIndex]
		local k = (px / 2) / RANGE
		local yaw = math.deg(math.atan2(fwd.X, fwd.Z))

		local function place(f: GuiObject, pos: Vector3)
			local rel = pos - centre
			local sx, sy = rel:Dot(right), rel:Dot(fwd)
			f.Position = UDim2.fromOffset(px / 2 + sx * k, px / 2 - sy * k)
		end

		local mine = player:GetAttribute("PlotIndex")
		for i, f in plotFrames do
			f.BackgroundColor3 = i == mine and Color3.fromRGB(214, 170, 92) or Color3.fromRGB(110, 120, 80)
		end
		for _, item in fixed do
			place(item.frame, item.pos)
			item.frame.Size = UDim2.fromOffset(math.max(item.size.X * k, 4), math.max(item.size.Y * k, 4))
			item.frame.Rotation = yaw
			if item.text then
				item.text.Rotation = -yaw
			end
		end

		local n = 0
		for _, other in Players:GetPlayers() do
			local r = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if r then
				n += 1
				local f = dot(n)
				f.BackgroundColor3 = Color3.new(1, 1, 1)
				f.Size = UDim2.fromOffset(7, 7)
				place(f, r.Position)
			end
		end
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("Ship") then
				n += 1
				local f = dot(n)
				local owner = child:GetAttribute("OwnerUserId")
				f.BackgroundColor3 = owner == player.UserId and Color3.fromRGB(90, 170, 255) or (owner == 0 and Color3.fromRGB(230, 70, 60) or Color3.fromRGB(240, 240, 240))
				f.Size = UDim2.fromOffset(10, 10)
				place(f, child:GetPivot().Position)
			end
		end
		for i = n + 1, #pool do
			pool[i].Visible = false
		end
	end)
end

return MinimapController
