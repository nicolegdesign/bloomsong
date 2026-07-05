class_name PlantView
extends Node2D
## Visual for one planted plant. Anchored at the BOTTOM-CENTER of its cell (the
## 3/4-view convention: sprites grow upward past their tile and Y-sort by base).
## Renders the plant's stage texture when its PlantData has art; falls back to
## the placeholder circle otherwise. Reads the model; never mutates it.
##
## Freshly planted (no growth yet) shows the shared "planted dirt" mound — one
## generic texture for every plant, so new plants need no extra art for day 0.

const PLANTED_TEXTURE := preload("res://assets/art/plants/planted_dirt.png")
## Display box, in cells: plants render 1 cell wide, 1.5 cells tall (art spec ratio
## 64×96), aspect-fit. Because all stages share one source canvas, a sprout is
## automatically small within the same box.
const BOX_CELLS := Vector2(1.0, 1.5)

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
	var texture := _texture_for(pl, data)
	if texture != null:
		_draw_texture_anchored(texture)
	else:
		_draw_placeholder(pl, data)
	if bool(pl.get("fruit_ready", false)):
		draw_circle(Vector2(Garden.CELL * 0.3, -Garden.CELL * 0.9), 3.5, Color(0.9, 0.2, 0.25))


func _texture_for(pl: Dictionary, data: PlantData) -> Texture2D:
	if int(pl.days_grown) == 0 and not bool(pl.was_mature):
		return PLANTED_TEXTURE
	var stage := _garden.model.stage_of(_cell)
	if stage < data.stage_textures.size() and data.stage_textures[stage] != null:
		return data.stage_textures[stage]
	return null


## Aspect-fits the texture into the display box with the ARTWORK's baseline (not the
## canvas bottom — see SpriteAnchor) on the cell's bottom edge (this node's origin).
func _draw_texture_anchored(texture: Texture2D) -> void:
	var box := BOX_CELLS * Garden.CELL
	var s := minf(box.x / texture.get_width(), box.y / texture.get_height())
	var size := Vector2(texture.get_width(), texture.get_height()) * s
	var baseline := SpriteAnchor.bottom_margin(texture) * s
	draw_texture_rect(texture, Rect2(Vector2(-size.x / 2.0, -size.y + baseline), size), false)


## Pre-art fallback: the growing colored circle (bottom-anchored like the sprites).
func _draw_placeholder(pl: Dictionary, data: PlantData) -> void:
	var stage := _garden.model.stage_of(_cell)
	var t := float(stage) / maxf(data.growth_stages - 1, 1)
	var radius := lerpf(MIN_RADIUS, MAX_RADIUS, t)
	var color := data.placeholder_color
	var blooming: bool = pl.was_mature \
			and data.bloom_seasons & Types.flag(Clock.season) != 0
	if not pl.was_mature:
		color = color.darkened(0.25)
	var center := Vector2(0, -radius - 2.0)
	draw_circle(center, radius, color)
	if blooming:
		draw_arc(center, radius + 2.5, 0, TAU, 24, color.lightened(0.5), 2.0)
