extends Node2D
## Root scene script: assembles the world and wires references (PLAN.md §2 — Main
## instantiates; systems find each other via autoloads/EventBus). Also hosts the
## debug hotkeys until real UI replaces them.

var garden: Garden
var player: Player


func _ready() -> void:
	garden = Garden.new()
	garden.name = "Garden"
	add_child(garden)

	player = Player.new()
	player.name = "Player"
	player.bounds = garden.bounds()
	player.global_position = garden.bounds().get_center()
	add_child(player)

	var build := BuildController.new()
	build.name = "BuildController"
	build.garden = garden
	add_child(build)

	var hud := Hud.new()
	hud.name = "Hud"
	hud.build = build
	add_child(hud)

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
		KEY_B:
			var earned := PlayerData.sell_all()
			EventBus.toast.emit("Sold produce for %d coins." % earned if earned > 0
					else "Nothing to sell.")
		KEY_F9:
			if SaveManager.save_game():
				EventBus.toast.emit("Game saved.")
		KEY_F10:
			if SaveManager.load_game():
				EventBus.toast.emit("Game loaded.")
