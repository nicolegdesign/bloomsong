extends RefCounted
## SpriteAnchor.bottom_margin(): finds a sprite's true visual baseline. Regression
## coverage for a real bug — the blackberry bush's fruiting texture had a single
## stray low-alpha pixel trailing ~60 rows below the actual artwork (an export
## artifact), which made the old pure per-pixel check anchor the sprite to that
## stray pixel instead of the mound, jumping its ground position on harvest.


func _make_texture(width: int, height: int, opaque_rows: Array, stray_pixels: Array = []) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y: int in opaque_rows:
		for x in width:
			img.set_pixel(x, y, Color(1, 1, 1, 1))
	for p: Vector2i in stray_pixels:
		img.set_pixel(p.x, p.y, Color(1, 1, 1, 0.2))  # faint, isolated — above the alpha threshold
	return ImageTexture.create_from_image(img)


func test_finds_clean_baseline(t: Node) -> void:
	var tex := _make_texture(10, 10, [0, 1, 2, 3, 4])
	t.check_eq(SpriteAnchor.bottom_margin(tex), 5, "margin counts the empty rows below the content")


func test_ignores_isolated_stray_pixel(t: Node) -> void:
	var tex := _make_texture(10, 10, [0, 1, 2, 3, 4], [Vector2i(7, 9)])
	t.check_eq(SpriteAnchor.bottom_margin(tex), 5,
			"an isolated single-pixel artifact doesn't move the computed baseline")


func test_two_qualifying_pixels_count_as_real_content(t: Node) -> void:
	var tex := _make_texture(10, 10, [0, 1, 2, 3, 4], [Vector2i(7, 8), Vector2i(8, 8)])
	t.check_eq(SpriteAnchor.bottom_margin(tex), 1,
			"a row with 2+ qualifying pixels is treated as real content, not noise")
