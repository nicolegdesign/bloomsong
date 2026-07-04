class_name Player
extends Node2D
## The walking player character (PLAN.md §1: player embodiment). WASD/arrow movement,
## clamped to the garden; the camera follows. Placeholder visual until the art pass.
## Asks Garden to act (via BuildController); never mutates the grid itself.

const SPEED := 150.0

var bounds := Rect2()

var _camera := Camera2D.new()


func _ready() -> void:
	z_index = 20
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.zoom = Vector2(1.5, 1.5)
	add_child(_camera)
	_camera.make_current()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		global_position += dir.normalized() * SPEED * delta
		if bounds.has_area():
			global_position = global_position.clamp(bounds.position, bounds.end)


func _draw() -> void:
	# Placeholder character: body + head + hat brim, so it reads as "a person".
	draw_circle(Vector2(0, 2), 8.0, Color(0.85, 0.45, 0.3))       # body
	draw_circle(Vector2(0, -8), 5.5, Color(0.98, 0.85, 0.7))      # head
	draw_arc(Vector2(0, -9), 7.0, PI, TAU, 16, Color(0.95, 0.8, 0.3), 3.0)  # straw hat
