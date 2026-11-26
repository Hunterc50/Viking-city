--[[
	PlotService
	Gives each player their own square of land, builds the ground for it,
	and moves their character there when they spawn.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local PlotService = {}

local plotsFolder: Folder
local used = {} -- [index] = player

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

function PlotService:Init()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	-- A big grassy landmass so the game works even in an empty place.
	if not workspace:FindFirstChild("Baseplate") then
		makePart({
			Name = "Land",
			Size = Vector3.new(2048, 4, 2048),
			Position = Vector3.new(512, Config.GROUND_Y - 2.5, 0),
			Color = Color3.fromRGB(86, 120, 70),
			Material = Enum.Material.Grass,
			Parent = workspace,
		})
	end

	-- A pleasant late-afternoon light.
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2
end

function PlotService:Start()
	Players.PlayerRemoving:Connect(function(player)
		self:Release(player)
	end)
end

-- Returns plotIndex, origin, plotModel. Called by ColonyService.
function PlotService:Assign(player: Player)
	local index
	for i = 1, Config.MAX_PLOTS do
		if not used[i] then
			index = i
			break
		end
	end
	if not index then
		warn("[PlotService] no free plots for " .. player.Name)
		return nil
	end
	used[index] = player

	local origin = Grid.plotOrigin(index)
	local size = Grid.PLOT_SIZE

	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. index
	plot:SetAttribute("OwnerUserId", player.UserId)

	makePart({
		Name = "Ground",
		Size = Vector3.new(size, 1, size),
		Position = origin + Vector3.new(size / 2, -0.5, size / 2),
		Color = Color3.fromRGB(104, 140, 78),
		Material = Enum.Material.Grass,
		Parent = plot,
	})
	-- A dirt apron in front of the plot where the player spawns.
	makePart({
		Name = "Apron",
		Size = Vector3.new(size, 1, Config.CELL * 2),
		Position = origin + Vector3.new(size / 2, -0.55, -Config.CELL),
		Color = Color3.fromRGB(120, 96, 66),
		Material = Enum.Material.Ground,
		CanQuery = false,
		Parent = plot,
	})

	-- Wooden marker posts at the corners so you can see your borders.
	for _, x in { 0, size } do
		for _, z in { 0, size } do
			makePart({
				Name = "BorderPost",
				Size = Vector3.new(1, 6, 1),
				Position = origin + Vector3.new(x, 3, z),
				Color = Color3.fromRGB(78, 54, 36),
				Material = Enum.Material.Wood,
				Parent = plot,
			})
		end
	end

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(260, 40)
	sign.StudsOffset = Vector3.new(0, 4, 0)
	sign.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 240, 210)
	label.TextStrokeTransparency = 0.4
	label.Text = player.DisplayName .. "'s settlement"
	label.Parent = sign
	sign.Parent = plot:FindFirstChild("BorderPost")

	for _, name in { "Buildings", "Nodes", "Villagers" } do
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = plot
	end

	plot.Parent = plotsFolder

	player:SetAttribute("PlotIndex", index)
	player:SetAttribute("PlotOrigin", origin)
	player.CameraMaxZoomDistance = 160

	local function spawnAtPlot(character: Model)
		task.defer(function()
			character:PivotTo(CFrame.new(origin + Vector3.new(size / 2, 4, -Config.CELL)) * CFrame.Angles(0, math.pi, 0))
		end)
	end
	player.CharacterAdded:Connect(spawnAtPlot)
	if player.Character then
		spawnAtPlot(player.Character)
	end

	return index, origin, plot
end

function PlotService:Release(player: Player)
	for i, p in used do
		if p == player then
			used[i] = nil
			local plot = plotsFolder:FindFirstChild("Plot_" .. i)
			if plot then
				plot:Destroy()
			end
		end
	end
end

return PlotService
