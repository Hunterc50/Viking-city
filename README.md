# Viking City

A Roblox Viking settlement builder. Start with a longhouse and three settlers, gather wood, stone and food, build up your village, and grow your population through births and newcomers from neighbouring tribes. Later phases add technology, religion, culture, boats, and raiding (see [docs/DESIGN.md](docs/DESIGN.md)).

> **Easiest way:** download [VikingCity.rbxl](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/VikingCity.rbxl) (click the link, it downloads straight away), then double-click it in your Downloads folder to open it in Roblox Studio, and press Play.
>
> No VS Code, Git or Rojo needed. This file is rebuilt from the code every time the code changes, so download it again to get the latest version. (`VikingCity.rbxlx` is the same place in text form, handy for reading changes on GitHub.)

This repository holds all the game's code. You edit it in **VS Code**, and **Rojo** syncs it live into **Roblox Studio** (setup below, only needed when you want to edit code yourself).

---

## What's in the game so far

- A big Nordic valley made of realistic terrain: a flat green building area, a fjord with docks, pine and birch forests, rocky outcrops and snow-capped mountains, with warm afternoon light, haze and sun rays.
- Your own plot with a starting longhouse and 3 villagers.
- Tools: **Axe** (key 1) for trees, **Pickaxe** (key 2) for rocks, **Bow** (key 3) for hunting, **Torch** (key 4) for burning, and the **Sword** (key 5), your real weapon. Axe and Pickaxe only scratch an enemy. Hold E on berry bushes to forage by hand.
- 7 buildings: Longhouse and A-frame Cottage (housing), Woodcutter, Quarry, Barley Farm (jobs), Storehouse (storage), Palisade wall.
- Villagers take jobs, walk to work (arms and legs swinging), eat, and get happier or sadder. Single adults marry and share a home, couples have babies named after a parent (like Astrid Bjornsdottir), babies toddle after their parents, children play and grow up, and old-timers become grey-bearded elders. Newcomers also arrive from neighbouring tribes.
- Your village saves automatically (see "Saving your village").
- Sea battles against a raider longship and other players' ships, and Clash-style raids on other players' villages.
- A city-builder camera, a HUD with resources, population, happiness and day, a build bar and a message feed.

---

## Setup, step by step (first time only)

You need: **Roblox Studio**, **VS Code**, and **Git** (Windows: install from <https://git-scm.com>; Mac: run `git --version` in Terminal and accept the install prompt).

1. **Clone the repo.** Open a terminal (Windows: "Git Bash" or PowerShell, Mac: Terminal) and run:
   ```
   git clone https://github.com/Hunterc50/Viking-city.git
   ```
   Or in VS Code: press `Ctrl+Shift+P` (`Cmd+Shift+P` on Mac), choose **Git: Clone**, and paste the URL.

2. **Open the folder in VS Code.** File > Open Folder > pick `Viking-city`. If VS Code suggests the recommended extensions (Rojo and Luau Language Server), click **Install**.

3. **Install the Rojo Studio plugin.** In VS Code press `Ctrl+Shift+P`, run **Rojo: Open Menu**, then click **Install Roblox Studio plugin**. Restart Studio if it was open.

4. **Start Rojo.** Run **Rojo: Open Menu** again and click `default.project.json`. The status bar should say Rojo is serving on port 34872.

5. **Open a place in Studio.** Start Roblox Studio and create a new **Baseplate** place.

6. **Connect.** In Studio, open the **Plugins** tab, click **Rojo**, then click **Connect**. You should now see `ServerScriptService > Server`, `ReplicatedStorage > Shared`, and `StarterPlayer > StarterPlayerScripts > Client` in the Explorer.

7. **Press Play** (F5).

## Every time after that

Open the folder in VS Code, start Rojo (step 4), open your place in Studio, click **Connect** in the Rojo plugin, press Play. Any change you save in VS Code appears in Studio instantly. Stop and press Play again to test it.

`VikingCity.rbxl` and `VikingCity.rbxlx` in the repo are generated from `src/` by `scripts/build-place.sh` (which runs `rojo build`). Don't edit that file by hand; any place you save yourself under another name is ignored by Git.

---

## How to play

| Action | How |
| --- | --- |
| Chop trees | Press **1** to hold the Axe, walk to a tree, hold **E** |
| Mine rocks | Press **2** to hold the Pickaxe, walk to a rock, hold **E** |
| Hunt deer | Press **3** to hold the Bow, aim at a deer in the meadow and click (they run if you get too close) |
| Forage berries | Walk to a berry bush and hold **E** |
| Build | Pick a tab in the bottom menu (Housing, Production, Lore & Craft, Faith, War & Sea), hover a card to see what it does, click it, then click your land to place. Click the open tab again to fold the menu away |
| Rotate building | **R** while placing |
| Cancel | **Q**, or click the same button again |
| Demolish | Click **Demolish** (right end of the tabs), then click one of your buildings (50% refund) |
| Raid a rival hold | **Greywater Hold** is west past your plot; **Ravensfell**, a smaller hold with stone and smithy loot, is at the far east end past the last plot. Sound the war horn at the gate (E) if you want a proper fight |
| Fight | Hold the Sword (5) and click near a guard, or shoot with the Bow (3). The Axe and Pickaxe only do a little damage. Greywater Hold has 9 axemen and 4 archers on towers, so research Ring Mail and Iron Blades first |
| Burn buildings | Hold the Torch (4) and press **F** at a rival building. Fire spreads and chars it |
| Plunder | Hold **E** at the chests by their storehouses for food, silver and wood |
| New villagers | When every guard has fallen, hold **E** on the hold's villagers to offer them a home (needs a free bed) |
| Research | Press **T** (or the Research button). Build a **Lore Hall** to earn Lore, then unlock techs in Buildings, Gear, Boats, Culture and Religion. A Smithy, Shipyard or Shrine opens their branch |
| Sail | Build a **Shipyard**, research **Karve**, then hold **E** at the end of your jetty. W/S row, A/D steer, Space jumps off. Beach it near Greywater Hold for a sea raid |
| Trade | Walk to **Ottar's stall** (striped awning) on the beach in front of your plot and hold **E**. Swap wood, stone, food and hides for silver, or silver for goods. Food is dear in winter and cheap at harvest |
| Sea battle | At the helm press **F** to loose a volley of arrows at the nearest enemy ship, or ram it at full speed. Every ship has a hull bar; at zero it sinks. A Greywater raider ship patrols the fjord: sink it for silver, food and wood. Moor by your own jetty to repair |
| Raid another player | Walk to the **war horn post** on the west edge of their plot and hold **E**. Beat their militia in time, then plunder the chest by their longhouse for 20% of their stores. Villages are never destroyed; a raided village gets a 10-minute shield, and new villages are safe until day 3 |
| Defend your village | From day 4, rival warbands raid you every few days (you get a warning first). They head for your Storehouse; any raider who reaches it steals a share. **Palisades** slow them (they must hack through), **Watchtowers** with an archer at work shoot them, and you fight with the Sword and Bow. Nothing is ever destroyed |
| Camera | Mouse wheel zooms, hold right mouse and drag to turn, **V** switches to the normal camera |

The rival hold rebuilds itself about 5 minutes after a raid. Seasons change every 3 minutes: farms stop in winter and everyone eats more, so stock food in autumn.

The **Saga** panel (top left) always shows your next goal and its reward, from felling your first tree to building a Great Hall. It's the easiest way to learn the game.

Research shows on your Viking: **Chain Mail** gives you a mail shirt and helmet, and **Iron Axes** / **Steel Edges** change your axe head.

Families: a ♥ by a villager's name means they're married. Babies are only born to married couples with a free bed, so keep spare housing. Babies grow into children after 1 day and adults after 3.

Tips: build a **Barley Farm** first so nobody starves, then a **Woodcutter**. Each Longhouse holds 5 people and each Cottage 3. Immigrants only come when you have free housing and your people are happy.

---

## Changing the sounds and music

Every sound lives in one place: **Explorer > ReplicatedStorage > Shared > Sounds**. Double-click it to open it. Each line is a slot, like `Wind = { Id = "", Volume = 0.3 }`.

Music, wind, birds, waves, fire and the war horn start out empty (silent), so you can choose the ones you like. Chopping, mining, the bow, building and splashes already use Roblox's built-in sounds.

To fill or change a slot:
1. Open the **Toolbox** (View or Window menu), click the **Audio** tab, and search, for example "nordic music", "wind", "forest birds", "ocean waves", "fire crackle" or "war horn".
2. Click a sound to hear it. When you like one, right-click it and choose **Copy Asset ID**.
3. In the Sounds script, paste it between the quotes after `rbxassetid://`, like `Wind = { Id = "rbxassetid://1234567890", Volume = 0.3 },`
4. Press Play. Change `Volume` (0 to 1) if it's too loud.

Save your place afterwards. When you download a new version, copy your filled-in lines across.

---

## Saving your village

Your village (buildings, resources, research and villagers) saves automatically every minute and when you leave. Next time you play, it's all back.

Roblox only allows saving in a game that is **published** with **API access** turned on. Do this once:

1. In Studio, click **File > Publish to Roblox**. Pick **Create new game**, give it a name (like "Viking City"), and click **Create**. It can stay private.
2. Click **Game Settings** (Home tab, or File > Game Settings in newer Studio).
3. Click **Security**, then turn on **Enable Studio Access to API Services**. Click **Save**.
4. Press Play. You'll see "Welcome back!" the second time you play.

Until you do this, the game still works. It just says "Saving is off" in the message feed and starts fresh each time.

From then on, after you download a new `VikingCity.rbxl`, open it and use **File > Publish to Roblox** again, picking your existing game, so it keeps using the same saves.

---

## Editing the world and models yourself (no coding)

Normally the valley and every building are made by code when you press Play, so in edit mode you only see a flat grey plate. One command turns them into real models you can click on, move, recolour and save.

### Step 1: get the models into the editor (once)

1. Open `VikingCity.rbxl` in Roblox Studio. Don't press Play yet.
2. In the **Explorer** (the list of everything in the game, usually on the right), click **Workspace** to open it, then click **ShowModelWorkshop**.
3. In the **Properties** window, tick the **Value** box.
4. Press **Play**. Behind your plot, in the grassy meadow, is a row of one of every building, tree, rock, bush, a deer and the tools.
5. In the Explorer, under **Workspace**, right-click **ModelWorkshop** and choose **Copy** (or click it and press Ctrl+C).
6. Press **Stop**.
7. In the Explorer, right-click **Workspace** and choose **Paste Into**. The row of models is now in your place for real.
8. Click **ShowModelWorkshop** again and untick **Value**.
9. Save: **File > Save to File As**, with a new name like `MyVikingCity.rbxl`.

Can't find the Explorer or Properties? Open them from the **View** tab (or the **Window** menu in newer Studio).

**Optional, for the whole valley as well:** if your Studio has a **Command Bar** (old Studio: View > Command Bar; newer Studio: search "Command Bar" in the menus), paste this in it and press Enter instead of the steps above. It brings in both the models and the whole valley (terrain, forests, docks), and Studio may freeze for up to a minute:
```
require(game.ServerScriptService.Server.EditTools).Setup()
```

### Step 2: moving around and picking things

- **Fly the camera:** hold the **right mouse button** and use **W A S D** (Q / E go down and up). Mouse wheel zooms.
- **Find something:** open **View > Explorer**. Click the arrow next to `Workspace`, then `ModelWorkshop`. Click a name (say `Longhouse`), then press **F** to fly the camera to it.
- **Select it:** click it in the 3D view or in the Explorer. A blue box shows the whole model is selected.
- **Select one piece inside a model** (a roof, a wall): hold **Alt** and click it, or open the model's arrow in the Explorer and click the part.
- **Properties:** **View > Properties** shows everything about what you selected (colour, material, size).

### Step 3: changing things

| I want to... | Do this |
| --- | --- |
| Move it | **Home** tab > **Move** (or Ctrl+2), drag the coloured arrows |
| Turn it | **Rotate** (Ctrl+4), drag the coloured rings |
| Make a part bigger or smaller | **Scale** (Ctrl+3), drag the dots. Whole model: in Properties change **Scale** |
| Change colour | Select a part, in Properties click the **Color** box and pick one. Or **Home > Color** |
| Change material (wood, stone, grass) | Properties > **Material**, or **Home > Material** |
| Copy something | **Ctrl+D** (duplicates it in place, then move it) |
| Delete something | Select it, press **Delete** |
| Undo | **Ctrl+Z** |
| Add a new block | **Home > Part**, then move, scale and colour it. Drag it in the Explorer onto a model to make it part of that model |
| Paint or sculpt the ground | **Home > Editor** (Terrain Editor): Paint, Grow, Erode, Smooth, Flatten |

Tips:
- Keep each building **inside its model** (in the Explorer, every piece should sit under `Longhouse`, `Cottage`, ...). Don't rename the models: the name tells the game what it is.
- Keep a building about the same size it already is, so it still fits its spot on the build grid. Its bottom becomes ground level.
- Edits to a model in **ModelWorkshop** change **every** copy in the game (every Longhouse you build, every pine tree). Don't worry about where the workshop row sits: it disappears when you press Play.
- Edits to the valley (moving a tree, painting the ground, deleting a rock in **Workspace > Scenery**) need the Command Bar way, and change just that spot.
- Don't want one of your edited models any more? Delete it from ModelWorkshop and the game goes back to its built-in one. (The built-in trees vary randomly, a workshop tree is the same shape every time, just resized and turned.)

### Step 4: test and save

1. Press **Play** (F5) to try it. Press **Stop** to go back. **Changes you make while playing are thrown away**, so always edit after pressing Stop.
2. **File > Save to File As** (or Ctrl+S after the first save) to keep your work.

### Getting a new version without losing your edits

When a new `VikingCity.rbxl` comes out:
1. Open your saved place, click **ModelWorkshop** in the Explorer, press **Ctrl+C**.
2. Open the new `VikingCity.rbxl`, right-click **Workspace** and choose **Paste Into**. Save.

Hand edits to the valley itself (Command Bar way only) don't carry over, so put your favourite changes into the models where you can.

Other commands, if you have the Command Bar:
- `require(game.ServerScriptService.Server.EditTools).Models()` only adds the ModelWorkshop row (for example, after you deleted one model and want it back).
- `require(game.ServerScriptService.Server.EditTools).Reset()` removes the saved valley so the game makes a fresh one every Play again.

### Using free models from the Toolbox (easiest way to make it prettier)

1. Open the **Toolbox** (View or Window menu > Toolbox) and stay on the **Models** tab (Creator Store).
2. Search for what you want, for example "viking longhouse", "pine tree", "low poly rock", "viking ship", "deer".
3. Click a model to drop it into your place. Look at it: if it's far too big or small, that's fine, the game resizes buildings to fit their spot on the grid.
4. In the **Explorer**, find the new model (it's usually at the bottom of **Workspace**). Drag it into **ReplicatedStorage > Assets**.
5. Rename it to the slot it should replace, like `Longhouse` or `Tree_Pine` (the full list is below). Exact spelling matters.
6. Press Play. Every Longhouse (or pine tree) in the game now uses your model, including the rival holds.

Safety: the game removes any scripts inside these models before using them, so a free model can't run its own code. Still, prefer models with lots of likes from well-known creators, and only use models that are free to use.

Trees, rocks and bushes keep the size you give them (with a little random variety), so scale them in Studio first (Scale tool, or the model's **Scale** property) until they look right next to your Viking.

### Using real 3D models (meshes)

You can also replace any model with an imported one:
1. **Window > 3D Importer** (or the Toolbox, **Creator Store** tab, for free models) and import your `.fbx`, `.obj` or `.gltf`.
2. Drag it into **ReplicatedStorage > Assets**, and rename it to one of these slot names:
   `Longhouse`, `Cottage`, `Woodcutter`, `Quarry`, `Farm`, `Storehouse`, `Palisade`, `LoreHall`, `Smithy`, `Shrine`, `Shipyard`, `HuntingLodge`, `GreatHall`, `Tree_Pine`, `Tree_Spruce`, `Tree_Birch`, `Rock`, `Bush`, `Dock`, `Deer`, `Longship`, `Axe`, `Pickaxe`, `Bow`, `Torch`
3. Press Play. Imported buildings are resized to fit their spot on the grid automatically. If a model with the same name is in ModelWorkshop, the workshop one wins, so delete that one.

Notes: `Axe`, `Pickaxe`, `Bow` and `Torch` must be **Tools** with a part named `Handle`. Only use models you made or that are free to use, and avoid ones with scripts inside.

---

## Project layout

```
default.project.json          Rojo: maps folders to places in the Roblox game tree
src/
  shared/   -> ReplicatedStorage.Shared   (code both sides use)
    Config.luau         every balance number: costs, rates, timings
    Grid.luau           grid maths: cells, footprints, rotation
    Remotes.luau        RemoteEvents/RemoteFunctions between client and server
    Sounds.luau         every sound slot (swap IDs here)
    ModelFactory.luau   builds every model from parts, or uses your own from Assets / ModelWorkshop
  server/   -> ServerScriptService.Server
    init.server.luau    loads every service in Services/
    EditTools.luau      Command Bar helpers that put the world and models into edit mode
    Services/
      WorldService.luau         generates the valley terrain, forests, docks and lighting
      PlotService.luau          gives each player land, spawns them there
      ToolService.luau          gives out Axe, Pickaxe and Bow, handles arrows
      WildlifeService.luau      deer that wander, flee and can be hunted
      ColonyService.luau        colony state, resources, main loop, HUD sync
      BuildingService.luau      validates and places / demolishes buildings
      ResourceNodeService.luau  trees, rocks, bushes, hand gathering, regrowth
      VillagerService.luau      jobs, food, happiness, births, immigrants, walking
      SaveService.luau          saves and loads each village with a DataStore
      QuestService.luau         the Saga: a chain of goals with rewards
      TradeService.luau         Ottar's trading stalls on the beach
      VillageDefenseService.luau  rival warbands raiding your village, watchtowers
      BoatService.luau          sailing, ship health, volleys, ramming, the raider ship
      TownRaidService.luau      raiding other players' villages (militia, plunder, shields)
  client/   -> StarterPlayer.StarterPlayerScripts.Client
    init.client.luau    loads every controller in Controllers/
    Controllers/
      StateController.luau  receives colony snapshots from the server
      CameraController.luau city-builder camera
      ToolController.luau   bow shooting and tool swings
      HudController.luau    the on-screen interface
      BuildController.luau  placement preview and demolish mode
      VillagerAnimController.luau  arm and leg swing for walking villagers
docs/DESIGN.md          the full game design and roadmap
```

**Want to change the balance?** Edit `src/shared/Config.luau`. For example, make the Longhouse cheaper or days shorter.

**Adding a new system?** Make a new module in `src/server/Services/` with `Init` and `Start` functions; it is loaded automatically. Client UI goes in `src/client/Controllers/` the same way.

## Known limits of this first version

- Buildings appear instantly; construction time comes later.
- Models are made from parts in code; edit them or swap in real meshes (see "Editing the world and models yourself").
- The rival village layout, villagers and guards are still made by code each time (its buildings do use your edited models).
