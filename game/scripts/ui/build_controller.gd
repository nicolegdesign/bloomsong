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


## One line for the HUD, e.g. "[Plant] 1:Sunflower ▶2:Blackberry Bush 3:Oak Tree".
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
		var world_pos := garden.get_global_mouse_position()
		var cell := garden.cell_at(world_pos)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not garden.collect_gift(world_pos):
				_apply(cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			garden.remove(cell)


func _apply(cell: Vector2i) -> void:
	# Harvests always win, regardless of mode: ripe fruit first, then whole-plant
	# cutting (e.g. a mature sunflower).
	if garden.harvest(cell):
		return
	if garden.harvest_whole(cell):
		return
	var item := current_item()
	if item == null:
		return
	match _mode:
		Mode.TERRAIN:
			garden.set_terrain(item.id, cell)
		Mode.PLANT:
			_place_with_feedback(GardenModel.KIND_PLANT, item, cell)
		Mode.DECORATION:
			_place_with_feedback(GardenModel.KIND_DECORATION, item, cell)


## Places via Garden, explaining refusals instead of failing silently. The clicked
## cell becomes the footprint's top-left anchor for multi-tile items.
func _place_with_feedback(kind: StringName, item: Resource, cell: Vector2i) -> void:
	match garden.model.place_error(kind, item.id, cell):
		"":
			garden.place(kind, item.id, cell)
		"soil":
			if kind == GardenModel.KIND_PLANT:
				EventBus.toast.emit("%s needs %s." % [item.display_name, _soil_names(item)])
			else:
				EventBus.toast.emit("%s can't sit on that ground." % item.display_name)
		"occupied", "bounds":
			var fp: Vector2i = garden.model.footprint_of(kind, item.id)
			if fp != Vector2i.ONE:
				EventBus.toast.emit("%s needs a clear %d×%d space." % [item.display_name, fp.x, fp.y])
			# 1×1 on an occupied cell is self-evident — no toast noise.


func _soil_names(plant: PlantData) -> String:
	var names: Array[String] = []
	for terrain_id in plant.allowed_terrain:
		var t := ContentDB.get_terrain(terrain_id)
		names.append(t.display_name if t != null else String(terrain_id))
	return " or ".join(names)
