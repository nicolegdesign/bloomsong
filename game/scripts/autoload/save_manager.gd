extends Node
## Saves/loads the whole game as JSON in user:// (PLAN.md §5.3).
## Content is referenced by id only — never serialized into saves.

const SAVE_DIR := "user://saves"
const SAVE_PATH := "user://saves/slot1.json"
const SAVE_VERSION := 1
const AUTOSAVE_SECONDS := 120.0

var _garden: Node = null
var _autosave_accumulator := 0.0


func register_garden(garden: Node) -> void:
	_garden = garden


func _process(delta: float) -> void:
	_autosave_accumulator += delta
	if _autosave_accumulator >= AUTOSAVE_SECONDS:
		_autosave_accumulator = 0.0
		save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> bool:
	if _garden == null:
		return false
	var data := {
		"version": SAVE_VERSION,
		"clock": Clock.serialize(),
		"player": PlayerData.serialize(),
		"garden": _garden.model.serialize(),
	}
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	EventBus.game_saved.emit()
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		push_error("SaveManager: corrupt save file")
		return false
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version > SAVE_VERSION:
		push_error("SaveManager: save from a newer game version")
		return false
	# version < SAVE_VERSION: run migrations here as the format evolves.
	Clock.deserialize(data.get("clock", {}))
	PlayerData.deserialize(data.get("player", {}))
	if _garden != null:
		_garden.load_model(GardenModel.deserialize(data.get("garden", {})))
	EventBus.game_loaded.emit()
	return true
