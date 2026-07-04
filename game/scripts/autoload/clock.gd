extends Node
## Owns game time: minutes, days, time-of-day, season, weather (PLAN.md §2).
## Nothing else in the game keeps its own clock. Time does NOT pass while the
## game is closed (ROADMAP 3.3 — the cozy convention).

## Speed of time. 10 game minutes per real second => one full day in 2.4 real minutes.
const GAME_MINUTES_PER_REAL_SECOND := 10.0
const MINUTES_PER_DAY := 24 * 60
const MORNING_START := 6 * 60
const AFTERNOON_START := 12 * 60
const EVENING_START := 18 * 60
const NIGHT_START := 22 * 60
const WAKE_UP_MINUTE := 8 * 60
const DAYS_PER_SEASON := 7
## Vertical slice: locked to spring (ROADMAP 4.4). Flip to false in Phase 9.
const SEASON_LOCKED := true
## Weights must sum to 100 (unit-tested).
const WEATHER_WEIGHTS := {
	Types.Weather.SUNNY: 50,
	Types.Weather.CLOUDY: 30,
	Types.Weather.RAIN: 20,
}

var day := 1
var minute := WAKE_UP_MINUTE
var season: int = Types.Season.SPRING
var weather: int = Types.Weather.SUNNY

var _accumulator := 0.0
var _prev_time_of_day := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_prev_time_of_day = time_of_day()


func _process(delta: float) -> void:
	_accumulator += delta * GAME_MINUTES_PER_REAL_SECOND
	while _accumulator >= 1.0:
		_accumulator -= 1.0
		advance_minute()


func advance_minute() -> void:
	minute += 1
	if minute >= MINUTES_PER_DAY:
		minute = 0
		_start_new_day()
	EventBus.minute_ticked.emit(minute)
	var tod := time_of_day()
	if tod != _prev_time_of_day:
		_prev_time_of_day = tod
		EventBus.time_of_day_changed.emit(tod)


## Debug helper: jump to 8:00 the next morning.
func skip_to_next_day() -> void:
	minute = WAKE_UP_MINUTE
	_start_new_day()
	var tod := time_of_day()
	if tod != _prev_time_of_day:
		_prev_time_of_day = tod
		EventBus.time_of_day_changed.emit(tod)


func time_of_day() -> int:
	if minute >= MORNING_START and minute < AFTERNOON_START:
		return Types.TimeOfDay.MORNING
	if minute >= AFTERNOON_START and minute < EVENING_START:
		return Types.TimeOfDay.AFTERNOON
	if minute >= EVENING_START and minute < NIGHT_START:
		return Types.TimeOfDay.EVENING
	return Types.TimeOfDay.NIGHT


## "08:24" style display string.
func display_time() -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]


func _start_new_day() -> void:
	day += 1
	if not SEASON_LOCKED:
		var new_season := (day - 1) / DAYS_PER_SEASON % 4
		if new_season != season:
			season = new_season
			EventBus.season_changed.emit(season)
	_roll_weather()
	EventBus.day_passed.emit(day)


func _roll_weather() -> void:
	var roll := _rng.randi_range(1, 100)
	var cumulative := 0
	for w in WEATHER_WEIGHTS:
		cumulative += WEATHER_WEIGHTS[w]
		if roll <= cumulative:
			if w != weather:
				weather = w
				EventBus.weather_changed.emit(weather)
			return


func serialize() -> Dictionary:
	return {
		"day": day, "minute": minute,
		"season": Types.SEASON_NAMES[season],
		"weather": Types.WEATHER_NAMES[weather],
	}


func deserialize(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	minute = int(d.get("minute", WAKE_UP_MINUTE))
	season = Types.name_to_index(Types.SEASON_NAMES, String(d.get("season", "spring")))
	weather = Types.name_to_index(Types.WEATHER_NAMES, String(d.get("weather", "sunny")))
	_prev_time_of_day = time_of_day()
