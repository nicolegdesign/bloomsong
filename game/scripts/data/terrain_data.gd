class_name TerrainData
extends Resource
## One terrain type (content data — see PLAN.md §5.1). Authored as .tres in content/terrain/.

@export var id: StringName
@export var display_name: String
## Placeholder rendering until the art pass replaces it with tiles.
@export var placeholder_color: Color = Color.WHITE
## Can plants/decorations be placed on this terrain?
@export var plantable := true
@export var unlock_level := 1
