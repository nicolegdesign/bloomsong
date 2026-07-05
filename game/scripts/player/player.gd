class_name Player
extends Node2D
## The walking player character (PLAN.md §1: player embodiment). WASD/arrow movement,
## clamped to the garden; the camera follows. Placeholder visual until the art pass.
## Asks Garden to act (via BuildController); never mutates the grid itself.

const SPEED := 300.0  # world px/sec — scaled with Garden.CELL
const FARMER_TEXTURE := preload("res://assets/art/player/farmer.png")
## Display box in cells (art spec: character 64×96 at 64 px cells → 1 × 1.5).
const BOX_CELLS := Vector2(1.0, 1.5)

var bounds := Rect2()

var _camera := Camera2D.new()


func _ready() -> void:
	# No z_index boost: the player Y-sorts against plants/decorations (walks behind
	# a sunflower that's lower on screen). Position = the character's FEET.
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
	# The farmer sprite, aspect-fit into the display box, feet at the origin —
	# baseline-anchored like all sprites (see SpriteAnchor).
	var box := BOX_CELLS * Garden.CELL
	var s := minf(box.x / FARMER_TEXTURE.get_width(), box.y / FARMER_TEXTURE.get_height())
	var size := Vector2(FARMER_TEXTURE.get_width(), FARMER_TEXTURE.get_height()) * s
	var baseline := SpriteAnchor.bottom_margin(FARMER_TEXTURE) * s
	draw_texture_rect(FARMER_TEXTURE, Rect2(Vector2(-size.x / 2.0, -size.y + baseline), size), false)
