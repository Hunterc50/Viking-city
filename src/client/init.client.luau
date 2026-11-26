--[[
	Client entry point.
	Loads every ModuleScript in the Controllers folder, then calls :Init()
	and :Start() on each, the same pattern as the server.
]]

local controllersFolder = script:WaitForChild("Controllers")

local controllers = {}
for _, module in controllersFolder:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module)
	end
end

for _, controller in controllers do
	if controller.Init then
		controller:Init(controllers)
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(function()
			controller:Start()
		end)
	end
end
