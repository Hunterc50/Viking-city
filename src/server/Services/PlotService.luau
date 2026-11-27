--[[
	PlotService
	Gives each player their own square of land, builds the ground for it,
	and moves their character there when they spawn.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)

local PlotService = {}

local plotsFolder: Folder
local used = {} -- [index] = player
local drawBorders

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

-- Wooden posts at the corners and stakes along the edges, so you can see
-- your borders. Redrawn when the land grows.
drawBorders = function(plot: Model, origin: Vector3, land: number)
	for _, child in plot:GetChildren() do
		if child.Name == "BorderPost" or child.Name == "BorderStake" then
			child:Destroy()
		end
	end
	local corner, size = Grid.landRect(origin, land)
	local first
	for _, x in { 0, size.X } do
		for _, z in { 0, size.Z } do
			local post = makePart({
				Name = "BorderPost",
				Size = Vector3.new(1, 6, 1),
				Position = corner + Vector3.new(x, 3, z),
				Color = Color3.fromRGB(78, 54, 36),
				Material = Enum.Material.Wood,
				Parent = plot,
			})
			first = first or post
		end
	end
	-- low stakes every 4 cells along the sides and back
	local step = Config.CELL * 4
	local function stake(p: Vector3)
		makePart({
			Name = "BorderStake",
			Size = Vector3.new(0.5, 2.4, 0.5),
			Position = p + Vector3.new(0, 1.2, 0),
			Color = Color3.fromRGB(96, 70, 46),
			Material = Enum.Material.Wood,
			CanCollide = false,
			Parent = plot,
		})
	end
	for d = step, size.Z - 1, step do
		stake(corner + Vector3.new(0, 0, d))
		stake(corner + Vector3.new(size.X, 0, d))
	end
	for d = step, size.X - 1, step do
		stake(corner + Vector3.new(d, 0, size.Z))
	end
	local ground = plot:FindFirstChild("Ground")
	if ground then
		ground.Size = Vector3.new(size.X, 1, size.Z)
		ground.Position = corner + Vector3.new(size.X / 2, -0.5, size.Z / 2)
	end
	local sign = plot:FindFirstChild("OwnerSign")
	if sign and first then
		sign.Adornee = first
	end
end

-- Grows (or restores) the plot's visible borders to the colony's land stage.
function PlotService:ApplyLand(colony)
	if colony.plot then
		drawBorders(colony.plot, colony.origin, colony.land or 1)
	end
end

function PlotService:Init()
	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace
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
		-- Invisible: the grass you see is Terrain (WorldService). This part
		-- is what the build preview aims at. Resized when you buy land.
		Name = "Ground",
		Size = Vector3.new(size, 1, size),
		Position = origin + Vector3.new(size / 2, -0.5, size / 2),
		Transparency = 1,
		CanCollide = false,
		Parent = plot,
	})

	local sign = Instance.new("BillboardGui")
	sign.Name = "OwnerSign"
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
	sign.Parent = plot
	drawBorders(plot, origin, 1)

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
