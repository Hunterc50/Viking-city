--[[
	Server entry point.
	Loads every ModuleScript in the Services folder, calls :Init() on all of
	them (set-up, no cross-service calls yet), then :Start() (begin running).
	To add a new system, drop a new module in src/server/Services.
]]

local servicesFolder = script:WaitForChild("Services")

-- Models you edited in Workspace > ModelWorkshop become the game's models.
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("ModelFactory")).collectWorkshop()

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

for name, service in services do
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
	print("[VikingCity] started " .. name)
end
