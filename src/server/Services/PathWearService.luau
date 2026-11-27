--[[
	PathWearService
	Paths form where people walk. Every couple of seconds each villager and
	each player leaves a little wear on the 4x4-stud patch of ground under
	their feet. Grass on a well-trodden patch turns to bare earth, and a
	really busy one becomes a gravel road. Paved paths, fields and water are
	left alone.
]]

local Players = game:GetService("Players")

local PathWearService = {}

local services
local Terrain = workspace.Terrain
local M = Enum.Material

local STEP = 2 -- seconds between footstep passes
local DIRT = 14 -- wear for grass to become bare earth
local GRAVEL = 60 -- wear for earth to become a gravel road
local VOXEL = 4

local wear = {} -- ["x,z"] = wear
local lastCell = setmetatable({}, { __mode = "k" }) -- [part] = key (only walking wears a path)
local stage = {} -- ["x,z"] = 1 earth, 2 gravel

function PathWearService:Init(all)
	services = all
end

local function cellOf(pos: Vector3): (number, number)
	return math.floor(pos.X / VOXEL), math.floor(pos.Z / VOXEL)
end

local function repaint(cx: number, cz: number, y: number, from: { Enum.Material }, to: Enum.Material)
	local lo = Vector3.new(cx * VOXEL, math.floor((y - 6) / VOXEL) * VOXEL, cz * VOXEL)
	local region = Region3.new(lo, lo + Vector3.new(VOXEL, 12, VOXEL)):ExpandToGrid(VOXEL)
	for _, m in from do
		Terrain:ReplaceMaterial(region, VOXEL, m, to)
	end
end

local function step(who: BasePart, pos: Vector3, groundY: number, amount: number)
	local cx, cz = cellOf(pos)
	local key = cx .. "," .. cz
	if lastCell[who] == key then
		return -- standing still
	end
	lastCell[who] = key
	local w = (wear[key] or 0) + amount
	wear[key] = w
	local s = stage[key] or 0
	if s < 1 and w >= DIRT then
		stage[key] = 1
		repaint(cx, cz, groundY, { M.Grass, M.LeafyGrass }, M.Ground)
	elseif s < 2 and w >= GRAVEL then
		stage[key] = 2
		repaint(cx, cz, groundY, { M.Ground, M.Grass, M.LeafyGrass }, M.Pebble)
	end
end

function PathWearService:Start()
	task.spawn(function()
		while true do
			task.wait(STEP)
			for _, colony in services.ColonyService:All() do
				for _, v in colony.villagers do
					local body = v.body
					if body and body.Parent and not v.away then
						step(body, body.Position, body.Position.Y - (v.height or 2), 1)
					end
				end
			end
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					step(root, root.Position, root.Position.Y - 3, 1)
				end
			end
		end
	end)
end

return PathWearService
