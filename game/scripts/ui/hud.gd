class_name Hud
extends CanvasLayer
## Minimal debug HUD: clock/season/weather, money/XP, current build selection,
## controls help, and toast messages. Observes systems via EventBus; never mutates.

var build: BuildController

var _info := Label.new()      # top-left: day/time/season/weather
var _status := Label.new()    # top-right: money/level/xp/inventory
var _help := Label.new()      # above the palette: controls
var _toast := Label.new()     # center: transient messages
var _diary_button := Button.new()  # top-right: opens the diary
var _shop_button := Button.new()   # top-right: opens the shop
var _xp_bar := ProgressBar.new()   # top-right: visible XP progress (ROADMAP 7.1)
var _xp_label := Label.new()       # overlaid on the bar: "120 / 200 xp"
var _level_label := Label.new()    # top-right, beside the bar: "Lv 1"
var _refresh_accumulator := 0.0


func _ready() -> void:
	for label: Label in [_info, _status, _help, _level_label]:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_info.position = Vector2(10, 8)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.position = Vector2(-460, 8)
	_status.size.x = 450
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position.y -= PaletteUI.BAR_HEIGHT + 22
	_help.position.x = 10
	_help.text = "WASD move · click palette or 1-9 select, Tab mode · LMB place/harvest · RMB remove · J diary · K shop · N next day · F9 save · F10 load · F12 new game"
	_help.add_theme_font_size_override("font_size", 13)
	_level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_level_label.position = Vector2(-360, 28)
	_level_label.size = Vector2(50, 24)
	_level_label.add_theme_font_size_override("font_size", 18)

	# A CenterContainer spanning a band across the top of the screen keeps the
	# toast correctly centered no matter how long the message is — manually
	# repositioning a Label via reset_size()+position math (the old approach)
	# left it slightly off-center and clipped at the screen edge.
	var toast_band := CenterContainer.new()
	toast_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_band.offset_top = 70
	toast_band.offset_bottom = 130
	toast_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_band)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.modulate.a = 0.0
	toast_band.add_child(_toast)

	var palette := PaletteUI.new()
	palette.build = build
	add_child(palette)

	# Bar added before its label so the label always draws on top of it, and
	# explicit colors so the fill reads clearly regardless of ambient theme
	# (ROADMAP 7.1 — the bar was invisible without either of these).
	_xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_xp_bar.position = Vector2(-310, 32)
	_xp_bar.size = Vector2(300, 16)
	_xp_bar.show_percentage = false
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.15, 0.13, 0.1, 0.85)
	xp_bg.set_corner_radius_all(4)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.98, 0.79, 0.2, 1)
	xp_fill.set_corner_radius_all(4)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	add_child(_xp_bar)
	_xp_label.add_theme_color_override("font_color", Color.WHITE)
	_xp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_xp_label.add_theme_constant_override("outline_size", 4)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_xp_label.position = Vector2(-310, 32)
	_xp_label.size = Vector2(300, 16)
	_xp_label.add_theme_font_size_override("font_size", 12)
	add_child(_xp_label)

	_diary_button.text = "📖 Diary (J)"
	_diary_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_diary_button.position = Vector2(-150, 56)
	_diary_button.size = Vector2(140, 32)
	_diary_button.pressed.connect(func() -> void: EventBus.toggle_diary.emit())
	add_child(_diary_button)

	_shop_button.text = "🛒 Shop (K)"
	_shop_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_shop_button.position = Vector2(-150, 92)
	_shop_button.size = Vector2(140, 32)
	_shop_button.pressed.connect(func() -> void: EventBus.toggle_shop.emit())
	add_child(_shop_button)

	EventBus.toast.connect(show_toast)
	EventBus.level_up.connect(_on_level_up)


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < 0.15:
		return
	_refresh_accumulator = 0.0
	_info.text = "Day %d · %s %s · %s · %s" % [
		Clock.day,
		Types.TIME_NAMES[Clock.time_of_day()].capitalize(),
		Clock.display_time(),
		Types.SEASON_NAMES[Clock.season].capitalize(),
		Types.WEATHER_NAMES[Clock.weather].capitalize(),
	]
	var inv_total := 0
	for id: StringName in PlayerData.inventory:
		inv_total += PlayerData.inventory[id]
	_status.text = "🌼 %d coins · %d items" % [PlayerData.money, inv_total]
	_level_label.text = "Lv %d" % PlayerData.level
	var xp_needed := PlayerData.xp_to_next()
	_xp_bar.max_value = xp_needed
	_xp_bar.value = PlayerData.xp
	_xp_label.text = "%d / %d xp" % [PlayerData.xp, xp_needed]


func show_toast(message: String) -> void:
	_toast.text = message
	var tween := create_tween()
	_toast.modulate.a = 1.0
	tween.tween_interval(2.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _on_level_up(level: int, unlocked_names: Array) -> void:
	var msg := "⭐ Level %d!" % level
	if not unlocked_names.is_empty():
		msg += "  Unlocked: %s" % ", ".join(unlocked_names)
	show_toast(msg)
