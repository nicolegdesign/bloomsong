class_name Garden
extends Node2D
## The garden scene: owns the GardenModel (source of truth) and keeps the visuals
## in sync with it. The ONLY code allowed to mutate the model (PLAN.md §4).
## Placeholder rendering: terrain as colored cells via _draw(); swap for a
## TileMapLayer in the Phase 8 art pass.

## Ground cell size in world px. 64 = the art-spec scale (PROMPTS.md §3): big enough
## on screen to appreciate the painted detail. All view sizes derive from this.
const CELL := 64

var model := GardenModel.new()

var _views: Dictionary = {}  # cell (Vector2i) -> Node2D view
var _placements_layer := Node2D.new()
var _residents_layer := Node2D.new()
var _hover_cell := Vector2i(-999, -999)
var _gifts: Array[GiftPickup] = []


func _ready() -> void:
	# Y-sort chain (3/4 view): things lower on screen draw in front. Combined with
	# Main's y_sort_enabled, the player interleaves with plant/decoration views.
	y_sort_enabled = true
	_placements_layer.y_sort_enabled = true
	_residents_layer.y_sort_enabled = true
	_placements_layer.name = "Placements"
	_residents_layer.name = "Residents"
	add_child(_placements_layer)
	add_child(_residents_layer)
	HabitatDirector.register_garden(self)
	SaveManager.register_garden(self)
	EventBus.day_passed.connect(_on_day_passed)
	EventBus.season_changed.connect(func(_s: int) -> void: _refresh_all_views())


func _process(_delta: float) -> void:
	var cell := cell_at(get_global_mouse_position())
	if cell != _hover_cell:
		_hover_cell = cell
		queue_redraw()


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


## Plants/decorations must be bought from the shop first (ROADMAP 7.5) — this
## draws one unit from PlayerData's purchased stock. Terrain stays free.
func place(kind: StringName, id: StringName, cell: Vector2i) -> bool:
	if kind == GardenModel.KIND_PLANT and not PlayerData.has_seed(id):
		EventBus.toast.emit("No seeds in stock — visit the shop.")
		return false
	if kind == GardenModel.KIND_DECORATION and not PlayerData.has_decoration(id):
		EventBus.toast.emit("None in stock — visit the shop.")
		return false
	if not model.place(kind, id, cell, Clock.day):
		return false
	if kind == GardenModel.KIND_PLANT:
		PlayerData.consume_seed(id)
		PlayerData.record_plant_planted(id)
	elif kind == GardenModel.KIND_DECORATION:
		PlayerData.consume_decoration(id)
	_create_view(cell)
	EventBus.placement_changed.emit(cell)
	return true


## Refunds the removed plant/decoration back to purchased stock — removing a
## mistake is never punished (PLAN.md §8: "removal refunds partially or fully").
func remove(cell: Vector2i) -> bool:
	var removed := model.remove(cell)
	if removed.is_empty():
		return false
	if removed.kind == GardenModel.KIND_PLANT:
		PlayerData.add_seed(removed.id)
	elif removed.kind == GardenModel.KIND_DECORATION:
		PlayerData.add_decoration(removed.id)
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


## Cuts a whole mature plant (e.g. a sunflower) for its harvest item. The plant is
## removed and the item goes to inventory — no seed refund; this is the reward path,
## unlike remove(). Returns true if something was cut.
func harvest_whole(cell: Vector2i) -> bool:
	var item_id := model.harvest_whole(cell)
	if item_id == &"":
		return false
	PlayerData.add_item(item_id, 1)
	var item := ContentDB.get_item(item_id)
	if item != null:
		EventBus.toast.emit("Harvested: %s" % item.display_name)
	_free_view(cell)
	EventBus.placement_changed.emit(cell)
	return true


func add_resident_view(view: Node2D) -> void:
	_residents_layer.add_child(view)


## Places a dropped gift in the world (ROADMAP 7.4). Sits until collect_gift()
## finds a click near it.
func add_gift(pickup: GiftPickup) -> void:
	_residents_layer.add_child(pickup)
	_gifts.append(pickup)


## Collects the nearest gift within pickup radius of world_pos, if any. Returns
## true if something was collected (so the caller doesn't also try to place/
## harvest at the clicked cell).
func collect_gift(world_pos: Vector2) -> bool:
	for pickup in _gifts:
		if not is_instance_valid(pickup):
			continue
		if pickup.global_position.distance_to(world_pos) <= GiftPickup.PICKUP_RADIUS:
			_gifts.erase(pickup)
			pickup.collect()
			return true
	return false


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
	# Uncollected gifts are momentary/cosmetic like resident positions (ROADMAP
	# 5.6) — they don't survive a reload, only what's already in the inventory does.
	for pickup in _gifts:
		if is_instance_valid(pickup):
			pickup.queue_free()
	_gifts.clear()
	queue_redraw()


# --- Views (placeholder visuals; a projection of the model, never state) -----

func _create_view(cell: Vector2i) -> void:
	var pl := model.get_placement(cell)
	var view: Node2D
	if pl.kind == GardenModel.KIND_PLANT:
		view = PlantView.new(self, cell)
	else:
		view = DecorationView.new(self, cell)
	# Anchored at the cell's BOTTOM-center: sprites draw upward from their base,
	# and Y-sort uses this base position — the 3/4-view convention.
	view.position = Vector2(cell) * CELL + Vector2(CELL / 2.0, CELL)
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
	_draw_hover_highlight()


## Highlights the cell under the mouse: gold when it's inside the editable garden,
## dim red when the cursor has wandered past the border. Hidden while the mouse is
## over a UI control (e.g. the palette) so it doesn't look like it's under the panel.
func _draw_hover_highlight() -> void:
	if get_viewport().gui_get_hovered_control() != null:
		return
	var rect := Rect2(Vector2(_hover_cell) * CELL, Vector2.ONE * CELL)
	if model.in_bounds(_hover_cell):
		draw_rect(rect, Color(1.0, 0.92, 0.55, 0.28))
		draw_rect(rect, Color(1.0, 0.92, 0.55, 0.9), false, 2.0)
	else:
		draw_rect(rect, Color(0.9, 0.2, 0.2, 0.6), false, 2.0)
