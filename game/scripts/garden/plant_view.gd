class_name PlantView
extends Node2D
## Placeholder visual for one planted plant: a circle that grows with its stage,
## brightens when blooming, and shows a dot when fruit is ready. Reads the model;
## never mutates it.

const MIN_RADIUS := 4.0
const MAX_RADIUS := 13.0

var _garden: Garden
var _cell: Vector2i


func _init(garden: Garden, cell: Vector2i) -> void:
	_garden = garden
	_cell = cell


func _draw() -> void:
	var pl := _garden.model.get_placement(_cell)
	if pl.is_empty():
		return
	var data := ContentDB.get_plant(pl.id)
	if data == null:
		return
	var stage := _garden.model.stage_of(_cell)
	var t := float(stage) / maxf(data.growth_stages - 1, 1)
	var radius := lerpf(MIN_RADIUS, MAX_RADIUS, t)
	var color := data.placeholder_color
	var blooming: bool = pl.was_mature \
			and data.bloom_seasons & Types.flag(Clock.season) != 0
	if not pl.was_mature:
		color = color.darkened(0.25)
	draw_circle(Vector2.ZERO, radius, color)
	if blooming:
		draw_arc(Vector2.ZERO, radius + 2.5, 0, TAU, 24, color.lightened(0.5), 2.0)
	if bool(pl.get("fruit_ready", false)):
		draw_circle(Vector2(radius * 0.7, -radius * 0.7), 3.5, Color(0.9, 0.2, 0.25))
