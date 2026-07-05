class_name SpriteAnchor
## Finds a sprite's visual baseline: the bottom-most row with meaningful alpha.
## AI-generated art arrives with uneven empty margins below the subject, so anchoring
## the CANVAS bottom would make the ground point wander between growth stages.
## Views subtract this margin instead, so the artwork itself (its contact shadow /
## soil mound) always sits exactly on the ground point — no manual alignment, ever.
## Computed once per texture and cached (PROMPTS.md §7).

## Ignore near-invisible pixels (soft glow halos) when finding the baseline.
const ALPHA_THRESHOLD := 0.12

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
			for x in img.get_width():
				if img.get_pixel(x, y).a > ALPHA_THRESHOLD:
					found = true
					break
			if found:
				margin = img.get_height() - 1 - y
				break
	_cache[key] = margin
	return margin
