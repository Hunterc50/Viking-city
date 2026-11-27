--[[
	WeatherService
	Picks the weather every few minutes (Config.Weather): Clear, Fog or Storm.
	It sets workspace attributes that everything else reads:
	  Weather     "Clear" | "Fog" | "Storm"  (what it is turning into)
	  FogLevel    0..1, eases in and out over RampSeconds
	  StormLevel  0..1, eases in and out over RampSeconds
	WorldService thickens the haze and darkens the clouds from these,
	BoatService slows ships in storms and blinds the raider in fog, and the
	client (WeatherFxController) draws rain, lightning and thunder.
]]

local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local WeatherService = {}

local W = Config.Weather
local services
local rng = Random.new()

local MESSAGES = {
	Clear = { "The skies clear over the fjord.", "info" },
	Fog = { "A fog bank rolls in off the sea. Ships can slip past the raiders unseen.", "info" },
	Storm = { "A sea storm is coming! Ships will be slowed and tossed about.", "bad" },
}

function WeatherService:Init(all)
	services = all
	workspace:SetAttribute("Weather", "Clear")
	workspace:SetAttribute("FogLevel", 0)
	workspace:SetAttribute("StormLevel", 0)
end

local function pick(current: string): string
	-- never the same twice in a row, so there is always something to notice
	local total = 0
	for name, chance in W.Chances do
		if name ~= current then
			total += chance
		end
	end
	local roll = rng:NextNumber() * total
	for name, chance in W.Chances do
		if name ~= current then
			roll -= chance
			if roll <= 0 then
				return name
			end
		end
	end
	return "Clear"
end

function WeatherService:Set(name: string)
	workspace:SetAttribute("Weather", name)
	local msg = MESSAGES[name]
	if msg and services.ColonyService then
		for _, colony in services.ColonyService:All() do
			services.ColonyService:Notify(colony, msg[1], msg[2])
		end
	end
end

-- How much the weather slows ships (1 = not at all).
function WeatherService:ShipSpeed(): number
	return 1 - (1 - W.StormShipSpeed) * (workspace:GetAttribute("StormLevel") or 0)
end

-- How far the raider ship can see, as a share of its normal range.
function WeatherService:Sight(): number
	return 1 - (1 - W.FogRaiderSight) * (workspace:GetAttribute("FogLevel") or 0)
end

function WeatherService:Start()
	local nextChange = os.clock() + W.FirstChangeSeconds
	local fog, storm = 0, 0
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	while true do
		local dt = task.wait(0.25)
		if os.clock() >= nextChange then
			self:Set(pick(workspace:GetAttribute("Weather") or "Clear"))
			nextChange = os.clock() + rng:NextNumber(W.MinSeconds, W.MaxSeconds)
		end
		local now = workspace:GetAttribute("Weather")
		local step = dt / W.RampSeconds
		local function toward(v: number, goal: number): number
			if v < goal then
				return math.min(goal, v + step)
			end
			return math.max(goal, v - step)
		end
		fog = toward(fog, now == "Fog" and 1 or 0)
		storm = toward(storm, now == "Storm" and 1 or 0)
		workspace:SetAttribute("FogLevel", math.floor(fog * 100 + 0.5) / 100)
		workspace:SetAttribute("StormLevel", math.floor(storm * 100 + 0.5) / 100)

		-- the sea and sky (haze and light are handled in WorldService's day cycle)
		workspace.Terrain.WaterWaveSize = 0.16 + storm * 0.5
		workspace.Terrain.WaterWaveSpeed = 9 + storm * 14
		clouds = clouds or workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Cover = 0.55 + storm * 0.4 + fog * 0.2
			clouds.Density = 0.55 + storm * 0.4
			clouds.Color = Color3.fromRGB(245, 240, 232):Lerp(Color3.fromRGB(90, 96, 108), storm)
		end
		Lighting.EnvironmentDiffuseScale = 1 - storm * 0.4
	end
end

return WeatherService
