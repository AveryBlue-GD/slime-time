extends "res://tests/suite_base.gd"

## Tests, tools, headless and dev runs never touch the player's real save (user://save.cfg): Progress
## points at a per-process throwaway file that starts fresh, and saving there leaves the real
## save byte-identical. Never creates or modifies the real file (only compares it if it exists).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_save_isolation.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")



func _initialize() -> void:
	await process_frame
	var progress: Node = root.get_node("Progress")
	var real: String = PROGRESS_SCRIPT.REAL_SAVE_PATH
	var real_exists := FileAccess.file_exists(real)
	var real_md5 := FileAccess.get_md5(real) if real_exists else ""
	var real_mtime := FileAccess.get_modified_time(real) if real_exists else 0

	_check(PROGRESS_SCRIPT._is_non_player_run(), "a -s test run is recognised as not the player")
	_check(not PROGRESS_SCRIPT._is_real_save(progress.save_path), "the test's save_path isn't the real save")
	_check(progress.save_path.begins_with(PROGRESS_SCRIPT.THROWAWAY_PREFIX)
		and progress.save_path.contains(str(OS.get_process_id())), "the throwaway save is per process")
	_check(not PROGRESS_SCRIPT._is_real_save(PROGRESS_SCRIPT._default_save_path()), "the default path in a test run isn't the real save")
	_check(PROGRESS_SCRIPT._is_real_save("user://./save.cfg"), "the real save is recognised however it's spelled")

	# A fresh Progress (like any test's reloaded copy) also defaults to a throwaway file.
	var other: Node = PROGRESS_SCRIPT.new()
	_check(not PROGRESS_SCRIPT._is_real_save(other.save_path), "a new Progress in a test defaults to a throwaway save")
	other.free()

	# Saving writes the throwaway file only.
	progress.saving_enabled = true
	progress.coins_found = {1: ["2,3"]}
	progress.save_progress()
	_check(FileAccess.file_exists(progress.save_path), "save_progress writes the throwaway save")
	progress.equip_first_run_skin(2)
	progress.save_progress()
	if real_exists:
		_check(FileAccess.get_md5(real) == real_md5 and FileAccess.get_modified_time(real) == real_mtime,
			"the real save is byte-identical and untouched")
	else:
		_check(not FileAccess.file_exists(real), "no real save was created")
	progress.saving_enabled = false
	progress.coins_found = {}

	_result()
	quit(1 if failures else 0)


