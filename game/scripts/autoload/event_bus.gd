extends Node
## Global signals only — no logic lives here (see PLAN.md §2).
## Cross-system communication goes through these; within one scene, direct signals are fine.

# World / time (emitted by Clock)
signal minute_ticked(minute: int)
signal day_passed(day: int)
signal time_of_day_changed(time_of_day: int)
signal season_changed(season: int)
signal weather_changed(weather: int)

# Garden (emitted by Garden)
signal terrain_changed(cell: Vector2i)
signal placement_changed(cell: Vector2i)
signal plant_matured(cell: Vector2i, plant_id: StringName)
signal fruit_ready(cell: Vector2i, plant_id: StringName)

# Residents (emitted by HabitatDirector / PlayerData)
signal resident_spawned(resident_id: StringName, cell: Vector2i)
signal resident_despawned(resident_id: StringName)
signal resident_discovered(resident_id: StringName, cell: Vector2i)

# Player progression / economy (emitted by PlayerData)
signal xp_changed(xp: int, level: int)
signal level_up(level: int, unlocked_names: Array)
signal money_changed(money: int)
signal item_collected(item_id: StringName, count: int)

# Meta
signal toast(message: String)
signal game_loaded
signal game_saved
signal toggle_diary
