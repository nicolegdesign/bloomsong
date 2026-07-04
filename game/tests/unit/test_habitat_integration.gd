extends RefCounted
## End-to-end core loop: plant flowers → grow → habitat pass → butterfly spawns →
## diary discovery → weather turns → butterfly leaves. Drives the real Garden node
## and HabitatDirector, so it also covers their wiring.


func test_full_discovery_flow(t: Node) -> void:
	var player_snapshot := PlayerData.serialize()
	PlayerData.deserialize({})

	var garden := Garden.new()
	t.add_child(garden)  # _ready registers it with HabitatDirector/SaveManager

	# Build the butterfly habitat: 3 sunflowers, grown to bloom.
	for i in 3:
		t.check(garden.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(i, 0)),
				"sunflower %d planted" % i)
	EventBus.day_passed.emit(2)
	EventBus.day_passed.emit(3)  # sunflowers mature (2 days)
	t.check_eq(garden.model.count_plants_by_category(Types.PlantCategory.FLOWER, true,
			Types.Season.SPRING), 3, "3 blooming flowers in the model")

	# A sunny spring morning.
	Clock.weather = Types.Weather.SUNNY
	Clock.season = Types.Season.SPRING
	Clock.minute = 9 * 60

	# Spawn delay is 1–3 ticks — bounded, never denied (PLAN.md §8).
	for i in 4:
		HabitatDirector._evaluation_pass()
	t.check(PlayerData.diary.has(&"butterfly"), "butterfly discovered within bounded window")
	t.check(HabitatDirector._active.has(&"butterfly"), "butterfly view active in the garden")
	t.check(not PlayerData.diary.has(&"robin"), "robin not discovered (no tree, no bird bath)")
	t.check(PlayerData.xp > 0 or PlayerData.level > 1, "discovery granted XP")

	# Rain rolls in: butterflies don't fly in rain, snails come out.
	Clock.weather = Types.Weather.RAIN
	for i in 4:
		HabitatDirector._evaluation_pass()
	t.check(not HabitatDirector._active.has(&"butterfly"), "butterfly leaves when rain starts")
	t.check(PlayerData.diary.has(&"snail"), "snail discovered in the rain (no other needs)")

	# Cleanup so later tests/sessions are unaffected.
	HabitatDirector.reset()
	HabitatDirector._garden = null
	SaveManager._garden = null
	garden.queue_free()
	PlayerData.deserialize(player_snapshot)
