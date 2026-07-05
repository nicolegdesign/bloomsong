class_name SpriteAnchor
## Finds a sprite's visual baseline: the bottom-most row with meaningful alpha.
## AI-generated art arrives with uneven empty margins below the subject, so anchoring
## the CANVAS bottom would make the ground point wander between growth stages.
## Views subtract this margin instead, so the artwork itself (its contact shadow /
## soil mound) always sits exactly on the ground point — no manual alignment, ever.
## Computed once per texture and cached (PROMPTS.md §7).

## Ignore near-invisible pixels (soft glow halos) when finding the baseline.
const ALPHA_THRESHOLD := 0.12
## A row only counts as visible content if at least this many pixels clear the
## alpha threshold — filters an isolated stray artifact pixel (seen in one export,
## a single-pixel-wide haze trailing ~60 rows below the actual artwork) that a
## bare single-pixel check would mistake for the sprite's true base.
const MIN_QUALIFYING_PIXELS := 2

static var _cache: Dictionary = {}


## Fully-transparent rows below the artwork, in source-texture pixels.
static func bottom_margin(texture: Texture2D) -> int:
	var key: RID = texture.get_rid()
	if _cache.has(key):
		return _cache[key]
	var margin := 0
	var img := texture.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var found := false
		for y in range(img.get_height() - 1, -1, -1):
			var qualifying := 0
			for x in img.get_width():
				if img.get_pixel(x, y).a > ALPHA_THRESHOLD:
					qualifying += 1
					if qualifying >= MIN_QUALIFYING_PIXELS:
						found = true
						break
			if found:
				margin = img.get_height() - 1 - y
				break
	_cache[key] = margin
	return margin


## Aspect-fits `texture` into `box_size` (in the caller's local units) and draws it
## on `canvas` at the local origin — the shared "grow in place, never float or
## jump" logic used by every view with art (plants, residents, decorations).
## `centered`: true centers the sprite on the origin (PROMPTS.md's small-resident
## category — butterflies, snails); false (the default) puts the origin at the
## texture's true visual baseline (bottom_margin), so it's ground-anchored like
## plants and upright decorations.
static func draw_fitted(canvas: CanvasItem, texture: Texture2D, box_size: Vector2,
		centered: bool = false) -> void:
	var s := minf(box_size.x / texture.get_width(), box_size.y / texture.get_height())
	var size := Vector2(texture.get_width(), texture.get_height()) * s
	if centered:
		canvas.draw_texture_rect(texture, Rect2(-size / 2.0, size), false)
	else:
		var baseline := bottom_margin(texture) * s
		canvas.draw_texture_rect(texture, Rect2(Vector2(-size.x / 2.0, -size.y + baseline), size), false)
