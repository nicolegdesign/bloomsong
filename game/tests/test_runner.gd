extends Node
## Lightweight headless test runner (no addon). Loads every tests/unit/test_*.gd,
## calls each method starting with "test_" (passing itself for assertions), prints
## a summary, and exits nonzero on failure.
## Run: $GODOT --path game/ --headless res://tests/TestRunner.tscn

const SUITE_DIR := "res://tests/unit"

var passed := 0
var failed := 0
var _current := ""
var _failures: Array[String] = []


func _ready() -> void:
	var dir := DirAccess.open(SUITE_DIR)
	if dir == null:
		push_error("No test suite directory at " + SUITE_DIR)
		get_tree().quit(1)
		return
	var files := Array(dir.get_files())
	files.sort()
	for file: String in files:
		var name: String = file.trim_suffix(".remap")
		if not (name.begins_with("test_") and name.ends_with(".gd")):
			continue
		var suite: RefCounted = load(SUITE_DIR + "/" + name).new()
		for m in suite.get_method_list():
			if m.name.begins_with("test_"):
				_current = "%s :: %s" % [name, m.name]
				@warning_ignore("unsafe_method_access")
				suite.call(m.name, self)
	print("")
	print("== %d passed, %d failed ==" % [passed, failed])
	for f in _failures:
		print("  FAIL  " + f)
	await get_tree().process_frame
	get_tree().quit(1 if failed > 0 else 0)


func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		_failures.append("%s — %s" % [_current, message])
		push_error("FAIL %s — %s" % [_current, message])


func check_eq(got: Variant, want: Variant, message: String) -> void:
	check(got == want, "%s (got %s, want %s)" % [message, str(got), str(want)])
