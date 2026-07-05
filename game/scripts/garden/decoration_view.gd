class_name DecorationView
extends Node2D
## Placeholder visual for one decoration: a rounded square in its content color.

const SIZE := 44.0

var _garden: Garden
var _cell: Vector2i


func _init(garden: Garden, cell: Vector2i) -> void:
	_garden = garden
	_cell = cell


func _draw() -> void:
	var pl := _garden.model.get_placement(_cell)
	if pl.is_empty():
		return
	var data := ContentDB.get_decoration(pl.id)
	if data == null:
		return
	# Bottom-anchored like all placement views (origin = cell bottom-center).
	var rect := Rect2(Vector2(-SIZE / 2.0, -SIZE - 3.0), Vector2.ONE * SIZE)
	draw_rect(rect, data.placeholder_color)
	draw_rect(rect, data.placeholder_color.darkened(0.4), false, 2.0)
