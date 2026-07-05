extends Node2D
## Root scene script: assembles the world and wires references (PLAN.md §2 — Main
## instantiates; systems find each other via autoloads/EventBus). Also hosts the
## debug hotkeys until real UI replaces them.

var garden: Garden
var player: Player


func _ready() -> void:
	# Root of the Y-sort chain (see Garden._ready) — lets the player character
	# sort against garden objects for the 3/4-view depth illusion.
	y_sort_enabled = true
	garden = Garden.new()
	garden.name = "Garden"
	add_child(garden)

	var tint := DayNightTint.new()
	tint.name = "DayNightTint"
	add_child(tint)

	var music := MusicPlayer.new()
	music.name = "MusicPlayer"
	add_child(music)

	player = Player.new()
	player.name = "Player"
	player.bounds = garden.bounds()
	player.global_position = garden.bounds().get_center()
	add_child(player)

	var build := BuildController.new()
	build.name = "BuildController"
	build.garden = garden
	add_child(build)

	var weather_layer := CanvasLayer.new()
	weather_layer.name = "WeatherLayer"
	weather_layer.layer = 5
	add_child(weather_layer)
	var rain := RainEffect.new()
	rain.name = "Rain"
	weather_layer.add_child(rain)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.layer = 10
	hud.build = build
	add_child(hud)

	var discovery := DiscoveryBanner.new()
	discovery.name = "DiscoveryBanner"
	discovery.garden = garden
	add_child(discovery)

	var diary := DiaryUI.new()
	diary.name = "DiaryUI"
	add_child(diary)

	var shop := ShopUI.new()
	shop.name = "ShopUI"
	add_child(shop)

	if SaveManager.load_game():
		EventBus.toast.emit("Welcome back to your garden 🌱")
	else:
		EventBus.toast.emit("A fresh patch of land awaits 🌱")


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_N:
			Clock.skip_to_next_day()
			EventBus.toast.emit("Day %d begins." % Clock.day)
		KEY_F9:
			if SaveManager.save_game():
				EventBus.toast.emit("Game saved.")
		KEY_F10:
			if SaveManager.load_game():
				EventBus.toast.emit("Game loaded.")
		KEY_F12:
			_start_new_game()


## Debug hotkey: wipes the save file and resets every system to fresh-game
## defaults in place, so testing doesn't require deleting the save by hand
## between runs (user://saves/, see CLAUDE.md).
func _start_new_game() -> void:
	SaveManager.delete_save()
	Clock.deserialize({})
	PlayerData.deserialize({})
	HabitatDirector.reset()
	garden.load_model(GardenModel.new())
	EventBus.toast.emit("🌱 New game started.")
