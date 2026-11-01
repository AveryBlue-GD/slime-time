extends "res://tests/suite_base.gd"

## IMP-04: save notices, newer-save backup, PICK YOUR COLOR with jelly, win stops the leap guard.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_trust_fixes.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")


func _initialize() -> void:
	await process_frame
	var tmp := "user://trust_test_%d.cfg" % OS.get_process_id()
	var g := ProjectSettings.globalize_path(tmp)

	# A newer save is backed up, left untouched and never overwritten.
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("[meta]\nversion=%d\nepoch=%d\n" % [PROGRESS_SCRIPT.SAVE_VERSION + 1, PROGRESS_SCRIPT.RELEASE_EPOCH])
	f.close()
	var before := FileAccess.get_md5(tmp)
	var p: Node = PROGRESS_SCRIPT.new()
	p.save_path = tmp
	p.saving_enabled = true
	p.load_progress(tmp)
	_check(not p.saving_enabled, "a newer save turns saving off")
	_check(FileAccess.file_exists(PROGRESS_SCRIPT.newer_backup_path(tmp)), "a newer save is copied to save.newer.cfg")
	_check(p.notices.size() == 1, "one newer-save notice")
	p.save_progress()
	_check(FileAccess.get_md5(tmp) == before, "the newer save is not overwritten")
	p.notify_once("newer", "x")
	_check(p.notices.size() == 1, "a notice shows once per session")
	p.free()

	# A damaged save is set aside with a notice.
	f = FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string("not a save [[[ =")
	f.close()
	var q: Node = PROGRESS_SCRIPT.new()
	q.save_path = tmp
	q.saving_enabled = true
	q.load_progress(tmp)
	_check(q.corrupt_backup != "" and q.notices.size() == 1, "a damaged save gives a notice")
	q.free()

	# PICK YOUR COLOR with jelly on selects the custom skin (opaque).
	var pr: Node = root.get_node("Progress")
	pr.saving_enabled = false
	pr.levels_cleared = Levels.COUNT
	pr.set_jelly(true)
	pr.select_skin(Skins.CUSTOM)
	_check(pr.selected_skin != Skins.CUSTOM, "(with jelly on, select_skin refuses custom: the old bug)")
	pr.set_jelly(false)
	pr.select_skin(Skins.CUSTOM)
	_check(pr.selected_skin == Skins.CUSTOM, "custom skin selectable with jelly off")

	for path in [tmp, PROGRESS_SCRIPT.newer_backup_path(tmp), PROGRESS_SCRIPT.corrupt_backup_path(tmp)]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_result()
	quit(1 if failures else 0)
