--[[
	Sounds
	Every sound in the game, by slot name. To change one, put a different
	sound's ID in its slot, written like "rbxassetid://1234567890".

	How to find a sound in Studio:
	  1. Open the Toolbox (View or Window menu > Toolbox).
	  2. Pick the Audio tab (the music-note icon), search e.g. "wind",
	     "ocean waves", "viking", "war horn", "fire crackle".
	  3. Click a sound to listen. Right-click it > Copy Asset ID.
	  4. In the Explorer open ReplicatedStorage > Shared and double-click
	     Sounds (this script). Paste the number between the quotes, after
	     rbxassetid://  e.g.  Wind = "rbxassetid://9112854440",
	  5. Press Play.
	An empty slot ("") is silent. The ones filled in already are Roblox's
	built-in sounds that come with every Roblox install.
]]

local AssetIds = require(script.Parent.AssetIds)

local Sounds = {}

Sounds.Slots = {
	-- background, loops forever (empty until you pick one you like)
	Music = { Id = "", Volume = 0.25 }, -- a calm Nordic / folk track
	Wind = { Id = "", Volume = 0.3 }, -- soft wind
	Birds = { Id = "", Volume = 0.25 }, -- daytime birdsong (quiet at night)
	Waves = { Id = "", Volume = 0.45 }, -- sea on the shore (louder near the fjord)
	Fire = { Id = "", Volume = 0.6 }, -- crackling flames on burning buildings
	Rain = { Id = "", Volume = 0.5 }, -- steady rain, plays during sea storms
	Thunder = { Id = "", Volume = 0.8 }, -- one thunder clap after each lightning flash

	-- one-off effects
	Chop = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.5, Pitch = 0.6 },
	Mine = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.5, Pitch = 0.55 },
	Swing = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.6, Pitch = 1 },
	Bow = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.5, Pitch = 1.7 },
	Build = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.8, Pitch = 0.6 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 1, Pitch = 0.7 },
	QuestDone = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.5, Pitch = 1 },
	Growl = { Id = "", Volume = 1.2, Range = 220 }, -- the bear's roar (upload music/sfx/Growl.ogg to fill it)
	WarHorn = { Id = "", Volume = 2.5, Range = 900, Life = 14 }, -- a long, loud horn blast when a raid begins
}

-- A slot left empty can still be filled from Studio: upload the game's own
-- sound (music/sfx/<Name>.ogg), insert it, and leave the Sound named after
-- the slot (WarHorn, Wind, Waves, Fire) in Workspace. It is found here.
local found = {} -- [name] = id or false
local lastLook = {}
local function idFor(name: string): string?
	local slot = Sounds.Slots[name]
	if not slot then
		return nil
	end
	if slot.Id ~= "" then
		return slot.Id
	end
	local uploaded = AssetIds.sound(name)
	if uploaded then
		return uploaded
	end
	if found[name] then
		return found[name]
	end
	if lastLook[name] and os.clock() - lastLook[name] < 30 then
		return nil
	end
	lastLook[name] = os.clock()
	for _, root in { workspace, game:GetService("ReplicatedStorage") } do
		for _, d in root:GetDescendants() do
			if d:IsA("Sound") and d.Name == name and d.SoundId ~= "" then
				found[name] = d.SoundId
				return d.SoundId
			end
		end
	end
	return nil
end
Sounds.idFor = idFor

-- Plays slot `name` once, at a part or a position (or everywhere if nil).
function Sounds.play(name: string, where: (Instance | Vector3)?)
	local slot = Sounds.Slots[name]
	local id = idFor(name)
	if not slot or not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = slot.Volume or 0.5
	sound.PlaybackSpeed = slot.Pitch or 1
	sound.RollOffMaxDistance = slot.Range or 160
	if slot.Range then
		sound.RollOffMinDistance = 60 -- loud for a long way, then fading
	end
	local holder
	if typeof(where) == "Vector3" then
		holder = Instance.new("Attachment")
		holder.WorldPosition = where
		holder.Parent = workspace.Terrain
		sound.Parent = holder
	elseif typeof(where) == "Instance" then
		sound.Parent = where
	else
		sound.Parent = workspace
	end
	sound:Play()
	task.delay(slot.Life or 8, function()
		sound:Destroy()
		if holder then
			holder:Destroy()
		end
	end)
end

-- A looping sound inside `parent` for slot `name`, or nil if the slot is empty.
function Sounds.loop(name: string, parent: Instance): Sound?
	local slot = Sounds.Slots[name]
	local id = idFor(name)
	if not slot or not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = slot.Volume or 0.5
	sound.PlaybackSpeed = slot.Pitch or 1
	sound.Looped = true
	sound.Parent = parent
	sound:Play()
	return sound
end

return Sounds
