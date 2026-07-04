extends RefCounted
## GardenModel: placement rules, growth, fruit, queries, save round-trip.


func test_default_terrain_fill(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	t.check_eq(m.count_terrain(&"short_grass"), 80, "all cells start as default terrain")
	t.check(not m.in_bounds(Vector2i(10, 0)), "x == width is out of bounds")
	t.check(not m.in_bounds(Vector2i(-1, 0)), "negative is out of bounds")


func test_terrain_painting(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	t.check(m.set_terrain(Vector2i(2, 2), &"dirt"), "painting dirt succeeds")
	t.check_eq(m.count_terrain(&"dirt"), 1, "dirt count updated")
	t.check(not m.set_terrain(Vector2i(2, 2), &"dirt"), "repainting same terrain is a no-op")
	t.check(not m.set_terrain(Vector2i(99, 0), &"dirt"), "out of bounds rejected")
	t.check(not m.set_terrain(Vector2i(3, 3), &"lava"), "unknown terrain rejected")
	m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(4, 4), 1)
	t.check(not m.set_terrain(Vector2i(4, 4), &"dirt"), "terrain locked under a placement")


func test_placement_rules(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	t.check(m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(1, 1), 1), "plant on grass ok")
	t.check(not m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(1, 1), 1), "occupied cell rejected")
	t.check(not m.place(GardenModel.KIND_PLANT, &"space_cactus", Vector2i(2, 2), 1), "unknown plant rejected")
	m.set_terrain(Vector2i(3, 3), &"water")
	t.check(not m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(3, 3), 1), "unplantable terrain rejected")
	t.check(m.place(GardenModel.KIND_DECORATION, &"bird_bath", Vector2i(5, 5), 1), "decoration placement ok")
	t.check(m.remove(Vector2i(9, 7)).is_empty(), "removing an empty cell returns {}")
	t.check_eq(m.remove(Vector2i(1, 1)).get("id"), &"sunflower", "remove returns the placement")
	t.check(not m.is_occupied(Vector2i(1, 1)), "cell free after remove")


func test_growth_to_maturity(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	var cell := Vector2i(2, 2)
	m.place(GardenModel.KIND_PLANT, &"sunflower", cell, 1)  # days_to_mature = 2, 3 stages
	t.check_eq(m.stage_of(cell), 0, "starts at stage 0")
	t.check(not m.is_mature(cell), "not mature at day 0")
	var events: Dictionary = m.advance_day()
	t.check_eq((events.matured as Array).size(), 0, "no maturity after day 1")
	t.check_eq(m.stage_of(cell), 1, "mid stage after day 1")
	events = m.advance_day()
	t.check_eq((events.matured as Array).size(), 1, "matures exactly once")
	t.check(m.is_mature(cell), "mature flag set")
	t.check_eq(m.stage_of(cell), 2, "final stage when mature")
	events = m.advance_day()
	t.check_eq((events.matured as Array).size(), 0, "maturity not re-reported")


func test_fruit_cycle(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	var cell := Vector2i(2, 2)
	m.place(GardenModel.KIND_PLANT, &"berry_bush", cell, 1)  # mature 3d, fruit every 2d
	for i in 3:
		m.advance_day()
	t.check(m.is_mature(cell), "bush mature after 3 days")
	t.check_eq(m.harvest(cell), &"", "nothing to harvest before fruit is ready")
	m.advance_day()
	var events: Dictionary = m.advance_day()
	t.check_eq((events.fruited as Array).size(), 1, "fruit ready 2 days after maturity")
	t.check_eq(m.harvest(cell), &"berry", "harvest yields the configured item")
	t.check_eq(m.harvest(cell), &"", "harvest resets fruit")
	m.advance_day()
	m.advance_day()
	t.check(bool(m.get_placement(cell).fruit_ready), "fruit regrows on its interval")


func test_category_queries(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(0, 0), 1)
	m.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(1, 0), 1)
	m.place(GardenModel.KIND_PLANT, &"oak_tree", Vector2i(2, 0), 1)
	var flower := Types.PlantCategory.FLOWER
	t.check_eq(m.count_plants_by_category(flower, false), 2, "immature flowers counted when mature_only=false")
	t.check_eq(m.count_plants_by_category(flower, true), 0, "no mature flowers yet")
	m.advance_day()
	m.advance_day()  # sunflowers mature (2 days)
	t.check_eq(m.count_plants_by_category(flower, true), 2, "mature flowers counted")
	var spring := Types.Season.SPRING
	var winter := Types.Season.WINTER
	t.check_eq(m.count_plants_by_category(flower, true, spring), 2, "sunflowers bloom in spring")
	t.check_eq(m.count_plants_by_category(flower, true, winter), 0, "sunflowers don't bloom in winter")
	t.check_eq(m.count_plant(&"oak_tree", false), 1, "specific plant counted")


func test_serialize_round_trip(t: Node) -> void:
	var m := GardenModel.new(10, 8)
	m.set_terrain(Vector2i(0, 1), &"long_grass")
	m.set_terrain(Vector2i(1, 1), &"water")
	m.place(GardenModel.KIND_PLANT, &"berry_bush", Vector2i(4, 4), 3)
	m.place(GardenModel.KIND_DECORATION, &"log", Vector2i(5, 5), 3)
	for i in 4:
		m.advance_day()
	# Round-trip through actual JSON, exactly like a real save file.
	var json: String = JSON.stringify(m.serialize())
	var m2 := GardenModel.deserialize(JSON.parse_string(json))
	t.check_eq(m2.width, 10, "width restored")
	t.check_eq(m2.count_terrain(&"water"), 1, "terrain restored")
	t.check_eq(m2.count_terrain(&"short_grass"), 78, "default terrain restored")
	t.check(m2.is_mature(Vector2i(4, 4)), "growth state restored")
	t.check_eq(int(m2.get_placement(Vector2i(4, 4)).days_grown), 4, "days_grown restored")
	t.check_eq(m2.count_decoration(&"log"), 1, "decoration restored")
