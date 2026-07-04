class_name DiaryUI
extends CanvasLayer
## The diary book screen (ROADMAP 6.2/6.3): toggled with J or the Hud's 📖 button.
## Two tabs — Residents and Plants — each a grid of entries (silhouette + hint until
## discovered) with a detail pane on the right. Read-only: observes PlayerData/
## ContentDB, never mutates anything (PLAN.md — nothing calls into UI, and UI must
## not call back out into gameplay state).

enum Tab { RESIDENTS, PLANTS }

const PANEL_SIZE := Vector2(900, 600)
const ENTRY_SIZE := Vector2(64, 64)

var _tab: Tab = Tab.RESIDENTS
var _selected_id: StringName = &""

var _root := Control.new()
var _tab_buttons: Array[Button] = []
var _grid := GridContainer.new()
var _detail_title := Label.new()
var _detail_body := RichTextLabel.new()


func _ready() -> void:
	layer = 12
	visible = false
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var book := PanelContainer.new()
	book.custom_minimum_size = PANEL_SIZE
	center.add_child(book)

	var outer := VBoxContainer.new()
	book.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	for i in Tab.size():
		var b := Button.new()
		b.text = "Residents" if i == Tab.RESIDENTS else "Plants"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(140, 32)
		b.pressed.connect(_set_tab.bind(i))
		header.add_child(b)
		_tab_buttons.append(b)
	var close := Button.new()
	close.text = "✕ Close (J)"
	close.pressed.connect(close_diary)
	header.add_child(close)

	var body := HBoxContainer.new()
	body.custom_minimum_size = PANEL_SIZE - Vector2(0, 50)
	outer.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 0)
	body.add_child(scroll)
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_grid)

	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(380, 0)
	_detail_title.add_theme_font_size_override("font_size", 22)
	detail.add_child(_detail_title)
	_detail_body.fit_content = true
	_detail_body.bbcode_enabled = true
	_detail_body.custom_minimum_size = Vector2(380, 500)
	detail.add_child(_detail_body)
	body.add_child(detail)

	EventBus.toggle_diary.connect(toggle)
	EventBus.resident_discovered.connect(func(_id: StringName, _c: Vector2i) -> void: _refresh())
	EventBus.plant_matured.connect(func(_c: Vector2i, _id: StringName) -> void: _refresh())
	_set_tab(Tab.RESIDENTS)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_J:
		toggle()


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func close_diary() -> void:
	visible = false


func _set_tab(tab: Tab) -> void:
	_tab = tab
	_selected_id = &""
	for i in _tab_buttons.size():
		_tab_buttons[i].button_pressed = (i == tab)
	_refresh()


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var ids: Array = _current_ids()
	if _selected_id == &"" and not ids.is_empty():
		_selected_id = ids[0]
	for id: StringName in ids:
		var discovered := _is_discovered(id)
		var b := Button.new()
		b.custom_minimum_size = ENTRY_SIZE
		b.toggle_mode = true
		b.button_pressed = (id == _selected_id)
		if discovered:
			var color: Color = ContentDB.get_resident(id).placeholder_color \
					if _tab == Tab.RESIDENTS else ContentDB.get_plant(id).placeholder_color
			b.modulate = color.lightened(0.3)
			b.text = String(_display_name(id))
		else:
			b.modulate = Color(0.25, 0.25, 0.28)
			b.text = "?"
		b.pressed.connect(_select.bind(id))
		_grid.add_child(b)
	_show_detail(_selected_id)


func _select(id: StringName) -> void:
	_selected_id = id
	_refresh()


func _current_ids() -> Array:
	if _tab == Tab.RESIDENTS:
		var ids := ContentDB.residents.keys()
		ids.sort_custom(func(a, b): return String(ContentDB.get_resident(a).display_name) \
				< String(ContentDB.get_resident(b).display_name))
		return ids
	var out: Array = []
	for p: PlantData in ContentDB.sorted_list(ContentDB.plants):
		out.append(p.id)
	return out


func _display_name(id: StringName) -> String:
	if _tab == Tab.RESIDENTS:
		return ContentDB.get_resident(id).display_name
	return ContentDB.get_plant(id).display_name


func _is_discovered(id: StringName) -> bool:
	if _tab == Tab.RESIDENTS:
		return PlayerData.diary.has(id)
	return PlayerData.plants_grown.has(id)


func _show_detail(id: StringName) -> void:
	if id == &"":
		_detail_title.text = ""
		_detail_body.text = ""
		return
	if _tab == Tab.RESIDENTS:
		_show_resident_detail(id)
	else:
		_show_plant_detail(id)


func _show_resident_detail(id: StringName) -> void:
	var data := ContentDB.get_resident(id)
	if not PlayerData.diary.has(id):
		_detail_title.text = "???"
		_detail_body.text = "[i]%s[/i]" % data.diary_hint
		return
	var entry: Dictionary = PlayerData.diary[id]
	_detail_title.text = data.display_name
	var lines: Array[String] = [data.description, ""]
	lines.append("Seen: %d time%s" % [entry.times_seen, "" if entry.times_seen == 1 else "s"])
	lines.append("First seen: day %d" % entry.first_seen_day)
	var fav_season := PlayerData.favorite_season(id)
	var fav_weather := PlayerData.favorite_weather(id)
	var fav_time := PlayerData.favorite_time(id)
	if fav_season >= 0:
		lines.append("Usually seen in: %s" % Types.SEASON_NAMES[fav_season].capitalize())
	if fav_weather >= 0:
		lines.append("Favorite weather: %s" % Types.WEATHER_NAMES[fav_weather].capitalize())
	if fav_time >= 0:
		lines.append("Favorite time: %s" % Types.TIME_NAMES[fav_time].capitalize())
	lines.append("")
	lines.append("[b]Likes[/b]")
	for like in _likes(data):
		lines.append("• %s" % like)
	_detail_body.text = "\n".join(lines)


func _likes(data: ResidentData) -> Array[String]:
	var lines: Array[String] = []
	for r: Requirement in data.requirements:
		lines.append(r.describe().capitalize())
	if data.weather_needed != 0:
		var names: Array[String] = []
		for w in Types.WEATHER_NAMES.size():
			if data.weather_needed & Types.flag(w) != 0:
				names.append(Types.WEATHER_NAMES[w].capitalize())
		lines.append("%s weather" % " or ".join(names))
	return lines


func _show_plant_detail(id: StringName) -> void:
	var data := ContentDB.get_plant(id)
	if not PlayerData.plants_grown.has(id):
		_detail_title.text = "???"
		_detail_body.text = "[i]Not grown yet — plant one and let it mature.[/i]"
		return
	_detail_title.text = data.display_name
	var lines: Array[String] = []
	lines.append("Category: %s" % Types.CATEGORY_NAMES[data.category].capitalize())
	lines.append("Grown to maturity: %d time%s" % [PlayerData.plants_grown[id],
			"" if int(PlayerData.plants_grown[id]) == 1 else "s"])
	var seasons: Array[String] = []
	for s in Types.SEASON_NAMES.size():
		if data.bloom_seasons & Types.flag(s) != 0:
			seasons.append(Types.SEASON_NAMES[s].capitalize())
	lines.append("Blooms in: %s" % ", ".join(seasons))
	_detail_body.text = "\n".join(lines)
