class_name ItemData
extends Resource
## A sellable item (fruit, resident gifts). Authored as .tres in content/items/.

@export var id: StringName
@export var display_name: String
@export var placeholder_color: Color = Color.WHITE
## Small square icon shown in the shop's Sell tab and anywhere inventory is
## listed (PROMPTS.md §5.7). Empty = placeholder_color swatch.
@export var icon: Texture2D
@export var sell_price := 5
