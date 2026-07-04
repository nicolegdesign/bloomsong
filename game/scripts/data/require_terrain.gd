class_name RequireTerrain
extends Requirement
## "At least N cells of a terrain type" — e.g. 6 cells of long grass.

@export var terrain_id: StringName
@export var min_cells := 1


func is_met(ctx: HabitatContext) -> bool:
	return ctx.garden.count_terrain(terrain_id) >= min_cells


func matching_cells(ctx: HabitatContext) -> Array[Vector2i]:
	return ctx.garden.cells_by_terrain(terrain_id)


func describe() -> String:
	return "a patch of %s" % terrain_id
