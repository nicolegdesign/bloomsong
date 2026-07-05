class_name DecorationData
extends Resource
## One decoration (content data). Authored as .tres in content/decorations/.

@export var id: StringName
@export var display_name: String
@export var placeholder_color: Color = Color.WHITE
## Idle sprite (PROMPTS.md §5.4). Empty = placeholder rendering.
@export var texture: Texture2D
## Aspect-fit display box in cells at the 64px art scale (PROMPTS.md's per-category
## table): 1×2 (64×128) upright (bird bath, lamp), 1.5×1 (96×64) wide (log, bench).
@export var display_box_cells: Vector2 = Vector2(1.0, 2.0)
@export var price := 10
@export var unlock_level := 1
