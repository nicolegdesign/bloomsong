class_name ShopUI
extends CanvasLayer
## Two-tab shop screen (ROADMAP 7.5): toggled with K or the Hud's 🛒 button.
## Buy: unlocked plants/decorations, gated by money (PlayerData.buy_seed/
## buy_decoration already gate on unlock_level too). Sell: harvested/gifted items
## from the inventory. Read-only observer of PlayerData/ContentDB except through
## those two explicit player-action methods (PLAN.md — UI may call player-action
## methods, never mutate state directly).

enum Tab { BUY, SELL }

const PANEL_SIZE := Vector2(640, 520)
const ICON_SIZE := 28.0
## Every plant shows this generic packet in the shop, not its own grown-plant art —
## you're buying a seed, not the finished flower (PROMPTS.md's icon convention).
const SEED_ICON := preload("res://assets/art/icons/seed.png")
## The shop storefront scene, filling the screen behind the buy/sell panel.
const BACKGROUND := preload("res://assets/art/ui/shop_background.png")

var _tab: Tab = Tab.BUY
var _root := Control.new()
var _tab_buttons: Array[Button] = []
var _money_label := Label.new()
var _list := VBoxContainer.new()


func _ready() -> void:
	layer = 13
	visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var background := TextureRect.new()
	background.texture = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_root.add_child(background)

	# A lighter dim than a plain black overlay would need — the storefront scene
	# already reads fine; this just keeps the panel itself easy to read on top of it.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_SIZE
	center.add_child(panel)

	var outer := VBoxContainer.new()
	panel.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	for i in Tab.size():
		var b := Button.new()
		b.text = "Buy" if i == Tab.BUY else "Sell"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(100, 32)
		b.pressed.connect(_set_tab.bind(i))
		header.add_child(b)
		_tab_buttons.append(b)
	_money_label.add_theme_font_size_override("font_size", 20)
	_money_label.custom_minimum_size = Vector2(140, 0)
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_money_label)
	var close := Button.new()
	close.text = "✕ Close (K)"
	close.pressed.connect(close_shop)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = PANEL_SIZE - Vector2(20, 70)
	outer.add_child(scroll)
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	EventBus.toggle_shop.connect(toggle)
	EventBus.money_changed.connect(func(_m: int) -> void: _update_money())
	EventBus.shop_stock_changed.connect(_refresh)
	EventBus.item_collected.connect(func(_id: StringName, _c: int) -> void: _refresh())
	_set_tab(Tab.BUY)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_K:
		toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func close_shop() -> void:
	visible = false


func _set_tab(tab: Tab) -> void:
	_tab = tab
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == tab)
	_refresh()


func _update_money() -> void:
	_money_label.text = "💰 %d" % PlayerData.money


func _refresh() -> void:
	_update_money()
	for child in _list.get_children():
		child.queue_free()
	if _tab == Tab.BUY:
		_build_buy_rows()
	else:
		_build_sell_rows()


func _build_buy_rows() -> void:
	var entries: Array[Dictionary] = []
	for data: PlantData in ContentDB.sorted_list(ContentDB.plants):
		if PlayerData.is_unlocked(data):
			entries.append({"data": data, "is_plant": true})
	for data: DecorationData in ContentDB.sorted_list(ContentDB.decorations):
		if PlayerData.is_unlocked(data):
			entries.append({"data": data, "is_plant": false})
	if entries.is_empty():
		_add_note("Nothing unlocked to buy yet — keep playing to level up.")
		return
	for e in entries:
		var data: Resource = e.data
		var is_plant: bool = e.is_plant
		var price: int = data.seed_price if is_plant else data.price
		var stock: int = int((PlayerData.seed_stock if is_plant else PlayerData.decoration_stock) \
				.get(data.id, 0))

		var row := HBoxContainer.new()
		var icon_tex: Texture2D = SEED_ICON if is_plant else data.texture
		row.add_child(_make_icon(icon_tex, data.placeholder_color))
		var name_label := Label.new()
		name_label.text = data.display_name
		name_label.custom_minimum_size = Vector2(220, 0)
		row.add_child(name_label)
		var price_label := Label.new()
		price_label.text = "%d coins" % price
		price_label.custom_minimum_size = Vector2(90, 0)
		row.add_child(price_label)
		var stock_label := Label.new()
		stock_label.text = "have ×%d" % stock
		stock_label.custom_minimum_size = Vector2(70, 0)
		row.add_child(stock_label)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.disabled = PlayerData.money < price
		buy_btn.pressed.connect(_on_buy.bind(data.id, is_plant))
		row.add_child(buy_btn)
		_list.add_child(row)


func _on_buy(id: StringName, is_plant: bool) -> void:
	var bought := PlayerData.buy_seed(id) if is_plant else PlayerData.buy_decoration(id)
	if not bought:
		EventBus.toast.emit("Not enough coins.")
	_refresh()


func _build_sell_rows() -> void:
	if PlayerData.inventory.is_empty():
		_add_note("Nothing to sell yet — harvest fruit or wait for a resident to leave something behind.")
		return
	var sell_all_btn := Button.new()
	sell_all_btn.text = "Sell All"
	sell_all_btn.pressed.connect(_on_sell_all)
	_list.add_child(sell_all_btn)
	for id: StringName in PlayerData.inventory.keys():
		var data := ContentDB.get_item(id)
		if data == null:
			continue
		var count: int = PlayerData.inventory[id]
		var row := HBoxContainer.new()
		row.add_child(_make_icon(data.icon, data.placeholder_color))
		var name_label := Label.new()
		name_label.text = "%s ×%d" % [data.display_name, count]
		name_label.custom_minimum_size = Vector2(260, 0)
		row.add_child(name_label)
		var value_label := Label.new()
		value_label.text = "%d coins total" % (data.sell_price * count)
		value_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(value_label)
		var sell_btn := Button.new()
		sell_btn.text = "Sell"
		sell_btn.pressed.connect(_on_sell_item.bind(id))
		row.add_child(sell_btn)
		_list.add_child(row)


func _on_sell_item(id: StringName) -> void:
	PlayerData.sell_item(id)
	_refresh()


func _on_sell_all() -> void:
	PlayerData.sell_all()
	_refresh()


## A small icon Control for a row: the texture aspect-fit into a fixed square if
## present, otherwise a flat color swatch — same fallback pattern as every view.
func _make_icon(texture: Texture2D, fallback_color: Color) -> Control:
	if texture == null:
		var swatch := ColorRect.new()
		swatch.color = fallback_color
		swatch.custom_minimum_size = Vector2.ONE * ICON_SIZE
		return swatch
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2.ONE * ICON_SIZE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _add_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_list.add_child(label)
