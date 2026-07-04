extends RefCounted
## PlayerData: XP/level math, diary sightings, inventory selling, serialization.
## Mutates the autoload, so it snapshots state first and restores it at the end.


func test_progression_and_diary(t: Node) -> void:
	var snapshot := PlayerData.serialize()

	PlayerData.deserialize({})  # reset to fresh-game defaults
	t.check_eq(PlayerData.level, 1, "fresh game starts at level 1")
	t.check_eq(PlayerData.money, 50, "fresh game starting money")

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

	PlayerData.add_item(&"berry", 3)
	var earned := PlayerData.sell_all()
	t.check_eq(earned, 18, "3 berries sell for 6 each")
	t.check(PlayerData.inventory.is_empty(), "inventory empty after selling")

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

	PlayerData.deserialize(snapshot)  # restore whatever was there before the test
