class_name RequireSpecificPlant
extends Requirement
## "N of one exact plant species" — e.g. an oak tree.

@export var plant_id: StringName
@export var count := 1
@export var mature_only := true


func is_met(ctx: HabitatContext) -> bool:
	return ctx.garden.count_plant(plant_id, mature_only) >= count


func describe() -> String:
	return "%d × %s" % [count, plant_id]
