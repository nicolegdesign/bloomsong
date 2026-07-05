extends RefCounted
## Shop economy (ROADMAP 7.2/7.5): unlock gating with real content, buying gated by
## money + unlock level, and Garden placement drawing from / refunding to stock.


func test_unlock_gating_starter_set(t: Node) -> void:
	var snapshot := PlayerData.serialize()
	PlayerData.deserialize({})  # fresh game, level 1

	var plants := ContentDB.sorted_list(ContentDB.plants).filter(PlayerData.is_unlocked)
	var decorations := ContentDB.sorted_list(ContentDB.decorations).filter(PlayerData.is_unlocked)
	var terrain := ContentDB.sorted_list(ContentDB.terrain).filter(PlayerData.is_unlocked)

	t.check_eq(plants.size(), 1, "only sunflower unlocked at level 1")
	t.check_eq(String(plants[0].id), "sunflower", "sunflower is the starter flower")
	t.check(decorations.is_empty(), "no decorations unlocked at level 1")
	var terrain_ids: Array[String] = []
	for d in terrain:
		terrain_ids.append(String(d.id))
	t.check(terrain_ids.has("short_grass") and terrain_ids.has("dirt"),
			"starter terrain is short grass + dirt")
	t.check(not terrain_ids.has("long_grass") and not terrain_ids.has("water"),
			"long grass and water are gated behind later levels")

	PlayerData.level = 3
	t.check_eq(ContentDB.sorted_list(ContentDB.plants).filter(PlayerData.is_unlocked).size(), 3,
			"all 3 plants unlocked by level 3")
	t.check_eq(ContentDB.sorted_list(ContentDB.decorations).filter(PlayerData.is_unlocked).size(), 1,
			"bird bath unlocked by level 3 (log needs level 4)")

	PlayerData.deserialize(snapshot)


func test_buy_seed_gated_by_unlock_and_money(t: Node) -> void:
	var snapshot := PlayerData.serialize()
	PlayerData.deserialize({})
	PlayerData.money = 100

	t.check(not PlayerData.has_seed(&"sunflower"), "no seeds before buying")
	t.check(PlayerData.buy_seed(&"sunflower"), "buying an unlocked, affordable seed succeeds")
	t.check_eq(PlayerData.money, 100 - ContentDB.get_plant(&"sunflower").seed_price, "money spent")
	t.check(PlayerData.has_seed(&"sunflower"), "seed in stock after buying")

	t.check(not PlayerData.buy_seed(&"oak_tree"), "buying a plant locked at level 1 fails")

	PlayerData.money = 0
	t.check(not PlayerData.buy_seed(&"sunflower"), "buying without enough money fails")

	PlayerData.deserialize(snapshot)


func test_place_consumes_and_remove_refunds_seed(t: Node) -> void:
	var player_snapshot := PlayerData.serialize()
	PlayerData.deserialize({})
	PlayerData.money = 100
	PlayerData.buy_seed(&"sunflower")

	var garden := Garden.new()
	t.add_child(garden)

	garden.set_terrain(&"dirt", Vector2i(0, 0))  # sunflowers need dirt (soil preference)
	t.check(garden.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(0, 0)),
			"placing succeeds with a seed in stock")
	t.check(not PlayerData.has_seed(&"sunflower"), "stock consumed after placing")
	t.check(not garden.place(GardenModel.KIND_PLANT, &"sunflower", Vector2i(1, 0)),
			"placing again fails without buying more")

	t.check(garden.remove(Vector2i(0, 0)), "removing the plant succeeds")
	t.check(PlayerData.has_seed(&"sunflower"), "removing refunds the seed to stock (no fail states)")

	HabitatDirector.reset()
	HabitatDirector._garden = null
	SaveManager._garden = null
	garden.queue_free()
	PlayerData.deserialize(player_snapshot)


func test_place_consumes_and_remove_refunds_decoration(t: Node) -> void:
	var player_snapshot := PlayerData.serialize()
	PlayerData.deserialize({})
	PlayerData.level = 3  # bird_bath unlocks at level 3
	PlayerData.money = 100
	PlayerData.buy_decoration(&"bird_bath")

	var garden := Garden.new()
	t.add_child(garden)

	t.check(garden.place(GardenModel.KIND_DECORATION, &"bird_bath", Vector2i(2, 2)),
			"placing succeeds with a decoration in stock")
	t.check(not PlayerData.has_decoration(&"bird_bath"), "stock consumed after placing")
	t.check(garden.remove(Vector2i(2, 2)), "removing succeeds")
	t.check(PlayerData.has_decoration(&"bird_bath"), "removing refunds the decoration to stock")

	HabitatDirector.reset()
	HabitatDirector._garden = null
	SaveManager._garden = null
	garden.queue_free()
	PlayerData.deserialize(player_snapshot)


## ROADMAP 7.4: a dropped gift sits in the garden until clicked — collecting is
## proximity-based, not an instant inventory teleport.
func test_gift_pickup_collection(t: Node) -> void:
	var player_snapshot := PlayerData.serialize()
	PlayerData.deserialize({})

	var garden := Garden.new()
	t.add_child(garden)

	var pickup := GiftPickup.new(&"feather", Vector2(100, 100))
	garden.add_gift(pickup)
	t.check(PlayerData.inventory.is_empty(), "gift doesn't teleport into inventory on drop")

	t.check(not garden.collect_gift(Vector2(500, 500)), "clicking far away misses the gift")
	t.check(PlayerData.inventory.is_empty(), "still nothing collected")

	t.check(garden.collect_gift(Vector2(105, 100)), "clicking near the gift collects it")
	t.check_eq(int(PlayerData.inventory.get(&"feather", 0)), 1, "the item lands in inventory")
	t.check(not garden.collect_gift(Vector2(100, 100)), "the same gift can't be collected twice")

	HabitatDirector.reset()
	HabitatDirector._garden = null
	SaveManager._garden = null
	garden.queue_free()
	PlayerData.deserialize(player_snapshot)


func test_sell_item(t: Node) -> void:
	var snapshot := PlayerData.serialize()
	PlayerData.deserialize({})

	PlayerData.add_item(&"berry", 4)
	var earned := PlayerData.sell_item(&"berry")
	t.check_eq(earned, 4 * ContentDB.get_item(&"berry").sell_price, "sells the whole stack at its price")
	t.check(not PlayerData.inventory.has(&"berry"), "stack cleared after selling")
	t.check_eq(PlayerData.sell_item(&"berry"), 0, "selling an empty stack earns nothing")

	PlayerData.deserialize(snapshot)
