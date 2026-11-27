--[[
	CameraController
	A city-builder camera that follows your character from high above at an
	angle, like looking down over your village.

	  Mouse wheel        zoom in / out
	  Right mouse drag   turn and tilt the view
	  V                  switch to the normal Roblox camera and back
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

local player = Players.LocalPlayer

local enabled = true
local yaw = math.pi -- looking from the lake toward the mountains (+Z)
local pitch = math.rad(48)
local distance = 75
local targetDistance = 75
local focus: Vector3? = nil
local rotating = false

local MIN_DIST, MAX_DIST = 18, 260
local MIN_PITCH, MAX_PITCH = math.rad(15), math.rad(82)

function CameraController:IsEnabled(): boolean
	return enabled
end

function CameraController:Start()
	local camera = workspace.CurrentCamera

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 and enabled then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.KeyCode == Enum.KeyCode.V and not processed then
			enabled = not enabled
			if not enabled then
				camera.CameraType = Enum.CameraType.Custom
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not enabled then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
			targetDistance = math.clamp(targetDistance * (1 - input.Position.Z * 0.12), MIN_DIST, MAX_DIST)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
			yaw -= input.Delta.X * 0.008
			pitch = math.clamp(pitch + input.Delta.Y * 0.006, MIN_PITCH, MAX_PITCH)
		end
	end)

	RunService:BindToRenderStep("VikingCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not enabled then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		local target = root.Position
		focus = focus and focus:Lerp(target, math.min(1, dt * 8)) or target
		distance += (targetDistance - distance) * math.min(1, dt * 10)
		-- lower the angle a little when zoomed in close, like a tilt-shift view
		local p = pitch - math.rad(18) * (1 - (distance - MIN_DIST) / (MAX_DIST - MIN_DIST)) ^ 3
		camera.CFrame = CFrame.new(focus) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-p, 0, 0) * CFrame.new(0, 0, distance)
	end)
end

return CameraController
