--[[
	AssetIds
	The game's own uploaded textures and sounds, by name. Paste each ID that
	Roblox gives you after uploading, as a plain number in quotes, e.g.
	    Planks = "1234567890",
	An empty slot ("") is simply not used.

	Textures (from the textures/ folder) go on the imported mesh pieces:
	  Planks  wood      Stone  stone      Thatch  roofs     Cloth  sails, banners
	  Iron    metal     Bark   logs       Fur     furs      Mail   ring mail
	  Leather leather
	Each texture is a pale "detail" image; the game tints it with the piece's
	own colour, so one wood texture serves pale and dark wood alike.

	Sounds (from music/ and music/sfx/) fill the sound slots of the same name.
]]

local AssetIds = {}

AssetIds.Textures = {
	Planks = "99219759031156",
	Bark = "81943827981119",
	Stone = "134784449121497",
	Thatch = "83706834634988",
	Fur = "108994538135725",
	Iron = "74881552321813",
	Mail = "110799894282775",
	Cloth = "133036267171125",
	Leather = "108816029250063",
}

-- Normal maps (<Name>_Normal.png). Only used if you also make SurfaceAppearances.
AssetIds.Normals = {
	Planks = "99000675698208",
	Bark = "137110303829148",
	Stone = "88416761511029",
	Thatch = "117669267634241",
	Fur = "105222209754048",
	Iron = "111404527296440",
	Mail = "71993879985414",
	Cloth = "76685064842577",
	Leather = "135894035407072",
}

AssetIds.Sounds = {
	VikingTheme = "134063905969129", -- music/VikingTheme.ogg, the theme "Over the Fjord"
	WarHorn = "122414446260321", -- music/sfx/WarHorn.ogg
	Wind = "136494073086031", -- music/sfx/Wind.ogg
	Waves = "123305574817861", -- music/sfx/Waves.ogg
	Fire = "114757074007418", -- music/sfx/Fire.ogg
}

-- "1234" -> "rbxassetid://1234"; already-full ids pass through; "" -> nil
function AssetIds.url(id: string?): string?
	if not id or id == "" then
		return nil
	end
	if string.find(id, "://", 1, true) then
		return id
	end
	return "rbxassetid://" .. id
end

-- Textures uploaded through Open Cloud come back as Decal IDs, but a Texture
-- needs the Image inside the decal. The server looks each one up at start
-- (resolveTextures) and shares the answer as an attribute on ReplicatedStorage.
local resolved = {} -- [name] = image url

function AssetIds.texture(name: string): string?
	if resolved[name] then
		return resolved[name]
	end
	local shared = game:GetService("ReplicatedStorage"):GetAttribute("Tex_" .. name)
	if typeof(shared) == "string" and shared ~= "" then
		resolved[name] = shared
		return shared
	end
	return AssetIds.url(AssetIds.Textures[name])
end

-- Server only. Turns each decal ID into its image ID (an ID that already is
-- an image is kept as it is). Waits at most `timeout` seconds in all.
function AssetIds.resolveTextures(timeout: number?)
	local InsertService = game:GetService("InsertService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local pending = 0
	for name, id in AssetIds.Textures do
		local number = tonumber(string.match(id or "", "(%d+)%s*$") or "")
		if number then
			pending += 1
			task.spawn(function()
				local image
				local ok, model = pcall(function()
					return InsertService:LoadAsset(number)
				end)
				if ok and model then
					local decal = model:FindFirstChildWhichIsA("Decal", true)
					if decal and decal.Texture ~= "" then
						image = decal.Texture
					end
					model:Destroy()
				end
				image = image or AssetIds.url(id)
				resolved[name] = image
				ReplicatedStorage:SetAttribute("Tex_" .. name, image)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < (timeout or 8) do
		task.wait(0.1)
	end
end

function AssetIds.sound(name: string): string?
	return AssetIds.url(AssetIds.Sounds[name])
end

return AssetIds
