extends RefCounted
## Clock math: time-of-day boundaries, day rollover, weather table, serialization.
## Uses a fresh Clock instance (not the autoload) so game state is untouched.


func _fresh_clock() -> Node:
	return (load("res://scripts/autoload/clock.gd") as GDScript).new()


func test_time_of_day_boundaries(t: Node) -> void:
	var c := _fresh_clock()
	var cases := {
		359: Types.TimeOfDay.NIGHT, 360: Types.TimeOfDay.MORNING,
		719: Types.TimeOfDay.MORNING, 720: Types.TimeOfDay.AFTERNOON,
		1079: Types.TimeOfDay.AFTERNOON, 1080: Types.TimeOfDay.EVENING,
		1319: Types.TimeOfDay.EVENING, 1320: Types.TimeOfDay.NIGHT,
		0: Types.TimeOfDay.NIGHT,
	}
	for minute: int in cases:
		c.minute = minute
		t.check_eq(c.time_of_day(), cases[minute], "time of day at minute %d" % minute)
	c.free()


func test_day_rollover(t: Node) -> void:
	var c := _fresh_clock()
	c.day = 3
	c.minute = 1439
	c.advance_minute()
	t.check_eq(c.day, 4, "day increments at midnight")
	t.check_eq(c.minute, 0, "minute wraps to 0")
	c.skip_to_next_day()
	t.check_eq(c.day, 5, "skip_to_next_day advances the day")
	t.check_eq(c.time_of_day(), Types.TimeOfDay.MORNING, "skip lands in the morning")
	c.free()


func test_weather_table(t: Node) -> void:
	var c := _fresh_clock()
	var total := 0
	for w: int in c.WEATHER_WEIGHTS:
		total += c.WEATHER_WEIGHTS[w]
	t.check_eq(total, 100, "weather weights sum to 100")
	c.free()


func test_serialize_round_trip(t: Node) -> void:
	var c := _fresh_clock()
	c.day = 12
	c.minute = 615
	c.season = Types.Season.SUMMER
	c.weather = Types.Weather.RAIN
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.serialize()))
	var c2 := _fresh_clock()
	c2.deserialize(d)
	t.check_eq(c2.day, 12, "day restored")
	t.check_eq(c2.minute, 615, "minute restored")
	t.check_eq(c2.season, Types.Season.SUMMER, "season restored (saved as name)")
	t.check_eq(c2.weather, Types.Weather.RAIN, "weather restored (saved as name)")
	t.check_eq(c2.display_time(), "10:15", "display time formats")
	c.free()
	c2.free()
