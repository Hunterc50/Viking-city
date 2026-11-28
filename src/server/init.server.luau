--[[
	Server entry point.
	Loads every ModuleScript in the Services folder, calls :Init() on all of
	them (set-up, no cross-service calls yet), then :Start() (begin running).
	To add a new system, drop a new module in src/server/Services.
]]

local servicesFolder = script:WaitForChild("Services")

-- Models you edited in Workspace > ModelWorkshop become the game's models.
local ModelFactory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelFactory"))
local okCollect, errCollect = pcall(ModelFactory.collectWorkshop)
if not okCollect then
	warn("[VikingCity] couldn't use ModelWorkshop: " .. tostring(errCollect))
end

-- Our uploaded textures arrive as decals: find the image inside each one in
-- the background (never holding up the world), then dress what is built.
local AssetIds = require(game:GetService("ReplicatedStorage").Shared.AssetIds)
task.spawn(function()
	local okTex, errTex = pcall(AssetIds.resolveTextures, 20)
	if not okTex then
		warn("[VikingCity] couldn't look up textures: " .. tostring(errTex))
		return
	end
	local okDress, errDress = pcall(ModelFactory.textureAll, workspace)
	if not okDress then
		warn("[VikingCity] couldn't put textures on: " .. tostring(errDress))
	end
end)

local services = {}
for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end

-- Each service starts on its own, so one error can't stop the whole game.
for name, service in services do
	if service.Init then
		local ok, err = pcall(service.Init, service, services)
		if not ok then
			warn("[VikingCity] " .. name .. " failed to set up: " .. tostring(err))
		end
	end
end

-- Workspace > ShowModelWorkshop ticked: lay out every model in the meadow
-- while playing, so it can be copied (Ctrl+C), then pasted back in after
-- pressing Stop, where it can be edited and saved.
local show = workspace:FindFirstChild("ShowModelWorkshop")
if show and show:IsA("BoolValue") and show.Value then
	local ok, err = pcall(function()
		ModelFactory.bakeTemplates()
		for _, item in workspace.ModelWorkshop:GetChildren() do
			local handle = item:IsA("Tool") and item:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.CanTouch = false -- so walking past doesn't pick the tool up
			end
		end
	end)
	if not ok then
		warn("[VikingCity] couldn't lay out ModelWorkshop: " .. tostring(err))
	end
	print("[VikingCity] ModelWorkshop is in Workspace: copy it, press Stop, paste it into Workspace")
end

for name, service in services do
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
	print("[VikingCity] started " .. name)
end
