class_name RequireDecoration
extends Requirement
## "N of a decoration" — e.g. a bird bath.

@export var decoration_id: StringName
@export var count := 1


func is_met(ctx: HabitatContext) -> bool:
	return ctx.garden.count_decoration(decoration_id) >= count


func describe() -> String:
	return "a %s" % decoration_id
