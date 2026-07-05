class_name PaletteUI
extends Control
## Clickable bottom-bar palette (ROADMAP 2.6): mode tabs (Terrain/Plant/Decoration) +
## buttons for every unlocked item in the current mode, built from ContentDB via
## BuildController. Replaces the keyboard-only 1-9 selection with mouse clicks;
## the keyboard shortcuts still work and stay in sync (BuildController.selection_changed).

const BAR_HEIGHT := 78.0
const TAB_HEIGHT := 26.0

var build: BuildController

var _tabs_row := HBoxContainer.new()
var _items_scroll := ScrollContainer.new()
var _items_row := HBoxContainer.new()
var _tab_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -BAR_HEIGHT

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.08, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_tabs_row.position = Vector2(8, 2)
	_tabs_row.add_theme_constant_override("separation", 4)
	add_child(_tabs_row)
	for i in BuildController.MODE_NAMES.size():
		var tab := Button.new()
		tab.text = BuildController.MODE_NAMES[i]
		tab.custom_minimum_size = Vector2(0, TAB_HEIGHT)
		tab.toggle_mode = true
		tab.pressed.connect(build.set_mode.bind(i))
		_tabs_row.add_child(tab)
		_tab_buttons.append(tab)

	_items_scroll.position = Vector2(4, TAB_HEIGHT + 6)
	_items_scroll.size = Vector2(1272, BAR_HEIGHT - TAB_HEIGHT - 10)
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_items_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_items_scroll)
	_items_row.add_theme_constant_override("separation", 6)
	_items_scroll.add_child(_items_row)

	build.selection_changed.connect(_rebuild)
	EventBus.level_up.connect(func(_l: int, _u: Array) -> void: _rebuild())
	EventBus.game_loaded.connect(_rebuild)
	EventBus.shop_stock_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == build.mode())
	# Clear every child directly (not just tracked buttons) — the empty-mode
	# label below isn't a Button, so it'd otherwise never get cleaned up and
	# would pile up one copy per rebuild.
	for child in _items_row.get_children():
		child.queue_free()
	_item_buttons.clear()

	var list := build.current_list()
	var selected := clampi(build.index(), 0, maxi(list.size() - 1, 0))
	for i in list.size():
		var data: Resource = list[i]
		var stock := _stock_for(data)
		var b := Button.new()
		b.text = "%s  ×%d" % [data.display_name, stock] if stock >= 0 else "%s" % data.display_name
		b.custom_minimum_size = Vector2(96, 40)
		b.toggle_mode = true
		b.button_pressed = (i == selected)
		var color: Color = data.placeholder_color if "placeholder_color" in data else Color.WHITE
		if stock == 0:
			b.modulate = Color(1, 1, 1, 0.5)  # out of stock — hint to visit the shop
		elif b.button_pressed:
			b.modulate = color.lightened(0.5)
		else:
			b.modulate = Color.WHITE
		b.pressed.connect(build.select_index.bind(i))
		_items_row.add_child(b)
		_item_buttons.append(b)
	if list.is_empty():
		var empty := Label.new()
		empty.text = "Nothing unlocked yet."
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_items_row.add_child(empty)


## Purchased stock remaining for a plant/decoration, or -1 in terrain mode (which
## has no stock concept — terrain painting stays free).
func _stock_for(data: Resource) -> int:
	match build.mode():
		BuildController.Mode.PLANT:
			return int(PlayerData.seed_stock.get(data.id, 0))
		BuildController.Mode.DECORATION:
			return int(PlayerData.decoration_stock.get(data.id, 0))
		_:
			return -1
