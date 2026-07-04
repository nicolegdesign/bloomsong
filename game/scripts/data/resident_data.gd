class_name ResidentData
extends Resource
## One resident species (content data). Authored as .tres in content/residents/.
## Flags with value 0 mean "any" for weather; times/seasons should list at least one.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Shown in the diary before discovery — every resident ships with a hint (CLAUDE.md).
@export_multiline var diary_hint: String
@export var placeholder_color: Color = Color.WHITE
@export var requirements: Array[Requirement] = []
@export_flags("Morning:1", "Afternoon:2", "Evening:4", "Night:8") var active_times: int = 15
@export_flags("Spring:1", "Summer:2", "Fall:4", "Winter:8") var active_seasons: int = 15
## 0 = any weather.
@export_flags("Sunny:1", "Cloudy:2", "Rain:4") var weather_needed: int = 0
## Item occasionally left behind when leaving (empty = none).
@export var leaves_behind: StringName
@export_range(0.0, 1.0) var gift_chance := 0.15
@export var xp_on_discovery := 25


## Season/weather/time gate — cheap check done before evaluating requirements.
func is_active(ctx: HabitatContext) -> bool:
	if active_seasons & Types.flag(ctx.season) == 0:
		return false
	if active_times & Types.flag(ctx.time_of_day) == 0:
		return false
	if weather_needed != 0 and weather_needed & Types.flag(ctx.weather) == 0:
		return false
	return true


func habitat_met(ctx: HabitatContext) -> bool:
	for r in requirements:
		if not r.is_met(ctx):
			return false
	return true
