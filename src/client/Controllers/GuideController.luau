--[[
	GuideController
	The tutorial's gold marker. It points at the thing your current saga goal
	needs: the nearest tree to chop, rock to break, deer to hunt, Ottar's
	stall, Greywater's gate or your jetty. For a building goal it points home
	and says which tab to open. It fades once you are close.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local GuideController = {}

local controllers
local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(240, 196, 92)

function GuideController:Init(all)
	controllers = all
end

-- Which build-menu tab holds a building.
local function tabOf(building: string): string?
	for _, cat in Config.BuildCategories or {} do
		for _, b in cat.Buildings do
			if b == building then
				return cat.Name
			end
		end
	end
	return nil
end

local function myPlot(): Instance?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	return index and plots and plots:FindFirstChild("Plot_" .. index)
end

local function nearestIn(container: Instance?, from: Vector3, accept): Vector3?
	if not container then
		return nil
	end
	local best, bestD = nil, math.huge
	for _, m in container:GetChildren() do
		if m:IsA("Model") and accept(m) then
			local p = m:GetPivot().Position
			local d = (p - from).Magnitude
			if d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

local function home(): Vector3
	local origin = player:GetAttribute("PlotOrigin")
	if typeof(origin) ~= "Vector3" then
		return Vector3.zero
	end
	return origin + Vector3.new(Grid.PLOT_SIZE / 2, 0, Grid.PLOT_SIZE / 2)
end

-- Where the current goal is, and a short line on what to do there.
local function target(from: Vector3): (Vector3?, string?)
	local state = controllers.StateController.State
	local q = state and state.quest
	if not q or q.done then
		return nil
	end
	local quest = Config.Quests[q.index]
	if not quest then
		return nil
	end
	if quest.Kind == "building" then
		local tab = tabOf(quest.Building)
		local def = Config.Buildings[quest.Building]
		local name = def and def.Display or quest.Building
		local line = "Build a " .. name .. (tab and (" (" .. tab .. " tab)") or "")
		if (from - home()).Magnitude < Grid.PLOT_SIZE * 0.8 then
			return nil, line -- already home: the tip is enough
		end
		return home(), line
	elseif quest.Stat == "chop" or quest.Stat == "mine" then
		local kind = quest.Stat == "chop" and "Tree" or "Rock"
		local plot = myPlot()
		local p = nearestIn(plot and plot:FindFirstChild("Nodes"), from, function(m)
			return m:GetAttribute("NodeKind") == kind
		end)
		return p, quest.Stat == "chop" and "Press 1, then click the tree" or "Press 2, then click the rock"
	elseif quest.Stat == "deer" then
		return nearestIn(workspace:FindFirstChild("Wildlife"), from, function()
			return true
		end), "Press 3, aim and click to shoot"
	elseif quest.Stat == "trade" then
		return nearestIn(workspace, from, function(m)
			return m.Name == "TraderStall"
		end), "Hold E at Ottar's stall"
	elseif quest.Stat == "plunder" or quest.Stat == "gate" then
		local rival = Config.Rivals[1]
		local a = rival.GateAngle or 0
		return rival.Center + Vector3.new(math.cos(a), 0, math.sin(a)) * (rival.Radius + 6), "Chop down the gate, then plunder a chest"
	elseif quest.Stat == "launch" then
		local origin = player:GetAttribute("PlotOrigin")
		if typeof(origin) == "Vector3" then
			return Vector3.new(origin.X + Grid.PLOT_SIZE * 0.25, 2, -76), "Hold E at the end of your jetty"
		end
	elseif quest.Kind == "tech" then
		return nil, "Press T to research"
	end
	return nil
end

-- If the server couldn't build the valley, say so on screen, so a
-- screenshot shows what went wrong.
local function showTerrainError()
	local function show()
		local text = workspace:GetAttribute("TerrainError")
		if not text then
			return
		end
		local gui = Instance.new("ScreenGui")
		gui.Name = "TerrainError"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 200
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 60)
		label.Size = UDim2.fromOffset(720, 60)
		label.BackgroundColor3 = Color3.fromRGB(90, 24, 20)
		label.BackgroundTransparency = 0.1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 14
		label.TextWrapped = true
		label.Text = "World problem (please send a screenshot): " .. tostring(text)
		label.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		task.delay(40, function()
			gui:Destroy()
		end)
	end
	show()
	workspace:GetAttributeChangedSignal("TerrainError"):Connect(show)
end

function GuideController:Start()
	task.spawn(showTerrainError)
	-- the marker: a soft pillar of light and a sign above it
	local beam = Instance.new("Part")
	beam.Name = "GuideBeam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = GOLD
	beam.Transparency = 0.75
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(60, 1.2, 1.2)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = beam

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 70)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 34, 0)
	sign.AlwaysOnTop = true
	sign.LightInfluence = 0
	sign.Adornee = beam
	local arrow = Instance.new("TextLabel")
	arrow.Size = UDim2.new(1, 0, 0, 30)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.TextSize = 28
	arrow.TextColor3 = GOLD
	arrow.TextStrokeTransparency = 0.3
	arrow.Text = "▼"
	arrow.Position = UDim2.fromOffset(0, 38)
	arrow.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 38)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Garamond
	label.TextSize = 20
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(245, 235, 210)
	label.TextStrokeTransparency = 0.35
	label.Parent = sign

	local folder = Instance.new("Folder")
	folder.Name = "Guide"
	folder.Parent = workspace.CurrentCamera -- only you can see it
	sign.Parent = player:WaitForChild("PlayerGui")

	local current: Vector3? = nil
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local intro = controllers.IntroController and controllers.IntroController.Active
		if acc > 0.5 then
			acc = 0
			if root and not intro then
				local line
				current, line = target(root.Position)
				label.Text = line or ""
			else
				current = nil
			end
		end
		local show = current ~= nil and root ~= nil and (current - root.Position).Magnitude > 12
		if show then
			local pulse = 0.72 + math.sin(os.clock() * 3) * 0.06
			beam.Transparency = pulse
			beam.CFrame = CFrame.new(current + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
			beam.Parent = folder
			sign.Enabled = true
			local d = math.floor((current - root.Position).Magnitude)
			arrow.Text = "▼  " .. d .. " m"
		else
			beam.Parent = nil
			sign.Enabled = false
		end
	end)
end

return GuideController
