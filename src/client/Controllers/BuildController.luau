--[[
	BuildController
	Placement mode: shows a see-through preview of the chosen building that
	snaps to your plot's grid. Green = you can build there, red = you can't.
	Click to build, R to rotate, Q to cancel.

	Demolish mode: hover one of your buildings (it turns red) and click.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Grid = require(Shared.Grid)
local Pointer = require(Shared.Pointer)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local BuildController = {}

local modeChanged = Instance.new("BindableEvent")
BuildController.ModeChanged = modeChanged.Event

local player = Players.LocalPlayer
local controllers

local mode = nil -- nil | { kind = "place", type = string } | { kind = "demolish" }
local rot = 0
local ghost: Model? = nil
local highlight: Highlight
local current = nil -- placement candidate { cx, cz, ok } or demolish target model
local busy = false

local GOOD = Color3.fromRGB(90, 220, 110)
local BAD = Color3.fromRGB(235, 80, 70)

local function plotGround(): BasePart?
	local index = player:GetAttribute("PlotIndex")
	local plots = workspace:FindFirstChild("Plots")
	local plot = index and plots and plots:FindFirstChild("Plot_" .. index)
	return plot and plot:FindFirstChild("Ground")
end

local function mouseRay(): (Vector3, Vector3)
	local camera = workspace.CurrentCamera
	local pos = Pointer.location()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	return ray.Origin, ray.Direction * 1000
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	highlight.Adornee = nil
	current = nil
end

-- Faint grid lines over your plot while you are placing something.
local gridLines: Folder? = nil
local function showGrid(visible: boolean)
	if gridLines then
		gridLines:Destroy()
		gridLines = nil
	end
	local origin = player:GetAttribute("PlotOrigin")
	if not visible or not origin then
		return
	end
	gridLines = Instance.new("Folder")
	gridLines.Name = "BuildGrid"
	local state = controllers.StateController.State
	local minX, minZ, maxX, maxZ = Grid.bounds(state and state.land)
	local corner = origin + Vector3.new(minX * Config.CELL, 0, minZ * Config.CELL)
	local sizeX, sizeZ = (maxX - minX) * Config.CELL, (maxZ - minZ) * Config.CELL
	for axis = 1, 2 do
		for i = 0, (axis == 1 and (maxX - minX) or (maxZ - minZ)) do
			local line = Instance.new("Part")
			line.Anchored = true
			line.CanCollide = false
			line.CanQuery = false
			line.CastShadow = false
			line.Material = Enum.Material.Neon
			line.Color = Color3.fromRGB(255, 236, 190)
			line.Transparency = 0.82
			local offset = i * Config.CELL
			if axis == 1 then
				line.Size = Vector3.new(0.12, 0.05, sizeZ)
				line.Position = corner + Vector3.new(offset, 0.08, sizeZ / 2)
			else
				line.Size = Vector3.new(sizeX, 0.05, 0.12)
				line.Position = corner + Vector3.new(sizeX / 2, 0.08, offset)
			end
			line.Parent = gridLines
		end
	end
	gridLines.Parent = workspace
end

local function setMode(newMode)
	clearGhost()
	mode = newMode
	showGrid(mode ~= nil and mode.kind == "place")
	if mode and mode.kind == "place" then
		ghost = ModelFactory.building(mode.type)
		ModelFactory.makeGhost(ghost)
		ghost.Parent = workspace
		highlight.Adornee = ghost
	end
	modeChanged:Fire(mode)
end

function BuildController:SelectBuild(buildingType: string)
	if mode and mode.type == buildingType then
		setMode(nil) -- clicking the same button again cancels
	else
		setMode({ kind = "place", type = buildingType })
	end
end

function BuildController:SelectDemolish()
	if mode and mode.kind == "demolish" then
		setMode(nil)
	else
		setMode({ kind = "demolish" })
	end
end

function BuildController:Cancel()
	setMode(nil)
end

local function updatePlacement()
	local ground = plotGround()
	local origin = player:GetAttribute("PlotOrigin")
	if not ground or not origin or not ghost then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { ground }
	local from, dir = mouseRay()
	local hit = workspace:Raycast(from, dir, params)
	if not hit then
		ghost.Parent = nil
		current = nil
		return
	end
	ghost.Parent = workspace

	local sx, sz = Grid.footprint(mode.type, rot)
	local cx, cz = Grid.worldToCell(origin, hit.Position, sx, sz)
	-- keep the preview inside the plot so it doesn't jump off the edge
	local state = controllers.StateController.State
	local land = state and state.land
	local minX, minZ, maxX, maxZ = Grid.bounds(land)
	cx = math.clamp(cx, minX, maxX - sx)
	cz = math.clamp(cz, minZ, maxZ - sz)

	local free = Grid.canPlace(controllers.StateController.Blocked, cx, cz, sx, sz, land)
	local affordable = state ~= nil and Grid.canAfford(state.resources, Config.Buildings[mode.type].Cost)
	local ok = free and affordable

	ghost:PivotTo(Grid.buildingCFrame(origin, cx, cz, sx, sz, rot))
	highlight.FillColor = ok and GOOD or BAD
	highlight.OutlineColor = ok and GOOD or BAD
	current = { cx = cx, cz = cz, ok = ok, affordable = affordable }
end

local function findOwnBuilding(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("BuildingId") then
			if inst:GetAttribute("OwnerUserId") == player.UserId then
				return inst
			end
			return nil
		end
		inst = inst.Parent
	end
	return nil
end

local function updateDemolish()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local from, dir = mouseRay()
	local hit = workspace:Raycast(from, dir, params)
	local target = hit and findOwnBuilding(hit.Instance)
	current = target
	highlight.Adornee = target
	highlight.FillColor = BAD
	highlight.OutlineColor = BAD
end

local function confirm()
	if busy or not mode then
		return
	end
	local StateController = controllers.StateController
	if mode.kind == "place" then
		if not current then
			return
		end
		if not current.affordable then
			StateController:LocalNotify("Not enough resources for " .. Config.Buildings[mode.type].Display, "bad")
			return
		end
		if not current.ok then
			StateController:LocalNotify("Can't build there. Clear trees and rocks first.", "bad")
			return
		end
		busy = true
		local ok, msg = Remotes.PlaceBuilding:InvokeServer(mode.type, current.cx, current.cz, rot)
		busy = false
		StateController:LocalNotify(msg, ok and "good" or "bad")
		-- stay in placement mode so you can place several in a row
	elseif mode.kind == "demolish" then
		if not current then
			return
		end
		busy = true
		local ok, msg = Remotes.DemolishBuilding:InvokeServer(current:GetAttribute("BuildingId"))
		busy = false
		StateController:LocalNotify(msg, ok and "good" or "bad")
	end
end

-- For the touch buttons (TouchController).
function BuildController:Confirm()
	confirm()
end

function BuildController:Rotate()
	if mode and mode.kind == "place" then
		rot = (rot + 1) % 4
	end
end

function BuildController:Mode()
	return mode
end

function BuildController:Init(allControllers)
	controllers = allControllers
end

function BuildController:Start()
	highlight = Instance.new("Highlight")
	highlight.Name = "BuildHighlight"
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	-- Parent it to a plain Folder: a Highlight with no Adornee lights up its
	-- parent, and we never want that to be the whole workspace.
	local fx = Instance.new("Folder")
	fx.Name = "ClientBuildFX"
	fx.Parent = workspace
	highlight.Parent = fx
	highlight:GetPropertyChangedSignal("Adornee"):Connect(function()
		highlight.Enabled = highlight.Adornee ~= nil
	end)

	RunService.RenderStepped:Connect(function()
		if not mode then
			return
		end
		if mode.kind == "place" then
			updatePlacement()
		else
			updateDemolish()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			confirm()
		elseif input.UserInputType == Enum.UserInputType.Touch then
			-- on a touch screen a tap moves the preview; the Place button builds
			-- (TouchController), so a stray tap never spends your wood
			return
		elseif input.KeyCode == Enum.KeyCode.R and mode and mode.kind == "place" then
			rot = (rot + 1) % 4
		elseif input.KeyCode == Enum.KeyCode.Q and mode then
			setMode(nil)
		end
	end)
end

return BuildController
