# Music for Viking City

`VikingTheme.ogg` is the game's own theme, "Over the Fjord" (about 2 minutes).
It's a slow Nordic piece with a bowed drone, a low choir, a frame drum, a
lyre and a flute. It was made from code (`tools/music/compose.py`), so it's
original and yours to use.

The game plays it on the title screen, then again every few minutes. Until
you add it, the game is silent apart from its sound effects.

## Add it to the game (one time, about 2 minutes)

1. **Download it.** Open
   [VikingTheme.ogg](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/music/VikingTheme.ogg).
   It downloads to your Downloads folder.
2. **Open VikingCity in Roblox Studio.**
3. **Upload it.** Click **View**, then **Asset Manager**. In the Asset Manager,
   click the **Import** button (the box with an up arrow), pick
   `VikingTheme.ogg` and click **Open**. Studio uploads it to your account.
   This can take a minute. Roblox may ask you to verify your account first.
4. **Put it in the game.** In the Asset Manager, open **Audio**, then
   double-click **VikingTheme**. A sound called VikingTheme appears in the
   Explorer under Workspace. Leave it there and don't rename it.
5. **Press Play.** The theme plays on the title screen.
6. **Save** the place (File > Save).

To change the music, edit `tools/music/compose.py` and run
`python3 tools/music/compose.py`.
