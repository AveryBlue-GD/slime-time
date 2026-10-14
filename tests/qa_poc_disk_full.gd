extends SceneTree

## QA proof of concept, now the S9 regression helper (not a test_*.gd suite; test_save_robust._disk_full runs it in a
## child process): a save that fails part way (disk full, quota; simulated with a 512-byte file size limit) used to
## leave a TRUNCATED save.cfg (ConfigFile.save wrote in place and the error was ignored). Progress.write_atomic now
## writes save.cfg.tmp, reads it back and only then renames it over the save, so the old save must survive.
## Run: (ulimit -f 1; trap '' XFSZ; ./tools/godot.sh --path . --headless -s res://tests/qa_poc_disk_full.gd)
## Prints "RESULT: old save intact" (fixed) or "RESULT: TRUNCATED ..." (the old bug). Throwaway user:// file only.
const P := preload("res://scripts/progress.gd")


func _initialize():
	var path := "user://qa_diskfull_%d.cfg" % OS.get_process_id()
	var p: Node = P.new()
	p.save_path = path
	p.saving_enabled = true
	# the old, small, valid save already on disk
	var old := ConfigFile.new()
	old.set_value("meta", "version", 5)
	old.set_value("meta", "epoch", 1)
	old.set_value("progress", "levels_cleared", 9)
	old.save(path)
	var before := FileAccess.get_md5(path)
	print("old size ", FileAccess.get_file_as_string(path).length())
	p.levels_cleared = 10
	p.coins_found = {1: ["1,1", "2,2"], 2: ["3,3"]}
	for i in 300:
		p.coins_found[1].append("%d,%d" % [i, i])  # a save of several KB, well over the limit (bash counts 1 KB blocks)
	for level in range(1, 11):
		p.best_times[level] = 10.0 + level
	var ok: bool = p.save_progress()  # bigger than 512 bytes: the write fails part way
	var size := FileAccess.get_file_as_string(path).length()
	print("save_progress returned ", ok, ", save_failed ", p.save_failed, ", file size now ", size, ", temp left ", FileAccess.file_exists(path + ".tmp"))
	if FileAccess.get_md5(path) == before and not ok and not FileAccess.file_exists(path + ".tmp"):
		print("RESULT: old save intact")
	else:
		print("RESULT: TRUNCATED or replaced (size %d)" % size)
	p.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	quit()
