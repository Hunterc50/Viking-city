--[[
	Config
	All the numbers that shape the game live here, so you can tweak balance
	without touching any game logic. Shared by the server and the client.
]]

local Config = {}

-- World / grid ------------------------------------------------------------
Config.CELL = 8 -- studs per grid cell
Config.PLOT_CELLS = 20 -- each colony plot is 20 x 20 cells
Config.PLOT_GAP = 48 -- studs of wilderness between neighbouring plots
Config.MAX_PLOTS = 8
Config.GROUND_Y = 1 -- height of the top of the plot ground

-- Simulation --------------------------------------------------------------
Config.TICK = 1 -- seconds between simulation steps
Config.DAY_LENGTH = 60 -- real seconds per in-game day

-- Resources ---------------------------------------------------------------
Config.ResourceOrder = { "Wood", "Stone", "Food", "Hides", "Silver", "Lore" }
Config.StartingResources = { Wood = 80, Stone = 20, Food = 40, Hides = 0, Silver = 0, Lore = 0 }
Config.BaseStorage = 200 -- max of each resource before any storehouse

-- Villagers ---------------------------------------------------------------
Config.Villagers = {
	Starting = 3,
	FoodPerAdultPerSecond = 0.1, -- 6 food per adult per day
	FoodPerChildPerSecond = 0.05,
	BabyDays = 1, -- babies toddle after a parent for their first day
	DaysToAdulthood = 3, -- then children play, and grow up after 3 days
	ElderAge = 30, -- adults grey and grow beards after 30 days
	MarriageChancePerDay = 0.5, -- two single adults may marry and share a home
	WalkSpeed = 7, -- studs per second for the little villager figures

	BirthMinHappiness = 50,
	BirthChancePerDay = 0.6,

	ImmigrationMinHappiness = 65,
	ImmigrationChancePerDay = 0.5,
	ImmigrationMaxGroup = 3,

	LeaveBelowHappiness = 25,
}

Config.Names = {
	"Astrid", "Bjarni", "Sigrid", "Leif", "Ingrid", "Gunnar", "Solveig", "Ulf",
	"Hilda", "Toke", "Runa", "Arne", "Halla", "Knut", "Ylva", "Sven",
	"Thyra", "Orm", "Gudrun", "Ketil", "Eydis", "Hakon", "Brynja", "Vali",
	"Ragna", "Dagr", "Signy", "Asger", "Tove", "Hrolf",
}

-- Fictional neighbouring tribes that send immigrants.
Config.Tribes = { "Ravenfjord clan", "Ashvale folk", "Stormholm kin", "Elkmarsh tribe", "Greywater clan" }

-- Wild resource nodes on each plot -----------------------------------------
Config.Nodes = {
	-- Tool = which tool must be held to gather it (nil = bare hands)
	Tree = { Count = 34, Regrow = 22, Gives = "Wood", Amount = 10, Action = "Chop", Hold = 0.8, Tool = "Axe" },
	Rock = { Count = 12, Regrow = 4, Gives = "Stone", Amount = 8, Action = "Mine", Hold = 1.2, Tool = "Pickaxe" },
	Bush = { Count = 10, Regrow = 6, Gives = "Food", Amount = 6, Action = "Forage", Hold = 0.6 },
}
Config.NodeRegrowInterval = 20 -- seconds between regrowth attempts

Config.AutosaveSeconds = 60 -- how often villages are saved

-- Buildings ---------------------------------------------------------------
--[[
	Size      = footprint in cells {x, z} before rotation
	Cost      = resources spent to place it
	Housing   = villagers it can shelter
	Workers   = job slots
	Produces  = resource per worker per second (scaled by happiness)
	Storage   = extra capacity for every resource
]]
Config.Buildings = {
	Longhouse = {
		Display = "Longhouse",
		Description = "Shelter for 5 villagers. Free housing attracts births and immigrants.",
		Size = { 4, 2 },
		Cost = { Wood = 40, Stone = 10 },
		Housing = 5,
	},
	Cottage = {
		Display = "A-frame Cottage",
		Description = "A small steep-roofed home for 3 villagers.",
		Size = { 2, 2 },
		Cost = { Wood = 25 },
		Housing = 3,
	},
	Woodcutter = {
		Display = "Woodcutter",
		Description = "2 workers fell timber.",
		Size = { 2, 2 },
		Cost = { Wood = 20 },
		Workers = 2,
		Produces = { Wood = 0.5 },
	},
	Quarry = {
		Display = "Quarry",
		Description = "2 workers cut stone.",
		Size = { 2, 2 },
		Cost = { Wood = 30 },
		Workers = 2,
		Produces = { Stone = 0.3 },
	},
	Farm = {
		Display = "Barley Farm",
		Description = "2 workers grow food.",
		Size = { 3, 3 },
		Cost = { Wood = 25 },
		Workers = 2,
		Produces = { Food = 0.4 },
	},
	Storehouse = {
		Display = "Storehouse",
		Description = "+200 storage for every resource.",
		Size = { 2, 3 },
		Cost = { Wood = 40, Stone = 20 },
		Storage = 200,
	},
	LoreHall = {
		Display = "Lore Hall",
		Description = "2 skalds gather Lore, which pays for research (press T).",
		Size = { 3, 2 },
		Cost = { Wood = 50, Stone = 20 },
		Workers = 2,
		Produces = { Lore = 0.12 },
	},
	Smithy = {
		Display = "Smithy",
		Description = "A forge. Needed to research gear. 1 smith makes silver goods.",
		Size = { 2, 2 },
		Cost = { Wood = 30, Stone = 30 },
		Workers = 1,
		Produces = { Silver = 0.05 },
	},
	Shrine = {
		Display = "Shrine",
		Description = "Standing stones and a carved idol. +5 happiness; unlocks the patron paths.",
		Size = { 2, 2 },
		Cost = { Stone = 40, Silver = 10 },
		Happiness = 5,
	},
	Shipyard = {
		Display = "Shipyard",
		Description = "Builds ships. Needed to research boats; launch them from your dock.",
		Size = { 3, 4 },
		Cost = { Wood = 90, Stone = 20 },
	},
	HuntingLodge = {
		Display = "Hunting Lodge",
		Description = "2 hunters bring back meat and hides.",
		Size = { 2, 2 },
		Cost = { Wood = 30, Hides = 4 },
		Workers = 2,
		Produces = { Food = 0.25, Hides = 0.04 },
		Requires = "Trapping",
	},
	GreatHall = {
		Display = "Great Hall",
		Description = "A chieftain's hall for 10 people. +5 happiness.",
		Size = { 5, 3 },
		Cost = { Wood = 140, Stone = 60, Silver = 20 },
		Housing = 10,
		Happiness = 5,
		Requires = "Chieftainship",
	},
	Palisade = {
		Display = "Palisade",
		Description = "A section of sharpened-log wall. Place many in a row.",
		Size = { 1, 1 },
		Cost = { Wood = 3 },
	},
}

-- Tabs of the build menu, in order, and the buildings on each tab.
-- Icon is an emoji shown on the tab and on each building card.
Config.BuildCategories = {
	{ Name = "Housing", Icon = "🏠", Buildings = { "Longhouse", "Cottage", "GreatHall" } },
	{ Name = "Production", Icon = "🌾", Buildings = { "Farm", "Woodcutter", "Quarry", "HuntingLodge", "Storehouse" } },
	{ Name = "Lore & Craft", Icon = "📜", Buildings = { "LoreHall", "Smithy" } },
	{ Name = "Faith", Icon = "🔥", Buildings = { "Shrine" } },
	{ Name = "War & Sea", Icon = "⚔️", Buildings = { "Palisade", "Shipyard" } },
}

Config.BuildingIcons = {
	Longhouse = "🏠", Cottage = "🏡", GreatHall = "🏰",
	Farm = "🌾", Woodcutter = "🪓", Quarry = "⛏️", HuntingLodge = "🦌", Storehouse = "📦",
	LoreHall = "📜", Smithy = "⚒️", Shrine = "🗿", Palisade = "🛡️", Shipyard = "⛵",
}

-- Every building in menu order (built from the tabs above).
Config.BuildOrder = {}
for _, category in Config.BuildCategories do
	for _, b in category.Buildings do
		table.insert(Config.BuildOrder, b)
	end
end

-- Tools every player carries (built in ModelFactory.tool).
Config.Tools = { "Axe", "Pickaxe", "Bow", "Torch" }

-- Wildlife ------------------------------------------------------------------
Config.Wildlife = {
	DeerPerPlot = 4, -- deer roaming the meadow behind each plot
	RespawnSeconds = 45,
	Speed = 9,
	FleeSpeed = 22,
	FleeDistance = 22, -- deer bolt when a player gets this close
	Meat = 15, -- Food from one deer
	Hides = 2,
}

-- The rival village you can raid ---------------------------------------------
Config.Rival = {
	Name = "Greywater Hold",
	Center = Vector3.new(-170, 1, 100), -- west end of the valley, past plot 1
	Radius = 92, -- palisade ring
	Defenders = 6,
	DefenderHealth = 100,
	DefenderDamage = 10,
	DefenderAggro = 70, -- studs from the village centre they will chase you
	Villagers = 4, -- folk you can offer a new home once the guards fall
	ChestLoot = { Food = 50, Silver = 20, Wood = 20 },
	BurnSeconds = 25,
	RegenSeconds = 300, -- after a raid the hold rebuilds itself in 5 minutes
}

Config.Combat = {
	AxeDamage = 34,
	ArrowDamage = 50,
	StrikeRange = 8,
	StrikeCooldown = 0.6,
}

-- Raiding other players' villages (they must be in the same server).
-- Villages are never destroyed: the raider fights the village militia and,
-- if every militia falls, plunders a share of the stores.
Config.TownRaid = {
	MinDay = 3, -- both villages must have reached this day (newcomer protection)
	ShieldSeconds = 600, -- a raided village can't be raided again for 10 minutes
	FailedShieldSeconds = 120,
	AttackerCooldown = 300, -- a raider must wait 5 minutes between raids
	Duration = 150, -- seconds to win the raid
	MilitiaPerAdult = 0.5,
	MinMilitia = 2,
	MaxMilitia = 6,
	MilitiaHealth = 90,
	MilitiaDamage = 8,
	LootShare = 0.2, -- the victor takes 20% of each resource...
	LootCap = 150, -- ...but at most this much of each
}

-- Sea battles: ship health, broadside volleys (F at the helm) and ramming.
Config.Naval = {
	KarveHull = 120,
	LongshipHull = 220,
	VolleyDamage = 14, -- per arrow hit on a ship; 5 arrows a volley
	VolleyArrows = 5,
	VolleyRange = 80,
	VolleyCooldown = 3,
	RamDamage = 60, -- at full speed (longships hit 1.5x harder)
	RamSelfDamage = 12,
	RepairPerSecond = 4, -- hull repaired while moored by your jetty
	-- the Greywater raider ship that patrols the fjord
	RaiderHull = 180,
	RaiderSpeed = 26,
	RaiderAggro = 150,
	RaiderRespawn = 180,
	RaiderLoot = { Silver = 25, Food = 30, Wood = 40 },
}

Config.Bow = {
	Range = 140,
	Cooldown = 0.9,
	ArrowSpeed = 160,
}

Config.DemolishRefund = 0.5 -- fraction of the cost returned

-- Research ------------------------------------------------------------------
--[[
	Each tech: Branch, Name, Description, Cost, Requires (other tech ids),
	Building (a building you must own first), Group (only one tech per group,
	used for the patron paths). Effects are read by the services via
	ColonyService:Has(colony, id).
]]
Config.TechBranches = { "Buildings", "Gear", "Boats", "Culture", "Religion" }
Config.Tech = {
	-- Buildings
	CropRotation = { Branch = "Buildings", Name = "Crop Rotation", Description = "Farms grow 25% more.", Cost = { Lore = 15 } },
	Masonry = { Branch = "Buildings", Name = "Masonry", Description = "Quarries cut 30% more stone.", Cost = { Lore = 20 } },
	Trapping = { Branch = "Buildings", Name = "Trapping", Description = "Unlocks the Hunting Lodge.", Cost = { Lore = 20 } },
	Chieftainship = { Branch = "Buildings", Name = "Chieftainship", Description = "Unlocks the Great Hall.", Cost = { Lore = 60, Silver = 20 }, Requires = { "Masonry" } },
	-- Gear (needs a Smithy)
	IronAxes = { Branch = "Gear", Name = "Iron Axes", Description = "Chop 50% more wood and hit 50% harder.", Cost = { Lore = 20, Stone = 30 }, Building = "Smithy" },
	Longbows = { Branch = "Gear", Name = "Yew Longbows", Description = "Arrows hit 50% harder and fly further.", Cost = { Lore = 25, Wood = 40 }, Building = "Smithy" },
	ChainMail = { Branch = "Gear", Name = "Ring Mail", Description = "You have 150 health instead of 100.", Cost = { Lore = 40, Silver = 25 }, Building = "Smithy", Requires = { "IronAxes" } },
	SteelEdges = { Branch = "Gear", Name = "Steel Edges", Description = "Axe blows hit twice as hard.", Cost = { Lore = 60, Silver = 30 }, Building = "Smithy", Requires = { "IronAxes" } },
	-- Boats (needs a Shipyard)
	Karve = { Branch = "Boats", Name = "Karve", Description = "Launch a small boat from your dock and sail the fjord.", Cost = { Lore = 30, Wood = 80 }, Building = "Shipyard" },
	Longship = { Branch = "Boats", Name = "Longship", Description = "Launch a fast war longship instead.", Cost = { Lore = 70, Wood = 150, Silver = 20 }, Building = "Shipyard", Requires = { "Karve" } },
	SeaRaiders = { Branch = "Boats", Name = "Sea Raiders", Description = "Plunder 50% more from chests.", Cost = { Lore = 50 }, Requires = { "Karve" } },
	-- Culture
	SagaTellers = { Branch = "Culture", Name = "Saga Tellers", Description = "Lore Halls gather 50% more lore.", Cost = { Lore = 20 } },
	Feasting = { Branch = "Culture", Name = "Feasting", Description = "+10 happiness.", Cost = { Lore = 30, Food = 60 } },
	Woodcraft = { Branch = "Culture", Name = "Woodcraft", Description = "Woodcutters work 30% faster.", Cost = { Lore = 25 } },
	OpenArms = { Branch = "Culture", Name = "Open Arms", Description = "Twice as many immigrants arrive.", Cost = { Lore = 45 }, Requires = { "Feasting" } },
	-- Religion (needs a Shrine; pick ONE patron path)
	PathStorm = { Branch = "Religion", Name = "Path of the Storm", Description = "Patron of the sea: raids plunder 50% more, guards hit you 30% softer.", Cost = { Lore = 40 }, Building = "Shrine", Group = "Patron" },
	PathHearth = { Branch = "Religion", Name = "Path of the Hearth", Description = "Patron of home: twice the births, +10 happiness.", Cost = { Lore = 40 }, Building = "Shrine", Group = "Patron" },
	PathWoods = { Branch = "Religion", Name = "Path of the Deep Woods", Description = "Patron of the wild: double hand gathering and hunting.", Cost = { Lore = 40 }, Building = "Shrine", Group = "Patron" },
	MidwinterRite = { Branch = "Religion", Name = "Midwinter Rite", Description = "Winter no longer makes your people eat more.", Cost = { Lore = 50, Food = 40 }, Building = "Shrine" },
}

-- Seasons -------------------------------------------------------------------
-- The year turns for everyone on the server. Each season lasts SeasonSeconds.
Config.SeasonSeconds = 180
Config.Seasons = {
	{ Name = "Summer", FarmRate = 1.25, FoodUse = 1.0 },
	{ Name = "Autumn", FarmRate = 0.8, FoodUse = 1.0 },
	{ Name = "Winter", FarmRate = 0, FoodUse = 1.5 }, -- frozen fields, cold bellies
	{ Name = "Spring", FarmRate = 0.9, FoodUse = 1.0 },
}

return Config
