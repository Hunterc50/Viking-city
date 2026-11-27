--[[
	Server entry point.
	Loads every ModuleScript in the Services folder, calls :Init() on all of
	them (set-up, no cross-service calls yet), then :Start() (begin running).
	To add a new system, drop a new module in src/server/Services.
]]

local servicesFolder = script:WaitForChild("Services")

-- Models you edited in Workspace > ModelWorkshop become the game's models.
local ModelFactory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelFactory"))
ModelFactory.collectWorkshop()

local services = {}
for _, module in servicesFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module)
	end
end

for _, service in services do
	if service.Init then
		service:Init(services)
	end
end

-- Workspace > ShowModelWorkshop ticked: lay out every model in the meadow
-- while playing, so it can be copied (Ctrl+C), then pasted back in after
-- pressing Stop, where it can be edited and saved.
local show = workspace:FindFirstChild("ShowModelWorkshop")
if show and show:IsA("BoolValue") and show.Value then
	ModelFactory.bakeTemplates()
	for _, item in workspace.ModelWorkshop:GetChildren() do
		local handle = item:IsA("Tool") and item:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			handle.CanTouch = false -- so walking past doesn't pick the tool up
		end
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
