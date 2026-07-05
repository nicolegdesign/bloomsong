extends RefCounted
## Habitat Requirement predicates + ResidentData gates — the heart of the game.


func _ctx(garden: GardenModel, season := Types.Season.SPRING, weather := Types.Weather.SUNNY,
		tod := Types.TimeOfDay.MORNING, sightings := {}) -> HabitatContext:
	return HabitatContext.new(garden, season, weather, tod, sightings)


func _garden_with_mature_flowers(count: int) -> GardenModel:
	var m := GardenModel.new(10, 8)
	for i in count:
		m.set_terrain(Vector2i(i, 0), &"dirt")  # sunflowers need dirt (soil preference)
		m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(i, 0), 1)
	m.advance_day()
	m.advance_day()
	return m


func test_require_plant_category(t: Node) -> void:
	var r := RequirePlantCategory.new()
	r.category = Types.PlantCategory.FLOWER
	r.count = 3
	r.blooming = true
	t.check(r.is_met(_ctx(_garden_with_mature_flowers(3))), "3 blooming flowers meet it")
	t.check(not r.is_met(_ctx(_garden_with_mature_flowers(2))), "2 flowers don't")
	t.check(not r.is_met(_ctx(_garden_with_mature_flowers(3), Types.Season.WINTER)),
			"blooming respects season (sunflowers don't bloom in winter)")


func test_require_specific_plant(t: Node) -> void:
	var r := RequireSpecificPlant.new()
	r.plant_id = &"oak_tree"
	var m := GardenModel.new(10, 8)
	t.check(not r.is_met(_ctx(m)), "empty garden fails")
	m.set_terrain(Vector2i(0, 0), &"dirt")
	m.place(GardenModel.KIND_PLANT, &"oak_tree", Vector2i(0, 0), 1)
	t.check(not r.is_met(_ctx(m)), "sapling doesn't count (mature_only)")
	for i in 5:
		m.advance_day()
	t.check(r.is_met(_ctx(m)), "mature oak counts")


func test_require_terrain(t: Node) -> void:
	var r := RequireTerrain.new()
	r.terrain_id = &"long_grass"
	r.min_cells = 6
	var m := GardenModel.new(10, 8)
	for i in 5:
		m.set_terrain(Vector2i(i, 0), &"long_grass")
	t.check(not r.is_met(_ctx(m)), "5 cells is not enough")
	m.set_terrain(Vector2i(5, 0), &"long_grass")
	t.check(r.is_met(_ctx(m)), "6 cells meets it")


func test_require_decoration(t: Node) -> void:
	var r := RequireDecoration.new()
	r.decoration_id = &"bird_bath"
	var m := GardenModel.new(10, 8)
	t.check(not r.is_met(_ctx(m)), "no bird bath fails")
	m.place(GardenModel.KIND_DECORATION, &"bird_bath", Vector2i(0, 0), 1)
	t.check(r.is_met(_ctx(m)), "bird bath placed meets it")


func test_require_resident_chain(t: Node) -> void:
	var r := RequireResident.new()
	r.resident_id = &"rabbit"
	r.min_sightings = 2
	var m := GardenModel.new(10, 8)
	t.check(not r.is_met(_ctx(m)), "no sightings fails")
	t.check(not r.is_met(_ctx(m, 0, 0, 0, {&"rabbit": 1})), "1 sighting is not enough")
	t.check(r.is_met(_ctx(m, 0, 0, 0, {&"rabbit": 2})), "2 sightings meets it (fox-chain works)")


func test_matching_cells_anchor_spawns(t: Node) -> void:
	# ROADMAP 5.4: a spawning resident is anchored near the cells that actually
	# satisfied its requirements, not a random spot in the garden.
	var m := GardenModel.new(10, 8)
	m.set_terrain(Vector2i(2, 3), &"dirt")  # sunflowers need dirt (soil preference)
	m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(2, 3), 1)
	for i in 5:
		m.advance_day()  # sunflower matures (2 days) — extra days are harmless

	var cat_req := RequirePlantCategory.new()
	cat_req.category = Types.PlantCategory.FLOWER
	cat_req.mature_only = true
	t.check_eq(cat_req.matching_cells(_ctx(m)), [Vector2i(2, 3)], "category requirement finds the flower cell")

	var plant_req := RequireSpecificPlant.new()
	plant_req.plant_id = &"sunflower"
	t.check_eq(plant_req.matching_cells(_ctx(m)), [Vector2i(2, 3)], "specific-plant requirement finds it too")

	m.set_terrain(Vector2i(4, 4), &"long_grass")
	var terrain_req := RequireTerrain.new()
	terrain_req.terrain_id = &"long_grass"
	t.check_eq(terrain_req.matching_cells(_ctx(m)), [Vector2i(4, 4)], "terrain requirement finds the cell")

	m.place(GardenModel.KIND_DECORATION, &"bird_bath", Vector2i(6, 6), 1)
	var deco_req := RequireDecoration.new()
	deco_req.decoration_id = &"bird_bath"
	t.check_eq(deco_req.matching_cells(_ctx(m)), [Vector2i(6, 6)], "decoration requirement finds the cell")

	var resident_req := RequireResident.new()
	resident_req.resident_id = &"rabbit"
	t.check(resident_req.matching_cells(_ctx(m)).is_empty(),
			"resident-chain requirements have no spatial anchor")


func test_resident_activity_gates(t: Node) -> void:
	var data := ResidentData.new()
	data.active_times = Types.flag(Types.TimeOfDay.MORNING)
	data.active_seasons = 15
	data.weather_needed = 0
	var m := GardenModel.new(4, 4)
	t.check(data.is_active(_ctx(m, 0, 0, Types.TimeOfDay.MORNING)), "active in the morning")
	t.check(not data.is_active(_ctx(m, 0, 0, Types.TimeOfDay.NIGHT)), "inactive at night")
	data.weather_needed = Types.flag(Types.Weather.RAIN)
	t.check(not data.is_active(_ctx(m, 0, Types.Weather.SUNNY, Types.TimeOfDay.MORNING)),
			"weather gate blocks sunny")
	t.check(data.is_active(_ctx(m, 0, Types.Weather.RAIN, Types.TimeOfDay.MORNING)),
			"weather gate passes rain")
	data.weather_needed = 0
	data.active_seasons = Types.flag(Types.Season.SUMMER)
	t.check(not data.is_active(_ctx(m, Types.Season.SPRING, 0, Types.TimeOfDay.MORNING)),
			"season gate blocks spring")


func test_authored_residents_load(t: Node) -> void:
	# The four starter .tres residents parse and their requirements are wired.
	t.check_eq(ContentDB.residents.size(), 4, "4 residents loaded from content/")
	var butterfly := ContentDB.get_resident(&"butterfly")
	t.check(butterfly != null and butterfly.requirements.size() == 1, "butterfly has 1 requirement")
	t.check(butterfly.requirements[0] is RequirePlantCategory, "requirement subclass resolved from .tres")
	var robin := ContentDB.get_resident(&"robin")
	t.check(robin != null and robin.requirements.size() == 2, "robin has 2 requirements")
	# End-to-end: build the butterfly's habitat and check the full eligibility gate.
	var m := _garden_with_mature_flowers(3)
	var ctx := _ctx(m, Types.Season.SPRING, Types.Weather.SUNNY, Types.TimeOfDay.MORNING)
	t.check(butterfly.is_active(ctx) and butterfly.habitat_met(ctx),
			"butterfly eligible: 3 blooming flowers + sun + morning")
	var rain_ctx := _ctx(m, Types.Season.SPRING, Types.Weather.RAIN, Types.TimeOfDay.MORNING)
	t.check(not butterfly.is_active(rain_ctx), "butterfly not eligible in rain")
