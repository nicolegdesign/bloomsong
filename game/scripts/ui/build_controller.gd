class_name BuildController
extends Node
## Temporary build controls until the real palette UI (ROADMAP 2.6):
##   Tab = cycle mode (terrain / plant / decoration), 1–9 = pick item,
##   Left click = paint/plant/place (or harvest ripe fruit), Right click = remove.
## Holds selection state only; all mutations go through Garden.

enum Mode { TERRAIN, PLANT, DECORATION }

const MODE_NAMES := ["Terrain", "Plant", "Decoration"]

## Emitted whenever mode or selected item changes, from keyboard or the palette UI.
signal selection_changed

var garden: Garden

var _mode: Mode = Mode.PLANT
var _index := 0


func mode() -> Mode:
	return _mode


func index() -> int:
	return _index


func set_mode(new_mode: Mode) -> void:
	_mode = new_mode
	_index = 0
	selection_changed.emit()


func select_index(i: int) -> void:
	_index = i
	selection_changed.emit()


func current_list() -> Array:
	var dict: Dictionary
	match _mode:
		Mode.TERRAIN: dict = ContentDB.terrain
		Mode.PLANT: dict = ContentDB.plants
		Mode.DECORATION: dict = ContentDB.decorations
	return ContentDB.sorted_list(dict).filter(PlayerData.is_unlocked)


func current_item() -> Resource:
	var list := current_list()
	if list.is_empty():
		return null
	return list[clampi(_index, 0, list.size() - 1)]


## One line for the HUD, e.g. "[Plant] 1:Sunflower ▶2:Berry Bush 3:Oak Tree".
func describe() -> String:
	var parts: Array[String] = []
	var list := current_list()
	for i in list.size():
		var marker := "▶" if i == clampi(_index, 0, list.size() - 1) else ""
		parts.append("%s%d:%s" % [marker, i + 1, list[i].display_name])
	return "[%s] %s" % [MODE_NAMES[_mode], " ".join(parts)]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				set_mode(((_mode + 1) % 3) as Mode)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				select_index(event.physical_keycode - KEY_1)
	elif event is InputEventMouseButton and event.pressed:
		var cell := garden.cell_at(garden.get_global_mouse_position())
		if event.button_index == MOUSE_BUTTON_LEFT:
			_apply(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			garden.remove(cell)


func _apply(cell: Vector2i) -> void:
	# Ripe fruit always harvests first, regardless of mode.
	if garden.harvest(cell):
		return
	var item := current_item()
	if item == null:
		return
	match _mode:
		Mode.TERRAIN:
			garden.set_terrain(item.id, cell)
		Mode.PLANT:
			garden.place(GardenModel.KIND_PLANT, item.id, cell)
		Mode.DECORATION:
			garden.place(GardenModel.KIND_DECORATION, item.id, cell)
