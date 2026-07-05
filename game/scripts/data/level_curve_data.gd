class_name LevelCurveData
extends Resource
## The XP curve (ROADMAP 7.1): xp_thresholds[i] is the XP needed to advance from
## level i+1 to i+2. Authored as content/progression/level_curve.tres so balancing
## (Phase 8.4) is a number in the Inspector, not a code change. Beyond the last
## entry, that final value repeats forever — a save reaching an unauthored level
## still works instead of erroring.

@export var xp_thresholds: Array[int] = [100, 200, 300, 400, 500]


func xp_to_next(level: int) -> int:
	if xp_thresholds.is_empty():
		return 100
	var index := clampi(level - 1, 0, xp_thresholds.size() - 1)
	return xp_thresholds[index]
