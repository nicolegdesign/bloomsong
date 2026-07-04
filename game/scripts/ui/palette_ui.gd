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
	_rebuild()


func _rebuild() -> void:
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == build.mode())
	for b in _item_buttons:
		b.queue_free()
	_item_buttons.clear()

	var list := build.current_list()
	var selected := clampi(build.index(), 0, maxi(list.size() - 1, 0))
	for i in list.size():
		var data: Resource = list[i]
		var b := Button.new()
		b.text = "%s" % data.display_name
		b.custom_minimum_size = Vector2(96, 40)
		b.toggle_mode = true
		b.button_pressed = (i == selected)
		var color: Color = data.placeholder_color if "placeholder_color" in data else Color.WHITE
		b.modulate = color.lightened(0.5) if b.button_pressed else Color.WHITE
		b.pressed.connect(build.select_index.bind(i))
		_items_row.add_child(b)
		_item_buttons.append(b)
	if list.is_empty():
		var empty := Label.new()
		empty.text = "Nothing unlocked yet."
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		_items_row.add_child(empty)
