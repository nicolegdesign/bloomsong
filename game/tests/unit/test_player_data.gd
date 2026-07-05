extends RefCounted
## PlayerData: XP/level math, diary sightings, inventory selling, serialization.
## Mutates the autoload, so it snapshots state first and restores it at the end.


func test_progression_and_diary(t: Node) -> void:
	var snapshot := PlayerData.serialize()

	PlayerData.deserialize({})  # reset to fresh-game defaults
	t.check_eq(PlayerData.level, 1, "fresh game starts at level 1")
	t.check_eq(PlayerData.money, 100, "fresh game starting money")

	PlayerData.add_xp(100)
	t.check_eq(PlayerData.level, 2, "100 xp reaches level 2")
	t.check_eq(PlayerData.xp, 0, "xp resets within level")
	PlayerData.add_xp(250)
	t.check_eq(PlayerData.level, 3, "xp overflow carries across levels")
	t.check_eq(PlayerData.xp, 50, "leftover xp kept")

	var was_new := PlayerData.record_sighting(&"snail")
	t.check(was_new, "first sighting is a discovery")
	t.check(not PlayerData.record_sighting(&"snail"), "second sighting is not")
	t.check_eq(int(PlayerData.diary[&"snail"].times_seen), 2, "times_seen counts visits")

	# Favorite season/weather/time (ROADMAP 6.2 diary favorites). Uses a different
	# resident than the times_seen checks above/below so it doesn't disturb them.
	Clock.weather = Types.Weather.RAIN
	Clock.minute = 9 * 60  # morning
	PlayerData.record_sighting(&"robin")
	Clock.weather = Types.Weather.RAIN
	Clock.minute = 9 * 60
	PlayerData.record_sighting(&"robin")
	Clock.weather = Types.Weather.SUNNY
	Clock.minute = 20 * 60  # evening, just once
	PlayerData.record_sighting(&"robin")
	t.check_eq(PlayerData.favorite_weather(&"robin"), Types.Weather.RAIN,
			"favorite weather is whichever was seen most (2 rain vs 1 sunny)")
	t.check_eq(PlayerData.favorite_time(&"robin"), Types.TimeOfDay.MORNING,
			"favorite time is whichever was seen most (2 morning vs 1 evening)")
	t.check_eq(PlayerData.favorite_season(&"butterfly"), -1,
			"a never-seen resident has no favorite (sentinel -1)")

	PlayerData.add_item(&"berry", 3)
	var earned := PlayerData.sell_all()
	t.check_eq(earned, 18, "3 berries sell for 6 each")
	t.check(PlayerData.inventory.is_empty(), "inventory empty after selling")

	# ROADMAP 7.6: seed/decoration stock persists too (money -> stock -> save).
	PlayerData.money = 100
	t.check(PlayerData.buy_seed(&"sunflower"), "buy a seed before the round-trip")
	PlayerData.add_decoration(&"log", 2)  # a refund-style grant, no purchase needed

	# Round-trip through JSON like a real save.
	PlayerData.appearance = {"body": "base_1"}
	var d: Dictionary = JSON.parse_string(JSON.stringify(PlayerData.serialize()))
	var money_before: int = PlayerData.money
	PlayerData.deserialize({})
	PlayerData.deserialize(d)
	t.check_eq(PlayerData.level, 3, "level survives save round-trip")
	t.check_eq(PlayerData.money, money_before, "money survives save round-trip")
	t.check_eq(int(PlayerData.diary[&"snail"].times_seen), 2, "diary survives save round-trip")
	t.check_eq(String(PlayerData.appearance.get("body", "")), "base_1", "appearance survives")
	t.check(PlayerData.has_seed(&"sunflower"), "seed stock survives save round-trip")
	t.check_eq(int(PlayerData.decoration_stock[&"log"]), 2, "decoration stock survives save round-trip")

	PlayerData.deserialize(snapshot)  # restore whatever was there before the test


## ROADMAP 7.1: the XP curve lives in content/progression/level_curve.tres, not a
## hardcoded formula — PlayerData just asks ContentDB for the threshold.
func test_level_curve_from_content(t: Node) -> void:
	var curve := LevelCurveData.new()
	curve.xp_thresholds = [50, 80]
	t.check_eq(curve.xp_to_next(1), 50, "level 1 uses the first authored threshold")
	t.check_eq(curve.xp_to_next(2), 80, "level 2 uses the second authored threshold")
	t.check_eq(curve.xp_to_next(3), 80, "beyond the authored levels, the last value repeats")
	t.check_eq(LevelCurveData.new().xp_to_next(1), 100, "an empty curve still returns something sane")

	var real_curve := ContentDB.level_curve
	t.check(real_curve != null, "the authored level_curve.tres loaded into ContentDB")

	var snapshot := PlayerData.serialize()
	PlayerData.deserialize({})
	t.check_eq(PlayerData.xp_to_next(), ContentDB.level_curve.xp_to_next(1),
			"PlayerData.xp_to_next() reads the content curve, not a hardcoded formula")
	PlayerData.deserialize(snapshot)
