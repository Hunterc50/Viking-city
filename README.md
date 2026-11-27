# Viking City

A Roblox Viking settlement builder. Start with a longhouse and three settlers, gather wood, stone and food, build up your village, and grow your population through births and newcomers from neighbouring tribes. Later phases add technology, religion, culture, boats, and raiding (see [docs/DESIGN.md](docs/DESIGN.md)).

> **Easiest way:** download [VikingCity.rbxl](https://github.com/hunterc50/viking-city/raw/claude/project-thread-ifpez8/VikingCity.rbxl) (click the link, it downloads straight away), then double-click it in your Downloads folder to open it in Roblox Studio, and press Play.
>
> No VS Code, Git or Rojo needed. This file is rebuilt from the code every time the code changes, so download it again to get the latest version. (`VikingCity.rbxlx` is the same place in text form, handy for reading changes on GitHub.)

This repository holds all the game's code. You edit it in **VS Code**, and **Rojo** syncs it live into **Roblox Studio** (setup below, only needed when you want to edit code yourself).

---

## What's in the first playable version

- Your own plot of land on a building grid, with a starting longhouse and 3 villagers.
- Trees, rocks and berry bushes to gather by hand (walk up and **hold E**). Gathering also clears land.
- 5 buildings: Longhouse (housing), Woodcutter, Quarry, Barley Farm (jobs), Storehouse (storage).
- Villagers take jobs automatically, walk to work, eat food, and get happier or sadder.
- Happy villages with free housing grow: babies are born and immigrants arrive. Starving or homeless villages shrink.
- A HUD with resources, population, happiness, the day counter, a build bar and a message feed.

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
| Gather wood / stone / food | Walk to a tree, rock or berry bush and hold **E** |
| Build | Click a building in the bottom bar, move the mouse over your land, click to place |
| Rotate | **R** while placing |
| Cancel | **Q**, or click the same button again |
| Demolish | Click **Demolish**, then click one of your buildings (50% refund) |

Tips: build a **Barley Farm** first so nobody starves, then a **Woodcutter**. Each Longhouse holds 5 people. Immigrants only come when you have free housing and your people are happy.

---

## Project layout

```
default.project.json          Rojo: maps folders to places in the Roblox game tree
src/
  shared/   -> ReplicatedStorage.Shared   (code both sides use)
    Config.luau         every balance number: costs, rates, timings
    Grid.luau           grid maths: cells, footprints, rotation
    Remotes.luau        RemoteEvents/RemoteFunctions between client and server
    ModelFactory.luau   builds the placeholder buildings, trees and villagers
  server/   -> ServerScriptService.Server
    init.server.luau    loads every service in Services/
    Services/
      PlotService.luau          gives each player land, spawns them there
      ColonyService.luau        colony state, resources, main loop, HUD sync
      BuildingService.luau      validates and places / demolishes buildings
      ResourceNodeService.luau  trees, rocks, bushes, hand gathering, regrowth
      VillagerService.luau      jobs, food, happiness, births, immigrants, walking
  client/   -> StarterPlayer.StarterPlayerScripts.Client
    init.client.luau    loads every controller in Controllers/
    Controllers/
      StateController.luau  receives colony snapshots from the server
      HudController.luau    the on-screen interface
      BuildController.luau  placement preview and demolish mode
docs/DESIGN.md          the full game design and roadmap
```

**Want to change the balance?** Edit `src/shared/Config.luau`. For example, make the Longhouse cheaper or days shorter.

**Adding a new system?** Make a new module in `src/server/Services/` with `Init` and `Start` functions; it is loaded automatically. Client UI goes in `src/client/Controllers/` the same way.

## Known limits of this first version

- Progress isn't saved yet (coming with DataStores in Phase 1).
- Buildings appear instantly; construction time comes later.
- Models are simple blocks made in code, so you can replace them with your own art.
