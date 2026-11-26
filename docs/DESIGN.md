# Viking City: Design Document

*Working title. Living document; update it as the game changes.*

## 1. Pitch

Lead a small band of Norse settlers to an untamed coast. Grow a humble camp into a thriving town through careful planning, keep your people fed, sheltered and inspired, then take to the sea to trade, fight and raid. Other players' towns can be raided for loot but are never wiped out, so losing a battle stings without ending your game.

Pillars:

1. **Organic growth.** Population grows from your people's wellbeing (births) and your reputation (immigrants), not by buying units.
2. **Meaningful choices.** Tech, faith and culture paths shape a distinct settlement identity.
3. **Fair conflict.** Raiding rewards preparation; defenders keep their town and gain shields and revenge options.
4. **Approachable.** Plays well with mouse, touch and controller, and sessions of 10 to 30 minutes feel productive.

## 2. Core loop

```
gather + produce  ->  build + upgrade  ->  more people / better tech
       ^                                         |
       +---------  raid / trade for loot  <------+
```

Short loop (minutes): gather, place buildings, assign workers, keep food above zero.
Mid loop (hours): unlock tech, choose faith and culture traits, expand housing, attract tribes.
Long loop (days): build a fleet, raid NPC and player towns, climb the leaderboard, join a clan (later).

## 3. Systems

### 3.1 Land and building
- Each player owns a plot on a grid (now 20 x 20 cells of 8 studs). Future: expandable land claims, terrain features (coast, hills, forest density) that affect what you can build.
- Buildings have footprint, cost, workers, housing, storage, and later **upgrade tiers** (I to III) and **construction time** that workers must complete.
- Roads (Phase 2) raise villager walk speed and are required to connect workplaces to storage.

### 3.2 Resources
| Tier | Resources | Source |
| --- | --- | --- |
| Basic (now) | Wood, Stone, Food | Woodcutter, Quarry, Farm, hand gathering |
| Processed (Phase 2) | Planks, Iron, Tools, Cloth, Mead | Sawmill, Smelter, Smithy, Weaver, Brewery |
| Luxury (Phase 3) | Silver, Amber, Furs | Trade, raids, special nodes |

Storage caps every resource; storehouses raise the cap. Later: resources physically carried to storage by villagers.

### 3.3 Villagers and needs
- Each villager has a name, age, job, and home. Children become workers after a few days.
- **Needs (now):** food and shelter. **Later:** warmth (firewood in winter), faith (temple access), variety (more than one food type), safety (defences).
- **Happiness** is the master stat: it drives productivity, birth rate, immigration and emigration.

### 3.4 Population growth
- **Births:** with 2+ adults, free housing, food and good happiness, a child may be born each day.
- **Immigration:** neighbouring tribes (Ravenfjord clan, Ashvale folk and others, all fictional) send settlers when you are happy and have room. Later, tribes have **relations**: gift them, trade with them, or raid them, which changes who comes and what traits they bring (for example skilled smiths or sailors).
- **Emigration:** unhappy villagers leave.

### 3.5 Technology
A tree unlocked with **Lore** points produced by a Skald's Hall and later a Runestone Workshop.
- *Economy branch:* crop rotation, heavy plough, sawmill, iron smelting.
- *Craft branch:* better tools (+production), longships, siege rams.
- *Civic branch:* roads, granary (food spoilage protection), town hall tiers.

### 3.6 Religion traits
Build a shrine, then a temple. Each settlement chooses **one patron path** and unlocks traits with **Faith** points earned from offerings and festivals. Paths are original and themed around nature rather than real deities:
- *Path of the Storm:* raiding and sea bonuses (faster ships, morale in battle).
- *Path of the Hearth:* growth bonuses (birth rate, happiness from feasts).
- *Path of the Deep Woods:* gathering bonuses and hidden scouting.
Seasonal festivals are timed events that cost resources and give a temporary happiness boost.

### 3.7 Culture traits
Gained at population milestones (10, 25, 50, 100). Pick one of three random traits each time, e.g. *Master Shipwrights* (cheaper boats), *Saga Tellers* (+Lore), *Shieldwall Tradition* (+defence), *Fur Traders* (better trade prices). Culture gives each town a unique identity and visible decorations.

### 3.8 Weapons and military
- **Smithy** makes weapons from iron: axes, spears, swords, bows, shields; later armour.
- Villagers are drafted into **warbands**; drafted villagers stop working, so war has an economic cost.
- Unit types: Spearmen (defence), Axemen (assault), Archers (ranged), Berserkers (elite, culture-gated).

### 3.9 Ships and naval combat (Phase 4)
- **Shipyard** builds boats: Skiff (scouting, fishing), Karve (cargo + 10 warriors), Longship (30 warriors, fast), Knarr (trade).
- Sailing is real-time on an open ocean map with islands and NPC settlements.
- Naval battles: ramming, boarding, and archers. Ships carry warbands to raid targets.

### 3.10 Raiding
- **NPC towns:** scripted settlements with defences and loot tables; they rebuild over time.
- **Player towns (asynchronous):** the attacker fights the defender's AI-controlled garrison and defences while the defender is offline or busy.
  - Towns are **never destroyed**. The raider takes a **capped percentage** of stored resources (unprotected portion; storehouse tiers protect more).
  - The defender gets a **peace shield** for a period after being raided, plus a **revenge** option.
  - Matchmaking by town strength so new players aren't farmed.
- Defences: palisades, watchtowers, gates, traps, and a garrison of drafted villagers.

### 3.11 Persistence and economy (Phase 1)
- DataStore save of resources, buildings, villagers, tech and traits; autosave plus save on leave.
- Offline progress: capped production while away so returning feels rewarding.
- Monetisation (optional, later and fair): cosmetics (building skins, ship sails), a seasonal pass with cosmetic rewards. No paying for raid power.

## 4. Roadmap

| Phase | Goal | Contents |
| --- | --- | --- |
| **0. Prototype (this PR)** | A playable core loop | Plots, grid placement, 5 buildings, hand gathering, villagers with food/shelter, happiness, births, immigration, HUD |
| **1. Foundation** | Players can come back to their town | DataStore saving, construction time, building upgrades, better camera (top-down builder camera), tutorial quests, sound |
| **2. Economy depth** | Production chains | Processed resources, roads, villagers carrying goods, seasons and winter warmth, more housing tiers, real art assets |
| **3. Identity** | Towns feel unique | Technology tree, religion paths and festivals, culture traits at milestones, tribe relations and trade |
| **4. Military and sea** | Fight and sail | Smithy and weapons, warbands, defences, shipyard and boats, ocean map, NPC raids |
| **5. Player raids** | Multiplayer conflict | Asynchronous raids on player towns, loot caps, shields, revenge, matchmaking, leaderboards |
| **6. Live game** | Keep players engaged | Clans, seasonal events, cosmetics, balance passes, analytics |

## 5. Technical architecture

- **Rojo** syncs `src/` into Studio. Code is plain Luau, organised as server **Services** and client **Controllers**, each with `Init` and `Start`.
- **Server authoritative:** the client only asks ("place a Farm here"); the server validates and changes state. This matters for raiding later.
- **State sync:** the server sends each player a compact colony snapshot every tick. As systems grow, switch to diff-based updates or a replication library.
- **Config-driven:** all numbers live in `src/shared/Config.luau` so balance changes need no logic changes.
- **Art:** placeholder models are generated in `ModelFactory`; real models can be dropped in later without changing game logic.
