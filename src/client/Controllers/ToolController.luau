--[[
	ToolController
	Makes the tools feel alive on your side:
	  Bow      click to shoot where the mouse points (the server checks the hit)
	  Axe /
	  Pickaxe  click to swing (just for show; gathering uses the E prompt)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

local ToolController = {}

local player = Players.LocalPlayer
local lastShot = 0

local function aimPoint(): Vector3
	local camera = workspace.CurrentCamera
	local pos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return hit and hit.Position or ray.Origin + ray.Direction * 1000
end

local function swing(tool: Tool)
	local base = tool.Grip
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	local t = TweenService:Create(tool, info, { Grip = base * CFrame.Angles(math.rad(-70), 0, 0) })
	t:Play()
	t.Completed:Wait()
	tool.Grip = base
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		if tool.Name == "Bow" then
			local now = os.clock()
			if now - lastShot < Config.Bow.Cooldown then
				return
			end
			lastShot = now
			Remotes.ShootArrow:FireServer(aimPoint())
		else
			if tool.Name == "Axe" then
				Remotes.Strike:FireServer()
			end
			swing(tool)
		end
	end)
end

function ToolController:Start()
	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			hookTool(child)
		end
		container.ChildAdded:Connect(hookTool)
	end
	local function onCharacter(character)
		watch(character)
		watch(player:WaitForChild("Backpack"))
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return ToolController
