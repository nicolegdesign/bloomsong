class_name GardenModel
extends RefCounted
## The garden's single source of truth (PLAN.md §4): pure data + queries, no nodes,
## no rendering. Only the Garden scene mutates it. Habitat requirements query it.

const KIND_PLANT := &"plant"
const KIND_DECORATION := &"decoration"

## Returned by anchor_at() for cells with nothing on them.
const NO_ANCHOR := Vector2i(-9999, -9999)

var width: int
var height: int
var default_terrain: StringName
## cell (Vector2i) -> terrain id (StringName)
var terrain: Dictionary = {}
## anchor cell (Vector2i) -> placement Dictionary:
## { id, kind, planted_day, days_grown, fruit_days, fruit_ready, was_mature }
## The anchor is the top-left cell of the placement's footprint.
var placements: Dictionary = {}
## covered cell (Vector2i) -> anchor cell. Multi-tile footprints (a 2×2 oak, a 2×1
## log) block every covered cell from the moment they're placed — growing included.
var occupancy: Dictionary = {}


func _init(w: int = 20, h: int = 15, p_default_terrain: StringName = &"short_grass") -> void:
	width = w
	height = h
	default_terrain = p_default_terrain
	for y in h:
		for x in w:
			terrain[Vector2i(x, y)] = p_default_terrain


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


# --- Terrain ---------------------------------------------------------------

func get_terrain(cell: Vector2i) -> StringName:
	return terrain.get(cell, &"")


func set_terrain(cell: Vector2i, id: StringName) -> bool:
	if not in_bounds(cell) or ContentDB.get_terrain(id) == null:
		return false
	if occupancy.has(cell):
		return false  # clear the placement first; terrain under objects is locked
	if terrain[cell] == id:
		return false
	terrain[cell] = id
	return true


# --- Placement --------------------------------------------------------------

func is_occupied(cell: Vector2i) -> bool:
	return occupancy.has(cell)


## Anchor of the placement covering this cell, or NO_ANCHOR. Any covered cell of a
## multi-tile placement resolves to its anchor (click a tree's corner = the tree).
func anchor_at(cell: Vector2i) -> Vector2i:
	return occupancy.get(cell, NO_ANCHOR)


## Footprint of a content id, in cells (1×1 for anything without one).
func footprint_of(kind: StringName, id: StringName) -> Vector2i:
	var data: Resource = ContentDB.get_plant(id) if kind == KIND_PLANT \
			else ContentDB.get_decoration(id)
	if data == null or data.footprint.x < 1 or data.footprint.y < 1:
		return Vector2i.ONE
	return data.footprint


func footprint_cells(anchor: Vector2i, footprint: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in footprint.y:
		for dx in footprint.x:
			cells.append(anchor + Vector2i(dx, dy))
	return cells


## Why placing would fail at this anchor: "" = it would succeed. One source of
## truth for both place() and the UI's refusal messages.
## Reasons: "unknown", "bounds", "occupied", "soil".
func place_error(kind: StringName, id: StringName, anchor: Vector2i) -> String:
	if kind == KIND_PLANT and ContentDB.get_plant(id) == null:
		return "unknown"
	if kind == KIND_DECORATION and ContentDB.get_decoration(id) == null:
		return "unknown"
	var cells := footprint_cells(anchor, footprint_of(kind, id))
	for cell in cells:
		if not in_bounds(cell):
			return "bounds"
	for cell in cells:
		if occupancy.has(cell):
			return "occupied"
	if kind == KIND_PLANT:
		# Plants follow their own soil preference (PlantData.allowed_terrain), which
		# may include terrain that blocks decorations — e.g. aquatics on water.
		if not soil_ok(id, anchor):
			return "soil"
	else:
		for cell in cells:
			var t: TerrainData = ContentDB.get_terrain(get_terrain(cell))
			if t == null or not t.plantable:
				return "soil"
	return ""


func place(kind: StringName, id: StringName, anchor: Vector2i, day: int) -> bool:
	if place_error(kind, id, anchor) != "":
		return false
	placements[anchor] = {
		"id": id, "kind": kind, "planted_day": day,
		"days_grown": 0, "fruit_days": 0, "fruit_ready": false, "was_mature": false,
	}
	for cell in footprint_cells(anchor, footprint_of(kind, id)):
		occupancy[cell] = anchor
	return true


## Removes the placement covering this cell (any covered cell works). Returns the
## removed placement Dictionary, or {} if the cell was empty.
func remove(cell: Vector2i) -> Dictionary:
	var anchor := anchor_at(cell)
	if anchor == NO_ANCHOR:
		return {}
	var removed: Dictionary = placements[anchor]
	placements.erase(anchor)
	_clear_occupancy(anchor)
	return removed


## Placement covering this cell (any covered cell of a footprint), or {}.
func get_placement(cell: Vector2i) -> Dictionary:
	return placements.get(anchor_at(cell), {})


func _clear_occupancy(anchor: Vector2i) -> void:
	# By reverse lookup rather than recomputing the footprint, so a placement is
	# fully cleared even if its content data's footprint changed since placing.
	for cell: Vector2i in occupancy.keys():
		if occupancy[cell] == anchor:
			occupancy.erase(cell)


# --- Growth (driven by Garden on day_passed) --------------------------------

## Advances every plant by one day. Returns {"matured": [cells], "fruited": [cells]}
## so the caller (Garden) can emit signals — the model itself stays signal-free.
func advance_day() -> Dictionary:
	var matured: Array[Vector2i] = []
	var fruited: Array[Vector2i] = []
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind != KIND_PLANT:
			continue
		var data: PlantData = ContentDB.get_plant(pl.id)
		if data == null:
			continue
		var was_already_mature: bool = pl.was_mature
		pl.days_grown += 1
		if not pl.was_mature and pl.days_grown >= data.days_to_mature:
			pl.was_mature = true
			matured.append(cell)
		# Fruit counts days AFTER maturity — the maturity day itself doesn't count.
		if was_already_mature and data.fruit_item != &"" and not pl.fruit_ready:
			pl.fruit_days += 1
			if pl.fruit_days >= data.fruit_interval_days:
				pl.fruit_ready = true
				fruited.append(cell)
	return {"matured": matured, "fruited": fruited}


func is_mature(cell: Vector2i) -> bool:
	return bool(get_placement(cell).get("was_mature", false))


## Visual growth stage index, 0 .. growth_stages-1.
func stage_of(cell: Vector2i) -> int:
	var pl := get_placement(cell)
	if pl.is_empty() or pl.kind != KIND_PLANT:
		return 0
	var data: PlantData = ContentDB.get_plant(pl.id)
	if data == null:
		return 0
	if pl.was_mature:
		return data.growth_stages - 1
	var stage := int(float(pl.days_grown) * data.growth_stages / data.days_to_mature)
	return clampi(stage, 0, data.growth_stages - 1)


## If the plant at cell has ripe fruit, collects it and returns the item id ("" otherwise).
func harvest(cell: Vector2i) -> StringName:
	var pl := get_placement(cell)
	if pl.is_empty() or not bool(pl.get("fruit_ready", false)):
		return &""
	var data: PlantData = ContentDB.get_plant(pl.id)
	if data == null:
		return &""
	pl.fruit_ready = false
	pl.fruit_days = 0
	return data.fruit_item


## Soil preference check only — placement additionally needs the cells in bounds
## and unoccupied. Kept separate so the UI can explain a refusal ("needs Dirt").
## Checks the plant's WHOLE footprint from this anchor (a 2×2 oak needs 4 dirt cells).
func soil_ok(plant_id: StringName, anchor: Vector2i) -> bool:
	var data: PlantData = ContentDB.get_plant(plant_id)
	if data == null:
		return false
	for cell in footprint_cells(anchor, footprint_of(KIND_PLANT, plant_id)):
		if not get_terrain(cell) in data.allowed_terrain:
			return false
	return true


## One-shot whole-plant harvest (e.g. cutting a mature sunflower): removes the
## plant and returns its harvest_whole_item ("" if not mature/harvestable).
## Any covered cell of the footprint works.
func harvest_whole(cell: Vector2i) -> StringName:
	var anchor := anchor_at(cell)
	var pl := placements.get(anchor, {}) as Dictionary
	if pl.is_empty() or pl.kind != KIND_PLANT or not bool(pl.was_mature):
		return &""
	var data: PlantData = ContentDB.get_plant(pl.id)
	if data == null or data.harvest_whole_item == &"":
		return &""
	placements.erase(anchor)
	_clear_occupancy(anchor)
	return data.harvest_whole_item


# --- Queries (used by habitat Requirements) ---------------------------------

## Cells with plants of a category. blooming_season >= 0 additionally requires the
## plant to be mature and to bloom in that season.
func cells_by_category(category: int, mature_only := true, blooming_season := -1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind != KIND_PLANT:
			continue
		var data: PlantData = ContentDB.get_plant(pl.id)
		if data == null or data.category != category:
			continue
		if (mature_only or blooming_season >= 0) and not pl.was_mature:
			continue
		if blooming_season >= 0 and data.bloom_seasons & Types.flag(blooming_season) == 0:
			continue
		out.append(cell)
	return out


func count_plants_by_category(category: int, mature_only := true, blooming_season := -1) -> int:
	return cells_by_category(category, mature_only, blooming_season).size()


func cells_by_plant(id: StringName, mature_only := true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind == KIND_PLANT and pl.id == id and (not mature_only or pl.was_mature):
			out.append(cell)
	return out


func count_plant(id: StringName, mature_only := true) -> int:
	return cells_by_plant(id, mature_only).size()


func cells_by_decoration(id: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind == KIND_DECORATION and pl.id == id:
			out.append(cell)
	return out


func count_decoration(id: StringName) -> int:
	return cells_by_decoration(id).size()


func cells_by_terrain(id: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in terrain:
		if terrain[cell] == id:
			out.append(cell)
	return out


func count_terrain(id: StringName) -> int:
	return cells_by_terrain(id).size()


# --- Serialization (JSON-safe: only String/int/bool/Array/Dictionary) -------

func serialize() -> Dictionary:
	var terrain_out: Array = []
	for cell: Vector2i in terrain:
		if terrain[cell] != default_terrain:
			terrain_out.append({"x": cell.x, "y": cell.y, "id": String(terrain[cell])})
	var placements_out: Array = []
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		placements_out.append({
			"x": cell.x, "y": cell.y, "id": String(pl.id), "kind": String(pl.kind),
			"planted_day": pl.planted_day, "days_grown": pl.days_grown,
			"fruit_days": pl.fruit_days, "fruit_ready": pl.fruit_ready,
			"was_mature": pl.was_mature,
		})
	return {
		"width": width, "height": height, "default_terrain": String(default_terrain),
		"terrain": terrain_out, "placements": placements_out,
	}


static func deserialize(d: Dictionary) -> GardenModel:
	var m := GardenModel.new(int(d.get("width", 20)), int(d.get("height", 15)),
			StringName(d.get("default_terrain", "short_grass")))
	for t: Dictionary in d.get("terrain", []):
		m.terrain[Vector2i(int(t.x), int(t.y))] = StringName(t.id)
	for p: Dictionary in d.get("placements", []):
		m.placements[Vector2i(int(p.x), int(p.y))] = {
			"id": StringName(p.id), "kind": StringName(p.kind),
			"planted_day": int(p.get("planted_day", 0)),
			"days_grown": int(p.get("days_grown", 0)),
			"fruit_days": int(p.get("fruit_days", 0)),
			"fruit_ready": bool(p.get("fruit_ready", false)),
			"was_mature": bool(p.get("was_mature", false)),
		}
	# Occupancy is derived, not saved: rebuild from footprints so saves stay small
	# and content-data footprint changes apply to existing gardens on load.
	for anchor: Vector2i in m.placements:
		var pl: Dictionary = m.placements[anchor]
		for cell in m.footprint_cells(anchor, m.footprint_of(pl.kind, pl.id)):
			m.occupancy[cell] = anchor
	return m
