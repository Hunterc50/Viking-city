--[[
	BoatController
	While you sit at a boat's helm, sends your W/A/S/D (or arrow keys) to the
	server, which moves the boat. F looses a volley of arrows.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local BoatController = {}

local player = Players.LocalPlayer

-- set by the on-screen buttons on phones and tablets (TouchController)
BoatController.TouchThrottle = 0
BoatController.TouchSteer = 0

local function down(...)
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

function BoatController:Volley()
	Remotes.BoatFire:FireServer()
end

local function atHelm(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:GetAttribute("Boat") == true
end

BoatController.AtHelm = atHelm

function BoatController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F and atHelm() then
			Remotes.BoatFire:FireServer()
		end
	end)

	local last = { 0, 0 }
	local timer = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not seat or not seat:GetAttribute("Boat") then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		local K = Enum.KeyCode
		local throttle = math.clamp((down(K.W, K.Up) and 1 or 0) - (down(K.S, K.Down) and 1 or 0) + BoatController.TouchThrottle, -1, 1)
		local steer = math.clamp((down(K.D, K.Right) and 1 or 0) - (down(K.A, K.Left) and 1 or 0) + BoatController.TouchSteer, -1, 1)
		timer += dt
		if throttle ~= last[1] or steer ~= last[2] or timer > 0.5 then
			timer = 0
			last = { throttle, steer }
			Remotes.BoatInput:FireServer(throttle, steer)
		end
	end)
end

return BoatController
