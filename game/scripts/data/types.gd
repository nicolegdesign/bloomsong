class_name Types
## Shared enums and their save-file/display names. Flags (1 << enum value) are used
## wherever content declares "any of these" (seasons, weathers, times of day).

enum Season { SPRING, SUMMER, FALL, WINTER }
enum Weather { SUNNY, CLOUDY, RAIN }
enum TimeOfDay { MORNING, AFTERNOON, EVENING, NIGHT }
enum PlantCategory { FLOWER, BUSH, TREE, GROUND_COVER, AQUATIC }

const SEASON_NAMES: Array[String] = ["spring", "summer", "fall", "winter"]
const WEATHER_NAMES: Array[String] = ["sunny", "cloudy", "rain"]
const TIME_NAMES: Array[String] = ["morning", "afternoon", "evening", "night"]
const CATEGORY_NAMES: Array[String] = ["flower", "bush", "tree", "ground cover", "aquatic"]


static func flag(value: int) -> int:
	return 1 << value


static func name_to_index(names: Array[String], n: String, fallback: int = 0) -> int:
	var i := names.find(n)
	return i if i >= 0 else fallback
