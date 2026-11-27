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
Config.StartingResources = { Wood = 80, Stone = 20, Food = 160, Hides = 0, Silver = 0, Lore = 0 }
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
	-- Hits = swings needed with the right tool (better tools need fewer)
	Tree = { Count = 34, Regrow = 22, Gives = "Wood", Amount = 10, Action = "Chop", Hold = 0.8, Tool = "Axe", Hits = 5 },
	Rock = { Count = 12, Regrow = 4, Gives = "Stone", Amount = 8, Action = "Mine", Hold = 1.2, Tool = "Pickaxe", Hits = 6 },
	Bush = { Count = 18, Regrow = 12, Gives = "Food", Amount = 10, Action = "Forage", Hold = 0.6 },
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
		Rank = 2, -- Chieftain
	},
	Fishery = {
		Display = "Fishery",
		Description = "2 fishers row out for herring and cod. Works all year, even in winter.",
		Size = { 2, 2 },
		Cost = { Wood = 35, Stone = 5 },
		Workers = 2,
		Produces = { Food = 0.22 },
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
		Rank = 3, -- Hersir
	},
	Palisade = {
		Display = "Palisade",
		Description = "A section of sharpened-log wall. Raiders must hack through it, which slows them down. Place many in a row.",
		Size = { 1, 1 },
		Cost = { Wood = 3 },
	},
	Watchtower = {
		Display = "Watchtower",
		Description = "A tall lookout. Its archer shoots at raiders who attack your village.",
		Size = { 2, 2 },
		Cost = { Wood = 40, Stone = 15 },
		Workers = 1,
	},
}

-- Tabs of the build menu, in order, and the buildings on each tab.
-- Icon is an emoji shown on the tab and on each building card.
Config.BuildCategories = {
	{ Name = "Housing", Icon = "🏠", Buildings = { "Longhouse", "Cottage", "GreatHall" } },
	{ Name = "Production", Icon = "🌾", Buildings = { "Farm", "Fishery", "Woodcutter", "Quarry", "HuntingLodge", "Storehouse" } },
	{ Name = "Lore & Craft", Icon = "📜", Buildings = { "LoreHall", "Smithy" } },
	{ Name = "Faith", Icon = "🔥", Buildings = { "Shrine" } },
	{ Name = "War & Sea", Icon = "⚔️", Buildings = { "Palisade", "Watchtower", "Shipyard" } },
}

Config.BuildingIcons = {
	Longhouse = "🏠", Cottage = "🏡", GreatHall = "🏰",
	Farm = "🌾", Fishery = "🐟", Woodcutter = "🪓", Quarry = "⛏️", HuntingLodge = "🦌", Storehouse = "📦",
	LoreHall = "📜", Smithy = "⚒️", Shrine = "🗿", Palisade = "🛡️", Watchtower = "🏹", Shipyard = "⛵",
}

-- Every building in menu order (built from the tabs above).
Config.BuildOrder = {}
for _, category in Config.BuildCategories do
	for _, b in category.Buildings do
		table.insert(Config.BuildOrder, b)
	end
end

-- Tools every player carries (built in ModelFactory.tool).
Config.Tools = { "Axe", "Pickaxe", "Bow", "Torch", "Sword" }

-- Wildlife ------------------------------------------------------------------
Config.Wildlife = {
	DeerPerPlot = 4, -- deer roaming the meadow behind each plot
	RespawnSeconds = 45,
	Speed = 9,
	FleeSpeed = 22,
	FleeDistance = 22, -- deer bolt when a player gets this close
	Meat = 25, -- Food from one deer
	Hides = 2,
}

-- The rival village you can raid ---------------------------------------------
Config.Rival = {
	Name = "Greywater Hold",
	Center = Vector3.new(-170, 1, 100), -- west end of the valley, past plot 1
	Radius = 92, -- palisade ring
	Defenders = 9, -- axemen who charge
	Archers = 4, -- bowmen who hold the walls and shoot from range
	DefenderHealth = 150,
	DefenderDamage = 14,
	ArcherDamage = 9,
	ArcherRange = 95,
	ArcherCooldown = 2.6,
	DefenderAggro = 70, -- studs from the village centre they will chase you
	Villagers = 4, -- folk you can offer a new home once the guards fall
	ChestLoot = { Food = 120, Silver = 45, Wood = 70, Hides = 6 },
	BurnSeconds = 25,
	RegenSeconds = 300, -- after a raid the hold rebuilds itself in 5 minutes
}

-- A second, smaller hold at the far east end of the valley, past the last
-- plot. Its gate faces west, toward the player plots.
Config.Rival2 = {
	Name = "Ravensfell",
	Center = Vector3.new(Config.MAX_PLOTS * (Config.PLOT_CELLS * Config.CELL + Config.PLOT_GAP) - Config.PLOT_GAP + 170, 1, 90),
	Radius = 72,
	GateAngle = math.pi,
	Defenders = 7,
	Archers = 3,
	DefenderHealth = 130,
	DefenderDamage = 12,
	ArcherDamage = 8,
	ArcherRange = 90,
	ArcherCooldown = 2.8,
	DefenderAggro = 60,
	Villagers = 3,
	ChestLoot = { Food = 90, Silver = 35, Stone = 60, Hides = 4 },
	BurnSeconds = 25,
	RegenSeconds = 300,
	Layout = {
		{ "Longhouse", Vector3.new(0, 0, 36) },
		{ "Cottage", Vector3.new(-40, 0, -18) },
		{ "Cottage", Vector3.new(40, 0, -20) },
		{ "Smithy", Vector3.new(-38, 0, 24) },
		{ "Storehouse", Vector3.new(0, 0, -42) },
	},
}

-- A sea-raider stronghold on an island out in the fjord. There is no way
-- there on foot: sail a longship over, land on the beach and storm the gate.
-- Tougher guards, but the longer voyage pays: its stores are far richer.
-- Sea = true means it never sends warbands overland to your village.
Config.Rival3 = {
	Name = "Skerholm",
	Sea = true,
	Center = Vector3.new(math.floor((Config.MAX_PLOTS * (Config.PLOT_CELLS * Config.CELL + Config.PLOT_GAP) - Config.PLOT_GAP) / 2), 1, -400),
	Radius = 70,
	GateAngle = math.pi / 2, -- the gate faces the beach on your side of the water
	Defenders = 10,
	Archers = 4,
	DefenderHealth = 180,
	DefenderDamage = 16,
	ArcherDamage = 10,
	ArcherRange = 100,
	ArcherCooldown = 2.4,
	DefenderAggro = 65,
	Villagers = 4,
	ChestLoot = { Food = 160, Silver = 90, Wood = 80, Stone = 60, Hides = 8 },
	BurnSeconds = 25,
	RegenSeconds = 420,
	Layout = {
		{ "Longhouse", Vector3.new(0, 0, -30) },
		{ "Cottage", Vector3.new(-36, 0, 10) },
		{ "Cottage", Vector3.new(36, 0, 8) },
		{ "Smithy", Vector3.new(-30, 0, -40) },
		{ "Storehouse", Vector3.new(32, 0, -38) },
	},
}

-- Every rival hold: two in the valley, one across the water.
Config.Rivals = { Config.Rival, Config.Rival2, Config.Rival3 }

-- Weather ------------------------------------------------------------------
-- Every few minutes the sky changes. Fog banks hide you from the Greywater
-- raider ship; sea storms slow every ship and rock it about.
Config.Weather = {
	FirstChangeSeconds = 240, -- calm for the first few minutes
	MinSeconds = 150, -- each spell of weather lasts between these
	MaxSeconds = 300,
	RampSeconds = 25, -- how long fog or a storm takes to roll in or clear
	Chances = { Clear = 0.5, Fog = 0.28, Storm = 0.22 },
	StormShipSpeed = 0.6, -- ships sail at 60% speed in a storm
	FogRaiderSight = 0.4, -- the raider ship only spots you at 40% of its usual range
}

-- Sieges: every rival hold has a gate in its palisade. Break it (axe blows,
-- or your war band in a wedge) before you can plunder or burn inside.
Config.Siege = {
	GateHealth = 600,
	ToolDamage = { Axe = 30, Pickaxe = 20, Sword = 18 }, -- per blow on the gate
	WedgeRam = 2, -- warriors in a wedge hit gates this much harder
}

-- War band formations (Jarl's Table > War band, or press G while they follow)
Config.Formations = {
	loose = { Label = "Loose", Text = "a loose crowd behind you" },
	wall = { Label = "Shield wall", Text = "two ranks of shields in front of you. They hold the line and take half damage", DamageTaken = 0.5 },
	wedge = { Label = "Wedge", Text = "a boar's-snout wedge. They charge harder, hit 40% harder and ram gates", Damage = 1.4, Speed = 1.25, Sight = 1.3 },
}

Config.Combat = {
	-- melee damage per blow by what you're holding: tools barely scratch,
	-- the Sword is the real weapon
	MeleeDamage = { Axe = 8, Pickaxe = 8, Sword = 40 },
	ArrowDamage = 50,
	StrikeRange = 8,
	StrikeCooldown = 0.6,
}

-- Trading at the stall on your beach. Each offer swaps Give for Get.
-- Prices shift with the seasons (Season = multiplier on what you GIVE).
Config.Trade = {
	Offers = {
		{ Give = { Wood = 40 }, Get = { Silver = 4 } },
		{ Give = { Stone = 30 }, Get = { Silver = 4 } },
		{ Give = { Food = 50 }, Get = { Silver = 5 }, Season = { Autumn = 0.8, Winter = 1.6 } },
		{ Give = { Hides = 4 }, Get = { Silver = 6 } },
		{ Give = { Silver = 5 }, Get = { Food = 40 }, Season = { Winter = 1.6, Summer = 0.8 } },
		{ Give = { Silver = 5 }, Get = { Wood = 50 } },
		{ Give = { Silver = 6 }, Get = { Stone = 40 } },
		{ Give = { Silver = 10 }, Get = { Lore = 8 } },
	},
}

-- The saga: a chain of goals that teaches the game, shown top left.
-- Kind: "stat" (something you did, counted), "building", "population",
-- "tech" (number researched). Rewards are added when a goal is done.
Config.Quests = {
	{ Title = "Food first", Text = "Your people eat every day. Open the Production tab and build a Barley Farm. For quick food, hold E on red berry bushes.", Kind = "building", Building = "Farm", Goal = 1, Reward = { Food = 40 } },
	{ Title = "Fell your first trees", Text = "Press 1 for the Axe, walk up to a tree and click to swing until it falls.", Kind = "stat", Stat = "chop", Goal = 3, Reward = { Wood = 15 } },
	{ Title = "A woodcutter's hut", Text = "Build a Woodcutter. Idle villagers will take the jobs.", Kind = "building", Building = "Woodcutter", Goal = 1, Reward = { Wood = 20 } },
	{ Title = "Break some stone", Text = "Press 2 for the Pickaxe, walk up to a rock and click to swing until it breaks.", Kind = "stat", Stat = "mine", Goal = 2, Reward = { Stone = 15 } },
	{ Title = "The hunt", Text = "Press 3 for the Bow and shoot a deer in the meadow behind your plot.", Kind = "stat", Stat = "deer", Goal = 1, Reward = { Food = 20 } },
	{ Title = "Strike a bargain", Text = "Visit Ottar's stall on your beach (hold E) and make a trade.", Kind = "stat", Stat = "trade", Goal = 1, Reward = { Silver = 5 } },
	{ Title = "Room to grow", Text = "Build an A-frame Cottage (Housing tab). Free beds bring babies and newcomers.", Kind = "building", Building = "Cottage", Goal = 1, Reward = { Wood = 20, Stone = 10 } },
	{ Title = "Keepers of lore", Text = "Build a Lore Hall. Its skalds earn Lore for research.", Kind = "building", Building = "LoreHall", Goal = 1, Reward = { Lore = 10 } },
	{ Title = "New knowledge", Text = "Press T and research anything.", Kind = "tech", Goal = 1, Reward = { Wood = 30 } },
	{ Title = "A growing village", Text = "Reach 8 people. Keep everyone fed, housed and happy.", Kind = "population", Goal = 8, Reward = { Silver = 10 } },
	{ Title = "Plunder Greywater", Text = "Walk west to Greywater Hold, chop through its gate with your axe, beat the guards and plunder a chest (E).", Kind = "stat", Stat = "plunder", Goal = 1, Reward = { Silver = 10 } },
	{ Title = "Shipwrights", Text = "Build a Shipyard (War & Sea tab).", Kind = "building", Building = "Shipyard", Goal = 1, Reward = { Wood = 40 } },
	{ Title = "Take to the sea", Text = "Research Karve (T), then hold E at the end of your jetty to launch.", Kind = "stat", Stat = "launch", Goal = 1, Reward = { Food = 30 } },
	{ Title = "Master of the fjord", Text = "Sink the Greywater Raider ship: F for volleys, or ram it at full speed.", Kind = "stat", Stat = "sunk", Goal = 1, Reward = { Silver = 20 } },
	{ Title = "Hold the line", Text = "Build a Watchtower, then beat off a raid on your village.", Kind = "stat", Stat = "defend", Goal = 1, Reward = { Silver = 15, Wood = 40 } },
	{ Title = "A chieftain's hall", Text = "Research Chieftainship and build a Great Hall.", Kind = "building", Building = "GreatHall", Goal = 1, Reward = { Silver = 30, Lore = 20 } },
}

-- Ranks: your title grows with your village. Each rank raises how many
-- people can live in your settlement and unlocks bigger buildings
-- (a building's Rank field). You rise as soon as you meet the needs.
Config.Ranks = {
	{ Name = "Settler", PopCap = 10 },
	{ Name = "Chieftain", PopCap = 16, Needs = { Population = 6, Buildings = 5 }, Reward = { Silver = 10 } },
	{ Name = "Hersir", PopCap = 26, Needs = { Population = 12, Buildings = 10, Tech = 3 }, Reward = { Silver = 25, Lore = 15 } },
	{ Name = "Jarl", PopCap = 40, Needs = { Population = 20, Buildings = 16, Tech = 7 }, Reward = { Silver = 50, Lore = 30 } },
	{ Name = "King", PopCap = 70, Needs = { Population = 32, Buildings = 24, Tech = 12 }, Reward = { Silver = 100, Lore = 60 } },
}

-- Land ----------------------------------------------------------------------
-- Buy bigger land in stages (Jarl's Table > Land). Cells are counted from the
-- plot's front-left corner; MinX below 0 grows the land sideways into the gap
-- between plots, MaxZ grows it back toward the meadow. Never overlaps a
-- neighbour: the gap between plots is 6 cells and each side takes at most 2.
Config.LandStages = {
	{ Name = "Homestead", MinX = 0, MaxX = 20, MaxZ = 20 },
	{ Name = "Farmstead", MinX = 0, MaxX = 20, MaxZ = 23, Cost = { Silver = 40, Wood = 60 }, Rank = 1 },
	{ Name = "Steading", MinX = -2, MaxX = 22, MaxZ = 23, Cost = { Silver = 90, Stone = 50 }, Rank = 2 },
	{ Name = "Great Steading", MinX = -2, MaxX = 22, MaxZ = 26, Cost = { Silver = 160, Wood = 100, Stone = 80 }, Rank = 3 },
}

-- War band ------------------------------------------------------------------
-- Hire grown villagers as warriors (Jarl's Table > War band). They stop
-- working, follow you, fight beside you and crew your longship. Or send them
-- off on their own to raid a hold and bring the loot home.
Config.Warband = {
	HireCost = { Silver = 10, Food = 20 },
	MaxByRank = { 2, 3, 5, 7, 10 }, -- Settler .. King
	Health = 100, -- + 40 with Ring Mail
	Damage = 12, -- per blow; Iron Blades +4, Steel Edges +8
	HitCooldown = 1.4,
	Reach = 6,
	Sight = 40, -- studs: how far they spot an enemy near you
	HealPerSecond = 1, -- when not fighting
	-- longship crew: each warrior aboard adds this much speed and one arrow per volley
	CrewSpeed = 0.05,
	CrewSpeedMax = 0.3,
	-- expeditions: the band leaves, then comes home with a report
	ExpeditionSeconds = 120, -- to a hold in the valley
	SeaExpeditionSeconds = 180, -- to Skerholm (needs the Karve research)
	WarriorPower = 3, -- + 1 each for Ring Mail, Iron Blades, Steel Edges
	LootShare = 0.8, -- share of the hold's chest loot on a full victory
}

-- Diplomacy -------------------------------------------------------------------
-- Every hold has a mood toward you, -100 (blood feud) to 100 (sworn allies).
Config.Diplomacy = {
	GiftCost = { Silver = 25 },
	GiftGain = 20,
	DemandMinPower = 0.6, -- your war band must be this strong vs the hold to demand tribute
	TributePerDay = { Silver = 12, Food = 25 },
	TributeDays = 4,
	AllianceMood = 60,
	AllianceCost = { Silver = 60 },
	DealMood = 30,
	AttackMood = -50, -- raiding a hold sets its mood to at most this
	DriftPerDay = 3, -- moods slowly return toward 0
	-- what each hold's trade deal swaps every day: you pay Give, they send Get
	Deals = {
		["Greywater Hold"] = { Give = { Wood = 20 }, Get = { Food = 30 } },
		["Ravensfell"] = { Give = { Food = 20 }, Get = { Stone = 25 } },
		["Skerholm"] = { Give = { Hides = 3 }, Get = { Silver = 12 } },
	},
}

-- Feasts and rites ------------------------------------------------------------
Config.Rites = {
	Feast = {
		Name = "Feast in the hall",
		Cost = { Food = 80, Hides = 2 },
		Needs = "Longhouse",
		Happiness = 20, -- extra happiness target while it lasts
		Days = 1,
		CooldownDays = 2,
	},
	-- one blót each season, at the Shrine; it blesses the rest of the season
	Blot = {
		Needs = "Shrine",
		Spring = { Name = "Sigrblót", Cost = { Food = 40, Silver = 10 }, Text = "Farms work 25% faster this season.", Farm = 1.25 },
		Summer = { Name = "Midsummer blót", Cost = { Food = 40, Silver = 10 }, Text = "+15 happiness and newcomers come twice as often this season.", Happiness = 15, Immigration = 2 },
		Autumn = { Name = "Haustblót", Cost = { Food = 30, Wood = 40 }, Text = "Woodcutters and quarries work 25% faster this season.", Work = 1.25 },
		Winter = { Name = "Jólablót (Yule)", Cost = { Food = 60, Silver = 15 }, Text = "+20 happiness and your people eat less this season.", Happiness = 20, FoodUse = 0.8 },
	},
}

-- Rival warbands raid YOUR village every few days. Fight them off, build
-- Palisades to slow them and Watchtowers (with an archer) to shoot them.
-- Raiders who reach your stores carry off a share; nothing is destroyed.
Config.VillageRaids = {
	Enabled = true,
	FirstDay = 4, -- no raids before this day
	EveryDays = { 2, 4 }, -- then one every 2 to 4 days
	WarningSeconds = 40,
	BaseRaiders = 2, -- plus one per 4 days survived, up to MaxRaiders
	MaxRaiders = 8,
	RaiderHealth = 90,
	RaiderDamage = 9,
	StealShare = 0.12, -- each raider who reaches the stores takes 12% of each resource
	StealCap = 60,
	TowerRange = 75,
	TowerDamage = 30,
	TowerCooldown = 2,
	Reward = { Silver = 10, Hides = 2 }, -- for beating off the whole warband
	LeaveAfter = 150, -- seconds before the raiders give up and go home
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
	Masonry = { Branch = "Buildings", Name = "Masonry", Description = "Quarries cut 30% more stone, and you break rocks faster.", Cost = { Lore = 20 } },
	Trapping = { Branch = "Buildings", Name = "Trapping", Description = "Unlocks the Hunting Lodge.", Cost = { Lore = 20 } },
	Chieftainship = { Branch = "Buildings", Name = "Chieftainship", Description = "Unlocks the Great Hall.", Cost = { Lore = 60, Silver = 20 }, Requires = { "Masonry" } },
	-- Gear (needs a Smithy)
	IronAxes = { Branch = "Gear", Name = "Iron Blades", Description = "Chop 50% more wood with fewer swings, and your Sword hits 50% harder.", Cost = { Lore = 20, Stone = 30 }, Building = "Smithy" },
	Longbows = { Branch = "Gear", Name = "Yew Longbows", Description = "Arrows hit 50% harder and fly further.", Cost = { Lore = 25, Wood = 40 }, Building = "Smithy" },
	ChainMail = { Branch = "Gear", Name = "Ring Mail", Description = "You have 150 health instead of 100.", Cost = { Lore = 40, Silver = 25 }, Building = "Smithy", Requires = { "IronAxes" } },
	SteelEdges = { Branch = "Gear", Name = "Steel Edges", Description = "Sword blows hit twice as hard.", Cost = { Lore = 60, Silver = 30 }, Building = "Smithy", Requires = { "IronAxes" } },
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
	{ Name = "Winter", FarmRate = 0.35, FoodUse = 1.25 }, -- hard fields, cold bellies
	{ Name = "Spring", FarmRate = 0.9, FoodUse = 1.0 },
}

return Config
