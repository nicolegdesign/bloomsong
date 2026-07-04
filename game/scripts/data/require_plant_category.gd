class_name RequirePlantCategory
extends Requirement
## "N plants of a category" — e.g. 3 flowers, 1 tree, 2 bushes.

@export var category: Types.PlantCategory = Types.PlantCategory.FLOWER
@export var count := 1
@export var mature_only := true
## If true, the plants must be blooming right now (mature + current season in bloom_seasons).
@export var blooming := false


func is_met(ctx: HabitatContext) -> bool:
	var season := ctx.season if blooming else -1
	return ctx.garden.count_plants_by_category(category, mature_only, season) >= count


func describe() -> String:
	var what := Types.CATEGORY_NAMES[category]
	return "%d %s%s%s" % [count, "blooming " if blooming else "", what, "s" if count > 1 else ""]
