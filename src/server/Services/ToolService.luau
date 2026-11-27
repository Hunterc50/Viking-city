--[[
	ToolService
	Gives every player an Axe, a Pickaxe and a Bow each time they spawn
	(keys 1, 2, 3), and handles Bow shots: the client sends where it aimed,
	the server checks the shot, flies an arrow and tells WildlifeService if a
	deer was hit.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Sounds = require(Shared.Sounds)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local ToolService = {}

local services
local lastShot = {} -- [player] = os.clock()

function ToolService:Init(allServices)
	services = allServices
end

-- Ring Mail research gives 150 health.
-- Welds a piece of gear to a body part (removed with the character).
local function wear(character: Model, onto: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3, material, shape)
	local old = character:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Metal
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = onto.CFrame * offset
	p.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = onto
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- Research shows on your Viking: chain mail and a helmet with Chain Mail,
-- darker iron then bright steel axe heads with Iron Axes / Steel Edges.
function ToolService:ApplyGear(player: Player)
	local character = player.Character
	local colony = services.ColonyService:Get(player)
	if not character or not colony then
		return
	end
	local Has = function(id)
		return services.ColonyService:Has(colony, id)
	end
	if Has("ChainMail") then
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		local head = character:FindFirstChild("Head")
		local mail = Color3.fromRGB(128, 130, 136)
		if torso then
			wear(character, torso, "GearMail", torso.Size + Vector3.new(0.12, 0.3, 0.12), CFrame.new(0, -0.1, 0), mail, Enum.Material.DiamondPlate)
		end
		local lower = character:FindFirstChild("LowerTorso")
		if lower then
			wear(character, lower, "GearSkirt", lower.Size + Vector3.new(0.14, 0.5, 0.14), CFrame.new(0, -0.2, 0), mail, Enum.Material.DiamondPlate)
		end
		if head then
			wear(character, head, "GearHelm", Vector3.new(1.3, 0.75, 1.3), CFrame.new(0, 0.38, 0), Color3.fromRGB(96, 98, 104), Enum.Material.Metal, Enum.PartType.Ball)
			wear(character, head, "GearNose", Vector3.new(0.14, 0.55, 0.14), CFrame.new(0, 0.05, -0.6), Color3.fromRGB(96, 98, 104), Enum.Material.Metal)
		end
	end
	local steel = Has("SteelEdges")
	local iron = Has("IronAxes")
	if steel or iron then
		local containers = { player:FindFirstChild("Backpack"), character }
		for _, c in containers do
			for _, toolName in { "Axe", "Sword" } do
				local axe = c and c:FindFirstChild(toolName) -- the axe or the sword
				if axe and axe:IsA("Tool") then
					for _, d in axe:GetChildren() do
						if d:IsA("BasePart") and d.Name == "Head" then
							d.Color = steel and Color3.fromRGB(210, 215, 225) or Color3.fromRGB(80, 82, 90)
							d.Material = steel and Enum.Material.Foil or Enum.Material.Metal
						end
					end
				end
			end
		end
	end
end

function ToolService:ApplyArmor(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local colony = services.ColonyService:Get(player)
	if humanoid and services.ColonyService:Has(colony, "ChainMail") then
		humanoid.MaxHealth = 150
		humanoid.Health = math.max(humanoid.Health, 150)
	end
	self:ApplyGear(player)
end

-- True if the player is currently holding the named tool.
function ToolService:IsHolding(player: Player, toolName: string): boolean
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool.Name == toolName
end

local function giveTools(player: Player)
	local backpack = player:WaitForChild("Backpack")
	for _, name in Config.Tools do
		if not backpack:FindFirstChild(name) and not (player.Character and player.Character:FindFirstChild(name)) then
			ModelFactory.tool(name).Parent = backpack
		end
	end
end

local function findDeer(inst: Instance?): Model?
	while inst and inst ~= workspace do
		if inst:IsA("Model") and inst:GetAttribute("DeerId") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function shoot(player: Player, aim)
	if typeof(aim) ~= "Vector3" or aim ~= aim then
		return
	end
	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < Config.Bow.Cooldown then
		return
	end
	if not ToolService:IsHolding(player, "Bow") then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	lastShot[player] = now

	local origin = head.Position + Vector3.new(0, 0.3, 0)
	local delta = aim - origin
	if delta.Magnitude < 1 then
		return
	end
	local colony = services.ColonyService:Get(player)
	local longbows = services.ColonyService:Has(colony, "Longbows")
	local dir = delta.Unit * (Config.Bow.Range + (longbows and 60 or 0))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(origin, dir, params)
	local endPoint = hit and hit.Position or origin + dir

	Sounds.play("Bow", head)
	-- the visible arrow
	local arrow = ModelFactory.arrow()
	arrow.CFrame = CFrame.lookAt(origin, endPoint)
	arrow.Parent = workspace
	local flight = (endPoint - origin).Magnitude / Config.Bow.ArrowSpeed
	TweenService:Create(arrow, TweenInfo.new(flight, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(endPoint, endPoint + dir) }):Play()
	Debris:AddItem(arrow, flight + 3)

	local deer = hit and findDeer(hit.Instance)
	if deer then
		task.delay(flight, function()
			services.WildlifeService:Kill(deer, player)
		end)
	end
	local guard = hit and services.RaidService:FindDefender(hit.Instance)
	if guard then
		task.delay(flight, function()
			services.RaidService:DamageDefender(guard, Config.Combat.ArrowDamage * (longbows and 1.5 or 1), player)
		end)
	end
	local raider = hit and services.VillageDefenseService:FindRaider(hit.Instance)
	if raider then
		task.delay(flight, function()
			services.VillageDefenseService:DamageRaider(raider, Config.Combat.ArrowDamage * (longbows and 1.5 or 1))
		end)
	end
	local militia = hit and services.TownRaidService:FindMilitia(hit.Instance)
	if militia then
		task.delay(flight, function()
			services.TownRaidService:DamageMilitia(militia, Config.Combat.ArrowDamage * (longbows and 1.5 or 1), player)
		end)
	end
	if hit then
		task.delay(flight, function()
			services.BoatService:ArrowHit(hit.Instance, player)
		end)
	end
end

local lastStrike = {}
local function strike(player: Player)
	local now = os.clock()
	if lastStrike[player] and now - lastStrike[player] < Config.Combat.StrikeCooldown then
		return
	end
	local character = player.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	local base = held and Config.Combat.MeleeDamage[held.Name]
	if not base then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	lastStrike[player] = now
	Sounds.play("Swing", root)
	if held.Name ~= "Sword" then
		services.ResourceNodeService:Hit(player, held.Name, root)
	end
	local colony = services.ColonyService:Get(player)
	local damage = base
	if held.Name == "Sword" then
		if services.ColonyService:Has(colony, "SteelEdges") then
			damage *= 2
		elseif services.ColonyService:Has(colony, "IronAxes") then
			damage *= 1.5
		end
	end
	for _, guard in services.RaidService:DefendersNear(root.Position, root.CFrame.LookVector, Config.Combat.StrikeRange) do
		services.RaidService:DamageDefender(guard, damage, player)
	end
	for _, raider in services.VillageDefenseService:RaidersNear(root.Position, root.CFrame.LookVector, Config.Combat.StrikeRange) do
		services.VillageDefenseService:DamageRaider(raider, damage)
	end
	for _, militia in services.TownRaidService:MilitiaNear(root.Position, root.CFrame.LookVector, Config.Combat.StrikeRange) do
		services.TownRaidService:DamageMilitia(militia, damage, player)
	end
end

function ToolService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			giveTools(player)
			character:WaitForChild("Head", 5)
			task.wait(0.5) -- let the avatar's look load first
			ToolService:ApplyArmor(player)
		end)
		if player.Character then
			giveTools(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		lastStrike[player] = nil
	end)

	Remotes.ShootArrow.OnServerEvent:Connect(shoot)
	Remotes.Strike.OnServerEvent:Connect(strike)
end

return ToolService
