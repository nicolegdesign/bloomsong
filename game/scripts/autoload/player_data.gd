extends Node
## Player progression state: XP, level, money, diary, inventory (PLAN.md §2).
## Pure state + mutation methods; announces changes on the EventBus.

var xp := 0            # progress within the current level
var level := 1
var money := 50
## resident_id (StringName) -> { "times_seen": int, "first_seen_day": int }
var diary: Dictionary = {}
## plant_id (StringName) -> times grown to maturity
var plants_grown: Dictionary = {}
## item_id (StringName) -> count
var inventory: Dictionary = {}
## Character appearance ids (Phase 13 character creation; saved from day one).
var appearance: Dictionary = {}


## TODO Phase 7: move the curve into a content .tres.
func xp_to_next() -> int:
	return 100 * level


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


## Records a resident visit. Returns true if this is a first-ever sighting (a discovery).
func record_sighting(resident_id: StringName) -> bool:
	var is_new := not diary.has(resident_id)
	if is_new:
		diary[resident_id] = {"times_seen": 0, "first_seen_day": Clock.day}
	diary[resident_id].times_seen += 1
	if is_new:
		var data := ContentDB.get_resident(resident_id)
		add_xp(data.xp_on_discovery if data != null else 10)
		EventBus.resident_discovered.emit(resident_id)
	return is_new


func record_plant_matured(plant_id: StringName) -> void:
	plants_grown[plant_id] = int(plants_grown.get(plant_id, 0)) + 1
	var data := ContentDB.get_plant(plant_id)
	add_xp(data.xp_on_mature if data != null else 5)


func add_item(item_id: StringName, count := 1) -> void:
	inventory[item_id] = int(inventory.get(item_id, 0)) + count
	EventBus.item_collected.emit(item_id, count)


## Sells the whole inventory (placeholder for the Phase 7 shop UI). Returns money earned.
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
		diary_out[String(id)] = {
			"times_seen": diary[id].times_seen,
			"first_seen_day": diary[id].first_seen_day,
		}
	var grown_out: Dictionary = {}
	for id: StringName in plants_grown:
		grown_out[String(id)] = plants_grown[id]
	var inv_out: Dictionary = {}
	for id: StringName in inventory:
		inv_out[String(id)] = inventory[id]
	return {
		"xp": xp, "level": level, "money": money, "appearance": appearance,
		"diary": diary_out, "plants_grown": grown_out, "inventory": inv_out,
	}


func deserialize(d: Dictionary) -> void:
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	money = int(d.get("money", 50))
	appearance = d.get("appearance", {})
	diary.clear()
	for id: String in d.get("diary", {}):
		var entry: Dictionary = d.diary[id]
		diary[StringName(id)] = {
			"times_seen": int(entry.get("times_seen", 0)),
			"first_seen_day": int(entry.get("first_seen_day", 1)),
		}
	plants_grown.clear()
	for id: String in d.get("plants_grown", {}):
		plants_grown[StringName(id)] = int(d.plants_grown[id])
	inventory.clear()
	for id: String in d.get("inventory", {}):
		inventory[StringName(id)] = int(d.inventory[id])
	EventBus.xp_changed.emit(xp, level)
	EventBus.money_changed.emit(money)
