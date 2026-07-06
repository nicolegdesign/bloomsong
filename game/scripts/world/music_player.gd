class_name MusicPlayer
extends Node
## Layered ambient audio (ROADMAP 8.3): a melodic bed that crossfades between day
## and night tracks, an ambience layer that crossfades between birdsong and night
## sounds on the same day/night boundary, a rain layer that fades in/out with the
## weather, and a one-shot chime for buying/leveling-up/treasure pickups. All four
## duck together under one mute toggle (M or the Hud button) via EventBus.toggle_mute,
## so the Hud doesn't need a direct reference to this node.

const DAY_MUSIC := preload("res://assets/audio/music/garden_song_1.mp3")
const NIGHT_MUSIC := preload("res://assets/audio/music/night_song_1.mp3")
const DAY_AMBIENCE := preload("res://assets/audio/music/day_birdsong.mp3")
const NIGHT_AMBIENCE := preload("res://assets/audio/music/night_sounds.mp3")
const RAIN_AMBIENCE := preload("res://assets/audio/music/rain.mp3")
const CHIME := preload("res://assets/audio/sfx/chime.mp3")

const MUSIC_VOLUME_DB := -16.0
const AMBIENCE_VOLUME_DB := -14.0
const RAIN_VOLUME_DB := -10.0
const SFX_VOLUME_DB := -6.0
const FADE_SECONDS := 1.5
## How far below its target volume a fading layer goes before its stream is
## swapped — well below audible, so the swap itself is never heard.
const SILENT_OFFSET_DB := -24.0

var muted := false

var _music := AudioStreamPlayer.new()
var _ambience := AudioStreamPlayer.new()
var _rain := AudioStreamPlayer.new()
var _sfx := AudioStreamPlayer.new()
var _is_night := false


func _ready() -> void:
	for track: AudioStreamMP3 in [DAY_MUSIC, NIGHT_MUSIC, DAY_AMBIENCE, NIGHT_AMBIENCE, RAIN_AMBIENCE]:
		track.loop = true

	_music.volume_db = MUSIC_VOLUME_DB
	_ambience.volume_db = AMBIENCE_VOLUME_DB
	_rain.volume_db = RAIN_VOLUME_DB
	_sfx.volume_db = SFX_VOLUME_DB
	for p in [_music, _ambience, _rain, _sfx]:
		add_child(p)

	_is_night = Clock.time_of_day() == Types.TimeOfDay.NIGHT
	_music.stream = NIGHT_MUSIC if _is_night else DAY_MUSIC
	_ambience.stream = NIGHT_AMBIENCE if _is_night else DAY_AMBIENCE
	_play(_music)
	_play(_ambience)
	if Clock.weather == Types.Weather.RAIN:
		_rain.stream = RAIN_AMBIENCE
		_play(_rain)

	EventBus.toggle_mute.connect(toggle_mute)
	EventBus.time_of_day_changed.connect(_on_time_of_day_changed)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.level_up.connect(func(_l: int, _u: Array) -> void: _play_chime())
	EventBus.item_purchased.connect(_play_chime)
	EventBus.treasure_collected.connect(func(_id: StringName) -> void: _play_chime())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_M:
		toggle_mute()


func toggle_mute() -> void:
	muted = not muted
	for p in [_music, _ambience, _rain, _sfx]:
		p.stream_paused = muted
	EventBus.music_muted_changed.emit(muted)


func _on_time_of_day_changed(time_of_day: int) -> void:
	var night := time_of_day == Types.TimeOfDay.NIGHT
	if night == _is_night:
		return
	_is_night = night
	_crossfade(_music, NIGHT_MUSIC if night else DAY_MUSIC, MUSIC_VOLUME_DB)
	_crossfade(_ambience, NIGHT_AMBIENCE if night else DAY_AMBIENCE, AMBIENCE_VOLUME_DB)


func _on_weather_changed(weather: int) -> void:
	_set_rain(weather == Types.Weather.RAIN)


## Re-syncs to the loaded save's actual time/weather — a load can jump straight
## into night or rain without the gradual signals that normally drive the fades.
func _on_game_loaded() -> void:
	_is_night = Clock.time_of_day() == Types.TimeOfDay.NIGHT
	_music.volume_db = MUSIC_VOLUME_DB
	_music.stream = NIGHT_MUSIC if _is_night else DAY_MUSIC
	_play(_music)
	_ambience.volume_db = AMBIENCE_VOLUME_DB
	_ambience.stream = NIGHT_AMBIENCE if _is_night else DAY_AMBIENCE
	_play(_ambience)
	_set_rain(Clock.weather == Types.Weather.RAIN)


## Fades a looping layer to silence, swaps its stream, then fades back in —
## the swap happens while inaudible, so there's never a harsh cut between tracks.
func _crossfade(player: AudioStreamPlayer, new_stream: AudioStream, target_db: float) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_db + SILENT_OFFSET_DB, FADE_SECONDS)
	tween.tween_callback(func() -> void:
		player.stream = new_stream
		_play(player))
	tween.tween_property(player, "volume_db", target_db, FADE_SECONDS)


func _set_rain(active: bool) -> void:
	var tween := create_tween()
	if active:
		if not _rain.playing:
			_rain.stream = RAIN_AMBIENCE
			_rain.volume_db = RAIN_VOLUME_DB + SILENT_OFFSET_DB
			_play(_rain)
		tween.tween_property(_rain, "volume_db", RAIN_VOLUME_DB, FADE_SECONDS)
	else:
		tween.tween_property(_rain, "volume_db", RAIN_VOLUME_DB + SILENT_OFFSET_DB, FADE_SECONDS)
		tween.tween_callback(_rain.stop)


func _play_chime() -> void:
	_sfx.stream = CHIME
	_play(_sfx)


## Godot quirk: AudioStreamPlayer.play() always resets stream_paused to false,
## even if it was true — so every call site must go through here instead of
## calling .play() directly, or a crossfade/rain-start/game-load silently
## un-mutes itself the instant it plays a new stream.
func _play(player: AudioStreamPlayer, from_position := 0.0) -> void:
	player.play(from_position)
	player.stream_paused = muted


func _exit_tree() -> void:
	for p in [_music, _ambience, _rain, _sfx]:
		p.stop()
