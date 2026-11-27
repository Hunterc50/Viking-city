--[[
	UIScaleController
	Shrinks every screen of the interface to fit smaller windows, laptops,
	tablets and phones, so nothing runs off the edge. Designed at 1500x860;
	never scales up, never below 60%.
]]

local Players = game:GetService("Players")

local UIScaleController = {}

local DESIGN = Vector2.new(1500, 860)

local function scaleFor(viewport: Vector2): number
	return math.clamp(math.min(viewport.X / DESIGN.X, viewport.Y / DESIGN.Y), 0.6, 1)
end

function UIScaleController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local scales = {}

	local function apply()
		local s = scaleFor(camera.ViewportSize)
		for _, ui in scales do
			ui.Scale = s
		end
	end

	local function hook(gui: Instance)
		if gui:IsA("ScreenGui") and not gui:FindFirstChild("AutoScale") then
			local ui = Instance.new("UIScale")
			ui.Name = "AutoScale"
			ui.Parent = gui
			table.insert(scales, ui)
			apply()
		end
	end

	for _, gui in playerGui:GetChildren() do
		hook(gui)
	end
	playerGui.ChildAdded:Connect(hook)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
end

return UIScaleController
