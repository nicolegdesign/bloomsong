# Bloomsong — Design & Architecture Plan

A relaxing single-player gardening game about creating a living ecosystem. This document explains **how** the game is built: the tech choices, the module boundaries, the data formats, and the reasoning behind each decision. For *what to build in what order*, see `ROADMAP.md`. For day-to-day conventions, see `CLAUDE.md`.

---

## 1. Tech Choices

| Choice | Decision | Why |
|---|---|---|
| Engine | **Godot 4.x** (latest stable, currently 4.4+) | Free, excellent 2D support, huge beginner community, and the user has chosen it. Godot 4's `TileMapLayer`, typed GDScript, and Resource system fit this game very well. |
| Language | **GDScript** (not C#) | Best documentation, best editor integration, no extra toolchain to install, and the vast majority of Godot tutorials use it. For a beginner this removes an entire category of setup problems. Performance is a non-issue for this game's scale. |
| Perspective | **2D, three-quarter (3/4) view** — square grid, camera as if tilted ~35° so objects show their fronts/sides and characters face the viewer (Stardew Valley / Legend of Mana convention) | The tilted look lives entirely in the sprite art + Y-sorting (lower on screen draws in front) + base-anchored sprites that overflow their tile upward. NOT true isometric — no diamond grid, no coordinate math changes; the garden model and habitat system are untouched. 2D stays dramatically simpler than 3D. Full art spec: `game/assets/PROMPTS.md`. |
| Visual scale | **64 px ground cells** at camera zoom 1.0; sprites base-anchored, taller than their tile (tree ≈ 128×192, character ≈ 64×96) | Large enough for painterly detail to read, small enough that the 20×15 starter garden fills a 1280×720 window nicely. The current 32 px placeholder scale is retuned to this spec when the first real art lands (ROADMAP 8.2) — one contained change to `CELL`, speeds, and radii. |
| Placement model | **Grid-based** (a cell grid, e.g. 32×32 px tiles for terrain; plants/decorations occupy 1×1, 1×2, 2×2 … cells) | A grid makes habitat logic simple and predictable ("3 flowers within 5 cells"), makes saving trivial, and makes the garden feel tidy without a placement UI nightmare. Free-form placement can be revisited later; the grid is the source of truth either way. |
| Player embodiment | **Walking character** (3/4 view, mostly front-facing so the face is visible; WASD/arrows, camera follows) | The player is a character in the garden, not a cursor. This enables character creation and buyable clothes/looks (a second, personal motivation for earning money alongside garden decorations) and adds cozy presence. Clothing items are content Resources like everything else; appearance is saved in PlayerData. |
| Content data | **Godot custom Resources (`.tres` files)** for plants, residents, decorations, terrain types | See §5. Short version: they're editable in the Godot Inspector (beginner-friendly, no JSON syntax errors possible), type-checked, and support dropdowns/previews. Adding a new plant = duplicating a file and editing fields in a form. |
| Save data | **JSON in `user://`** | See §5.3. Human-readable, version-tolerant, and safe (loading serialized Resources from disk can execute code; JSON can't). |
| Art | **AI-generated assets**, imported as PNGs with transparent backgrounds | Consistent prompt templates per asset category keep the style coherent — the master style anchor, per-category templates, exact canvas sizes, and the approved-prompt log all live in `game/assets/PROMPTS.md`. Placeholder colored shapes are used until art exists — gameplay never waits on art. |
| Testing | Manual **test scenes** per system + a **lightweight headless test runner** (`tests/TestRunner.tscn`, plain assertion functions, run from the CLI) for pure-logic code | Habitat evaluation, growth math, clock math, and save round-trips are pure logic and deserve automated tests. Running a scene headless loads the full project (autoloads included) with no addon to install or maintain. UI and visuals are verified by running dedicated small scenes. |

---

## 2. High-Level Architecture

```
                    ┌──────────────────────────────┐
                    │        EventBus (autoload)    │  ← global signals, no logic
                    └──────▲──────────▲──────────▲──┘
                           │          │          │
   ┌───────────┐    ┌──────┴────┐  ┌──┴───────┐  │
   │  Clock     │    │  Garden   │  │ Habitat  │  │
   │ (autoload) │───▶│  (scene)  │─▶│ Director │  │
   │ time/season│    │ grid state│  │(autoload)│  │
   │ /weather   │    │ + visuals │  │ evaluates│  │
   └───────────┘    └───────────┘  │ + spawns │  │
                           │        └────┬─────┘  │
                    ┌──────▼────┐   ┌────▼─────┐  │
                    │ SaveManager│   │ Residents │  │
                    │ (autoload) │   │ (scenes)  │  │
                    └───────────┘   └───────────┘  │
                    ┌───────────────────────────┐  │
                    │ PlayerData (autoload)      │──┘
                    │ xp, level, money, diary,   │
                    │ unlocks                    │
                    └───────────────────────────┘
```

### Autoload singletons (global, always loaded)

| Autoload | Responsibility |
|---|---|
| `EventBus` | Declares global signals only (`resident_discovered`, `plant_matured`, `season_changed`, …). **Contains zero game logic.** Systems talk through it instead of holding references to each other. |
| `Clock` | Owns game time: time-of-day, day count, season, weather. Emits ticks and change signals. Everything else *reads* time from here; nothing else keeps its own clock. |
| `PlayerData` | XP, level, money, unlocks, diary entries, achievements. Pure state + mutation methods (`add_xp()`, `record_sighting()`). Emits signals when values change. |
| `HabitatDirector` | On a slow tick (every few in-game minutes), evaluates every resident's requirements against the garden and decides who visits. Spawns/despawns resident scenes. |
| `SaveManager` | Serializes `PlayerData` + `Garden` grid + `Clock` to JSON and back. |
| `ContentDB` | Loads all content Resources (plants, residents, decorations, terrain) at startup and provides lookup by id. One place that knows where content lives on disk. |

### Scenes (instanced, in the scene tree)

| Scene | Responsibility |
|---|---|
| `Main` | Root. Instantiates Garden, UI, camera. Wires nothing — systems find each other via autoloads/EventBus. |
| `Garden` | Owns the **grid model** (see §4) and the visual layers (terrain TileMapLayer, plant sprites, decoration sprites). The only code allowed to mutate the grid. |
| `Plant` / `Decoration` | Visual scene per placed object; reads its data Resource for sprites and behavior (growth stages, bloom seasons). |
| `Resident` | A visiting animal. Small state machine: wander / eat / drink / rest / sit / leave. Purely cosmetic behaviors — residents never affect the grid. |
| `Player` | The walking character: input → movement, camera follow, later animations and clothing sprite layers. Asks `Garden` to act on cells; never mutates the grid itself. Appearance (body/hair/clothing ids) lives in `PlayerData`. |
| `UI` | HUD (money, XP, clock), build palette, diary screen, shop. Talks to systems only via autoload method calls and EventBus signals. |

---

## 3. The Game Loop

Bloomsong is **real-time with slow ticks**, not frame-driven simulation. Three cadences:

1. **Frame** (`_process`) — only animation and input. No game logic.
2. **Game-minute tick** (`Clock`, e.g. 1 real second = 1 game minute) — advances time-of-day; triggers time-of-day / weather / season change signals at boundaries.
3. **Simulation tick** (every ~10 game minutes) — the interesting one:
   - **Growth pass**: every planted plant advances its growth timer; matured plants emit `plant_matured`; fruiting plants may produce fruit.
   - **Habitat pass** (`HabitatDirector`): evaluate resident requirements → spawn qualifying residents (with gentle randomness in *when*, never in *whether* — if requirements are met, the resident **will** appear within a bounded window; the player is never denied a discovery they earned).

Why slow ticks: the game has no reflexes, so evaluating habitats 60×/second is wasted work and makes behavior hard to reason about. A visible-but-gentle cadence also creates the pleasant "checking back in" rhythm of cozy games.

**Player interaction loop** (event-driven, outside the ticks):
select tool/item → click cell → `Garden` validates & mutates grid → grid emits change → visuals update → habitat pass picks up the new state on its next tick.

---

## 4. Garden State Model

**The grid model is the single source of truth; visuals are a projection of it.** This is the most important architectural rule in the project.

```gdscript
# Conceptually, per cell (stored in Garden):
terrain: Dictionary[Vector2i, StringName]      # cell -> terrain id ("long_grass")
placements: Dictionary[Vector2i, Placement]    # anchor cell -> what's placed there
# Placement = { id: StringName, kind: PLANT|DECORATION, planted_on_day: int,
#               growth_stage: int, fruit_ready: bool, ... }
```

- All mutations go through `Garden` methods (`set_terrain()`, `place()`, `remove()`, `harvest()`), which validate, update the model, update visuals, and emit signals.
- **Habitat queries run against the model, never the scene tree.** "Are there 3 flowering plants within radius 6 of a water cell?" is a dictionary scan, not a physics query. This keeps the habitat system fast, deterministic, and unit-testable without rendering anything.
- Saving the garden = serializing these dictionaries. No scene state needs saving.

---

## 5. Data Formats

### 5.1 Content: custom Resources (`.tres`)

Every plant, resident, decoration, and terrain type is a **data file, not code**. Adding content must never require touching game logic (the stated technical goal).

Custom Resource classes (scripts in `scripts/data/`):

```gdscript
class_name PlantData extends Resource
@export var id: StringName
@export var display_name: String
@export var category: Types.PlantCategory  # FLOWER, BUSH, TREE, GROUND_COVER, AQUATIC
@export var allowed_terrain: Array[StringName]  # soil preference — dirt today; wildflowers
                                          # on grass / aquatics on water are content edits
@export var days_to_mature: int
@export var growth_stages: int            # visual stages incl. mature (textures at art pass)
@export var bloom_seasons: int            # season flags
@export var fruit_item: StringName        # repeating harvest ("" = none), every fruit_interval_days
@export var harvest_whole_item: StringName # one-shot: cut the whole mature plant for this item
@export var unlock_level: int
@export var seed_price: int               # plus xp_on_plant / xp_on_mature
```

```gdscript
class_name ResidentData extends Resource
@export var id: StringName
@export var display_name: String
@export var diary_description: String
@export var texture: Texture2D
@export var requirements: Array[Requirement]   # see below — the heart of the game
@export var behaviors: Array[Behavior]         # WANDER, EAT, DRINK, REST, FLY, SIT, SLEEP
@export var active_times: Array[TimeOfDay]
@export var active_seasons: Array[Season]
@export var weather_needed: Array[Weather]     # empty = any
@export var leaves_behind: ItemData            # honey, fur, … (null if none)
@export var xp_on_discovery: int
@export var diary_hint: String                 # shown before discovery
```

**Requirements are composable Resources** — this is what makes the habitat system extensible without code changes:

```gdscript
class_name Requirement extends Resource
func is_met(garden: GardenModel, clock: Clock) -> bool: ...   # overridden

# Concrete subclasses (each a tiny script):
# RequirePlantCategory  (category, count, radius)      "3 flowering plants"
# RequireSpecificPlant  (plant_id, count)              "an oak tree"
# RequireTerrain        (terrain_id, min_cells)        "some long grass"
# RequireDecoration     (decoration_id)                "a bird bath"
# RequireResident       (resident_id, min_visits)      "rabbits already live here" → fox chains
# RequireAdjacent       (a near b within radius)       "bush next to long grass"
```

A resident's habitat = an `Array[Requirement]`, ANDed together. New requirement types are new small scripts; new residents are pure data. This directly supports the "chains of discovery" design (fox requires rabbits).

**Why Resources instead of JSON:**
- Edited in the Godot Inspector as a **form with dropdowns, texture previews, and type checking** — a beginner cannot make a syntax error or typo an enum value.
- Textures and nested resources are direct references, not string paths to keep in sync.
- `.tres` is a text format, so it still diffs fine in git.
- Trade-off accepted: content is editable only inside Godot (fine — the user works in Godot anyway) and bulk edits are less convenient than JSON (acceptable at this game's content scale; a spreadsheet-import script can be added later if content grows into the hundreds).

### 5.2 Content organization

```
content/
  plants/        sunflower.tres, oak_tree.tres, ...
  residents/     robin.tres, butterfly.tres, ...
  decorations/   bird_bath.tres, log.tres, ...
  terrain/       short_grass.tres, water.tres, ...
  items/         honey.tres, apple.tres, ...
  clothing/      straw_hat.tres, ...          (post-slice: ClothingData — sprite layer, shop price, unlock level)
```

`ContentDB` scans these folders at startup; **dropping a new `.tres` in the folder is the entire integration step** for new content.

### 5.3 Save data: JSON in `user://saves/`

```json
{
  "version": 1,
  "clock":  { "day": 34, "minute": 610, "season": "summer", "weather": "sunny" },
  "player": { "xp": 1240, "level": 5, "money": 380,
              "appearance": { "body": "base_1", "hair": "short_brown", "clothes": ["straw_hat"] },
              "unlocks": ["sunflower", "bird_bath"],
              "diary": { "robin": { "times_seen": 12, "first_seen_day": 3 } } },
  "garden": { "terrain":    [ { "cell": [4, 7], "id": "long_grass" } ],
              "placements": [ { "cell": [5, 7], "id": "sunflower", "stage": 2,
                                "planted_on_day": 30 } ] }
}
```

- **Why JSON, not packed Resources:** loading `.tres`/`.res` from a save file can execute embedded scripts (a known Godot security foot-gun), resource saves break when class definitions change, and JSON is debuggable by opening it in a text editor. A `version` field + per-version migration function keeps old saves loadable as the game evolves.
- Content Resources are **never** serialized into saves — saves store content **ids** (`"sunflower"`), and `ContentDB` resolves ids at load time. Changing a plant's stats later automatically applies to existing gardens.
- Autosave on a timer + on quit. No fail states means no save-scumming concerns.

---

## 6. Module Boundaries & Dependency Rules

Allowed dependencies (an arrow means "may call / read"):

```
UI ──▶ PlayerData, Clock, Garden (read + player-action methods), ContentDB
HabitatDirector ──▶ Garden (model, read-only), Clock (read), ContentDB
Garden ──▶ ContentDB
Resident scenes ──▶ Clock (read)          # for time-of-day behavior
SaveManager ──▶ Garden, PlayerData, Clock  # serialize/restore only
everything ──▶ EventBus                    # emit + connect
```

Hard rules:
- **Nothing calls into UI.** UI observes via signals.
- **Only `Garden` mutates the grid.** Residents, UI, and the director request; Garden decides.
- **Only `Clock` knows what time it is.** No `Time.get_ticks_msec()` game logic anywhere else.
- **Residents are cosmetic.** They can be discovered and leave items (via HabitatDirector), but their scene-level wandering never changes game state — so despawning them is always safe.
- **Content scripts contain data + pure predicates only** (e.g. `Requirement.is_met()`), never side effects.

These rules are what make the systems independently testable: the habitat evaluator can be tested headlessly with a hand-built grid model and a fake clock.

---

## 7. Key Flows

**Planting:** UI (palette) → `Garden.place("sunflower", cell)` → validates terrain + occupancy + unlock → model updated → `Plant` scene instanced showing stage-0 texture → `EventBus.placement_changed`.

**Growth:** simulation tick → Garden advances each placement's timer using `days_to_mature` → stage changes swap the sprite → maturity emits `plant_matured` → PlayerData grants XP.

**Discovery:** habitat pass → all requirements of an undiscovered resident are met → HabitatDirector schedules an appearance within the next few ticks (bounded, so it's earned-not-lucky) → resident scene spawns, plays its behaviors → first sighting emits `resident_discovered` → diary page unlocks (celebration UI moment), XP granted → subsequent visits increment `times_seen` and occasionally drop `leaves_behind` items.

**Economy:** harvest fruit / pick up left-behind items → inventory in PlayerData → sell via shop UI → money → buy unlocked decorations/plants/**clothing** (two parallel spending motivations: beautify the garden, personalize the character).

**Progression:** XP thresholds per level in one curve Resource → level-up emits signal → UI shows what was unlocked → ContentDB filters palettes by `unlock_level`.

---

## 8. Design-Philosophy Guardrails (encoded in architecture)

- **No fail states:** plants cannot die; nothing costs XP; removal refunds partially or fully.
- **No punishing randomness:** randomness affects *timing and flavor* (when the robin shows up, where it lands), never *whether* an earned discovery happens.
- **Hints over recipes:** `diary_hint` fields ship with content; the diary reveals requirement categories ("likes: some kind of tree") after repeated near-misses, so experimentation converges instead of stalling.
- **Content-first extensibility:** if adding a resident requires editing any `.gd` file other than (possibly) a new `Requirement` subclass, the architecture has failed — fix the architecture, not the content.
