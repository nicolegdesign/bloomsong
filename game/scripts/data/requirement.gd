class_name Requirement
extends Resource
## Base class for one habitat condition. A resident's habitat is an Array[Requirement],
## ANDed together (PLAN.md §5.1). Subclasses are pure predicates — no side effects.
## Adding a new requirement type = one new small subclass; residents stay pure data.


func is_met(_ctx: HabitatContext) -> bool:
	push_warning("Requirement.is_met() not overridden")
	return false


## Human-readable phrase for diary hints, e.g. "3 flowering plants".
func describe() -> String:
	return "?"


## Cells in the garden that satisfy this requirement, so a spawning resident can be
## anchored near what it actually came for (ROADMAP 5.4). Empty = no spatial anchor
## (e.g. RequireResident, which isn't about a place).
func matching_cells(_ctx: HabitatContext) -> Array[Vector2i]:
	return []
