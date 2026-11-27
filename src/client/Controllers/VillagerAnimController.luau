--[[
	VillagerAnimController
	Makes the little villager figures walk: their arms and legs swing in
	step while they move and come to rest when they stop. Purely visual and
	done on each player's own screen (the server only moves the bodies).
	Only villagers near the camera are animated, to keep it cheap.
]]

local RunService = game:GetService("RunService")

local VillagerAnimController = {}

local figures = {} -- [model] = { body, limbs = { {weld, hip, half, side, isArm} }, last, phase, amount }
local RANGE = 160

local function track(model: Model)
	if figures[model] or not model:GetAttribute("Villager") then
		return
	end
	local body = model.PrimaryPart or model:FindFirstChild("Body")
	if not body then
		return
	end
	local limbs = {}
	for _, part in model:GetChildren() do
		local joint = part:IsA("BasePart") and part:FindFirstChild("Joint")
		if joint and joint:IsA("Weld") and part:GetAttribute("Hip") then
			table.insert(limbs, {
				weld = joint,
				hip = part:GetAttribute("Hip"),
				half = part:GetAttribute("HalfLen") or 0.5,
				side = part:GetAttribute("Side") or 1,
				isArm = part.Name == "Arm",
			})
		end
	end
	if #limbs == 0 then
		return
	end
	figures[model] = { body = body, limbs = limbs, last = body.Position, phase = math.random() * 6, amount = 0 }
end

function VillagerAnimController:Start()
	-- villager models appear inside every plot's Villagers folder; watch the
	-- whole workspace for them (they can be rebuilt when someone grows up)
	workspace.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") and inst:GetAttribute("Villager") then
			task.defer(track, inst)
		end
	end)
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("Model") and inst:GetAttribute("Villager") then
			track(inst)
		end
	end

	local camera = workspace.CurrentCamera
	RunService.RenderStepped:Connect(function(dt)
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		for model, f in figures do
			if not model.Parent then
				figures[model] = nil
				continue
			end
			local pos = f.body.Position
			if (pos - camPos).Magnitude > RANGE then
				f.last = pos
				continue
			end
			local moved = Vector3.new(pos.X - f.last.X, 0, pos.Z - f.last.Z).Magnitude
			f.last = pos
			local speed = dt > 0 and moved / dt or 0
			local moving = speed > 0.5
			f.amount += ((moving and 1 or 0) - f.amount) * math.min(1, dt * 8)
			f.phase += dt * math.clamp(speed, 0, 12) * 1.4
			local swing = math.sin(f.phase) * 0.7 * f.amount
			for _, limb in f.limbs do
				local angle = swing * limb.side * (limb.isArm and 0.8 or 1)
				limb.weld.C0 = limb.hip * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -limb.half, 0)
			end
		end
	end)
end

return VillagerAnimController
