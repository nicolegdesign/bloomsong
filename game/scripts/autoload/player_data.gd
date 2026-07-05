extends Node
## Player progression state: XP, level, money, diary, inventory (PLAN.md §2).
## Pure state + mutation methods; announces changes on the EventBus.

var xp := 0            # progress within the current level
var level := 1
var money := 100
## resident_id (StringName) -> { "times_seen": int, "first_seen_day": int }
var diary: Dictionary = {}
## plant_id (StringName) -> times grown to maturity
var plants_grown: Dictionary = {}
## item_id (StringName) -> count
var inventory: Dictionary = {}
## Seeds/decorations bought from the shop but not yet placed (ROADMAP 7.5) —
## placing a plant or decoration draws from here instead of being free.
## plant_id / decoration_id (StringName) -> count.
var seed_stock: Dictionary = {}
var decoration_stock: Dictionary = {}
## Character appearance ids (Phase 13 character creation; saved from day one).
var appearance: Dictionary = {}


func xp_to_next() -> int:
	return ContentDB.level_curve.xp_to_next(level)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		EventBus.level_up.emit(level, ContentDB.newly_unlocked_at(level))
	EventBus.xp_changed.emit(xp, level)


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


func spend_money(amount: int) -> bool:
	if amount > money:
		return false
	money -= amount
	EventBus.money_changed.emit(money)
	return true


## Records a resident visit — and which season/weather/time it happened in, so the
## diary can show favorites (ROADMAP 6.2). Returns true if this is a first-ever
## sighting (a discovery); the caller (HabitatDirector) emits resident_discovered,
## since it — not PlayerData — knows where in the garden the sighting happened.
func record_sighting(resident_id: StringName) -> bool:
	var is_new := not diary.has(resident_id)
	if is_new:
		diary[resident_id] = {
			"times_seen": 0, "first_seen_day": Clock.day,
			"season_counts": {}, "weather_counts": {}, "time_counts": {},
		}
	var entry: Dictionary = diary[resident_id]
	entry.times_seen += 1
	_bump(entry.season_counts, Clock.season)
	_bump(entry.weather_counts, Clock.weather)
	_bump(entry.time_counts, Clock.time_of_day())
	if is_new:
		var data := ContentDB.get_resident(resident_id)
		add_xp(data.xp_on_discovery if data != null else 40)
	return is_new


func _bump(counts: Dictionary, key: int) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


## JSON round-trips int-keyed dictionaries with string keys; convert back on load.
func _int_keyed(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[int(k)] = int(d[k])
	return out


## Most-frequent value in a diary entry's season/weather/time_counts, or -1 if the
## resident hasn't been seen yet.
func _favorite(resident_id: StringName, counts_key: String) -> int:
	if not diary.has(resident_id):
		return -1
	var counts: Dictionary = diary[resident_id].get(counts_key, {})
	var best := -1
	var best_count := -1
	for key: int in counts:
		if int(counts[key]) > best_count:
			best_count = counts[key]
			best = key
	return best


func favorite_season(resident_id: StringName) -> int:
	return _favorite(resident_id, "season_counts")


func favorite_weather(resident_id: StringName) -> int:
	return _favorite(resident_id, "weather_counts")


func favorite_time(resident_id: StringName) -> int:
	return _favorite(resident_id, "time_counts")


## Small immediate XP for the act of planting (ROADMAP 7.1 pacing) — separate from
## the bigger reward for actually growing it to maturity.
func record_plant_planted(plant_id: StringName) -> void:
	var data := ContentDB.get_plant(plant_id)
	add_xp(data.xp_on_plant if data != null else 5)


func record_plant_matured(plant_id: StringName) -> void:
	plants_grown[plant_id] = int(plants_grown.get(plant_id, 0)) + 1
	var data := ContentDB.get_plant(plant_id)
	add_xp(data.xp_on_mature if data != null else 20)


func add_item(item_id: StringName, count := 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	EventBus.item_collected.emit(item_id, count)


## Sells the whole inventory. Returns money earned.
func sell_all() -> int:
	var earned := 0
	for item_id: StringName in inventory:
		var data := ContentDB.get_item(item_id)
		if data != null:
			earned += data.sell_price * int(inventory[item_id])
	inventory.clear()
	if earned > 0:
		add_money(earned)
	return earned


## Sells every unit of one item stack (ROADMAP 7.5 shop). Returns money earned.
func sell_item(item_id: StringName) -> int:
	var count := int(inventory.get(item_id, 0))
	if count <= 0:
		return 0
	var data := ContentDB.get_item(item_id)
	var earned := data.sell_price * count if data != null else 0
	inventory.erase(item_id)
	if earned > 0:
		add_money(earned)
	return earned


func has_seed(plant_id: StringName) -> bool:
	return int(seed_stock.get(plant_id, 0)) > 0


func has_decoration(decoration_id: StringName) -> bool:
	return int(decoration_stock.get(decoration_id, 0)) > 0


## Adds to stock without charging money — used by buy_seed() and by Garden's
## remove() refund (removing a placed plant/decoration gives it back, not a fail
## state per PLAN.md §8).
func add_seed(plant_id: StringName, count := 1) -> void:
	seed_stock[plant_id] = int(seed_stock.get(plant_id, 0)) + count
	EventBus.shop_stock_changed.emit()


func add_decoration(decoration_id: StringName, count := 1) -> void:
	decoration_stock[decoration_id] = int(decoration_stock.get(decoration_id, 0)) + count
	EventBus.shop_stock_changed.emit()


func consume_seed(plant_id: StringName) -> void:
	_decrement(seed_stock, plant_id)
	EventBus.shop_stock_changed.emit()


func consume_decoration(decoration_id: StringName) -> void:
	_decrement(decoration_stock, decoration_id)
	EventBus.shop_stock_changed.emit()


func _decrement(stock: Dictionary, id: StringName) -> void:
	var left := int(stock.get(id, 0)) - 1
	if left > 0:
		stock[id] = left
	else:
		stock.erase(id)


## Buys one seed packet from the shop (ROADMAP 7.5). False if locked or unaffordable.
func buy_seed(plant_id: StringName) -> bool:
	var data := ContentDB.get_plant(plant_id)
	if data == null or not is_unlocked(data) or not spend_money(data.seed_price):
		return false
	add_seed(plant_id)
	EventBus.item_purchased.emit()
	return true


## Buys one decoration from the shop. False if locked or unaffordable.
func buy_decoration(decoration_id: StringName) -> bool:
	var data := ContentDB.get_decoration(decoration_id)
	if data == null or not is_unlocked(data) or not spend_money(data.price):
		return false
	add_decoration(decoration_id)
	EventBus.item_purchased.emit()
	return true


func is_unlocked(data: Resource) -> bool:
	return data.unlock_level <= level


## resident_id -> times_seen, for HabitatContext (discovery chains).
func sighting_counts() -> Dictionary:
	var out: Dictionary = {}
	for id: StringName in diary:
		out[id] = diary[id].times_seen
	return out


func serialize() -> Dictionary:
	var diary_out: Dictionary = {}
	for id: StringName in diary:
		var entry: Dictionary = diary[id]
		diary_out[String(id)] = {
			"times_seen": entry.times_seen,
			"first_seen_day": entry.first_seen_day,
			"season_counts": entry.get("season_counts", {}),
			"weather_counts": entry.get("weather_counts", {}),
			"time_counts": entry.get("time_counts", {}),
		}
	var grown_out: Dictionary = {}
	for id: StringName in plants_grown:
		grown_out[String(id)] = plants_grown[id]
	var inv_out: Dictionary = {}
	for id: StringName in inventory:
		inv_out[String(id)] = inventory[id]
	var seed_stock_out: Dictionary = {}
	for id: StringName in seed_stock:
		seed_stock_out[String(id)] = seed_stock[id]
	var deco_stock_out: Dictionary = {}
	for id: StringName in decoration_stock:
		deco_stock_out[String(id)] = decoration_stock[id]
	return {
		"xp": xp, "level": level, "money": money, "appearance": appearance,
		"diary": diary_out, "plants_grown": grown_out, "inventory": inv_out,
		"seed_stock": seed_stock_out, "decoration_stock": deco_stock_out,
	}


func deserialize(d: Dictionary) -> void:
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	money = int(d.get("money", 100))
	appearance = d.get("appearance", {})
	diary.clear()
	for id: String in d.get("diary", {}):
		var entry: Dictionary = d.diary[id]
		diary[StringName(id)] = {
			"times_seen": int(entry.get("times_seen", 0)),
			"first_seen_day": int(entry.get("first_seen_day", 1)),
			"season_counts": _int_keyed(entry.get("season_counts", {})),
			"weather_counts": _int_keyed(entry.get("weather_counts", {})),
			"time_counts": _int_keyed(entry.get("time_counts", {})),
		}
	plants_grown.clear()
	for id: String in d.get("plants_grown", {}):
		plants_grown[StringName(id)] = int(d.plants_grown[id])
	inventory.clear()
	for id: String in d.get("inventory", {}):
		inventory[StringName(id)] = int(d.inventory[id])
	seed_stock.clear()
	for id: String in d.get("seed_stock", {}):
		seed_stock[StringName(id)] = int(d.seed_stock[id])
	decoration_stock.clear()
	for id: String in d.get("decoration_stock", {}):
		decoration_stock[StringName(id)] = int(d.decoration_stock[id])
	EventBus.xp_changed.emit(xp, level)
	EventBus.money_changed.emit(money)
	EventBus.shop_stock_changed.emit()
