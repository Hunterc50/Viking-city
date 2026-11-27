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
local Remotes = require(Shared.Remotes)
local ModelFactory = require(Shared.ModelFactory)

local ToolService = {}

local services
local lastShot = {} -- [player] = os.clock()

function ToolService:Init(allServices)
	services = allServices
end

-- Ring Mail research gives 150 health.
function ToolService:ApplyArmor(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local colony = services.ColonyService:Get(player)
	if humanoid and services.ColonyService:Has(colony, "ChainMail") then
		humanoid.MaxHealth = 150
		humanoid.Health = math.max(humanoid.Health, 150)
	end
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
end

local lastStrike = {}
local function strike(player: Player)
	local now = os.clock()
	if lastStrike[player] and now - lastStrike[player] < Config.Combat.StrikeCooldown then
		return
	end
	if not ToolService:IsHolding(player, "Axe") then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	lastStrike[player] = now
	local colony = services.ColonyService:Get(player)
	local damage = Config.Combat.AxeDamage
	if services.ColonyService:Has(colony, "SteelEdges") then
		damage *= 2
	elseif services.ColonyService:Has(colony, "IronAxes") then
		damage *= 1.5
	end
	for _, guard in services.RaidService:DefendersNear(root.Position, root.CFrame.LookVector, Config.Combat.StrikeRange) do
		services.RaidService:DamageDefender(guard, damage, player)
	end
end

function ToolService:Start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			giveTools(player)
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
