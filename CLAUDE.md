# CLAUDE.md — Bloomsong

Cozy gardening/ecosystem game in three-quarter (3/4) view, built in **Godot 4.x + GDScript**. Art spec and AI prompt templates: `game/assets/PROMPTS.md`. Read `PLAN.md` for architecture (module boundaries, data formats, the dependency rules in §6 are **binding**) and `ROADMAP.md` for what to build next. Work in roadmap order; check off tasks in `ROADMAP.md` as they're completed.

## The user is a Godot beginner

This shapes everything:
- Whenever the user must do something in the Godot editor (import an asset, edit a `.tres`, add an autoload, click a button), give **numbered step-by-step instructions naming the exact UI elements** ("In the FileSystem dock (bottom-left), right-click `content/plants/` → New Resource… → type `PlantData` → …"). Never say "just create a resource".
- Prefer doing things in code/files over editor clicking when both work, so changes are reviewable and repeatable — but content authoring (`.tres` editing) is intentionally an Inspector workflow for the user.
- When something goes wrong, explain the *why* in one plain sentence before the fix.
- Introduce one new Godot concept at a time; link the relevant Godot docs page when introducing it.

## Repository layout

```
bloomsong/
  PLAN.md  ROADMAP.md  CLAUDE.md
  game/                      # the Godot project (project.godot lives here)
    project.godot
    scenes/                  # .tscn files
      main/                  # Main.tscn
      garden/                # Garden.tscn, Plant.tscn, Decoration.tscn (as they get authored)
      player/                # Player.tscn — the walking character
      residents/             # Resident.tscn (+ per-resident variants only if needed)
      ui/                    # HUD, diary, shop, palette
    scripts/
      autoload/              # event_bus.gd, clock.gd, player_data.gd, content_db.gd,
                             # habitat_director.gd, save_manager.gd
      data/                  # Resource class definitions: plant_data.gd, resident_data.gd,
                             # requirement.gd + subclasses, ...
      garden/  player/  residents/  ui/   # scene scripts, mirroring scenes/
    content/                 # ALL game content as .tres — no gameplay values in code
      plants/  residents/  decorations/  terrain/  items/  progression/
                             # clothing/ arrives post-slice (Phase 13)
    assets/
      art/                   # PNGs, subfolders mirror content/; PROMPTS.md for AI art prompts
      audio/                 # music/, sfx/
    tests/
      test_runner.gd         # headless assertion runner (+ TestRunner.tscn)
      unit/                  # one test_*.gd suite per system, loaded by the runner
      scenes/                # manual test scenes, one system each
```

## Conventions

**Naming**
- Files & folders: `snake_case` (`plant_data.gd`, `bird_bath.tres`). Scenes: `PascalCase.tscn` (`Garden.tscn`).
- Classes: `PascalCase` via `class_name`. Nodes in scene trees: `PascalCase`.
- Variables/functions: `snake_case`; constants `SCREAMING_SNAKE`; signals past tense (`plant_matured`, `season_changed`); private helpers `_prefixed`.
- Content ids: `snake_case` `StringName`s matching the filename (`bird_bath.tres` → `&"bird_bath"`). Ids are forever (they live in save files) — never rename a shipped id; if unavoidable, add a save-migration.

**GDScript**
- Static typing everywhere: `var count: int = 0`, typed function signatures, typed arrays (`Array[Requirement]`).
- Every script starts with `class_name` (if reusable) and a one-line comment saying what it owns.
- Signal flow: cross-system communication goes through `EventBus`; parent↔child within one scene may use direct signals/calls. Connect in `_ready()`, typed callables.
- No magic numbers in logic — tunables live in the relevant `.tres` or a `constants.gd`.
- Respect PLAN.md §6: only `Garden` mutates the grid; only `Clock` tells time; nothing calls into UI; residents never change game state.

**Content**
- Adding content = adding a `.tres` under `content/` (+ art). If a new plant/resident/decoration requires editing game logic, stop and fix the architecture instead (new `Requirement` subclasses are the one allowed code addition).
- Every resident ships with a `diary_hint` — no hintless content.
- Placeholder art is always acceptable; never block gameplay work on assets.

**Git**
- Commit per roadmap task, message like `1.4: terrain painting`. `.godot/` is gitignored; `.tres`, `.tscn`, `project.godot` are committed. Text (not binary) resource formats only.

## How to run

- **Editor:** open Godot → Import → select `game/project.godot` → F5 runs the game (F6 runs just the currently open scene — handy for test scenes).
- **CLI (for Claude):** the binary is `$GODOT` where
  `GODOT=/Users/nicoler/Downloads/Godot.app/Contents/MacOS/Godot` (Godot 4.7; if the app moves to `/Applications`, update this path here).
  `$GODOT --path game/` runs the game; `$GODOT --path game/ --headless --quit-after 60` is a quick "does it boot" check that surfaces script/runtime errors in the terminal.

## How to test

1. **Every roadmap task has a ✅ Test line** — run it before calling the task done, and say what you observed.
2. **Unit tests** for pure logic: clock math, requirements, growth, save round-trips. No addon — `tests/TestRunner.tscn` runs every `tests/unit/test_*.gd` suite and quits with a nonzero exit code on failure:
   `$GODOT --path game/ --headless res://tests/TestRunner.tscn`
   Habitat `Requirement` logic **must** have unit coverage — it's the heart of the game and is pure enough to test headlessly with hand-built garden models.
3. **Manual test scenes** in `tests/scenes/` for anything visual — one small scene per system, run with F6. Keep them working; they're the debugging toolkit.
4. **Save-file check:** after touching anything persisted, do a save → quit → load round-trip. Saves live at `user://saves/` (macOS: `~/Library/Application Support/Godot/app_userdata/Bloomsong/saves/`).

## Design guardrails (never violate)

No enemies, no combat, no fail states, no time pressure, no punishing randomness. Plants don't die. Randomness may affect *when/where*, never *whether* an earned discovery happens. If a mechanic can frustrate, redesign it — the game must stay relaxing.
