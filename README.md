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
- Tools: **Axe** (key 1) for trees, **Pickaxe** (key 2) for rocks, **Bow** (key 3) for hunting deer in the meadow behind your plot. Hold E on berry bushes to forage by hand.
- 7 buildings: Longhouse and A-frame Cottage (housing), Woodcutter, Quarry, Barley Farm (jobs), Storehouse (storage), Palisade wall.
- Villagers take jobs, walk to work, eat, and get happier or sadder. Happy villages with free housing grow through births and immigrants from neighbouring tribes.
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
| Build | Click a building in the bottom bar, move the mouse over your land, click to place |
| Rotate building | **R** while placing |
| Cancel | **Q**, or click the same button again |
| Demolish | Click **Demolish**, then click one of your buildings (50% refund) |
| Raid Greywater Hold | Walk west past your plot to the walled village. Sound the war horn at the gate (E) if you want a proper fight |
| Fight | Hold the Axe (1) and click near a guard, or shoot with the Bow (3) |
| Burn buildings | Hold the Torch (4) and press **F** at a rival building. Fire spreads and chars it |
| Plunder | Hold **E** at the chests by their storehouses for food, silver and wood |
| New villagers | When every guard has fallen, hold **E** on the hold's villagers to offer them a home (needs a free bed) |
| Research | Press **T** (or the Research button). Build a **Lore Hall** to earn Lore, then unlock techs in Buildings, Gear, Boats, Culture and Religion. A Smithy, Shipyard or Shrine opens their branch |
| Sail | Build a **Shipyard**, research **Karve**, then hold **E** at the end of your jetty. W/S row, A/D steer, Space jumps off. Beach it near Greywater Hold for a sea raid |
| Camera | Mouse wheel zooms, hold right mouse and drag to turn, **V** switches to the normal camera |

The rival hold rebuilds itself about 5 minutes after a raid. Seasons change every 3 minutes: farms stop in winter and everyone eats more, so stock food in autumn.

Tips: build a **Barley Farm** first so nobody starves, then a **Woodcutter**. Each Longhouse holds 5 people and each Cottage 3. Immigrants only come when you have free housing and your people are happy.

---

## Using your own 3D models (meshes) for extra realism

The game is built from simple blocks so it works out of the box, but you can swap any of them for a realistic model, and the game will use yours automatically.

1. In Studio, open **Window > 3D Importer** (or the Toolbox, **Creator Store** tab, to find free models) and import your model (`.fbx`, `.obj` or `.gltf`).
2. In the Explorer, open **ReplicatedStorage > Assets**.
3. Drag your model into the **Assets** folder.
4. Rename it to exactly one of these slot names:
   `Longhouse`, `Cottage`, `Woodcutter`, `Quarry`, `Farm`, `Storehouse`, `Palisade`, `LoreHall`, `Smithy`, `Shrine`, `Shipyard`, `HuntingLodge`, `GreatHall`, `Tree_Pine`, `Tree_Birch`, `Rock`, `Bush`, `Dock`, `Deer`, `Axe`, `Pickaxe`, `Bow`
5. Press Play. Buildings are resized to fit their spot on the grid automatically.

Notes:
- `Axe`, `Pickaxe` and `Bow` must be **Tools** (with a part named `Handle`). Everything else is a **Model**.
- Only use models you made or that are free to use, and avoid ones with scripts inside.
- Save your place with your models in it (File > Save to File As). When a new `VikingCity.rbxl` comes out, open it, then copy your **Assets** folder across from your saved place.

---

## Project layout

```
default.project.json          Rojo: maps folders to places in the Roblox game tree
src/
  shared/   -> ReplicatedStorage.Shared   (code both sides use)
    Config.luau         every balance number: costs, rates, timings
    Grid.luau           grid maths: cells, footprints, rotation
    Remotes.luau        RemoteEvents/RemoteFunctions between client and server
    ModelFactory.luau   builds every model from parts, or uses your own from Assets
  server/   -> ServerScriptService.Server
    init.server.luau    loads every service in Services/
    Services/
      WorldService.luau         generates the valley terrain, forests, docks and lighting
      PlotService.luau          gives each player land, spawns them there
      ToolService.luau          gives out Axe, Pickaxe and Bow, handles arrows
      WildlifeService.luau      deer that wander, flee and can be hunted
      ColonyService.luau        colony state, resources, main loop, HUD sync
      BuildingService.luau      validates and places / demolishes buildings
      ResourceNodeService.luau  trees, rocks, bushes, hand gathering, regrowth
      VillagerService.luau      jobs, food, happiness, births, immigrants, walking
  client/   -> StarterPlayer.StarterPlayerScripts.Client
    init.client.luau    loads every controller in Controllers/
    Controllers/
      StateController.luau  receives colony snapshots from the server
      CameraController.luau city-builder camera
      ToolController.luau   bow shooting and tool swings
      HudController.luau    the on-screen interface
      BuildController.luau  placement preview and demolish mode
docs/DESIGN.md          the full game design and roadmap
```

**Want to change the balance?** Edit `src/shared/Config.luau`. For example, make the Longhouse cheaper or days shorter.

**Adding a new system?** Make a new module in `src/server/Services/` with `Init` and `Start` functions; it is loaded automatically. Client UI goes in `src/client/Controllers/` the same way.

## Known limits of this first version

- Progress isn't saved yet (coming with DataStores in Phase 1).
- Buildings appear instantly; construction time comes later.
- Models are made from parts in code; swap in real meshes with the Assets folder (above).
