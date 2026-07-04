# Bloomsong — Roadmap

Phases 0–8 build the **vertical slice**: planting, growth, one season, a handful of residents, the diary, and progression — the full core loop, enjoyable on its own. Phases 9+ expand content and systems.

Every task is small, concrete, and ends with a ✅ **Test** line describing how to verify it by running the game (or a test scene). Do tasks in order within a phase; phases 2–4 have some flexibility but the listed order is the recommended one.

Conventions used below: "test scene" = a minimal `.tscn` under `tests/scenes/` that exercises one system in isolation. "Unit test" = an assertion function in the headless test runner (`tests/TestRunner.tscn`, see CLAUDE.md for the run command).

---

## Phase 0 — Project Setup
*Goal: an empty Godot project that runs, with the folder structure and git in place.*

- [x] **0.1 Install Godot 4.x (latest stable) and create the project** in `bloomsong/game/` with the Compatibility renderer (best for 2D + older hardware).
      ✅ Test: pressing F5 in Godot shows an empty window without errors.
- [x] **0.2 Create the folder structure** from CLAUDE.md (`scenes/`, `scripts/`, `content/`, `assets/`, `tests/`) with `.gdkeep` placeholder files so empty folders survive git.
      ✅ Test: folders visible in Godot's FileSystem dock.
- [x] **0.3 Initialize git** with a Godot `.gitignore` (ignore `.godot/`), commit.
      ✅ Test: `git status` is clean after the commit.
- [x] **0.4 Create `Main.tscn`** (Node2D root) and set it as the main scene. (The camera follows the player character, built in 1.6.)
      ✅ Test: run the game — an empty window opens without errors.
- [x] **0.5 Register the autoload skeletons** — empty scripts for `EventBus`, `Clock`, `PlayerData`, `ContentDB`, `HabitatDirector`, `SaveManager` — in Project Settings → Autoload.
      ✅ Test: game still runs; `print(Clock)` from Main shows the node.

## Phase 1 — Garden Grid & Terrain
*Goal: a visible garden you can paint terrain onto.*

- [x] **1.1 Define `TerrainData` Resource** (id, name, texture/tile, walkable, placeable) and create 3 terrain types as `.tres`: short grass, long grass, dirt. Placeholder art: flat colored 32×32 tiles.
      ✅ Test: the three `.tres` files open in the Inspector with all fields editable.
- [x] **1.2 Build the `Garden` scene**: terrain rendering (placeholder colored-cell renderer for now; swap to `TileMapLayer` with the Phase 8 art pass) + a `garden_model.gd` holding the terrain dictionary. Initialize a small garden (e.g. 20×15 cells) of short grass surrounded by a non-editable border.
      ✅ Test: run the game — a grass rectangle appears.
- [ ] **1.3 Cell picking + hover highlight**: convert mouse position to grid cell; draw a highlight over the hovered cell (dimmed/red outside the editable area).
      ✅ Test: highlight follows the mouse and snaps to cells.
- [x] **1.4 Terrain painting**: a temporary hotbar (keys 1–3 select terrain) and click-to-paint via `Garden.set_terrain()`. Model updates first, TileMapLayer reflects it.
      ✅ Test: paint dirt paths and long-grass patches; print the model dict and confirm it matches what's on screen.
- [x] **1.5 `ContentDB` autoload**: scan `content/terrain/` at startup into an id → Resource dictionary; hotbar now builds itself from ContentDB instead of hardcoded entries.
      ✅ Test: add a 4th terrain `.tres` (sand) — it appears in the hotbar with **zero code changes**.
- [x] **1.6 Player character v1**: a placeholder character walks with WASD/arrow keys, clamped to the garden; `Camera2D` follows with smoothing.
      ✅ Test: walk around the whole garden; camera follows; can't leave the map.

## Phase 2 — Planting & Growth
*Goal: plant things; watch them grow over time.*

- [x] **2.1 Define `PlantData` Resource** (per PLAN.md §5.1, without fruit for now) and author 3 plants: a flower (3 growth stages), a bush (3), a tree (4). Placeholder art: colored circles growing in size per stage.
      ✅ Test: `.tres` files editable in Inspector; stage texture arrays hold 3–4 images.
- [x] **2.2 `Clock` autoload v1**: game-minute tick (1 real second = 1 game minute, constant in one place), day counter, `day_passed` signal, and a debug time label on screen. Add a debug key to skip a whole day.
      ✅ Test: label ticks up; skip-day key advances the day counter.
- [x] **2.3 Placement in the model**: `Garden.place(id, cell)` / `remove(cell)` with validation (in bounds, unoccupied, terrain allows planting). Placements dictionary per PLAN.md §4.
      ✅ Test: from a debug key, place a flower — a stage-0 sprite appears at the cell; placing on water/dirt-where-invalid or an occupied cell is refused.
- [x] **2.4 Plant visual scene**: `Plant.tscn` reads its `PlantData` + growth stage and shows the right texture, positioned on its cell (multi-cell footprints anchor top-left).
      ✅ Test: manually set a placement's stage in code — sprite swaps correctly.
- [x] **2.5 Growth on the simulation tick**: each `day_passed`, placements advance growth toward `days_to_mature`; stage = fraction of maturity. Emit `plant_matured` on the EventBus.
      ✅ Test: plant all 3 species, skip days with the debug key — each reaches maturity after its configured day count.
- [ ] **2.6 Planting UI v1**: replace the debug key with a simple bottom-bar palette (terrain + plants from ContentDB, tool modes: plant / paint / remove).
      ✅ Test: full flow with mouse only — pick a flower, plant 5 of them, remove one, paint terrain.

## Phase 3 — Save/Load
*Goal: the garden persists. (Early on purpose — retrofitting saves is painful, and from here on every feature must save.)*

- [x] **3.1 `SaveManager`**: serialize clock + garden model to JSON in `user://saves/slot1.json` per PLAN.md §5.3 (with `version: 1`); load restores the model and rebuilds visuals from it.
      ✅ Test: plant a garden, quit, relaunch — everything is back, growth stages intact.
- [x] **3.2 Autosave** every 2 real minutes and on quit (`NOTIFICATION_WM_CLOSE_REQUEST`).
      ✅ Test: plant something, force-kill the game after the autosave interval, relaunch — it's there.
- [x] **3.3 Growth catch-up decision**: time does **not** pass while the game is closed (cozy convention — nothing is missed by not playing). Document in code; verify load doesn't double-apply growth.
      ✅ Test: save at day 3, wait, reload — still day 3.

## Phase 4 — Time, Season & Weather (single-season slice)
*Goal: mornings and nights exist; weather changes; the world state that habitats depend on is real.*

- [x] **4.1 Time-of-day**: `Clock` derives Morning/Afternoon/Evening/Night from the minute counter; emits `time_of_day_changed`. HUD shows a small clock + day.
      ✅ Test: watch the label cycle through all four periods across a day.
- [ ] **4.2 Ambient tint**: a `CanvasModulate` lerps color by time of day (warm morning, bright noon, orange evening, dark blue night).
      ✅ Test: visible, smooth day/night look.
- [ ] **4.3 Weather v1**: `Clock` rolls weather (sunny/cloudy/rain) once per morning from a weighted table; emits `weather_changed`; HUD icon + a simple rain overlay (particle scene).
      ✅ Test: skip several days; weather varies; rain is visible.
- [x] **4.4 Season scaffolding**: `Clock` knows the season (fixed to **Spring** for the slice, but the field, signal, and save support exist). `PlantData.bloom_seasons` respected: a mature flower shows its bloom texture only in listed seasons.
      ✅ Test: set a plant's bloom season to summer in its `.tres` — it stays unbloomed in spring.
- [x] **4.5 Unit tests for clock logic**: clock rollover (minute→day), time-of-day boundaries, weather table sums to 100%.
      ✅ Test: the headless test runner passes from the CLI.

## Phase 5 — Habitat System & First Residents ⭐ the heart
*Goal: create the right habitat → a creature actually shows up.*

- [x] **5.1 `Requirement` base + first subclasses**: `RequirePlantCategory`, `RequireSpecificPlant`, `RequireTerrain`, `RequireDecoration` (decoration support lands in 5.5) — each a small Resource with `is_met(model, clock)`.
      ✅ Test: unit tests — hand-build tiny garden models and assert each requirement type passes/fails correctly.
- [x] **5.2 Define `ResidentData`** (per PLAN.md §5.1) and author 4 residents with placeholder art: **Butterfly** (3 flowering plants + sunny + day), **Robin** (any mature tree + morning), **Rabbit** (bush + long grass), **Snail** (rain). Deliberately spans plants, terrain, weather, and time requirements.
      ✅ Test: `.tres` files open cleanly; requirements arrays visible in Inspector.
- [x] **5.3 `HabitatDirector` evaluation pass**: on the simulation tick, check each resident: requirements met AND active time/season/weather → mark eligible; schedule spawn within the next 1–3 ticks (bounded randomness). Despawn when conditions stop holding (leave animation, not a pop).
      ✅ Test: unit test for eligibility logic with a fake clock; in-game, plant 3 flowers on a sunny day → butterfly appears within a couple of minutes.
- [ ] **5.4 `Resident` scene + behaviors**: state machine cycling wander / rest / eat (behaviors listed in its data), staying near the cells that satisfied its requirements. Simple tween/`AnimatedSprite2D` movement.
      ✅ Test: robin flies to the tree area, hops around, occasionally sits.
- [x] **5.5 `DecorationData` + placement**: decorations placeable like plants (no growth); author **Bird Bath** and **Log**; give Robin a bird-bath requirement to prove decoration requirements work end-to-end.
      ✅ Test: tree alone ≠ robin; tree + bird bath in the morning = robin.
- [x] **5.6 Residents in saves**: discovered-status and sighting counts persist (resident *positions* don't need to — they're cosmetic and re-evaluated on load).
      ✅ Test: discover the butterfly, reload — still discovered; habitat still occupied.

## Phase 6 — Diary & Discovery Feel
*Goal: discovery is celebrated and recorded; the collection loop motivates.*

- [ ] **6.1 Discovery moment**: first sighting pauses ambient flow briefly — sparkle at the resident, name banner, gentle sound placeholder, "added to diary" toast.
      ✅ Test: first butterfly triggers the moment; second butterfly doesn't.
- [ ] **6.2 Diary UI — residents**: a book screen (toggle with Tab/button): grid of entries, undiscovered = silhouette + `diary_hint`. Entry page shows illustration, description, times seen, favorite season/weather/time, and favorites (plants/terrain/decorations) revealed per PLAN.md §8 hint policy.
      ✅ Test: 4 residents show correct discovered/undiscovered states; data matches their `.tres`.
- [ ] **6.3 Diary — plants section**: every species grown to maturity gets a page (times grown, bloom season).
      ✅ Test: grow all 3 plants, all 3 pages appear.
- [ ] **6.4 Sighting tracking**: `times_seen` increments per distinct visit (not per frame!); diary live-updates.
      ✅ Test: let the robin visit twice across two mornings → times_seen = 2.

## Phase 7 — Progression & Economy
*Goal: XP, levels, unlocks, money — the reward loop closes.*

- [ ] **7.1 XP + levels**: `PlayerData` grants XP for plant matured / resident discovered / diary page completed; level curve in a single `.tres`. HUD XP bar; level-up banner listing unlocks.
      ✅ Test: discoveries move the bar; crossing a threshold levels up.
- [ ] **7.2 Unlock gating**: palettes only show content with `unlock_level <= level`. Start the game with ~3 things unlocked; gate the rest across levels 2–5.
      ✅ Test: new save shows the starter set; leveling reveals more.
- [x] **7.3 Fruit & harvesting**: `FruitData` on plants (interval, item, value); mature fruiting plants show a fruit overlay on a timer; click to harvest into inventory. Author one fruiting plant (berry bush).
      ✅ Test: berry bush sprouts berries every N days; clicking collects them.
- [ ] **7.4 Resident gifts**: residents with `leaves_behind` occasionally drop an item sparkle on despawn; click to collect.
      ✅ Test: after several robin visits, a feather appears and is collectible.
- [ ] **7.5 Money + shop v1**: sell inventory items; buy seeds/decorations (money-gated on top of level-gating). Simple two-tab shop UI.
      ✅ Test: sell berries, buy a bird bath with the proceeds.
- [ ] **7.6 All of Phase 6–7 persists** (inventory, money, xp, level, diary).
      ✅ Test: full loop, reload, everything intact.

## Phase 8 — Vertical Slice Polish 🎉
*Goal: a stranger can enjoy 30 minutes unaided. Milestone: **the slice**.*

- [ ] **8.1 First-run experience**: tiny non-blocking hint prompts ("try planting a flower…", "something might like these blooms…") driven by state, dismissible, never a locked tutorial.
      ✅ Test: fresh save → a new player reaches their first discovery without being told the recipe.
- [ ] **8.2 First art pass (AI assets)**: replace placeholders for the ~15 slice items **plus the player character** using consistent prompt templates per category (documented in `assets/PROMPTS.md`); soft storybook look, transparent PNGs.
      ✅ Test: everything readable at gameplay zoom; no placeholder circles remain.
- [ ] **8.3 Audio pass**: one calm music loop, ambient birdsong by time-of-day, soft SFX for plant/harvest/discover/UI.
      ✅ Test: play with sound on — nothing harsh, discovery sound feels rewarding.
- [ ] **8.4 Balance pass**: tune growth times (first discovery within ~5 minutes), XP curve, prices; keep all tunables in the `.tres` files, not code.
      ✅ Test: a fresh playthrough hits discovery #1 in ≤5 min and level 2 in ≤15 min.
- [ ] **8.5 Playtest with 1–2 real people**, watch silently, fix the top 3 confusions.
      ✅ Test: second playtester has meaningfully fewer confusions.

---

## Post-Slice Expansion (each phase independently shippable)

## Phase 9 — Full Seasons
Season cycle (spring→…→winter) over N in-game days; per-season terrain/plant palettes (winter snow tint); seasonal blooming already works from 4.4; ~4 season-exclusive residents; diary favorite-season data becomes meaningful; season-change moment (falling leaves / first snow).

## Phase 10 — More Weather & Time Residents
Windy + snow weather; rare-weather excitement (post-rain puddles attract new visitors); night content: fireflies, owl; `RequireResident` chains go live: **fox requires rabbits**, dragonfly requires pond.

## Phase 11 — Water & Advanced Terrain
Water/sand/mud/stone terrain with auto-tiling edges; aquatic plants; pond-dependent residents (frog, turtle, dragonfly); `RequireAdjacent` requirement ("mud near water" → salamander).

## Phase 12 — Content Wave & Garden Expansion
Target ~25 plants / ~20 residents / ~15 decorations (pure content authoring — the architecture test: zero logic changes); purchasable garden expansions (unlock adjacent land parcels); achievements section in the diary.

## Phase 13 — Character Creation & Wardrobe
Character creator on new game (body/hair/color options as content Resources); `ClothingData` items (sprite layer, price, unlock level) sold in the shop — the personal-spending half of the economy; wardrobe UI to change outfits anytime; appearance persists in saves; bench "sit mode" (camera settles, ambient plays, residents ignore you); photo mode for sharing gardens + outfits.

## Phase 14 — Depth & Long-Tail
Plant color varieties/cross-pollination discoveries; resident favorites deepening (feeding preferences); diary completion rewards; daily gentle "curiosity prompts" ("a visitor was spotted near ponds at night…"); Steam page / itch.io build when it feels right.
