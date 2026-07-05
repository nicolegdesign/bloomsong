class_name GiftPickup
extends Node2D
## A resident's dropped gift (ROADMAP 7.4): sits in the garden with a gentle bob
## and sparkle until the player clicks it, instead of teleporting straight into
## the inventory. Purely cosmetic until collected — never affects the grid.

const PICKUP_RADIUS := 40.0
const BOB_AMPLITUDE := 6.0
const BOB_SPEED := 2.5
const ICON_SIZE := Vector2(28.0, 28.0)

var item_id: StringName

var _base_pos: Vector2
var _time := 0.0


func _init(p_item_id: StringName, world_pos: Vector2) -> void:
	item_id = p_item_id
	_base_pos = world_pos
	global_position = world_pos
	z_index = 9


func _process(delta: float) -> void:
	_time += delta
	global_position = _base_pos + Vector2(0, sin(_time * BOB_SPEED) * BOB_AMPLITUDE)


## Adds the item to the inventory, toasts, and removes the pickup. Called by
## Garden once it decides a click landed on this pickup.
func collect() -> void:
	PlayerData.add_item(item_id, 1)
	var data := ContentDB.get_item(item_id)
	if data != null:
		EventBus.toast.emit("Collected: %s" % data.display_name)
	queue_free()


func _draw() -> void:
	var data := ContentDB.get_item(item_id)
	if data != null and data.icon != null:
		SpriteAnchor.draw_fitted(self, data.icon, ICON_SIZE, true)
		return
	var color: Color = data.placeholder_color if data != null else Color.YELLOW
	draw_circle(Vector2.ZERO, 6.0, color)
	draw_arc(Vector2.ZERO, 9.0, 0, TAU, 16, Color(1, 1, 0.6, 0.85), 1.5)
