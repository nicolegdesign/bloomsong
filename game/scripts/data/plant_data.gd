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
## One texture per growth stage (index = stage). All stages of a plant must share
## the same source canvas size so relative scale between stages is preserved —
## see game/assets/PROMPTS.md §7. Empty = placeholder circle rendering.
@export var stage_textures: Array[Texture2D] = []
## Overrides the final (mature) stage_textures entry while fruit is ripe and ready
## to harvest — e.g. a blackberry bush visibly bearing berries (PROMPTS.md §5.2's
## "fruit_ready variant"). Empty = no visual difference; only relevant for plants
## with a fruit_item.
@export var fruiting_texture: Texture2D
@export_flags("Spring:1", "Summer:2", "Fall:4", "Winter:8") var bloom_seasons: int = 1
## Soil preference: terrain ids this plant can be planted on. Currently all plants
## want dirt; later content can list short_grass (wildflowers), water/mud (aquatics).
@export var allowed_terrain: Array[StringName] = [&"dirt"]
## Item produced when mature (empty StringName = no fruit).
@export var fruit_item: StringName
## Days between fruit harvests once mature.
@export var fruit_interval_days := 2
## One-shot harvest: if set, clicking the MATURE plant removes the whole plant and
## collects this item (e.g. cutting a sunflower). Distinct from fruit_item, which
## repeats and leaves the plant standing.
@export var harvest_whole_item: StringName
@export var placeholder_color: Color = Color.WHITE
@export var unlock_level := 1
@export var seed_price := 5
## Granted immediately on planting (ROADMAP 7.1 pacing) — xp_on_mature is separate,
## granted later when it finishes growing.
@export var xp_on_plant := 5
@export var xp_on_mature := 20
