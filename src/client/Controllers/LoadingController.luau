--[[
	LoadingController
	Shows a title card while the server shapes the valley and settles your
	people, then fades it away once your colony arrives.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LoadingController = {}

local controllers

function LoadingController:Init(allControllers)
	controllers = allControllers
end

function LoadingController:Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Loading"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100
	gui.ResetOnSpawn = false

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 18, 16)
	bg.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(46, 52, 58), Color3.fromRGB(18, 16, 14))
	gradient.Rotation = 90
	gradient.Parent = bg

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.42)
	title.Size = UDim2.fromOffset(700, 90)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Fantasy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(232, 206, 150)
	title.Text = "VIKING CITY"
	title.Parent = bg

	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.52)
	sub.Size = UDim2.fromOffset(700, 30)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.TextSize = 18
	sub.TextColor3 = Color3.fromRGB(200, 190, 170)
	sub.Text = "Shaping the valley..."
	sub.Parent = bg

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local lines = { "Shaping the valley...", "Growing the forests...", "Filling the fjord...", "Your settlers are landing..." }
	local i = 1
	while not controllers.StateController.State do
		task.wait(1.2)
		i = i % #lines + 1
		sub.Text = lines[i]
	end
	task.wait(0.5)
	local fade = TweenInfo.new(1.2)
	TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(sub, fade, { TextTransparency = 1 }):Play()
	task.wait(1.3)
	gui:Destroy()
end

return LoadingController
