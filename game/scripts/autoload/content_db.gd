extends Node
## Loads every content .tres at startup and provides lookup by id (PLAN.md §2).
## Dropping a new .tres into content/<folder>/ is the entire integration step.

var terrain: Dictionary = {}      # id -> TerrainData
var plants: Dictionary = {}       # id -> PlantData
var decorations: Dictionary = {}  # id -> DecorationData
var residents: Dictionary = {}    # id -> ResidentData
var items: Dictionary = {}        # id -> ItemData
## The XP curve (ROADMAP 7.1) — a single resource, not a folder of many, since
## there's only one progression curve for the whole game.
var level_curve: LevelCurveData


func _ready() -> void:
	_load_dir("res://content/terrain", terrain)
	_load_dir("res://content/plants", plants)
	_load_dir("res://content/decorations", decorations)
	_load_dir("res://content/residents", residents)
	_load_dir("res://content/items", items)
	level_curve = load("res://content/progression/level_curve.tres") as LevelCurveData
	print("ContentDB: %d terrain, %d plants, %d decorations, %d residents, %d items"
			% [terrain.size(), plants.size(), decorations.size(), residents.size(), items.size()])


func get_terrain(id: StringName) -> TerrainData:
	return terrain.get(id) as TerrainData


func get_plant(id: StringName) -> PlantData:
	return plants.get(id) as PlantData


func get_decoration(id: StringName) -> DecorationData:
	return decorations.get(id) as DecorationData


func get_resident(id: StringName) -> ResidentData:
	return residents.get(id) as ResidentData


func get_item(id: StringName) -> ItemData:
	return items.get(id) as ItemData


## Sorted list for build palettes (by unlock level, then name).
func sorted_list(dict: Dictionary) -> Array:
	var arr := dict.values()
	arr.sort_custom(func(a, b):
		if a.unlock_level != b.unlock_level:
			return a.unlock_level < b.unlock_level
		return String(a.display_name) < String(b.display_name))
	return arr


## Display names of content that becomes available at exactly this level.
func newly_unlocked_at(level: int) -> Array:
	var names: Array = []
	for dict in [plants, decorations, terrain]:
		for data in dict.values():
			if data.unlock_level == level:
				names.append(data.display_name)
	return names


func _load_dir(path: String, into: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ContentDB: missing content folder " + path)
		return
	for file in dir.get_files():
		# Exported builds rename resources to .tres.remap; strip that suffix.
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res: Resource = load(path + "/" + name)
		if res == null or not "id" in res or res.id == StringName(""):
			push_warning("ContentDB: could not load or missing id: " + name)
			continue
		if into.has(res.id):
			push_warning("ContentDB: duplicate id " + String(res.id))
		into[res.id] = res
