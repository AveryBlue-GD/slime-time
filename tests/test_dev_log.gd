extends SceneTree

## DevLog (dev-only diagnostics file): nothing written outside dev mode, a line per event in dev mode,
## truncated at each launch, capped near 200 KB, and a test/headless run never uses the plain
## dev_attempts.log (that is the owner's play.sh --dev launch) but a per-process file.
## Uses a throwaway save. Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_dev_log.gd

const LOG := "user://test_dev_log.log"
var failures := 0


func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	progress.save_path = "user://test_save.cfg"
	DevLog.path_override = LOG
	_remove()

	progress.dev_tools = false
	DevLog._started = false
	DevLog.log_event(self, "maze built")
	_check(not FileAccess.file_exists(LOG), "no log outside dev mode")

	progress.dev_tools = true
	DevLog.log_event(self, "maze built")
	DevLog.route(self, "R")
	var text := FileAccess.get_file_as_string(LOG)
	_check(text.count("\n") == 2 and "maze built" in text and "restart: R" in text, "dev mode writes one line per event")
	_check(DevLog.last_route == "R", "route remembered for the next maze built")

	DevLog._started = false  # a new launch
	DevLog.log_event(self, "again")
	text = FileAccess.get_file_as_string(LOG)
	_check(text.count("\n") == 1 and "again" in text, "truncated at each launch")

	for i in 20000:
		DevLog.log_event(self, "fill %d" % i)
	var size := FileAccess.get_file_as_string(LOG).length()
	_check(size <= DevLog.MAX_BYTES + 200 and size > DevLog.MAX_BYTES / 2, "size capped (%d)" % size)

	DevLog.path_override = ""
	var path := DevLog.log_path()
	_check(path != DevLog.PLAIN_PATH and str(OS.get_process_id()) in path, "headless/test runs use a per-process file")

	_remove()
	progress.dev_tools = false
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _remove() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG))


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
