class_name MusicPlayer
extends AudioStreamPlayer
## Ambient music loop (ROADMAP 8.3): one calm track, seamlessly looping, quiet
## enough to sit under everything else. Just the music-loop slice of 8.3 —
## time-of-day birdsong and UI/action SFX are separate, still-unstarted pieces.
## Mute toggles via M or the Hud button; both go through EventBus.toggle_mute
## so the Hud doesn't need a direct reference to this node.

const TRACK := "res://assets/audio/music/garden_song_1.mp3"
const VOLUME_DB := -16.0

var muted := false


func _ready() -> void:
	var track := load(TRACK) as AudioStreamMP3
	track.loop = true
	stream = track
	volume_db = VOLUME_DB
	autoplay = true
	play()
	EventBus.toggle_mute.connect(toggle_mute)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_M:
		toggle_mute()


func toggle_mute() -> void:
	muted = not muted
	stream_paused = muted
	EventBus.music_muted_changed.emit(muted)


func _exit_tree() -> void:
	stop()
