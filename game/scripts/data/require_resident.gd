class_name RequireResident
extends Requirement
## "Another resident already visits" — enables discovery chains (fox needs rabbits).

@export var resident_id: StringName
@export var min_sightings := 1


func is_met(ctx: HabitatContext) -> bool:
	return int(ctx.sightings.get(resident_id, 0)) >= min_sightings


func describe() -> String:
	return "%s living nearby" % resident_id
