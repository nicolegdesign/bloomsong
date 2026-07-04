class_name Garden
extends Node2D
## The garden scene: owns the GardenModel (source of truth) and keeps the visuals
## in sync with it. The ONLY code allowed to mutate the model (PLAN.md §4).
## Placeholder rendering: terrain as colored cells via _draw(); swap for a
## TileMapLayer in the Phase 8 art pass.

const CELL := 32

var model := GardenModel.new()

var _views: Dictionary = {}  # cell (Vector2i) -> Node2D view
var _placements_layer := Node2D.new()
var _residents_layer := Node2D.new()


func _ready() -> void:
	_placements_layer.name = "Placements"
	_residents_layer.name = "Residents"
	add_child(_placements_layer)
	add_child(_residents_layer)
	HabitatDirector.register_garden(self)
	SaveManager.register_garden(self)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.season_changed.connect(func(_s: int) -> void: _refresh_all_views())


# --- Coordinate helpers ------------------------------------------------------

func cell_at(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos)
	return Vector2i(floori(local.x / CELL), floori(local.y / CELL))


## World position of a cell's center.
func cell_to_world(cell: Vector2i) -> Vector2:
	return to_global(Vector2(cell) * CELL + Vector2.ONE * CELL / 2.0)


func bounds() -> Rect2:
	return Rect2(global_position, Vector2(model.width, model.height) * CELL)


# --- Player-facing mutations (called by BuildController) ---------------------

func set_terrain(id: StringName, cell: Vector2i) -> bool:
	if not model.set_terrain(cell, id):
		return false
	queue_redraw()
	EventBus.terrain_changed.emit(cell)
	return true


func place(kind: StringName, id: StringName, cell: Vector2i) -> bool:
	if not model.place(kind, id, cell, Clock.day):
		return false
	_create_view(cell)
	EventBus.placement_changed.emit(cell)
	return true


func remove(cell: Vector2i) -> bool:
	if model.remove(cell).is_empty():
		return false
	_free_view(cell)
	EventBus.placement_changed.emit(cell)
	return true


## Collects ripe fruit at cell into the inventory. Returns true if something was picked.
func harvest(cell: Vector2i) -> bool:
	var item_id := model.harvest(cell)
	if item_id == &"":
		return false
	PlayerData.add_item(item_id, 1)
	var item := ContentDB.get_item(item_id)
	if item != null:
		EventBus.toast.emit("Harvested: %s" % item.display_name)
	_refresh_view(cell)
	return true


func add_resident_view(view: Node2D) -> void:
	_residents_layer.add_child(view)


# --- Simulation --------------------------------------------------------------

func _on_day_passed(_day: int) -> void:
	var events: Dictionary = model.advance_day()
	for cell: Vector2i in events.matured:
		var pl := model.get_placement(cell)
		PlayerData.record_plant_matured(pl.id)
		EventBus.plant_matured.emit(cell, pl.id)
	for cell: Vector2i in events.fruited:
		EventBus.fruit_ready.emit(cell, model.get_placement(cell).id)
	_refresh_all_views()


# --- Save/load ---------------------------------------------------------------

func load_model(new_model: GardenModel) -> void:
	model = new_model
	for cell: Vector2i in _views.keys():
		_free_view(cell)
	for cell: Vector2i in model.placements:
		_create_view(cell)
	queue_redraw()


# --- Views (placeholder visuals; a projection of the model, never state) -----

func _create_view(cell: Vector2i) -> void:
	var pl := model.get_placement(cell)
	var view: Node2D
	if pl.kind == GardenModel.KIND_PLANT:
		view = PlantView.new(self, cell)
	else:
		view = DecorationView.new(self, cell)
	view.position = Vector2(cell) * CELL + Vector2.ONE * CELL / 2.0
	_placements_layer.add_child(view)
	_views[cell] = view


func _free_view(cell: Vector2i) -> void:
	if _views.has(cell):
		_views[cell].queue_free()
		_views.erase(cell)


func _refresh_view(cell: Vector2i) -> void:
	if _views.has(cell):
		_views[cell].queue_redraw()


func _refresh_all_views() -> void:
	for cell: Vector2i in _views:
		_views[cell].queue_redraw()


func _draw() -> void:
	for y in model.height:
		for x in model.width:
			var cell := Vector2i(x, y)
			var t := ContentDB.get_terrain(model.get_terrain(cell))
			var color := t.placeholder_color if t != null else Color.MAGENTA
			draw_rect(Rect2(Vector2(cell) * CELL, Vector2.ONE * CELL), color)
	# Faint grid lines for placement readability.
	var grid_color := Color(0, 0, 0, 0.06)
	for x in model.width + 1:
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, model.height * CELL), grid_color)
	for y in model.height + 1:
		draw_line(Vector2(0, y * CELL), Vector2(model.width * CELL, y * CELL), grid_color)
	# Border.
	draw_rect(Rect2(Vector2.ZERO, Vector2(model.width, model.height) * CELL),
			Color(0.2, 0.15, 0.1), false, 3.0)
