class_name Hud
extends CanvasLayer
## Minimal debug HUD: clock/season/weather, money/XP, current build selection,
## controls help, and toast messages. Observes systems via EventBus; never mutates.

var build: BuildController

var _info := Label.new()      # top-left: day/time/season/weather
var _status := Label.new()    # top-right: money/level/xp/inventory
var _palette := Label.new()   # bottom: build selection
var _help := Label.new()      # bottom: controls
var _toast := Label.new()     # center: transient messages
var _refresh_accumulator := 0.0


func _ready() -> void:
	for label: Label in [_info, _status, _palette, _help, _toast]:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 6)
		add_child(label)
	_info.position = Vector2(10, 8)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_status.position = Vector2(-460, 8)
	_status.size.x = 450
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_palette.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_palette.position.y -= 58
	_palette.position.x = 10
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_help.position.y -= 30
	_help.position.x = 10
	_help.text = "WASD move · Tab mode · 1-9 select · LMB place/harvest · RMB remove · N next day · B sell produce · F9 save · F10 load"
	_help.add_theme_font_size_override("font_size", 13)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 80
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.modulate.a = 0.0
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
	_status.text = "🌼 Lv %d  (%d/%d xp) · %d coins · %d items" % [
		PlayerData.level, PlayerData.xp, PlayerData.xp_to_next(), PlayerData.money, inv_total,
	]
	if build != null:
		_palette.text = build.describe()


func show_toast(message: String) -> void:
	_toast.text = message
	# Center horizontally around the anchor point.
	_toast.reset_size()
	_toast.position.x = -_toast.size.x / 2.0
	var tween := create_tween()
	_toast.modulate.a = 1.0
	tween.tween_interval(2.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.8)


func _on_level_up(level: int, unlocked_names: Array) -> void:
	var msg := "⭐ Level %d!" % level
	if not unlocked_names.is_empty():
		msg += "  Unlocked: %s" % ", ".join(unlocked_names)
	show_toast(msg)
