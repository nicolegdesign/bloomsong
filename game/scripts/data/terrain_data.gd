class_name TerrainData
extends Resource
## One terrain type (content data — see PLAN.md §5.1). Authored as .tres in content/terrain/.

@export var id: StringName
@export var display_name: String
## Placeholder rendering until the art pass replaces it with tiles.
@export var placeholder_color: Color = Color.WHITE
## Seamless 64×64 tile (PROMPTS.md §5.1). Empty = flat placeholder_color rendering.
@export var texture: Texture2D
## Can plants/decorations be placed on this terrain?
@export var plantable := true
@export var unlock_level := 1
