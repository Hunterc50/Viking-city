--[[
	ToolController
	Makes the tools feel alive on your side:
	  Bow      click to shoot where the mouse points (the server checks the hit)
	  Axe /
	  Pickaxe  click to swing at a tree or rock (or an enemy)
	  Sword    click to fight
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)
local Pointer = require(Shared.Pointer)

local ToolController = {}

local player = Players.LocalPlayer
local lastShot = 0

local function aimPoint(): Vector3
	local camera = workspace.CurrentCamera
	local pos = Pointer.location()
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	return hit and hit.Position or ray.Origin + ray.Direction * 1000
end

-- A two-handed overhead chop: wind the arm up and back, lean in, bring it
-- down hard, then recover. Works on the character's own shoulder and waist
-- joints, so there's no animation to upload. Other tools get a quicker swing.
local swinging = false

local function joint(character: Model, r15: string, r15Part: string, r6: string): Motor6D?
	local part = character:FindFirstChild(r15Part)
	local j = part and part:FindFirstChild(r15)
	if j and j:IsA("Motor6D") then
		return j
	end
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
	j = torso and torso:FindFirstChild(r6)
	return (j and j:IsA("Motor6D")) and j or nil
end

local function swing(tool: Tool)
	if swinging then
		return
	end
	swinging = true
	local character = player.Character
	local heavy = tool.Name == "Axe" or tool.Name == "Pickaxe"
	local shoulder = character and joint(character, "RightShoulder", "RightUpperArm", "Right Shoulder")
	local waist = character and joint(character, "Waist", "UpperTorso", "RootJoint")
	local r6 = shoulder ~= nil and shoulder.Name == "Right Shoulder"
	-- the tool's true resting grip, remembered once, so quick clicks can never
	-- leave it turned (that was the sideways axe)
	local baseGrip = tool:GetAttribute("RestGrip")
	if typeof(baseGrip) ~= "CFrame" then
		baseGrip = tool.Grip
		tool:SetAttribute("RestGrip", baseGrip)
	end
	local baseShoulder = shoulder and shoulder.C0
	local baseWaist = waist and waist.C0

	-- arm angle: how far the arm is raised forward from hanging (degrees)
	local function arm(deg: number): CFrame?
		if not baseShoulder then
			return nil
		end
		if r6 then
			return baseShoulder * CFrame.Angles(0, 0, math.rad(deg))
		end
		return baseShoulder * CFrame.Angles(math.rad(deg), 0, 0)
	end
	local function lean(deg: number, twist: number): CFrame?
		if not baseWaist or r6 then
			return baseWaist
		end
		return baseWaist * CFrame.Angles(math.rad(deg), math.rad(twist), 0)
	end
	local function step(duration: number, style: Enum.EasingStyle, dir: Enum.EasingDirection, armDeg: number, leanDeg: number, twist: number, gripDeg: number)
		local info = TweenInfo.new(duration, style, dir)
		-- tilt in the hand's own frame, so a tool turned round in its grip (the axe) still chops forward
		local tweens = { TweenService:Create(tool, info, { Grip = CFrame.new(baseGrip.Position) * CFrame.Angles(math.rad(gripDeg), 0, 0) * baseGrip.Rotation }) }
		if shoulder then
			table.insert(tweens, TweenService:Create(shoulder, info, { C0 = arm(armDeg) }))
		end
		if waist and not r6 then
			table.insert(tweens, TweenService:Create(waist, info, { C0 = lean(leanDeg, twist) }))
		end
		for _, t in tweens do
			t:Play()
		end
		task.wait(duration)
	end

	local ok = pcall(function()
		if heavy then
			-- wind up: arm high and back, body turning away, blade cocked
			step(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 165, 8, 20, 35)
			task.wait(0.04)
			-- the chop: fast and hard, leaning into it
			step(0.11, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 45, -18, -10, -60)
			task.wait(0.08)
			-- recover
			step(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, 0, 0, 0)
		else
			step(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 120, 4, 25, 20)
			step(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 40, -10, -25, -50)
			step(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, 0, 0, 0)
		end
	end)
	-- always put everything back exactly, even if the character changed
	if tool.Parent then
		tool.Grip = baseGrip
	end
	if shoulder and shoulder.Parent and baseShoulder then
		shoulder.C0 = baseShoulder
	end
	if waist and waist.Parent and baseWaist then
		waist.C0 = baseWaist
	end
	if not ok then
		warn("[ToolController] swing failed")
	end
	swinging = false
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool:SetAttribute("RestGrip", tool.Grip)
	tool.Activated:Connect(function()
		if tool.Name == "Bow" then
			local now = os.clock()
			if now - lastShot < Config.Bow.Cooldown then
				return
			end
			lastShot = now
			Remotes.ShootArrow:FireServer(aimPoint())
		else
			if Config.Combat.MeleeDamage[tool.Name] then
				Remotes.Strike:FireServer()
			end
			task.spawn(swing, tool)
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
