--[[
	ClanService
	Your clan's colours (Jarl's Table > Land & clan). They go on the banners
	of your halls, the Great Hall's standards and the sail of your longship.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local ClanService = {}

local services

function ClanService:Init(all)
	services = all
end

local function colours(colony)
	local name = colony.clan or "Blood"
	for _, c in Config.ClanColours do
		if c.Name == name then
			return c
		end
	end
	return Config.ClanColours[1]
end

-- Is this part a banner, standard or sail cloth (and is it the main colour)?
local function role(part: BasePart): string?
	local n = part.Name
	if n == "Banner" or n == "Cloth" or n == "Sail" then
		return "main"
	elseif n == "BannerCloth" then
		return part.Size.X < 1 and "trim" or "main"
	elseif n == "Emblem" or n == "SailStripe" then
		return "trim"
	end
	local kind, hex = string.match(n, "^Mat_(%a+)_(%x%x%x%x%x%x)")
	if kind == "Cloth" then
		local c = Color3.fromHex(hex)
		if c.R > c.G * 1.6 and c.R > c.B * 1.6 then
			return "main" -- the red cloth of a mesh banner or sail
		end
	end
	return nil
end

-- Paints the clan's colours onto every banner and sail inside `root`.
function ClanService:Apply(colony, root: Instance)
	local c = colours(colony)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			local r = role(d)
			if r == "main" then
				d.Color = c.Main
			elseif r == "trim" then
				d.Color = c.Trim
			end
		end
	end
end

function ClanService:ApplyAll(colony)
	if colony.plot then
		self:Apply(colony, colony.plot)
	end
	local ship = services.BoatService and services.BoatService:ShipOf(colony.player)
	if ship and ship.model then
		self:Apply(colony, ship.model)
	end
end

function ClanService:SetColours(colony, name: string?): (boolean, string)
	for _, c in Config.ClanColours do
		if c.Name == name then
			colony.clan = name
			self:ApplyAll(colony)
			services.ColonyService:Notify(colony, "Your banners now fly the colours of the " .. c.Label .. ".", "good")
			services.ColonyService:Sync(colony)
			return true, c.Label
		end
	end
	return false, "Unknown colours."
end

return ClanService
