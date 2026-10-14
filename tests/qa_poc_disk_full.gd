extends SceneTree

## QA proof of concept (not run by test_all.sh): a save that fails part way (disk full, quota) leaves a TRUNCATED
## save.cfg because Progress.save_progress -> ConfigFile.save truncates the old file and writes in place (no temp
## file + rename, no .bak), and ignores the returned error. Simulated with a file size limit.
## Run: (ulimit -f 1; trap '' XFSZ; ./tools/godot.sh --path . --headless -s res://tests/qa_poc_disk_full.gd)
## Expected "after failed save: size 512" (cut mid-file), the old 56-byte save is gone.
const P := preload("res://scripts/progress.gd")
func _initialize():
	var path := "user://qa_diskfull.cfg"
	var p: Node = P.new()
	p.save_path = path
	p.saving_enabled = true
	# the old, small, valid save already on disk
	var old := ConfigFile.new()
	old.set_value("meta", "version", 5)
	old.set_value("meta", "epoch", 1)
	old.set_value("progress", "levels_cleared", 9)
	old.save(path)
	print("old size ", FileAccess.get_file_as_string(path).length())
	p.levels_cleared = 10
	p.coins_found = {1: ["1,1", "2,2"], 2: ["3,3"]}
	p.save_progress()   # file-size limit makes the write fail part way
	var after := ConfigFile.new()
	var err := after.load(path)
	print("after failed save: size ", FileAccess.get_file_as_string(path).length(), " load err=", err, " levels_cleared=", after.get_value("progress", "levels_cleared", "MISSING"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	quit()
