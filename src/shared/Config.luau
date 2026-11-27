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
Config.ResourceOrder = { "Wood", "Stone", "Food", "Hides" }
Config.StartingResources = { Wood = 80, Stone = 20, Food = 40, Hides = 0 }
Config.BaseStorage = 200 -- max of each resource before any storehouse

-- Villagers ---------------------------------------------------------------
Config.Villagers = {
	Starting = 3,
	FoodPerAdultPerSecond = 0.1, -- 6 food per adult per day
	FoodPerChildPerSecond = 0.05,
	DaysToAdulthood = 2,
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
	Palisade = {
		Display = "Palisade",
		Description = "A section of sharpened-log wall. Place many in a row.",
		Size = { 1, 1 },
		Cost = { Wood = 3 },
	},
}

-- Order of buttons in the build bar.
Config.BuildOrder = { "Longhouse", "Cottage", "Woodcutter", "Quarry", "Farm", "Storehouse", "Palisade" }

-- Tools every player carries (built in ModelFactory.tool).
Config.Tools = { "Axe", "Pickaxe", "Bow" }

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

Config.Bow = {
	Range = 140,
	Cooldown = 0.9,
	ArrowSpeed = 160,
}

Config.DemolishRefund = 0.5 -- fraction of the cost returned

return Config
