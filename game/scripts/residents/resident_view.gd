class_name ResidentView
extends Node2D
## A visiting resident: purely cosmetic wandering near its home point (PLAN.md §6 —
## residents never change game state; despawning them is always safe). Cycles
## between wander / rest / eat depending on ResidentData.behaviors (ROADMAP 5.4).
## Placeholder visual: a colored circle with an outline; rest/eat show as a gentle
## bob in place until real sprite animations exist.

const WANDER_RADIUS := 72.0
const RADIUS := 7.0
const WANDER_PAUSE_MIN := 0.5
const WANDER_PAUSE_MAX := 2.5
const REST_PAUSE_MIN := 3.0
const REST_PAUSE_MAX := 6.0
const EAT_PAUSE_MIN := 2.0
const EAT_PAUSE_MAX := 4.0
const BOB_AMPLITUDE := 2.5
const BOB_SPEED := 3.0

enum State { WANDER, RESTING, EATING }

var data: ResidentData

var _home: Vector2
var _target: Vector2
var _speed := 40.0
var _pause := 0.0
var _state: State = State.WANDER
var _bob_time := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_data: ResidentData, home: Vector2) -> void:
	data = p_data
	_home = home
	global_position = home
	_target = home
	z_index = 10
	_speed = _rng.randf_range(25.0, 55.0)


func _process(delta: float) -> void:
	_bob_time += delta
	if _pause > 0.0:
		_pause -= delta
		if _state != State.WANDER:
			global_position = _target + Vector2(0, sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE)
		if _pause <= 0.0:
			_begin_next_leg()
		return
	var to_target := _target - global_position
	if to_target.length() < 2.0:
		_pause = _pause_for(_state)
	else:
		global_position += to_target.normalized() * _speed * delta


## Picks the next behavior (weighted toward whatever the resident actually does)
## and the target it travels to before performing it.
func _begin_next_leg() -> void:
	var options: Array[State] = [State.WANDER]
	if data.behaviors & ResidentData.BEHAVIOR_REST != 0:
		options.append(State.RESTING)
	if data.behaviors & ResidentData.BEHAVIOR_EAT != 0:
		options.append(State.EATING)
	_state = options[_rng.randi_range(0, options.size() - 1)]
	match _state:
		State.WANDER:
			_target = _home + Vector2.from_angle(_rng.randf() * TAU) \
					* _rng.randf_range(8.0, WANDER_RADIUS)
		State.RESTING:
			_target = global_position
		State.EATING:
			_target = _home


func _pause_for(state: State) -> float:
	match state:
		State.RESTING:
			return _rng.randf_range(REST_PAUSE_MIN, REST_PAUSE_MAX)
		State.EATING:
			return _rng.randf_range(EAT_PAUSE_MIN, EAT_PAUSE_MAX)
		_:
			return _rng.randf_range(WANDER_PAUSE_MIN, WANDER_PAUSE_MAX)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, data.placeholder_color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
