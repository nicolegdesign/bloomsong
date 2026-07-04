class_name HabitatContext
extends RefCounted
## Snapshot of everything a habitat Requirement may inspect.
## Built by HabitatDirector each evaluation pass; hand-built in unit tests.

var garden: GardenModel
var season: int
var weather: int
var time_of_day: int
## resident_id -> times_seen (from the diary) — enables discovery chains (fox needs rabbits).
var sightings: Dictionary


func _init(p_garden: GardenModel, p_season: int, p_weather: int, p_time_of_day: int,
		p_sightings: Dictionary = {}) -> void:
	garden = p_garden
	season = p_season
	weather = p_weather
	time_of_day = p_time_of_day
	sightings = p_sightings
