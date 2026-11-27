--[[
	VillagerAnimController
	Makes the little villager figures walk: their arms and legs swing in
	step while they move and come to rest when they stop. Purely visual and
	done on each player's own screen (the server only moves the bodies).
	Only villagers near the camera are animated, to keep it cheap.
	Workers also show their work (the server sets the model's Task and Carry):
	  Chop / Mine   an axe or pick raised and brought down
	  Farm          a hoe worked along the rows
	  Hammer        a hammer beating, the other hand steadying
	  Carry         a log, stone, sack or hide held in both arms on the way
	                to the storehouse
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
	figures[model] = { model = model, body = body, limbs = limbs, last = body.Position, phase = math.random() * 6, amount = 0, work = math.random() * 4 }
end

-- Little props made on this screen only and welded to the figure.
local function prop(parent: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = "WorkProp"
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Wood
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.CFrame = parent.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local WOOD = Color3.fromRGB(138, 100, 64)
local IRON = Color3.fromRGB(110, 112, 118)

-- A tool in the right hand, pointing forward out of the fist.
local function makeTool(arm: BasePart, kind: string): { BasePart }
	local k = arm.Size.X -- scales with the figure
	local hand = CFrame.new(0, -arm.Size.Y / 2, 0)
	local parts = {}
	local function add(size, offset, color, material, shape)
		table.insert(parts, prop(arm, size * k, hand * offset, color, material, shape))
	end
	local along = CFrame.Angles(math.pi / 2, 0, 0) -- haft along -Z (forward)
	if kind == "Chop" then
		add(Vector3.new(0.16, 2.4, 0.16), CFrame.new(0, 0, -0.8 * k) * along, WOOD)
		add(Vector3.new(0.12, 0.7, 0.75), CFrame.new(0, 0.35 * k, -1.9 * k), IRON, Enum.Material.Metal)
	elseif kind == "Mine" then
		add(Vector3.new(0.16, 2.4, 0.16), CFrame.new(0, 0, -0.8 * k) * along, WOOD)
		add(Vector3.new(0.18, 2.0, 0.22), CFrame.new(0, 0, -1.95 * k), IRON, Enum.Material.Metal)
	elseif kind == "Farm" then
		add(Vector3.new(0.14, 3.2, 0.14), CFrame.new(0, 0, -1.1 * k) * along, WOOD)
		add(Vector3.new(0.9, 0.1, 0.5), CFrame.new(0, -0.25 * k, -2.65 * k), IRON, Enum.Material.Metal)
	elseif kind == "Hammer" then
		add(Vector3.new(0.14, 1.3, 0.14), CFrame.new(0, 0, -0.45 * k) * along, WOOD)
		add(Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, 0.1 * k, -1.05 * k), IRON, Enum.Material.Metal)
	end
	return parts
end

-- A load held in front with both arms.
local function makeLoad(body: BasePart, kind: string): { BasePart }
	local k = body.Size.Y / 2
	local front = CFrame.new(0, -0.1 * k, -body.Size.Z / 2 - 0.55 * k)
	if kind == "Log" then
		return { prop(body, Vector3.new(3.0, 0.75, 0.75) * k, front * CFrame.new(0, 0.2 * k, 0), Color3.fromRGB(122, 86, 54), Enum.Material.Wood, Enum.PartType.Cylinder) }
	elseif kind == "Stone" then
		return { prop(body, Vector3.new(1.3, 0.9, 0.9) * k, front, Color3.fromRGB(140, 138, 132), Enum.Material.Slate) }
	elseif kind == "Sack" then
		return { prop(body, Vector3.new(1.2, 1.4, 1.0) * k, front, Color3.fromRGB(176, 156, 112), Enum.Material.Fabric) }
	elseif kind == "Hide" then
		return { prop(body, Vector3.new(1.6, 0.5, 1.0) * k, front * CFrame.new(0, 0.2 * k, 0), Color3.fromRGB(150, 108, 72), Enum.Material.Fabric) }
	end
	return {}
end

local function clearProps(list)
	for _, p in list or {} do
		p:Destroy()
	end
end

-- Arm angle (forward swing, radians) for a work pose at time t.
local function workAngle(kind: string, t: number, right: boolean): number
	if kind == "Chop" or kind == "Mine" then
		-- raise slowly over the head, strike fast; both hands on the haft
		local p = (t * 0.9) % 1
		if p < 0.7 then
			return 0.5 + 2.3 * (p / 0.7)
		end
		return 2.8 - 2.3 * ((p - 0.7) / 0.3)
	elseif kind == "Farm" then
		return 0.7 + 0.45 * math.sin(t * 3)
	elseif kind == "Hammer" then
		if right then
			return 1.1 + 0.8 * math.abs(math.sin(t * 4.5))
		end
		return 0.8
	end
	return 0
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
			local work = f.model:GetAttribute("Task")
			local carry = f.model:GetAttribute("Carry")
			local working = work ~= nil and f.amount < 0.3
			-- tools and loads appear and go as the work changes
			if work ~= f.toolKind then
				clearProps(f.tool)
				f.tool = nil
				f.toolKind = work
				if work then
					for _, limb in f.limbs do
						if limb.isArm and limb.side == 1 then
							f.tool = makeTool(limb.weld.Part1, work)
						end
					end
				end
			end
			if carry ~= f.loadKind then
				clearProps(f.load)
				f.loadKind = carry
				f.load = carry and makeLoad(f.body, carry) or nil
			end
			if working then
				f.work += dt
			end
			local guard = f.model:GetAttribute("Guard")
			for _, limb in f.limbs do
				local angle = swing * limb.side * (limb.isArm and 0.8 or 1)
				if limb.isArm and guard and limb.side ~= 1 then
					-- in the wall: the arm comes up and turns so the shield faces front
					limb.weld.C0 = limb.hip * CFrame.Angles(0.7, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, -limb.half, 0)
					continue
				elseif limb.isArm and carry then
					angle = 0.95 -- both arms hold the load
				elseif limb.isArm and working then
					angle = workAngle(work, f.work, limb.side == 1)
				end
				limb.weld.C0 = limb.hip * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -limb.half, 0)
			end
		end
	end)
end

return VillagerAnimController
