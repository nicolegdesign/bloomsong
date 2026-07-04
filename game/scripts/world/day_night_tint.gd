class_name DayNightTint
extends CanvasModulate
## Ambient day/night lighting (ROADMAP 4.2): lerps a global tint across the day using
## Clock.minute. CanvasModulate only affects world nodes (Garden/Player/residents),
## never CanvasLayer UI (Hud), so the HUD stays fully readable at night.

## (minute-of-day, tint color) keyframes, sorted ascending; the day wraps 1440 -> 0.
## Minute values mirror Clock's MORNING/AFTERNOON/EVENING/NIGHT_START constants
## (kept as literals here since const initializers can't read another autoload's consts).
const KEYFRAMES: Array[Array] = [
	[0, Color(0.28, 0.3, 0.5)],       # midnight: dim blue
	[360, Color(1.0, 0.82, 0.6)],     # 6:00 dawn: warm
	[720, Color(1.0, 1.0, 0.98)],     # 12:00 midday: bright, near-neutral
	[1080, Color(1.0, 0.6, 0.4)],     # 18:00 evening: orange
	[1320, Color(0.28, 0.3, 0.5)],    # 22:00 night: dim blue
	[1440, Color(0.28, 0.3, 0.5)],    # wraps back to midnight
]


func _process(_delta: float) -> void:
	color = _tint_for_minute(Clock.minute)


static func _tint_for_minute(minute: int) -> Color:
	for i in KEYFRAMES.size() - 1:
		var a: Array = KEYFRAMES[i]
		var b: Array = KEYFRAMES[i + 1]
		if minute >= a[0] and minute <= b[0]:
			var t := inverse_lerp(float(a[0]), float(b[0]), float(minute))
			return (a[1] as Color).lerp(b[1] as Color, t)
	return KEYFRAMES[0][1]
