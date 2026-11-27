--[[
	EditTools
	Run from Studio's Command Bar (View > Command Bar) while NOT playing:

	    require(game.ServerScriptService.Server.EditTools).Setup()

	It does two things, so you can see and change the game's world and
	models in edit mode, then save them in your place:
	  1. builds the whole valley (terrain, forests, rocks, docks, lighting)
	     into Workspace, and marks it as saved so the game doesn't rebuild it
	  2. puts a copy of every building, tree, rock, bush, deer and tool in
	     Workspace > ModelWorkshop, in a row in the meadow behind your plot

	Studio may freeze for up to a minute while it builds. Run it once; run
	it again later only if you want to start the valley from scratch (your
	ModelWorkshop edits are kept).

	Other commands:
	    require(game.ServerScriptService.Server.EditTools).Models()  -- only step 2
	    require(game.ServerScriptService.Server.EditTools).Reset()   -- undo step 1
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EditTools = {}

local function factory()
	return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ModelFactory"))
end

function EditTools.Models()
	local made = factory().bakeTemplates()
	print("[EditTools] added " .. made .. " models to Workspace > ModelWorkshop")
end

function EditTools.Setup()
	local start = os.clock()
	local WorldService = require(script.Parent:WaitForChild("Services"):WaitForChild("WorldService"))
	WorldService:Bake()
	EditTools.Models()
	print(string.format("[EditTools] done in %.0f seconds. Now File > Save to File As to keep it.", os.clock() - start))
end

-- Throws the saved valley away, so the game builds a fresh one each time again.
function EditTools.Reset()
	for _, name in { "Scenery", "ShoreFoam" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	workspace.Terrain:Clear()
	workspace:SetAttribute("WorldBaked", nil)
	print("[EditTools] saved valley removed; the game will build a new one when you press Play")
end

return EditTools
