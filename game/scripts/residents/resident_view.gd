class_name ResidentView
extends Node2D
## A visiting resident: purely cosmetic wandering near its home point (PLAN.md §6 —
## residents never change game state; despawning them is always safe).
## Placeholder visual: a colored circle with an outline.

const WANDER_RADIUS := 72.0
const RADIUS := 7.0

var data: ResidentData

var _home: Vector2
var _target: Vector2
var _speed := 40.0
var _pause := 0.0
var _rng := RandomNumberGenerator.new()


func _init(p_data: ResidentData, home: Vector2) -> void:
	data = p_data
	_home = home
	global_position = home
	_target = home
	z_index = 10
	_speed = _rng.randf_range(25.0, 55.0)


func _process(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var to_target := _target - global_position
	if to_target.length() < 2.0:
		# Rest a moment, then wander somewhere new near home.
		_pause = _rng.randf_range(0.5, 2.5)
		_target = _home + Vector2.from_angle(_rng.randf() * TAU) \
				* _rng.randf_range(8.0, WANDER_RADIUS)
	else:
		global_position += to_target.normalized() * _speed * delta


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, data.placeholder_color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 20, Color(1, 1, 1, 0.9), 1.5)
