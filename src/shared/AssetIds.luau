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
	Planks = "",
	Bark = "",
	Stone = "",
	Thatch = "",
	Fur = "",
	Iron = "",
	Mail = "",
	Cloth = "",
	Leather = "",
}

-- Normal maps (<Name>_Normal.png). Only used if you also make SurfaceAppearances.
AssetIds.Normals = {
	Planks = "",
	Bark = "",
	Stone = "",
	Thatch = "",
	Fur = "",
	Iron = "",
	Mail = "",
	Cloth = "",
	Leather = "",
}

AssetIds.Sounds = {
	VikingTheme = "", -- music/VikingTheme.ogg, the theme "Over the Fjord"
	WarHorn = "", -- music/sfx/WarHorn.ogg
	Wind = "", -- music/sfx/Wind.ogg
	Waves = "", -- music/sfx/Waves.ogg
	Fire = "", -- music/sfx/Fire.ogg
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

function AssetIds.texture(name: string): string?
	return AssetIds.url(AssetIds.Textures[name])
end

function AssetIds.sound(name: string): string?
	return AssetIds.url(AssetIds.Sounds[name])
end

return AssetIds
