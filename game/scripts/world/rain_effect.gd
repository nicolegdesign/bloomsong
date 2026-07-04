class_name RainEffect
extends CPUParticles2D
## Rain overlay (ROADMAP 4.3): fixed to the viewport (lives in its own CanvasLayer so it
## doesn't scroll with the camera), on whenever Clock.weather is RAIN. Placeholder look
## (tinted streak-colored dots) until the art pass.

const VIEWPORT_SIZE := Vector2(1280, 720)


func _ready() -> void:
	amount = 220
	lifetime = 1.0
	preprocess = 1.0
	speed_scale = 1.0
	randomness = 0.4
	position = Vector2(VIEWPORT_SIZE.x / 2.0, -20.0)
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(VIEWPORT_SIZE.x / 2.0 + 20.0, 4.0)
	direction = Vector2(0.15, 1.0)
	spread = 4.0
	gravity = Vector2.ZERO
	initial_velocity_min = 600.0
	initial_velocity_max = 850.0
	scale_amount_min = 1.5
	scale_amount_max = 2.5
	color = Color(0.75, 0.85, 1.0, 0.55)
	emitting = Clock.weather == Types.Weather.RAIN
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.game_loaded.connect(func() -> void: emitting = Clock.weather == Types.Weather.RAIN)


func _on_weather_changed(weather: int) -> void:
	emitting = weather == Types.Weather.RAIN
