--[[
	TouchController
	On-screen buttons for phones and tablets (only shown on touch screens).
	  Always      Map size, Camera mode
	  Building    Place, Rotate, Cancel (a tap moves the preview first)
	  At a helm   hold Row / Back / Left / Right, and Volley
	The camera: pinch to zoom, twist two fingers to turn, drag two fingers to
	tilt (CameraController). Tools work by tapping where you want to strike
	or shoot. Prompts (gather, loot, talk) are tapped like buttons.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TouchController = {}

local controllers
local player = Players.LocalPlayer

local ACCENT = Color3.fromRGB(214, 170, 92)
local PANEL = Color3.fromRGB(34, 28, 22)

local function new(className, props)
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function roundButton(parent, text: string, size: number, pos: UDim2, textSize: number?)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextSize = textSize or 16,
		TextColor3 = ACCENT,
		TextWrapped = true,
		Text = text,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
	new("UIStroke", { Color = ACCENT, Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	return b
end

-- A button that sets a value while held down.
local function holdButton(parent, text: string, pos: UDim2, onDown, onUp)
	local b = roundButton(parent, text, 64, pos, 26)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onDown()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			onUp()
		end
	end)
	return b
end

function TouchController:Init(all)
	controllers = all
end

function TouchController:Start()
	if not UserInputService.TouchEnabled then
		return
	end
	local gui = new("ScreenGui", { Name = "TouchControls", ResetOnSpawn = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })

	-- always: small helpers on the right edge, above the jump button
	local side = new("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -190),
		Size = UDim2.fromOffset(60, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local mapButton = roundButton(side, "Map", 54, UDim2.new(0.5, 0, 0, 27), 14)
	mapButton.Activated:Connect(function()
		if controllers.MinimapController and controllers.MinimapController.Toggle then
			controllers.MinimapController:Toggle()
		end
	end)
	local camButton = roundButton(side, "Cam", 54, UDim2.new(0.5, 0, 0, 95), 14)
	camButton.Activated:Connect(function()
		controllers.CameraController:Toggle()
	end)

	-- building: Place / Rotate / Cancel, above the build menu
	local build = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -320),
		Size = UDim2.fromOffset(300, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local place = roundButton(build, "✔\nPlace", 68, UDim2.new(0.5, 0, 0.5, 0), 15)
	place.BackgroundColor3 = Color3.fromRGB(46, 84, 44)
	place.Activated:Connect(function()
		controllers.BuildController:Confirm()
	end)
	local rotate = roundButton(build, "⟳\nTurn", 60, UDim2.new(0.5, -96, 0.5, 0), 14)
	rotate.Activated:Connect(function()
		controllers.BuildController:Rotate()
	end)
	local cancel = roundButton(build, "✖\nStop", 60, UDim2.new(0.5, 96, 0.5, 0), 14)
	cancel.Activated:Connect(function()
		controllers.BuildController:Cancel()
	end)
	controllers.BuildController.ModeChanged:Connect(function(mode)
		build.Visible = mode ~= nil
		rotate.Visible = mode ~= nil and mode.kind == "place"
		place.Text = (mode and mode.kind == "demolish") and "✔\nTear down" or "✔\nPlace"
	end)

	-- sailing: hold buttons for the oars and rudder, and the volley
	local boat = new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 24, 1, -40),
		Size = UDim2.fromOffset(220, 220),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local Boat = controllers.BoatController
	holdButton(boat, "▲", UDim2.fromOffset(110, 40), function()
		Boat.TouchThrottle = 1
	end, function()
		Boat.TouchThrottle = 0
	end)
	holdButton(boat, "▼", UDim2.fromOffset(110, 180), function()
		Boat.TouchThrottle = -1
	end, function()
		Boat.TouchThrottle = 0
	end)
	holdButton(boat, "◀", UDim2.fromOffset(40, 110), function()
		Boat.TouchSteer = -1
	end, function()
		Boat.TouchSteer = 0
	end)
	holdButton(boat, "▶", UDim2.fromOffset(180, 110), function()
		Boat.TouchSteer = 1
	end, function()
		Boat.TouchSteer = 0
	end)
	local volley = roundButton(gui, "🏹\nVolley", 76, UDim2.new(1, -150, 1, -110), 15)
	volley.Visible = false
	volley.Activated:Connect(function()
		Boat:Volley()
	end)

	local wasAtHelm = false
	RunService.Heartbeat:Connect(function()
		local atHelm = Boat.AtHelm and Boat.AtHelm() or false
		if atHelm ~= wasAtHelm then
			wasAtHelm = atHelm
			boat.Visible = atHelm
			volley.Visible = atHelm
			if not atHelm then
				Boat.TouchThrottle = 0
				Boat.TouchSteer = 0
			end
		end
	end)
end

return TouchController
