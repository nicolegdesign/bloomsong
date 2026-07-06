class_name DiaryUI
extends CanvasLayer
## The diary book screen (ROADMAP 6.2/6.3): toggled with J or the Hud's 📖 button.
## An illustrated open book — a big picture of the selected resident/plant on the
## left page, centered handwritten-feeling text about it on the right. Four tabs
## (Residents, Plants, Flowers, Achievements) are painted into the book art itself
## along its left edge; the whole background image swaps per tab (the "active" tab
## is baked into each image). Corner arrows on the pages flip between entries.
## Read-only: observes PlayerData/ContentDB, never mutates anything (PLAN.md —
## nothing calls into UI, and UI must not call back out into gameplay state).

enum Tab { RESIDENTS, PLANTS, FLOWERS, ACHIEVEMENTS }

const BOOK_TEXTURES := {
	Tab.RESIDENTS: preload("res://assets/art/ui/diary_residents.png"),
	Tab.PLANTS: preload("res://assets/art/ui/diary_plants.png"),
	Tab.FLOWERS: preload("res://assets/art/ui/diary_flowers.png"),
	Tab.ACHIEVEMENTS: preload("res://assets/art/ui/diary_achievements.png"),
}
const HAND_FONT := preload("res://assets/fonts/PatrickHand-Regular.ttf")

## Displayed at the image's true 1536:1024 ratio so nothing stretches.
const BOOK_SIZE := Vector2(870, 580)
const ARROW_SIZE := 40.0
## Warm brown "ink" — plain white body text would vanish against cream paper.
const INK_COLOR := Color(0.28, 0.19, 0.12)
## Silhouette tint for undiscovered entries: same artwork, read as a shadow.
const SILHOUETTE_TINT := Color(0.08, 0.07, 0.08, 1.0)

## Safe-to-put-content rects on the book texture, as (x, y, w, h) fractions of the
## whole image — measured by sampling the art for paper-colored pixels (cream/tan,
## excluding the green cover, the brown page-edge shading, and the new tab column)
## rather than eyeballed, so content sits inside the painted page and never
## overlaps the binding, cover, or tabs.
const LEFT_PAGE := Rect2(0.178, 0.108, 0.297, 0.671)
## Wider and shallower-padded than the left page on purpose — this is where the
## text lives, and it needed room to avoid a scrollbar.
const RIGHT_PAGE := Rect2(0.603, 0.119, 0.360, 0.659)
## The 4 tab icons painted along the book's left edge, as click hotspots. Same
## position in all 4 background images — only which tab looks "pressed in" differs.
const TAB_COLUMN_X := Vector2(0.008, 0.159)
const TAB_COLUMN_Y := Vector2(0.059, 0.924)

var _tab: Tab = Tab.RESIDENTS
var _selected_id: StringName = &""

var _root := Control.new()
var _book_tex := TextureRect.new()
var _tab_hotspots: Array[Button] = []
var _illustration := TextureRect.new()
var _title := Label.new()
var _divider := ColorRect.new()
var _body := RichTextLabel.new()
var _prev_button := Button.new()
var _next_button := Button.new()
## Patrick Hand has no true bold weight — [b] tags need a synthetically
## emboldened variant or "Likes" would render identically to normal text.
var _bold_font := FontVariation.new()


func _ready() -> void:
	layer = 12
	visible = false
	_bold_font.base_font = HAND_FONT
	_bold_font.variation_embolden = 1.4
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	# Only the book itself is centered — no header/footer rows around it, so
	# "centered on screen" means exactly what it looks like.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	center.add_child(_build_book())

	var close := Button.new()
	close.text = "✕ (J)"
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-90, 10)
	close.size = Vector2(80, 32)
	close.pressed.connect(close_diary)
	_root.add_child(close)

	EventBus.toggle_diary.connect(toggle)
	EventBus.resident_discovered.connect(func(_id: StringName, _c: Vector2i) -> void: _refresh())
	EventBus.plant_matured.connect(func(_c: Vector2i, _id: StringName) -> void: _refresh())
	_set_tab(Tab.RESIDENTS)


func _build_book() -> Control:
	var frame := Control.new()
	frame.custom_minimum_size = BOOK_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_book_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_book_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_book_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_book_tex)

	for i in Tab.size():
		var y0: float = TAB_COLUMN_Y.x + (TAB_COLUMN_Y.y - TAB_COLUMN_Y.x) * i / Tab.size()
		var y1: float = TAB_COLUMN_Y.x + (TAB_COLUMN_Y.y - TAB_COLUMN_Y.x) * (i + 1) / Tab.size()
		var hotspot := Button.new()
		hotspot.flat = true
		hotspot.anchor_left = TAB_COLUMN_X.x
		hotspot.anchor_right = TAB_COLUMN_X.y
		hotspot.anchor_top = y0
		hotspot.anchor_bottom = y1
		hotspot.pressed.connect(_set_tab.bind(i))
		frame.add_child(hotspot)
		_tab_hotspots.append(hotspot)

	var left_page := Control.new()
	_anchor_to_rect(left_page, LEFT_PAGE)
	left_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(left_page)
	_illustration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_page.add_child(_illustration)

	var right_page := Control.new()
	_anchor_to_rect(right_page, RIGHT_PAGE)
	right_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(right_page)

	var text_col := VBoxContainer.new()
	text_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 10)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_page.add_child(text_col)

	_title.add_theme_font_override("font", HAND_FONT)
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", INK_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(_title)

	_divider.color = Color(INK_COLOR, 0.55)
	_divider.custom_minimum_size = Vector2(0, 2)
	text_col.add_child(_divider)

	_body.add_theme_font_override("normal_font", HAND_FONT)
	_body.add_theme_font_override("bold_font", _bold_font)
	_body.add_theme_font_size_override("normal_font_size", 18)
	_body.add_theme_font_size_override("bold_font_size", 18)
	_body.add_theme_color_override("default_color", INK_COLOR)
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.clip_contents = false
	text_col.add_child(_body)

	_prev_button.text = "◀"
	_prev_button.anchor_left = LEFT_PAGE.position.x
	_prev_button.anchor_right = LEFT_PAGE.position.x
	_prev_button.anchor_top = LEFT_PAGE.position.y
	_prev_button.anchor_bottom = LEFT_PAGE.position.y
	_prev_button.offset_right = ARROW_SIZE
	_prev_button.offset_bottom = ARROW_SIZE
	_prev_button.pressed.connect(_step_entry.bind(-1))
	frame.add_child(_prev_button)

	_next_button.text = "▶"
	var right_edge: float = RIGHT_PAGE.position.x + RIGHT_PAGE.size.x
	_next_button.anchor_left = right_edge
	_next_button.anchor_right = right_edge
	_next_button.anchor_top = RIGHT_PAGE.position.y
	_next_button.anchor_bottom = RIGHT_PAGE.position.y
	_next_button.offset_left = -ARROW_SIZE
	_next_button.offset_bottom = ARROW_SIZE
	_next_button.pressed.connect(_step_entry.bind(1))
	frame.add_child(_next_button)

	return frame


## Maps anchor_left/top/right/bottom directly to a fractional rect (offsets stay
## 0), so the child's rect is always exactly that fraction of its parent.
func _anchor_to_rect(control: Control, rect: Rect2) -> void:
	control.anchor_left = rect.position.x
	control.anchor_top = rect.position.y
	control.anchor_right = rect.position.x + rect.size.x
	control.anchor_bottom = rect.position.y + rect.size.y


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
	_book_tex.texture = BOOK_TEXTURES[tab]
	for i in _tab_hotspots.size():
		_tab_hotspots[i].disabled = (i == tab)
	_refresh()


func _refresh() -> void:
	var ids := _current_ids()
	if _selected_id == &"" and not ids.is_empty():
		_selected_id = ids[0]
	var has_entries := not ids.is_empty()
	_prev_button.visible = has_entries
	_next_button.visible = has_entries
	_show_detail(_selected_id)


## Moves to the next/previous entry in the current tab, wrapping around at
## either end — a dead-end "can't go further" would be a small frustration in
## an otherwise no-fail-state game (CLAUDE.md's design guardrails).
func _step_entry(direction: int) -> void:
	var ids := _current_ids()
	if ids.is_empty():
		return
	var i := ids.find(_selected_id)
	i = (i + direction + ids.size()) % ids.size()
	_selected_id = ids[i]
	_show_detail(_selected_id)


func _current_ids() -> Array:
	match _tab:
		Tab.RESIDENTS:
			var ids := ContentDB.residents.keys()
			ids.sort_custom(func(a, b): return String(ContentDB.get_resident(a).display_name) \
					< String(ContentDB.get_resident(b).display_name))
			return ids
		Tab.PLANTS:
			return _plant_ids(func(cat: int) -> bool: return cat != Types.PlantCategory.FLOWER)
		Tab.FLOWERS:
			return _plant_ids(func(cat: int) -> bool: return cat == Types.PlantCategory.FLOWER)
		_:
			return []


func _plant_ids(matches_category: Callable) -> Array:
	var out: Array = []
	for p: PlantData in ContentDB.sorted_list(ContentDB.plants):
		if matches_category.call(p.category):
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


## The resident's idle sprite, or the plant's mature stage art — its "portrait."
func _texture_for(id: StringName) -> Texture2D:
	if _tab == Tab.RESIDENTS:
		return ContentDB.get_resident(id).texture
	var data := ContentDB.get_plant(id)
	if data.stage_textures.is_empty():
		return null
	return data.stage_textures[-1]


func _show_detail(id: StringName) -> void:
	if _tab == Tab.ACHIEVEMENTS:
		_illustration.texture = null
		_title.text = "Achievements"
		_body.text = "[center][i]Coming soon![/i][/center]"
		return
	if id == &"":
		_illustration.texture = null
		_title.text = ""
		_body.text = ""
		return
	var discovered := _is_discovered(id)
	_illustration.texture = _texture_for(id)
	_illustration.self_modulate = Color.WHITE if discovered else SILHOUETTE_TINT
	if _tab == Tab.RESIDENTS:
		_show_resident_detail(id, discovered)
	else:
		_show_plant_detail(id, discovered)


func _show_resident_detail(id: StringName, discovered: bool) -> void:
	var data := ContentDB.get_resident(id)
	if not discovered:
		_title.text = "???"
		_body.text = "[center][i]%s[/i][/center]" % data.diary_hint
		return
	var entry: Dictionary = PlayerData.diary[id]
	_title.text = data.display_name
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
		lines.append(like)
	_body.text = "[center]%s[/center]" % "\n".join(lines)


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


func _show_plant_detail(id: StringName, discovered: bool) -> void:
	var data := ContentDB.get_plant(id)
	if not discovered:
		_title.text = "???"
		_body.text = "[center][i]Not grown yet — plant one and let it mature.[/i][/center]"
		return
	_title.text = data.display_name
	var lines: Array[String] = []
	lines.append("Category: %s" % Types.CATEGORY_NAMES[data.category].capitalize())
	lines.append("Grown to maturity: %d time%s" % [PlayerData.plants_grown[id],
			"" if int(PlayerData.plants_grown[id]) == 1 else "s"])
	var seasons: Array[String] = []
	for s in Types.SEASON_NAMES.size():
		if data.bloom_seasons & Types.flag(s) != 0:
			seasons.append(Types.SEASON_NAMES[s].capitalize())
	lines.append("Blooms in: %s" % ", ".join(seasons))
	_body.text = "[center]%s[/center]" % "\n".join(lines)
