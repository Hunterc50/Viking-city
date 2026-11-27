# Music for Viking City

`VikingTheme.ogg` is the game's own theme, "Over the Fjord" (about 2 minutes).
It's a slow Nordic piece with a bowed drone, a low choir, a frame drum, a
lyre and a flute. It was made from code (`tools/music/compose.py`), so it's
original and yours to use.

The game plays it on the title screen, then again every few minutes. Until
you add it, the game is silent apart from its sound effects.

## Add it to the game (one time, about 3 minutes)

1. **Download it.** Open
   [VikingTheme.ogg](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/VikingTheme.ogg).
   It downloads to your Downloads folder.
2. **Upload it on the Roblox website.** Go to
   [create.roblox.com/dashboard/creations](https://create.roblox.com/dashboard/creations).
   Click **Development Items** along the top, then **Audio**, then **Upload Asset**.
   Pick `VikingTheme.ogg`, type the name **VikingTheme**, and click **Upload**.
   Roblox checks it first, so it may take a few minutes before it plays.
3. **Get its number.** Click the uploaded VikingTheme. The web address now has
   a long number in it, like `.../audio/1234567890/...`. That number is the ID.
   (Or open the **...** menu on the audio and pick **Copy Asset ID**.)
4. **Send the number to Claude.** It gets put into the game for you. The next
   time you click **Start Viking City** and Connect, the theme plays on the
   title screen.

You can also upload it from inside Studio: press **Ctrl+M** (or File > Import),
pick the file, and confirm. Then open the **Toolbox**, go to **Inventory**, pick
**Audio**, and click VikingTheme. A sound named VikingTheme appears in the
Explorer; leave it there and save. The game finds it by that name.

The music is uploaded under your account, so it can only play in your own games.

## Sound effects (optional)

The folder `music/sfx` has four more of the game's own sounds: **WarHorn**
(raids and sieges), **Wind**, **Waves** (the shore) and **Fire** (burning
buildings and feasts). Until you add them, those moments are silent.

Upload them the same way as the theme:
[WarHorn](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/sfx/WarHorn.ogg),
[Wind](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/sfx/Wind.ogg),
[Waves](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/sfx/Waves.ogg),
[Fire](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/sfx/Fire.ogg).
Then either send Claude the numbers, or put each one in Workspace from the
Toolbox and keep its name (WarHorn, Wind, Waves, Fire). The game finds them by name.

To change the music, edit `tools/music/compose.py` and run
`python3 tools/music/compose.py`.
