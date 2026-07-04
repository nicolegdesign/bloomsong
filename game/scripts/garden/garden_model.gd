class_name GardenModel
extends RefCounted
## The garden's single source of truth (PLAN.md §4): pure data + queries, no nodes,
## no rendering. Only the Garden scene mutates it. Habitat requirements query it.

const KIND_PLANT := &"plant"
const KIND_DECORATION := &"decoration"

var width: int
var height: int
var default_terrain: StringName
## cell (Vector2i) -> terrain id (StringName)
var terrain: Dictionary = {}
## anchor cell (Vector2i) -> placement Dictionary:
## { id, kind, planted_day, days_grown, fruit_days, fruit_ready, was_mature }
var placements: Dictionary = {}


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
	if placements.has(cell):
		return false  # clear the placement first; terrain under objects is locked
	if terrain[cell] == id:
		return false
	terrain[cell] = id
	return true


# --- Placement --------------------------------------------------------------

func is_occupied(cell: Vector2i) -> bool:
	return placements.has(cell)


func place(kind: StringName, id: StringName, cell: Vector2i, day: int) -> bool:
	if not in_bounds(cell) or placements.has(cell):
		return false
	var t: TerrainData = ContentDB.get_terrain(get_terrain(cell))
	if t == null or not t.plantable:
		return false
	if kind == KIND_PLANT and ContentDB.get_plant(id) == null:
		return false
	if kind == KIND_DECORATION and ContentDB.get_decoration(id) == null:
		return false
	placements[cell] = {
		"id": id, "kind": kind, "planted_day": day,
		"days_grown": 0, "fruit_days": 0, "fruit_ready": false, "was_mature": false,
	}
	return true


func remove(cell: Vector2i) -> Dictionary:
	if not placements.has(cell):
		return {}
	var removed: Dictionary = placements[cell]
	placements.erase(cell)
	return removed


func get_placement(cell: Vector2i) -> Dictionary:
	return placements.get(cell, {})


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


# --- Queries (used by habitat Requirements) ---------------------------------

## Count plants of a category. blooming_season >= 0 additionally requires the plant
## to be mature and to bloom in that season.
func count_plants_by_category(category: int, mature_only := true, blooming_season := -1) -> int:
	var n := 0
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
		n += 1
	return n


func count_plant(id: StringName, mature_only := true) -> int:
	var n := 0
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind == KIND_PLANT and pl.id == id and (not mature_only or pl.was_mature):
			n += 1
	return n


func count_decoration(id: StringName) -> int:
	var n := 0
	for cell: Vector2i in placements:
		var pl: Dictionary = placements[cell]
		if pl.kind == KIND_DECORATION and pl.id == id:
			n += 1
	return n


func count_terrain(id: StringName) -> int:
	var n := 0
	for cell: Vector2i in terrain:
		if terrain[cell] == id:
			n += 1
	return n


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
	return m
