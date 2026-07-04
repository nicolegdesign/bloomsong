class_name DiscoveryBanner
extends CanvasLayer
## Celebrates a first sighting (ROADMAP 6.1): a sparkle at the resident's spot in the
## garden, a name banner that pops in and holds a moment before fading (a gentle
## "pause" on the ambient flow — purely visual; it never touches game state or
## timing), and a toast for repeat visits stays on the regular Hud toast instead.
## Sound placeholder: no audio assets exist yet (Phase 8.3 adds the real SFX pass);
## this is where an AudioStreamPlayer.play() would go once one does.

const HOLD_SECONDS := 1.8
const FADE_SECONDS := 0.9

var garden: Garden

var _panel := PanelContainer.new()
var _icon := ColorRect.new()
var _title := Label.new()
var _name_label := Label.new()
var _hint_label := Label.new()


func _ready() -> void:
	layer = 15
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_icon.custom_minimum_size = Vector2(48, 48)
	var icon_center := CenterContainer.new()
	icon_center.add_child(_icon)
	vbox.add_child(icon_center)
	_title.text = "✨ New Resident Discovered! ✨"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_name_label)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint_label.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(_hint_label)
	_panel.add_child(vbox)
	_panel.modulate.a = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(_panel)

	EventBus.resident_discovered.connect(_on_discovered)


func _on_discovered(resident_id: StringName, cell: Vector2i) -> void:
	var data := ContentDB.get_resident(resident_id)
	if data == null:
		return
	_icon.color = data.placeholder_color
	_name_label.text = data.display_name
	_hint_label.text = data.description
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.85, 0.85)
	if garden != null:
		_spawn_sparkle(garden.cell_to_world(cell))

	var tween := create_tween()
	_panel.modulate.a = 1.0
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)


func _spawn_sparkle(world_pos: Vector2) -> void:
	var sparkle := CPUParticles2D.new()
	sparkle.global_position = world_pos
	sparkle.z_index = 30
	sparkle.emitting = false
	sparkle.one_shot = true
	sparkle.amount = 24
	sparkle.lifetime = 0.8
	sparkle.explosiveness = 0.9
	sparkle.direction = Vector2.UP
	sparkle.spread = 180.0
	sparkle.gravity = Vector2(0, 40)
	sparkle.initial_velocity_min = 40.0
	sparkle.initial_velocity_max = 90.0
	sparkle.scale_amount_min = 2.0
	sparkle.scale_amount_max = 4.0
	sparkle.color = Color(1.0, 0.95, 0.6, 0.95)
	garden.add_resident_view(sparkle)
	sparkle.emitting = true
	var timer := get_tree().create_timer(sparkle.lifetime + 0.2)
	timer.timeout.connect(sparkle.queue_free)
