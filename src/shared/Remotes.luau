--[[
	Remotes
	The server creates the network objects; the client waits for them.
	Require this module from either side and use e.g. Remotes.PlaceBuilding.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"ColonyState", -- server -> client: full colony snapshot every tick
	"Notify", -- server -> client: short message for the toast feed
	"ShootArrow", -- client -> server: (aimPosition) when the Bow is used
	"Strike", -- client -> server: an Axe swing (server finds who it hits)
	"BoatInput", -- client -> server: (throttle, steer) while sailing
	"BoatFire", -- client -> server: loose a volley from your ship (F at the helm)
}

local FUNCTIONS = {
	"PlaceBuilding", -- client -> server: (type, cx, cz, rot) -> ok, message
	"DemolishBuilding", -- client -> server: (buildingId) -> ok, message
	"Research", -- client -> server: (techId) -> ok, message
}

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		Remotes[name] = remote
	end
	folder.Parent = ReplicatedStorage
else
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	for _, name in EVENTS do
		Remotes[name] = folder:WaitForChild(name)
	end
	for _, name in FUNCTIONS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
