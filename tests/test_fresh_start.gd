extends SceneTree

## Fresh-start policy for the public release (docs/itch-release.md): user:// is the release dir
## (custom_user_dir_name "SlimeTime_R<epoch>"), never the old "Slime Time" app_userdata dir; saves and
## codes carry [meta] epoch and anything without this epoch (every pre-release build) starts fresh /
## is refused; "SLIME1-" codes get "THAT CODE IS FROM AN OLD VERSION" in the SAVE CODE panel (also
## through the browser paste path); 5,000 hostile codes never crash and never change the progress.
## Throwaway files only: the real save (old and new path) is only compared, never created or touched.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_fresh_start.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")
const OLD_DIR_NAME := "Slime Time"  # application/config/name: the pre-release user dir (app_userdata)

var failures := 0
var progress: Node
var scratch: Array[String] = []


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	var epoch: int = PROGRESS_SCRIPT.RELEASE_EPOCH
	var real := ProjectSettings.globalize_path(PROGRESS_SCRIPT.REAL_SAVE_PATH)
	var old_real := OS.get_data_dir().path_join("Godot").path_join("app_userdata").path_join(OLD_DIR_NAME).path_join("save.cfg")
	var watched := {}
	for path in [real, old_real]:
		watched[path] = [FileAccess.get_md5(path), FileAccess.get_modified_time(path)] if FileAccess.file_exists(path) else []

	# --- The release user dir, the epoch and the code prefix belong together
	var dir_name: String = ProjectSettings.get_setting("application/config/custom_user_dir_name", "")
	_check(ProjectSettings.get_setting("application/config/use_custom_user_dir", false) and dir_name == "SlimeTime_R%d" % epoch,
		"user:// is the release dir %s (epoch %d)" % [dir_name, epoch])
	_check(PROGRESS_SCRIPT.SAVE_CODE_PREFIX == "SLIME%d-" % (epoch + 1) and PROGRESS_SCRIPT.SAVE_CODE_PREFIX != "SLIME1-",
		"codes start %s (pre-release codes were SLIME1-)" % PROGRESS_SCRIPT.SAVE_CODE_PREFIX)
	var user_dir := OS.get_user_data_dir()
	_check(user_dir == OS.get_data_dir().path_join(dir_name) and not "app_userdata" in user_dir, "OS.get_user_data_dir() = %s" % user_dir)
	_check(real == user_dir.path_join("save.cfg") and real != old_real and not OLD_DIR_NAME in real,
		"the real save is %s, never the old %s" % [real, old_real])
	_check(not PROGRESS_SCRIPT._is_real_save(progress.save_path) and progress.save_path != PROGRESS_SCRIPT.REAL_SAVE_PATH,
		"this test run saves to a throwaway file (%s)" % progress.save_path)

	# --- A clean new dir: no save file at all is a fresh start
	var missing := _scratch("missing")
	var p := _new_progress(missing)
	p.load_progress()
	_check(p.is_fresh_save() and p.levels_cleared == 0 and p.coins() == 0 and not FileAccess.file_exists(missing), "no save file: a fresh start")
	p.free()

	# --- Every save has [meta] epoch; a save of this epoch round-trips
	var full := _new_progress(_scratch("full"))
	full.levels_cleared = 6
	full.highest_unlocked = 7
	full.coins_found = {1: ["2,3", "5,1"]}
	full.best_times = {1: 12.5}
	full.medals = {1: 2}
	var written: ConfigFile = full._write()
	_check(written.get_value("meta", "epoch", -1) == epoch and written.get_value("meta", "version", -1) == PROGRESS_SCRIPT.SAVE_VERSION,
		"a save writes [meta] epoch = %d and version %d" % [epoch, PROGRESS_SCRIPT.SAVE_VERSION])
	full.saving_enabled = true
	full.save_progress()
	var back := _new_progress(full.save_path)
	back.load_progress()
	_check(back._write().encode_to_text() == written.encode_to_text(), "a save of this epoch loads back exactly")
	back.free()

	# --- A save without this epoch (pre-release layout, or another epoch) starts fresh and is left as it is
	for bad_epoch: Variant in [null, 0, epoch + 1, "1", 1.5]:
		var old_save: ConfigFile = full._write()
		if bad_epoch == null:
			old_save.erase_section_key("meta", "epoch")
		else:
			old_save.set_value("meta", "epoch", bad_epoch)
		var path := _scratch("epoch")
		old_save.save(path)
		var md5 := FileAccess.get_md5(path)
		var q := _new_progress(path)
		q.load_progress()
		_check(q.is_fresh_save() and q.levels_cleared == 0 and q.coins() == 0 and q.best_times.is_empty() and FileAccess.get_md5(path) == md5,
			"a save with epoch %s starts fresh (and isn't rewritten)" % [bad_epoch])
		q.free()
	var old_version := ConfigFile.new()  # a version 3 save, exactly as pre-release builds wrote them
	old_version.set_value("meta", "version", 3)
	old_version.set_value("progress", "levels_cleared", 10)
	old_version.set_value("wallet", "globs", 40)
	var old_path := _scratch("v3")
	old_version.save(old_path)
	var r := _new_progress(old_path)
	r.load_progress()
	_check(r.is_fresh_save() and r.tickets == 0, "a pre-release version 3 save is never migrated: a fresh start")
	r.free()

	# --- Save codes: this build's round-trips; the epoch is inside
	var code: String = full.save_code()
	var decoded: ConfigFile = PROGRESS_SCRIPT.read_code(code)
	_check(code.begins_with(PROGRESS_SCRIPT.SAVE_CODE_PREFIX) and decoded != null and decoded.get_value("meta", "epoch", -1) == epoch,
		"a new code starts %s and carries epoch %d" % [PROGRESS_SCRIPT.SAVE_CODE_PREFIX, epoch])
	progress.reset_progress()
	_check(progress.load_code(code) and progress._write().encode_to_text() == written.encode_to_text(), "a new code round-trips exactly")
	_check(not PROGRESS_SCRIPT.is_old_code(code), "...and isn't called old")
	progress.reset_progress()
	var snapshot: String = progress._write().encode_to_text()

	# --- Old codes: refused, called old, nothing changes
	var no_epoch: ConfigFile = full._write()
	no_epoch.erase_section_key("meta", "epoch")
	var body := _body(no_epoch)
	var old_codes := {
		"a SLIME1- code from a pre-release build": "SLIME1-" + body,
		"a SLIME1- code of this epoch's save": "SLIME1-" + _body(written),
		"an old code re-labelled SLIME2-": PROGRESS_SCRIPT.SAVE_CODE_PREFIX + body,
		"a code from a later epoch": PROGRESS_SCRIPT.SAVE_CODE_PREFIX + _body(_with_epoch(written, epoch + 1)),
		"a SLIME1- code pasted with spaces": "  SLIME1-" + body + "\n",
		"SLIME1-garbage": "SLIME1-garbage",
	}
	for label: String in old_codes:
		var old_code: String = old_codes[label]
		_check(PROGRESS_SCRIPT.read_code(old_code) == null and PROGRESS_SCRIPT.is_old_code(old_code) and not progress.load_code(old_code)
			and progress._write().encode_to_text() == snapshot, "%s is refused as old and changes nothing" % label)
	for broken: String in ["", "hello", PROGRESS_SCRIPT.SAVE_CODE_PREFIX, PROGRESS_SCRIPT.SAVE_CODE_PREFIX + "zzz", "SLIME-" + body, code.substr(0, code.length() / 2)]:
		_check(not PROGRESS_SCRIPT.is_old_code(broken) and not progress.load_code(broken), "a broken code %s... isn't called old" % broken.left(12))

	# --- The SAVE CODE panel (desktop LOAD, and the browser paste path)
	var screen: Control = load("res://scenes/controls.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._open_codes()
	_check(screen.code_in.placeholder_text.begins_with(PROGRESS_SCRIPT.SAVE_CODE_PREFIX), "the paste box hints %s..." % PROGRESS_SCRIPT.SAVE_CODE_PREFIX)
	for attempt in 2:  # LOAD twice: an old code never arms or loads
		screen.code_in.text = old_codes["a SLIME1- code from a pre-release build"]
		screen._load_code()
	_check(screen.code_status.text == screen.OLD_CODE_MESSAGE and not screen.load_armed and progress._write().encode_to_text() == snapshot,
		"LOAD on a SLIME1- code says %s and loads nothing" % screen.code_status.text)
	screen._set_pasted(old_codes["an old code re-labelled SLIME2-"])  # what a paste into the web page hands over
	_check(screen.code_status.text == screen.OLD_CODE_MESSAGE, "web paste of an old code says %s" % screen.code_status.text)
	screen._set_pasted("SLIME2-garbage")
	_check("DOESN'T WORK" in screen.code_status.text, "a broken code still says %s" % screen.code_status.text)
	screen._set_pasted(code)
	screen._load_code()
	screen._load_code()
	_check(progress.levels_cleared == 6, "a new code still loads from the panel")
	screen.free()
	progress.reset_progress()
	snapshot = progress._write().encode_to_text()

	# --- Hostile code fuzz: never crashes, never loads, never changes the progress
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261014
	var loaded := 0
	var started := Time.get_ticks_msec()
	for i in 5000:
		var junk := _junk(rng, i, code, body)
		PROGRESS_SCRIPT.is_old_code(junk)
		if PROGRESS_SCRIPT.read_code(junk) != null or progress.load_code(junk):
			loaded += 1
	_check(loaded == 0 and progress._write().encode_to_text() == snapshot,
		"5,000 garbage / oversized / truncated / old-prefix codes: %d loaded, progress unchanged (%d ms)" % [loaded, Time.get_ticks_msec() - started])

	# --- Nothing here touched a real save (the new path or the old pre-release one)
	for path: String in watched:
		var before: Array = watched[path]
		if before.is_empty():
			_check(not FileAccess.file_exists(path), "no real save created at %s" % path)
		else:
			_check(FileAccess.get_md5(path) == before[0] and FileAccess.get_modified_time(path) == before[1], "the real save at %s is untouched" % path)

	full.free()
	for path in scratch:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## One hostile code: random text, random base64, valid gzip of junk, truncations, old prefixes, huge.
func _junk(rng: RandomNumberGenerator, i: int, good: String, old_body: String) -> String:
	var prefix: String = ["", PROGRESS_SCRIPT.SAVE_CODE_PREFIX, "SLIME1-", "SLIME0-", "SLIME99-", "slime2-", "SLIME-", "SLIMEX-"][i % 8]
	match (i / 8) % 8:
		0:  # random unicode-ish text
			var s := ""
			for _c in rng.randi_range(0, 200):
				s += char(rng.randi_range(1, 0x2FFF))
			return prefix + s
		1:  # random base64
			var bytes := PackedByteArray()
			bytes.resize(rng.randi_range(0, 400))
			for b in bytes.size():
				bytes[b] = rng.randi() & 0xFF
			return prefix + Marshalls.raw_to_base64(bytes)
		2:  # gzip of junk text (decodes, never a save of this epoch)
			var text: String = ["[progress]\nlevels_cleared=10", "[meta]\nepoch=\"1\"\n[progress]\nlevels_cleared=10", "[meta]\nepoch=0\n[progress]\n",
				"[[[", "[progress]\nlevels_cleared=1e999", "x".repeat(rng.randi_range(0, 3000))][rng.randi() % 6]
			return prefix + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
		3:  # this build's code, truncated (always loses the gzip trailer)
			return good.substr(0, rng.randi_range(0, good.length() - 5))
		4:  # an old save's body under any prefix
			return prefix + old_body.substr(0, rng.randi_range(0, old_body.length()))
		5:  # oversized
			return prefix + "A".repeat(PROGRESS_SCRIPT.MAX_SAVE_CODE_LENGTH + rng.randi_range(-8, 4000))
		6:  # a good code with a byte flipped in its base64
			var chars := good.to_utf8_buffer()
			var at := rng.randi_range(PROGRESS_SCRIPT.SAVE_CODE_PREFIX.length(), chars.size() - 1)
			chars[at] = "!#%&*.,;:"[rng.randi() % 9].unicode_at(0)
			return chars.get_string_from_utf8()
		_:  # whitespace / control characters around old prefixes
			return " \t\n" + prefix + "\r\n" + old_body.left(rng.randi_range(0, 64)) + "\u0001"


func _new_progress(path: String) -> Node:
	var p: Node = PROGRESS_SCRIPT.new()
	p.save_path = path
	p.saving_enabled = false
	return p


func _scratch(tag: String) -> String:
	var path := "user://test_fresh_start_%d_%s_%d.cfg" % [OS.get_process_id(), tag, scratch.size()]
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	scratch.append(path)
	return path


func _with_epoch(file: ConfigFile, value: Variant) -> ConfigFile:
	var copy := ConfigFile.new()
	copy.parse(file.encode_to_text())
	copy.set_value("meta", "epoch", value)
	return copy


## The base64 body of a code for `file` (what follows the prefix).
func _body(file: ConfigFile) -> String:
	return Marshalls.raw_to_base64(file.encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
