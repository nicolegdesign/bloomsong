extends Node
## Evaluates resident habitat requirements on a slow tick and spawns/despawns
## resident scenes (PLAN.md §2, §3). Randomness affects only WHEN a resident
## appears (1–3 ticks), never WHETHER — earned discoveries always happen.

const TICK_GAME_MINUTES := 10
const SPAWN_DELAY_TICKS_MAX := 3

var _garden: Node = null                 # the Garden node (has .model)
var _active: Dictionary = {}             # resident_id -> ResidentView node
var _scheduled: Dictionary = {}          # resident_id -> ticks until spawn
var _minutes_since_tick := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	EventBus.minute_ticked.connect(_on_minute)
	EventBus.game_loaded.connect(reset)


func register_garden(garden: Node) -> void:
	_garden = garden


## Clears all visiting residents (used on save-load; they re-earn their spots next tick).
func reset() -> void:
	for id: StringName in _active:
		var view: Node = _active[id]
		if is_instance_valid(view):
			view.queue_free()
	_active.clear()
	_scheduled.clear()


func _on_minute(_minute: int) -> void:
	_minutes_since_tick += 1
	if _minutes_since_tick >= TICK_GAME_MINUTES:
		_minutes_since_tick = 0
		_evaluation_pass()


func _evaluation_pass() -> void:
	if _garden == null:
		return
	var ctx := HabitatContext.new(_garden.model, Clock.season, Clock.weather,
			Clock.time_of_day(), PlayerData.sighting_counts())
	for id: StringName in ContentDB.residents:
		var data: ResidentData = ContentDB.residents[id]
		var eligible := data.is_active(ctx) and data.habitat_met(ctx)
		if eligible:
			if not _active.has(id) and not _scheduled.has(id):
				_scheduled[id] = _rng.randi_range(1, SPAWN_DELAY_TICKS_MAX)
		else:
			_scheduled.erase(id)
			if _active.has(id):
				_despawn(id)
	# Count down scheduled arrivals.
	for id: StringName in _scheduled.keys():
		_scheduled[id] -= 1
		if _scheduled[id] <= 0:
			_scheduled.erase(id)
			_spawn(ContentDB.residents[id])


func _spawn(data: ResidentData) -> void:
	var cell := _pick_spawn_cell()
	var view := ResidentView.new(data, _garden.cell_to_world(cell))
	_garden.add_resident_view(view)
	_active[data.id] = view
	var is_new := PlayerData.record_sighting(data.id)
	EventBus.resident_spawned.emit(data.id, cell)
	if is_new:
		EventBus.toast.emit("✨ New resident discovered: %s!" % data.display_name)
	else:
		EventBus.toast.emit("%s is visiting." % data.display_name)


func _despawn(id: StringName) -> void:
	var view: Node = _active[id]
	_active.erase(id)
	var data := ContentDB.get_resident(id)
	# Departing residents sometimes leave a small gift (PLAN.md §7 economy).
	if data != null and data.leaves_behind != &"" and _rng.randf() < data.gift_chance:
		PlayerData.add_item(data.leaves_behind, 1)
		var item := ContentDB.get_item(data.leaves_behind)
		if item != null:
			EventBus.toast.emit("%s left behind: %s" % [data.display_name, item.display_name])
	if is_instance_valid(view):
		view.queue_free()
	EventBus.resident_despawned.emit(id)


## TODO Phase 5.4: anchor the spawn near the cells that satisfied the requirements.
func _pick_spawn_cell() -> Vector2i:
	var model: GardenModel = _garden.model
	return Vector2i(_rng.randi_range(0, model.width - 1), _rng.randi_range(0, model.height - 1))
