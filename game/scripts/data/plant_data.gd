class_name PlantData
extends Resource
## One plant species (content data). Authored as .tres in content/plants/.

@export var id: StringName
@export var display_name: String
@export var category: Types.PlantCategory = Types.PlantCategory.FLOWER
## In-game days from planting until fully grown.
@export var days_to_mature := 3
## Number of visual growth stages, including the mature one.
@export var growth_stages := 3
@export_flags("Spring:1", "Summer:2", "Fall:4", "Winter:8") var bloom_seasons: int = 1
## Item produced when mature (empty StringName = no fruit).
@export var fruit_item: StringName
## Days between fruit harvests once mature.
@export var fruit_interval_days := 2
@export var placeholder_color: Color = Color.WHITE
@export var unlock_level := 1
@export var seed_price := 5
@export var xp_on_mature := 10
