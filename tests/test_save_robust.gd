extends SceneTree

## QA: save file / save code robustness (docs/qa-release-report.md section 1).
## Hostile save.cfg files (empty, binary, huge, truncated, wrong types, NaN / inf / huge / negative values,
## missing sections, future version / epoch), a hostile value in EVERY key, read-only and missing user dirs,
## and 20,000 mutated codes. Checks: no engine/script error, every loaded value in range, nothing partially
## applied by a refused code, the corrupt file is not touched by a load. Throwaway files only (user://qa_*).
## Known open bugs found here would be printed as KNOWN and not fail the suite (`-- --qa-strict` fails them);
## none are open now. Regression checks for the fixed release bugs (docs/qa-release-report.md):
##   S1 code / save.cfg injection and S11 deep nesting (_injection, _validator, _limits: the SaveText allow-list,
##   with the inputs of tests/qa_poc_code_injection.gd), S10 gzip + trailing bytes (_gzip: tests/qa_poc_gzip_hang.gd
##   inputs), S2 unreadable save moved aside + S9 atomic writes (_file_cases, _overwrite_policy, _dirs, _disk_full:
##   runs tests/qa_poc_disk_full.gd under `ulimit -f` on macOS/Linux), S3 far-future pay day (_clock), S4/S6 (_matrix).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_save_robust.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")

class ErrLog extends Logger:
	var count := 0
	var noise := 0
	var lines: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _e: bool, error_type: int, _b: Array) -> void:
		if error_type == 1:
			return
		var all := code + " " + rationale
		if function == "decompress" and "err != 1" in code:
			noise += 1  # zlib refusing a broken gzip stream in a pasted code (SaveText.gunzip): console only
			return
		if "ConfigFile parse error" in all or "Decompression failed" in all or "no default was given" in all or "Unexpected" in all or "Expected value" in all or "Cannot represent" in all:
			noise += 1
			return
		if "ConfigFile parse error" in rationale or "no default was given" in rationale or "Decompression failed" in rationale or "Can't open file" in rationale or "Cannot open file" in rationale:
			noise += 1  # engine messages for a corrupt file / code (S8: printed to the console, harmless)
			return
		count += 1
		if lines.size() < 6:
			lines.append("%s:%d %s %s %s" % [file, line, function, code, rationale])

var failures := 0
var strict := false
var trace := false
var errlog := ErrLog.new()
var scratch: Array[String] = []
var known: Array[String] = []
var progress: Node
var full: Node  # a busy, valid save


func _initialize() -> void:
	await process_frame
	strict = "--qa-strict" in OS.get_cmdline_user_args()
	trace = "--qa-trace" in OS.get_cmdline_user_args()
	progress = root.get_node("Progress")
	progress.saving_enabled = false
	OS.add_logger(errlog)
	var real := ProjectSettings.globalize_path(PROGRESS_SCRIPT.REAL_SAVE_PATH)
	var old_real := OS.get_data_dir().path_join("Godot").path_join("app_userdata").path_join("Slime Time").path_join("save.cfg")
	var watched := {}
	for path in [real, old_real]:
		watched[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	var t0 := Time.get_ticks_msec()
	var stale := DirAccess.open("user://")  # leftovers of a killed earlier run - never a live run's files (qa_robust_<pid>_...)
	if stale:
		for f in stale.get_files():
			if f.begins_with("qa_robust_") and not _pid_alive(int(f.trim_prefix("qa_robust_").get_slice("_", 0))):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))

	full = _busy()
	await _file_cases()
	print("  [%d ms] _file_cases()" % (Time.get_ticks_msec() - t0))
	_matrix()
	print("  [%d ms] _matrix()" % (Time.get_ticks_msec() - t0))
	_future()
	print("  [%d ms] _future()" % (Time.get_ticks_msec() - t0))
	_overwrite_policy()
	print("  [%d ms] _overwrite_policy()" % (Time.get_ticks_msec() - t0))
	_dirs()
	print("  [%d ms] _dirs()" % (Time.get_ticks_msec() - t0))
	_clock()
	print("  [%d ms] _clock()" % (Time.get_ticks_msec() - t0))
	_state_fuzz()
	print("  [%d ms] _state_fuzz()" % (Time.get_ticks_msec() - t0))
	_injection()
	print("  [%d ms] _injection()" % (Time.get_ticks_msec() - t0))
	_validator()
	print("  [%d ms] _validator()" % (Time.get_ticks_msec() - t0))
	_limits()
	print("  [%d ms] _limits()" % (Time.get_ticks_msec() - t0))
	_gzip()
	print("  [%d ms] _gzip()" % (Time.get_ticks_msec() - t0))
	_full_round_trip()
	print("  [%d ms] _full_round_trip()" % (Time.get_ticks_msec() - t0))
	_disk_full()
	print("  [%d ms] _disk_full()" % (Time.get_ticks_msec() - t0))
	_code_fuzz()
	print("  [%d ms] _code_fuzz()" % (Time.get_ticks_msec() - t0))
	_e("whole suite: %d engine/script errors (%s)" % [errlog.count, "; ".join(errlog.lines)], errlog.count == 0)

	for path: String in watched:
		var now: String = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
		_e("real save %s untouched" % path, now == watched[path])
	for path in scratch:
		for f in [path, path + ".tmp", PROGRESS_SCRIPT.corrupt_backup_path(path, 1), PROGRESS_SCRIPT.corrupt_backup_path(path, 2), PROGRESS_SCRIPT.corrupt_backup_path(path, 3)]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	for line in known:
		print("  KNOWN " + line)
	print("elapsed %.1f s, %d harmless engine messages about corrupt files/codes (S8)" % [(Time.get_ticks_msec() - t0) / 1000.0, errlog.noise])
	var bad := failures + (known.size() if strict else 0)
	print("RESULT: %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	quit(1 if bad else 0)


# ------------------------------------------------------------------ cases

func _busy() -> Node:
	var p := _new("busy")
	p.levels_cleared = 7
	p.highest_unlocked = 8
	p.current_level = 5
	p.coins_found = {1: ["2,3", "5,1"], 3: ["1,1"]}
	p.best_times = {1: 12.5, 2: 40.0}
	p.medals = {1: 3, 2: 1}
	p.upgrades = {"slime": 1}
	p.tickets = 50
	p.tickets_lifetime = 80
	p.hats_owned.assign(["crown"])
	p.spins = 3
	p.random_pay_day = 20000
	p.random_paid = 2
	p.random_paid_seeds.assign([11, 22])
	p.volume = 0.4
	p.hard_mode = true
	return p


## Raw files straight from disk through the real Progress.load_progress.
func _file_cases() -> void:
	var text: String = full._write().encode_to_text()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var blobs := {
		"empty file": PackedByteArray(),
		"one byte": PackedByteArray([0x5B]),
		"NUL bytes": PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]),
		"only whitespace": "\n\n   \t\n".to_utf8_buffer(),
		"UTF-8 BOM + valid": PackedByteArray([0xEF, 0xBB, 0xBF]) + text.to_utf8_buffer(),
		"CRLF line endings": text.replace("\n", "\r\n").to_utf8_buffer(),
		"invalid UTF-8": PackedByteArray([0xFF, 0xFE, 0xC3, 0x28, 0xA0, 0xA1, 0xE2, 0x28, 0xA1]) + text.to_utf8_buffer(),
		"only [meta] epoch": "[meta]\nepoch=1\n".to_utf8_buffer(),
		"[meta] epoch, no progress section": "[meta]\nepoch=1\nversion=5\n[settings]\nvolume=0.5\n".to_utf8_buffer(),
		"sections only": "[meta]\n[progress]\n[wallet]\n[records]\n[coins]\n[maps]\n".to_utf8_buffer(),
		"lone brackets": "[[[[".to_utf8_buffer(),
		"unterminated string": "[meta]\nepoch=1\n[progress]\nlevels_cleared=\"abc\n".to_utf8_buffer(),
		"key without value": "[meta]\nepoch=1\n[progress]\nlevels_cleared=\n".to_utf8_buffer(),
		"duplicate sections/keys": (text + "\n" + text).to_utf8_buffer(),
		"5 MB of text": ("# junk\n".repeat(700000)).to_utf8_buffer(),
		"5 MB of random bytes": _random_bytes(rng, 5 * 1024 * 1024),
		"64 KB random bytes": _random_bytes(rng, 65536),
		"a directory-like path name": "../../etc/passwd".to_utf8_buffer(),
		"valid": text.to_utf8_buffer(),
	}
	for label: String in blobs:
		var path := _scratch("file")
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(blobs[label])
		f.close()
		var md5 := FileAccess.get_md5(path)
		var errs := errlog.count
		var p := _new_at(path)
		var t := Time.get_ticks_msec()
		p.load_progress()
		var ms := Time.get_ticks_msec() - t
		var bad := _insane(p)
		_e("file '%s' (%d bytes) boots: sane=%s, %d ms, %d errors" % [label, blobs[label].size(), bad == "", ms, errlog.count - errs],
			bad == "" and errlog.count == errs and FileAccess.get_md5(path) == md5 and ms < 5000)
		if bad != "":
			print("      insane: " + bad)
		if label in ["valid", "UTF-8 BOM + valid", "CRLF line endings", "duplicate sections/keys"]:
			_e("file '%s' loads the save (levels_cleared=%d)" % [label, p.levels_cleared], p.levels_cleared == 7)
		p.free()
		# the same file as the game's own save (saving on): a file that can't be used is moved aside intact
		var q := _new_at(path)
		q.saving_enabled = true
		q.load_progress()
		var backup: String = PROGRESS_SCRIPT.corrupt_backup_path(path)
		var kept := FileAccess.file_exists(path) and not FileAccess.file_exists(backup)  # (a loaded old-version save is rewritten)
		var moved: bool = not FileAccess.file_exists(path) and FileAccess.get_md5(backup) == md5 and q.corrupt_backup == backup
		var expect_moved := label in ["invalid UTF-8", "lone brackets", "unterminated string", "key without value", "5 MB of text",
			"5 MB of random bytes", "64 KB random bytes", "a directory-like path name", "NUL bytes", "one byte"]
		_e("file '%s' as the live save: %s" % [label, "moved aside to .corrupt.cfg intact" if moved else ("left as is" if kept else "CHANGED")],
			(moved if expect_moved else kept) and _insane(q) == "")
		q.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	# truncated at every 1/25th of a valid save, and byte-flipped
	var bytes := text.to_utf8_buffer()
	var sane_all := true
	for i in 100:
		var cut := bytes.slice(0, bytes.size() * i / 100) if i < 50 else bytes.duplicate()
		if i >= 50:
			for k in rng.randi_range(1, 8):
				cut[rng.randi() % cut.size()] = rng.randi() & 0xFF
		var path := _scratch("trunc")
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(cut)
		f.close()
		var p := _new_at(path)
		p.load_progress()
		var bad := _insane(p)
		if bad != "":
			sane_all = false
			print("      truncated/flipped #%d insane: %s" % [i, bad])
		p.free()
	_e("100 truncated / byte-flipped saves all load sane", sane_all)


## One hostile value in each key of a valid save (as a file and as a code), a fresh Progress each time.
func _matrix() -> void:
	var base: ConfigFile = full._write()
	var hostile: Array = ["", "x", "x".repeat(20000), -1, 0, 1, 2, 9223372036854775807, -9223372036854775808, 1e308, -1e308, NAN, INF, -INF,
		0.5, [], [1, 2, 3], ["a", "b"], [[[]]], {}, {"a": 1}, Color(1, 0, 0), Vector2(1, 2), true, false, PackedByteArray([1, 2]), "SLIME2-", "res://x", "../../x"]
	var errs := errlog.count
	var cases := 0
	var insane_n := 0
	var first_bad := ""
	for section in base.get_sections():
		for key in base.get_section_keys(section):
			for value: Variant in hostile:
				var file := ConfigFile.new()
				file.parse(base.encode_to_text())
				file.set_value(section, key, value)
				if section == "meta" and key == "epoch":
					continue  # (a wrong epoch is refused; covered in _future)
				var p := _new("matrix")
				p._read(file)  # what both the file loader and the code loader do
				var bad := _insane(p)
				cases += 1
				if bad != "":
					insane_n += 1
					if first_bad == "":
						first_bad = "[%s] %s = %s -> %s" % [section, key, str(value).left(30), bad]
				# the same through a real file round trip: written by ConfigFile, read by load_progress
				var path := _scratch("matrix")
				file.save(path)
				var q := _new_at(path)
				q.load_progress()
				var bad2 := _insane(q)
				if bad2 != "" and first_bad == "":
					first_bad = "(file) [%s] %s = %s -> %s" % [section, key, str(value).left(30), bad2]
					insane_n += 1
				q.free()
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				p.free()
	_e("%d hostile (key x value) saves: %d insane%s" % [cases, insane_n, (" first: " + first_bad) if first_bad != "" else ""], insane_n == 0)
	_e("hostile matrix produced no engine errors", errlog.count == errs)
	# values the loader accepts but that are semantically hostile (not crashes): report only
	var f2 := ConfigFile.new()
	f2.parse(base.encode_to_text())
	f2.set_value("records", "level_1", 0.0)
	f2.set_value("records", "level_2", -5.0)
	f2.set_value("records", "level_3", 1e-9)
	f2.set_value("wallet", "random_day", 9223372036854775807)
	f2.set_value("coins", "level_1", ["a"] if false else _many_strings(300000))
	f2.set_value("controls", "jump", 0)
	f2.set_value("controls", "move_up", KEY_SPACE)
	var p := _new("semantic")
	var t := Time.get_ticks_msec()
	p._read(f2)
	var ms := Time.get_ticks_msec() - t
	_e("a save with a 300,000-entry coin list reads in %d ms" % ms, ms < 4000)
	_e("best_time 0 / negative records are dropped or harmless: level 1 best = %s, level 2 = %s, level 3 = %s" % [p.best_times.get(1), p.best_times.get(2), p.best_times.get(3)],
		not p.best_times.has(1) and not p.best_times.has(2) and not p.best_times.has(3))
	_e("coins() cannot exceed the real coin count (%d coins from a hostile list)" % p.coins(), p.coins() <= 200 or _known("S5 [coins] level_N list of ANY strings counts up to Levels.COINS per level, so coins stay capped; total %d" % p.coins()))
	_e("one key bound twice or to nothing is repaired (jump=%d, move_up=%d)" % [p.bindings.get("jump"), p.bindings.get("move_up")],
		p.bindings.get("jump", 0) > 0 and p.bindings.values().size() == _unique(p.bindings.values()))
	p.free()


func _future() -> void:
	for ver: Variant in [0, -1, 4, 5, 6, 99, 2147483647, "5", 5.5, null]:
		for epoch: Variant in [1, 2, 0, null, 1.0]:
			var file: ConfigFile = full._write()
			if ver == null:
				file.erase_section_key("meta", "version")
			else:
				file.set_value("meta", "version", ver)
			if epoch == null:
				file.erase_section_key("meta", "epoch")
			else:
				file.set_value("meta", "epoch", epoch)
			var path := _scratch("future")
			file.save(path)
			var p := _new_at(path)
			p.load_progress()
			var accepted: bool = p.levels_cleared == 7
			var expect: bool = typeof(epoch) == TYPE_INT and epoch == 1
			_e("version %s epoch %s -> %s" % [ver, epoch, "loaded" if accepted else "fresh"], accepted == expect and _insane(p) == "")
			p.free()
	# a save from the future that is loaded then saved loses nothing it understood
	var file: ConfigFile = full._write()
	file.set_value("meta", "version", 99)
	file.set_value("future", "new_feature", [1, 2, 3])
	var path := _scratch("future2")
	file.save(path)
	var p := _new_at(path)
	p.load_progress()
	p.saving_enabled = true
	p.save_progress()
	var after := ConfigFile.new()
	after.load(path)
	_e("a version 99 save, loaded and saved again, is rewritten as version %s and drops [future] (a downgrade eats unknown data)" % after.get_value("meta", "version"),
		after.get_value("meta", "version") == PROGRESS_SCRIPT.SAVE_VERSION)
	p.free()


## S2: a save that can't be used is moved aside (rotating, bounded) before the game starts fresh, so the
## next save can't destroy it; S9: saves are written atomically (temp file, read back, rename).
func _overwrite_policy() -> void:
	var path := _scratch("corrupt")
	var typo := "[meta]\nepoch=1\n[progress]\nlevels_cleared=7\nhighest_unlocked=8\n[records\nlevel_1=12.5\n"  # a hand-edit typo
	_store(path, typo)
	var md5 := FileAccess.get_md5(path)
	var p := _new_at(path)
	p.saving_enabled = true
	p.load_progress()
	var backup: String = PROGRESS_SCRIPT.corrupt_backup_path(path)
	_e("an unreadable save starts fresh (levels_cleared=%d) and is moved to %s intact" % [p.levels_cleared, backup.get_file()],
		p.levels_cleared == 0 and not FileAccess.file_exists(path) and FileAccess.get_md5(backup) == md5 and p.corrupt_backup == backup)
	p.save_progress()  # e.g. the first coin, or hitting the title's PLAY
	_e("the next save writes a new file and the backup survives it", FileAccess.file_exists(path) and FileAccess.get_md5(backup) == md5)
	p.free()
	# backups rotate: the newest CORRUPT_KEEP are kept, never more
	for i in 5:
		_store(path, "[meta]\nepoch=1\n[progress]\nbroken %d=\n" % i)
		var q := _new_at(path)
		q.saving_enabled = true
		q.load_progress()
		q.free()
	var kept := 0
	for name in DirAccess.open(path.get_base_dir()).get_files():
		if name.begins_with(path.get_file().get_basename() + ".corrupt"):
			kept += 1
	_e("after 5 more unreadable saves: %d backups kept (max %d), newest first" % [kept, PROGRESS_SCRIPT.CORRUPT_KEEP],
		kept == PROGRESS_SCRIPT.CORRUPT_KEEP and FileAccess.get_file_as_string(backup).contains("broken 4") \
		and FileAccess.get_file_as_string(PROGRESS_SCRIPT.corrupt_backup_path(path, 3)).contains("broken 2"))
	# a save of another release epoch / an empty file is NOT corrupt: left in place (fresh start by policy)
	for text: String in ["[meta]\nepoch=7\n[progress]\nlevels_cleared=3\n", "", "\n  \n"]:
		var other := _scratch("epoch")
		_store(other, text)
		var r := _new_at(other)
		r.saving_enabled = true
		r.load_progress()
		_e("a %s save is left where it is (no backup)" % ("blank" if text.strip_edges() == "" else "other-epoch"),
			FileAccess.file_exists(other) and not FileAccess.file_exists(PROGRESS_SCRIPT.corrupt_backup_path(other)) and r.levels_cleared == 0)
		r.free()
	# dev / headless runs only peek at a save (saving off): they never move it
	var peek := _scratch("peek")
	_store(peek, typo)
	var s := _new_at(peek)
	s.load_progress()
	_e("with saving off, an unreadable save is not moved", FileAccess.get_md5(peek) == md5)
	s.free()
	# atomic write: no temp left behind, and a blocked temp path keeps the old save byte-identical
	var sp := _new_at(_scratch("atomic"))
	sp.saving_enabled = true
	sp.levels_cleared = 3
	_e("a save succeeds and leaves no temp file", sp.save_progress() and not FileAccess.file_exists(sp.save_path + ".tmp") and not sp.save_failed)
	var old := FileAccess.get_md5(sp.save_path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(sp.save_path + ".tmp"))  # the temp file can't be created
	sp.levels_cleared = 9
	var ok: bool = sp.save_progress()
	_e("a save that can't be written returns false, keeps the old file and the progress in memory",
		not ok and sp.save_failed and FileAccess.get_md5(sp.save_path) == old and sp.levels_cleared == 9)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sp.save_path + ".tmp"))
	_e("...and the next save (or the retry) writes it", sp.save_progress() and not sp.save_failed and _load_levels(sp.save_path) == 9)
	sp.free()
	# a rename that fails with no save left at the path (Windows removes the old save first): the verified temp stays
	var rp := _scratch("rename")
	var rn := _new_at(rp)
	rn.saving_enabled = true
	rn.levels_cleared = 7
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(rp))  # (a folder in the save's place: the rename fails)
	_e("a failed rename with no save at the path keeps the complete temp file", not rn.save_progress() and rn.save_failed and FileAccess.file_exists(rp + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(rp))
	var rv := _new_at(rp)
	rv.saving_enabled = true
	rv.load_progress()
	_e("...which the next launch promotes to the save (levels_cleared=%d)" % rv.levels_cleared, rv.levels_cleared == 7 and FileAccess.file_exists(rp) and not FileAccess.file_exists(rp + ".tmp"))
	for n in [rn, rv]:
		n.free()
	# an interrupted save: a temp next to a save is discarded; a lone valid temp (crash between remove and rename) is used
	var cp := _scratch("crash")
	var good := _new_at(cp)
	good.levels_cleared = 4
	_store(cp, good._write().encode_to_text())
	good.levels_cleared = 6
	_store(cp + ".tmp", good._write().encode_to_text().left(40))
	var t := _new_at(cp)
	t.saving_enabled = true
	t.load_progress()
	_e("a half-written temp next to the save is discarded and the save loads (levels_cleared=%d)" % t.levels_cleared,
		t.levels_cleared == 4 and not FileAccess.file_exists(cp + ".tmp"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cp))
	_store(cp + ".tmp", good._write().encode_to_text())
	var u := _new_at(cp)
	u.saving_enabled = true
	u.load_progress()
	_e("a complete temp with no save is recovered (levels_cleared=%d)" % u.levels_cleared, u.levels_cleared == 6 and FileAccess.file_exists(cp))
	for n in [good, t, u]:
		n.free()


func _dirs() -> void:
	# missing directory: saving fails quietly and the game keeps running
	var p := _new_at("user://qa_no_such_dir_%d/save.cfg" % OS.get_process_id())
	p.saving_enabled = true
	var errs := errlog.count
	var saved: bool = p.save_progress()
	p.load_progress()
	_e("save_path in a missing dir: save reports failure, load is a no-op, no crash (%d new errors)" % (errlog.count - errs), p.is_fresh_save() and not saved and p.save_failed)
	p.free()
	# read-only dir
	var dir_path := "user://qa_ro_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var abs_dir := ProjectSettings.globalize_path(dir_path)
	var ro_file := dir_path + "/save.cfg"
	var seed_p := _new_at(ro_file)
	seed_p.levels_cleared = 4
	seed_p.saving_enabled = true
	seed_p.save_progress()
	OS.execute("chmod", ["-R", "a-w", abs_dir])
	var md5 := FileAccess.get_md5(ro_file)
	var q := _new_at(ro_file)
	q.saving_enabled = true
	q.levels_cleared = 9
	errs = errlog.count
	var ok: bool = q.save_progress()
	var after := FileAccess.get_md5(ro_file)
	OS.execute("chmod", ["-R", "u+w", abs_dir])
	_e("a read-only save dir: the save fails visibly (save_failed), no crash, the old save is unchanged, progress kept in memory",
		not ok and q.save_failed and after == md5 and q.levels_cleared == 9)
	var r := _new_at(ro_file)
	r.load_progress()
	_e("...and the old save still loads (levels_cleared=%d)" % r.levels_cleared, r.levels_cleared == 4)
	DirAccess.remove_absolute(abs_dir.path_join("save.cfg"))
	DirAccess.remove_absolute(abs_dir)
	for n in [seed_p, q, r]:
		n.free()


## S9 for real: tests/qa_poc_disk_full.gd run in a child process under `ulimit -f 1` (a 512-byte file size
## limit: the write fails part way like a full disk). The old save must survive byte for byte.
func _disk_full() -> void:
	if OS.get_name() == "Windows":
		print("  info disk-full child run skipped on Windows (needs ulimit)")
		return
	var out: Array = []
	var cmd := "ulimit -f 1; trap '' XFSZ; '%s' --path '%s' --headless -s res://tests/qa_poc_disk_full.gd 2>&1" % [OS.get_executable_path(), ProjectSettings.globalize_path("res://")]
	var code := OS.execute("bash", ["-c", cmd], out)
	var text: String = "\n".join(out)
	var ok := text.contains("RESULT: old save intact") and not text.contains("TRUNCATED")
	_e("a save under a 512-byte file size limit fails cleanly: old save intact (exit %d)" % code, ok)
	if not ok:
		print("      child output: " + text.right(400).c_escape())


## S3: randomizer daily cap against a wrong clock (UTC day from the clock; tests set day_override).
func _clock() -> void:
	var p := _new("clock")
	p.upgrades = {"slime": 1}
	p.saving_enabled = false
	p.day_override = 20000
	var paid := []
	for i in 7:
		p.random_seed_fresh = true
		paid.append(p.complete_random(false, 100 + i, 1))
	_e("5 paying wins a day then 0: %s" % [paid], paid == [5, 5, 5, 5, 5, 0, 0])
	p.day_override = 19000  # clock moved back ~3 years
	_e("clock moved back: still capped (forward-only)", p.random_tickets_due(1, 301) == 0)
	p.day_override = 20001
	p.random_seed_fresh = true
	p.complete_random(false, 400, 1)
	_e("next day: pays again (paid today %d)" % p.random_paid, p.random_paid == 1)
	p.day_override = 20002 + 365 * 3
	p.random_seed_fresh = true
	_e("clock moved forward 3 years: cap resets (%d)" % p.random_tickets_due(1, 500), p.random_tickets_due(1, 500) == 5)
	# a one-off wrong clock far in the future: win once, set the clock right again
	var q := _new("clock2")
	q.upgrades = {"slime": 1}
	q.day_override = 20000 + 365 * 70  # a dead CMOS battery / wrong clock
	q.random_seed_fresh = true
	q.complete_random(false, 1, 1)
	q.day_override = 20000  # the clock is corrected
	q.random_seed_fresh = true
	_e("after a win under a clock 70 years ahead, the stored day is treated as today (%d)" % (q.random_tickets_due(1, 99)), q.random_tickets_due(1, 99) == 5 and q.random_pay_day == 20000)
	for i in 4:
		q.random_seed_fresh = true
		q.complete_random(false, 10 + i, 1)
	_e("...that win counts toward today's 5 (due now %d)" % q.random_tickets_due(1, 99), q.random_tickets_due(1, 99) == 0)
	q.day_override = 20001
	q.random_seed_fresh = true
	_e("...and the next real day pays again (%d), not in 70 years" % q.random_tickets_due(1, 99), q.random_tickets_due(1, 99) == 5)
	# small differences keep the forward-only rule: a day 1-2 ahead (time zones) is not reset
	q.day_override = 20000
	q.random_pay_day = 20002
	q.random_paid = 5
	_e("a stored day 2 ahead stays capped (clock-back protection)", q.random_tickets_due(1, 98) == 0 and q.random_pay_day == 20002)
	# a hostile day in the save
	var file: ConfigFile = full._write()
	file.set_value("wallet", "random_day", 9223372036854775807)
	file.set_value("wallet", "random_paid", 5)
	var r := _new("clock3")
	r.day_override = 20000
	r._read(file)
	_e("a save with random_day = INT64_MAX reads as today (%d), capped today, paying tomorrow" % r.random_pay_day, r.random_pay_day == 20000 and r.random_tickets_due(1, 7) == 0)
	r.day_override = 20001
	_e("...tomorrow pays (%d)" % r.random_tickets_due(1, 7), r.random_tickets_due(1, 7) > 0)
	for n in [p, q, r]:
		n.free()


## Random sequences of real Progress operations, every state checked and round-tripped through a file and a code.
func _state_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	Hats.available = true
	var bad := 0
	var first := ""
	var rt_bad := 0
	var rt_first := ""
	var ops := 0
	var ids := ["slime", "speed", "brightness"]
	var skin_ids: Array[String] = []
	for sk: Dictionary in Skins.PRESETS:
		skin_ids.append(sk.id)
	skin_ids += [Skins.CUSTOM, Skins.RAINBOW, Skins.STOPWATCH, "bogus"]
	for run in 150:
		var p := _new("state")
		p.saving_enabled = false
		p.day_override = 20000 + rng.randi_range(-5, 5) * 100
		for step in 40:
			ops += 1
			var level := rng.randi_range(1, 10)
			match rng.randi() % 20:
				0: p.collect_coin(level, Vector2i(rng.randi_range(0, 20), rng.randi_range(0, 20)), rng.randf() < 0.1)
				1: p.buy_upgrade(ids[rng.randi() % ids.size()])
				2: p.refund_upgrade(ids[rng.randi() % ids.size()])
				3: p.complete_level(clampi(level, 1, 10), false)
				4: p.record_clear(level, [0.01, 5.5, 33.333333333333, 1e6][rng.randi() % 4], 30.0, false, true)
				5: p.set_hard_mode(rng.randf() < 0.5)
				6: p.complete_random(rng.randf() < 0.2, rng.randi_range(0, 3) * 7, rng.randi_range(0, 9))
				7: p.spin_hat(rng.randf())
				8: p.select_skin(skin_ids[rng.randi() % skin_ids.size()], rng.randf() < 0.5 if rng.randf() < 0.7 else null)
				9: p.select_hat(Hats.ids()[rng.randi() % Hats.ids().size()])
				10: p.set_volume(rng.randf_range(-2.0, 3.0), false)
				11: p.set_binding(p.DEFAULT_KEYS.keys()[rng.randi() % 7], [KEY_W, KEY_A, KEY_SPACE, KEY_F, KEY_ESCAPE, 0, -1, 1 << 30][rng.randi() % 8])
				12: p.add_tickets(rng.randi_range(-100, 5000), false)
				13: p.record_clear(clampi(level, 1, 10), rng.randf_range(0.5, 200.0), rng.randf_range(5.0, 100.0), rng.randf() < 0.2, rng.randf() < 0.7)
				14: p.win_hat(Hats.ids()[rng.randi() % Hats.ids().size()])
				15: p.take_skin_notice(level)
				16: p.reduce_motion = rng.randf() < 0.5
				17: p.fog_brightness = rng.randi_range(p.FOG_DARK, p.FOG_BRIGHT)
				18: p.mark_tutorial_seen(rng.randi_range(1, 3))
				_: p.new_random_maze()
			var why := _insane(p)
			if why != "":
				bad += 1
				if first == "":
					first = "run %d step %d: %s" % [run, step, why]
		# the round trip: file and code both give back exactly this state
		var text: String = _canon(p._write())
		p.saving_enabled = true
		p.save_progress()
		var q := _new_at(p.save_path)
		q.load_progress()
		var r := _new("state_code")
		var code_ok: bool = r.load_code(p.save_code())
		if _canon(q._write()) != text or not code_ok or _canon(r._write()) != text:
			rt_bad += 1
			if rt_first == "":
				rt_first = "run %d: %s" % [run, _first_diff(text, _canon(q._write()))]
		for n in [p, q, r]:
			n.free()
	_e("%d random Progress operations: %d states out of range%s" % [ops, bad, (" first: " + first) if first != "" else ""], bad == 0)
	_e("150 random states survive save file -> load and save code -> load exactly (%d differ)%s" % [rt_bad, (" first: " + rt_first) if rt_first != "" else ""], rt_bad == 0)
	Hats.available = false


## S1: the PoC payload (tests/qa_poc_code_injection.gd --mode=object) and variants, through a pasted code
## (is_old_code / read_code / load_code) AND a save.cfg (load_progress): nothing runs, nothing is created.
func _injection() -> void:
	var marker := "Engine.set_meta(&'qa_pwned', true)"
	var obj := "Object(Node,\"name\":\"x\",\"script\":Object(GDScript,\"script/source\":\"extends Node\\nfunc _init():\\n\\t%s\\n\"))" % marker
	var payloads := {
		"PoC (plain value)": "levels_cleared=" + obj,
		"inside an array": "skin_notices_seen=[1, " + obj + "]",
		"inside a typed array": "hard_cleared=Array[int]([" + obj + "])",
		"Array[Object]": "hard_cleared=Array[Object]([" + obj + "])",
		"inside a dictionary": "x={\"a\": " + obj + "}",
		"as a dictionary key": "x={" + obj + ": 1}",
		"inside Color()": "custom_color=Color(" + obj + ", 1, 1)",
		"spaces before (": "levels_cleared=Object (Node,\"script\":Object (GDScript,\"script/source\":\"%s\"))" % marker,
		"lower case": "levels_cleared=object(Node)",
		"Cyrillic O lookalike": "levels_cleared=Оbject(Node)",
		"fullwidth letters": "levels_cleared=Ｏbject(Node)",
		"after a value on the line": "levels_cleared=1 " + obj,
		"on a continuation line": "levels_cleared=1\n  " + obj,
		"key then newline then value": "levels_cleared=\n" + obj,
		"escaped quote closes nothing": "skin=\"a\\\\\"\nlevels_cleared=" + obj,
		"section tag attribute": "[progress x=" + obj + "]",
		"# line (not a comment for ConfigFile)": "# hi\nlevels_cleared=" + obj,
		"; comment with code": "; x=" + obj,
		"Resource()": "x=Resource(\"res://icon.png\")",
		"Callable()": "x=Callable()",
		"Signal()": "x=Signal()",
		"RID()": "x=RID()",
		"ExtResource()": "x=ExtResource(\"1\")",
		"SubResource()": "x=SubResource(\"1\")",
		"preload()": "x=preload(\"res://scripts/progress.gd\")",
		"load()": "x=load(\"res://scripts/progress.gd\")",
		"StringName &\"\"": "x=&\"Object\"",
		"NodePath ^\"\"": "x=^\"/root\"",
		"Vector2 (not in a save)": "x=Vector2(1, 2)",
		"PackedByteArray (not in a save)": "x=PackedByteArray(1, 2)",
		"Transform3D": "x=Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)",
	}
	var created_before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for label: String in payloads:
		Engine.remove_meta(&"qa_pwned") if Engine.has_meta(&"qa_pwned") else null
		var text: String = "[meta]\nepoch=1\nversion=5\n[progress]\n" + payloads[label] + "\n"
		var code := _code_of(text)
		var old_code: bool = PROGRESS_SCRIPT.is_old_code(code)
		var read: ConfigFile = PROGRESS_SCRIPT.read_code(code)
		var target := _new("inject_code")
		var loaded: bool = target.load_code(code)
		var path := _scratch("inject")
		_store(path, text)
		var p := _new_at(path)
		p.saving_enabled = true
		p.load_progress()
		var ran := Engine.has_meta(&"qa_pwned")
		_e("injection '%s': code refused (%s/%s/%s), save.cfg moved aside, nothing ran" % [label, old_code, read, loaded],
			not ran and not old_code and read == null and not loaded and target.is_fresh_save() and p.is_fresh_save()
			and not FileAccess.file_exists(path) and FileAccess.file_exists(PROGRESS_SCRIPT.corrupt_backup_path(path)))
		target.free()
		p.free()
	# strings that merely CONTAIN those words are data: a valid save with them loads (no false rejects)
	var legit := "[meta]\nepoch=1\nversion=5\n[progress]\nlevels_cleared=2\n[skin]\nselected=\"Object(Node, \\\"script\\\": Object(GDScript))\"\nhat=\"preload(\\\"x\\\") ExtResource Callable Signal RID Script ; # = [ ] { }\"\n[maps]\nhint=\"Оbject( \\\\\"\n"
	var lf: ConfigFile = PROGRESS_SCRIPT.SaveText.parse(legit.to_utf8_buffer())
	_e("words like Object( / preload / ExtResource inside strings are accepted as text", lf != null and str(lf.get_value("skin", "selected")).begins_with("Object(Node") and not Engine.has_meta(&"qa_pwned"))
	var lc: ConfigFile = PROGRESS_SCRIPT.read_code(_code_of(legit))
	_e("...also inside a pasted code (levels_cleared=%s)" % (lc.get_value("progress", "levels_cleared") if lc else "refused"), lc != null)
	_e("no objects leaked by the injection cases (%d -> %d)" % [created_before, Performance.get_monitor(Performance.OBJECT_COUNT)],
		Performance.get_monitor(Performance.OBJECT_COUNT) <= created_before + 8)
	if Engine.has_meta(&"qa_pwned"):
		Engine.remove_meta(&"qa_pwned")


## SaveText unit checks: exact grammar edges.
func _validator() -> void:
	var st: GDScript = PROGRESS_SCRIPT.SaveText
	var good := ["[a]\nk=1\n", "[a]\nk=-1.5e-05\n", "[a]\nk=\"x\\\"y\"\n", "[a]\nk=Array[int]([])\n", "[a]\nk=Array[String]([\"a\", \"b\"])\n",
		"[a]\nk=Color(0.1, 0.2, 0.3, 1)\n", "[a]\nk=[[1, [2, [3]]], \"x\", true, false, null]\n", "[a]\nk={\"x\": 1, 2: [3]}\n",
		"[a]\nk=nan\nj=inf\nl=inf_neg\n", "; a comment\n[a]\nk = 1\n", "[a]\r\nk=1\r\n", "[a]\nk=9223372036854775807\nj=-9223372036854775808\n",
		"[a]\nk=\"multi\nline\"\n", "[a]\nk=[1,\n 2]\n", ""]
	var bad := ["[a]\nk=Array[float]([1.0])\n", "[a]\nk=Array[int]([\"a\"])\n", "[a]\nk=Array[String]([1])\n", "[a]\nk=Color(1, 2)\n", "[a]\nk=Color(1, 0, 0)\n", "[a]\nk=Color(1,2,3,4,5)\n",
		"[a]\nk=Color(\"x\", 1, 1)\n", "[a]\nk=[1,]\n", "[a]\nk=0x10\n", "[a]\nk=1e400\n", "[a]\nk=99999999999999999999\n", "[a]\nk=+5\n", "[a]\nk=.5\n",
		"[a]\nk=\"unterminated\n", "[a]\nk=1 2\n", "[a b]\nk=1\n", "[a]\n\"k\"=1\n", "[a]\nk\n", "[a]\n=1\n", "[a]\nk={[1]: 2}\n", "[a]\nk=Object()\n",
		"[a]\nk=\"x\u0001\"\n", "é=1\n", "[a]\nk=\"\\\n"]
	var wrong := 0
	for text: String in good:
		if not st.is_safe(text.to_utf8_buffer()) or st.parse(text.to_utf8_buffer()) == null:
			wrong += 1
			print("      false reject: " + text.c_escape())
	for text: String in bad:
		if st.is_safe(text.to_utf8_buffer()):
			wrong += 1
			print("      false accept: " + text.c_escape())
	_e("SaveText grammar: %d good texts accepted, %d bad ones refused (%d wrong)" % [good.size(), bad.size(), wrong], wrong == 0)
	var deep := "[a]\nk=" + "[".repeat(8) + "]".repeat(8) + "\n"
	var deeper := "[a]\nk=" + "[".repeat(9) + "]".repeat(9) + "\n"
	_e("nesting depth 8 accepted, 9 refused", st.is_safe(deep.to_utf8_buffer()) and not st.is_safe(deeper.to_utf8_buffer()))
	var invalid_utf8 := PackedByteArray([0x5B, 0x61, 0x5D, 0x0A, 0x6B, 0x3D, 0x22, 0xC3, 0x28, 0x22, 0x0A])
	var nul := "[a]\nk=1".to_utf8_buffer()
	nul.append(0)  # (a NUL byte; never written as a \u0000 escape in a script: Godot's tokenizer complains)
	_e("a NUL byte is refused", not st.is_safe(nul))
	_e("invalid UTF-8 inside a string refused, valid UTF-8 accepted", not st.is_safe(invalid_utf8) and st.is_safe("[a]\nk=\"héllo ☃\"\n".to_utf8_buffer()))


## S11 and size limits: checked BEFORE any parser runs, for a code and for a save.cfg, without crashing.
func _limits() -> void:
	var st: GDScript = PROGRESS_SCRIPT.SaveText
	for depth: int in [200000, 100000, 10000, 9]:
		var text := "[meta]\nepoch=1\n[progress]\nx=" + "[".repeat(depth) + "]".repeat(depth) + "\n"
		var t := Time.get_ticks_msec()
		var code_ok: bool = PROGRESS_SCRIPT.read_code(_code_of(text)) != null or PROGRESS_SCRIPT.is_old_code(_code_of(text))
		var path := _scratch("nest")
		_store(path, text)
		var p := _new_at(path)
		p.saving_enabled = true
		p.load_progress()
		_e("%d nested '[' (%d KB): code refused, save.cfg refused and moved aside, no crash, %d ms" % [depth, text.length() / 1024, Time.get_ticks_msec() - t],
			not code_ok and p.is_fresh_save() and FileAccess.file_exists(PROGRESS_SCRIPT.corrupt_backup_path(path)))
		p.free()
	var big := "[meta]\nepoch=1\n[progress]\nlevels_cleared=1\nx=\"" + "y".repeat(st.MAX_BYTES) + "\"\n"
	_e("a save text over %d KB is refused" % (st.MAX_BYTES / 1024), not st.is_safe(big.to_utf8_buffer()) and PROGRESS_SCRIPT.read_code(_code_of(big)) == null)
	var long_line := "[a]\nk=\"" + "y".repeat(st.MAX_LINE + 1) + "\"\n"
	_e("a line over %d KB is refused" % (st.MAX_LINE / 1024), not st.is_safe(long_line.to_utf8_buffer()))
	# the gzip size field can't make it allocate more than MAX_BYTES (a zip bomb inflates into a fixed buffer)
	var bomb := "A".repeat(4 << 20).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var t2 := Time.get_ticks_msec()
	var bomb_read: ConfigFile = PROGRESS_SCRIPT.read_code(PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(bomb))
	_e("a 4 MB zip bomb code is refused in %d ms" % (Time.get_ticks_msec() - t2), bomb_read == null)


## S10: the PoC inputs of tests/qa_poc_gzip_hang.gd (a gzip stream + 1..8 extra bytes), a code pasted twice,
## stray characters after it: every check returns at once (the old decompress_dynamic spun forever).
func _gzip() -> void:
	var gz := "[meta]\nepoch=1\n[progress]\nlevels_cleared=3\n".to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	var slowest := 0
	var all_ok := true
	for extra in 9:
		var bytes := gz.duplicate()
		for i in extra:
			bytes.append(0)
		while bytes.size() % 3 != 0:
			bytes.append(0)
		var code: String = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(bytes)
		var t := Time.get_ticks_msec()
		var old: bool = PROGRESS_SCRIPT.is_old_code(code)
		var read: ConfigFile = PROGRESS_SCRIPT.read_code(code)
		slowest = maxi(slowest, Time.get_ticks_msec() - t)
		var expect_ok := bytes.size() == gz.size()
		if old or (read != null) != expect_ok:
			all_ok = false
	_e("gzip + 0..8 trailing bytes (PoC): returns in %d ms max, only the exact stream reads" % slowest, all_ok and slowest < 500)
	var good: String = full.save_code()
	var t3 := Time.get_ticks_msec()
	var twice: ConfigFile = PROGRESS_SCRIPT.read_code(good + good.trim_prefix(PROGRESS_SCRIPT.SAVE_CODE_PREFIX))
	var stray: ConfigFile = PROGRESS_SCRIPT.read_code(good + "AAAA")
	PROGRESS_SCRIPT.is_old_code(good + "AAAAAAAA")
	_e("a code pasted twice / with stray AAAA after it returns at once (%d ms; twice %s, stray %s)" % [Time.get_ticks_msec() - t3, "reads" if twice else "refused", "reads" if stray else "refused"],
		Time.get_ticks_msec() - t3 < 500 and stray == null)
	# base64 stage: oversize and broken base64 are refused before decoding
	_e("base64 stage: 70,000 chars / bad padding / bad characters refused",
		PROGRESS_SCRIPT.read_code(PROGRESS_SCRIPT.SAVE_CODE_PREFIX + "A".repeat(70000)) == null and PROGRESS_SCRIPT.read_code(good + "=") == null
		and PROGRESS_SCRIPT.read_code(good.insert(20, "*")) == null)
	# mangled by a chat app: invisible / wrapping characters are cleaned off
	var mangled := [" " + good, good.insert(40, "​"), good + ".", "\"" + good + "\"", "“" + good + "”", "```\n" + good + "\n```", "﻿" + good]
	var all_read := true
	for m: String in mangled:
		all_read = all_read and PROGRESS_SCRIPT.read_code(m) != null
	_e("codes with NBSP / zero-width / quotes / code fence / trailing period / BOM still load", all_read)


## A fully populated save (every section: story complete on both modes, every coin, maps, records, medals,
## hats, custom color, upgrades, wallet) passes the allow-list and round-trips exactly as a file and a code.
func _full_round_trip() -> void:
	Hats.available = true
	var p := _new("full")
	p.enable_story_complete()
	p.hats_owned.assign(Hats.ids().slice(0, 4))
	p.selected_hat = p.hats_owned[0]
	p.custom_color = Color(0.123, 0.456, 0.789, 1.0)
	p.upgrades = {"slime": 4, "speed": 2, "brightness": 1}
	p.tickets = 1234
	p.tickets_lifetime = 5678
	p.random_pay_day = 20000
	p.random_paid = 3
	p.random_paid_seeds.assign([7, 8, 9])
	p.spins = 5
	p.rainbow_pity = 2
	p.maps_hint_seen = true
	p.volume = 0.35
	p.reduce_motion = true
	p.fog_brightness = p.FOG_BRIGHT
	p.set_binding("jump", KEY_J)
	for key: int in p.best_times:  # binary-exact times: Godot's own float text round trip can be 1 ulp off
		p.best_times[key] = snappedf(p.best_times[key], 0.25)
	var text: String = p._write().encode_to_text()
	var st: GDScript = PROGRESS_SCRIPT.SaveText
	_e("a fully populated save (%d bytes, %d map surveys) passes the allow-list" % [text.length(), p.maps.size()], st.is_safe(text.to_utf8_buffer()) and p.maps.size() == 20)
	p.saving_enabled = true
	p.save_progress()
	var q := _new_at(p.save_path)
	q.day_override = 20000
	q.load_progress()
	var r := _new("full_code")
	r.day_override = 20000
	var code_ok: bool = r.load_code(p.save_code())
	_e("...and round-trips exactly through save.cfg and a save code (%s / %s)" % [_first_diff(_canon(p._write()), _canon(q._write())), _first_diff(_canon(p._write()), _canon(r._write()))],
		_canon(q._write()) == _canon(p._write()) and code_ok and _canon(r._write()) == _canon(p._write()))
	for n in [p, q, r]:
		n.free()
	Hats.available = false


func _code_of(text: String) -> String:
	return PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))


func _store(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _load_levels(path: String) -> int:
	var f: ConfigFile = PROGRESS_SCRIPT.SaveText.parse(FileAccess.get_file_as_bytes(path))
	return f.get_value("progress", "levels_cleared", -1) if f else -1


# ------------------------------------------------------------------ code fuzz

func _code_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261015
	var good: String = full.save_code()
	var body := good.trim_prefix(PROGRESS_SCRIPT.SAVE_CODE_PREFIX)
	var raw := Marshalls.base64_to_raw(body)
	var target := _new("fuzz_target")
	target.levels_cleared = 2
	target.tickets = 7
	var snapshot: String = target._write().encode_to_text()
	var errs := errlog.count
	var loaded := 0
	var decoded_wrong := 0
	var typo_loaded := 0
	var typo_example := ""
	var full_text: String = full._write().encode_to_text()
	var changed := 0
	var slowest := 0
	var t0 := Time.get_ticks_msec()
	var b64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	var prefixes := ["", "SLIME1-", "SLIME2-", "SLIME3-", "slime2-", "SLIME2_", "SLIME2 -", "SLIME22-", "SLIME-2-", "SLIME2-SLIME2-", "﻿SLIME2-",
		"SLIME２-", "SLIME2–", "SLIME2:", " SLIME2- ", "​SLIME2-", "SLIME-", "SLIME", "-", "S"]
	for i in 20000:
		var code := ""
		match i % 10:
			0:  # valid code, one base64 char flipped to another valid char
				var chars := good.to_utf8_buffer()
				var at := rng.randi_range(PROGRESS_SCRIPT.SAVE_CODE_PREFIX.length(), chars.size() - 1)
				chars[at] = b64.unicode_at(rng.randi() % 64)
				code = chars.get_string_from_utf8()
			1:  # valid gzip with raw bytes flipped, re-encoded (valid base64, bad CRC / stream)
				var r := raw.duplicate()
				for k in rng.randi_range(1, 6):
					r[rng.randi() % r.size()] ^= 1 << (rng.randi() % 8)
				code = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(r)
			2:  # prefix variants over a good body
				code = prefixes[rng.randi() % prefixes.size()] + body
			3:  # truncated / extended
				code = good.substr(0, rng.randi_range(0, good.length()))  # (NOT good + extra: gzip + trailing bytes HANGS decompress_dynamic, see qa_poc_gzip_hang.gd)
			4:  # oversized
				code = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + body.repeat(rng.randi_range(int(70000 / body.length()) + 1, 300)) if rng.randf() < 0.5 else "A".repeat(rng.randi_range(60000, 200000))
			5:  # unicode soup
				var s := PROGRESS_SCRIPT.SAVE_CODE_PREFIX if rng.randf() < 0.5 else ""
				for _c in rng.randi_range(0, 120):
					s += char([rng.randi_range(1, 0x2FFF), rng.randi_range(0x1F300, 0x1FAFF), rng.randi_range(0x200B, 0x200F), 0x202E, 0xFFFD, 0x3000][rng.randi() % 6])
				code = s
			6:  # whitespace / control chars sprinkled into a good code
				var s2 := good
				for _c in rng.randi_range(1, 10):
					var at2 := rng.randi_range(0, s2.length())
					s2 = s2.insert(at2, [" ", "\n", "\t", "\r\n", " ", " ", "​", "\u0001", "\u0002", "\u007f"][rng.randi() % 10])
				code = s2
			7:  # gzip of structured junk under the right prefix
				var junk: String = ["[meta]\nepoch=1\n[progress]\n", "[meta]\nepoch=1", "[progress]\nlevels_cleared=99999999999999999999\n", "[meta]\nepoch=1\n[progress]\nlevels_cleared=-9\n[wallet]\nglobs=nan\n",
					"\u0001\u0002", "[meta]\nepoch=1\n[progress]\nx=\"" + "y".repeat(rng.randi_range(0, 5000)) + "\"\n", "[meta\nepoch=1\n[progress]\n"][rng.randi() % 7]
				code = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(junk.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP))
			8:  # random base64 under good prefix / compression modes other than gzip
				var rb := PackedByteArray()
				rb.resize(rng.randi_range(1, 600))
				for k in rb.size():
					rb[k] = rng.randi() & 0xFF
				code = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(rb)
			_:  # a good body compressed with another mode (deflate / zstd / fastlz) or zlib-bomb-ish repetition
				var mode: int = [FileAccess.COMPRESSION_DEFLATE, FileAccess.COMPRESSION_ZSTD, FileAccess.COMPRESSION_FASTLZ][rng.randi() % 3]
				var txt := "[meta]\nepoch=1\n[progress]\nlevels_cleared=3\n" if rng.randf() < 0.5 else "A".repeat(1 << rng.randi_range(10, 22))
				code = PROGRESS_SCRIPT.SAVE_CODE_PREFIX + Marshalls.raw_to_base64(txt.to_utf8_buffer().compress(mode))
		if trace:
			print("#%d v%d len=%d" % [i, i % 10, code.length()])
		var t := Time.get_ticks_msec()
		PROGRESS_SCRIPT.is_old_code(code)
		var ok: bool = target.load_code(code)
		slowest = maxi(slowest, Time.get_ticks_msec() - t)
		if ok:
			loaded += 1
			var now_text: String = target._write().encode_to_text()
			var cleaned := code.strip_edges().replace(" ", "").replace("\n", "").replace("\r", "").replace("\t", "")
			if i % 10 == 7 and "epoch=1" in code:
				pass  # structured junk that legitimately is a (mostly empty) save
			elif now_text != full_text and not (cleaned == good):
				# a corrupted code that still decodes to a DIFFERENT valid save: gzip's CRC is not checked
				decoded_wrong += 1
				if i % 10 == 0:
					typo_loaded += 1
					if typo_example == "":
						typo_example = _first_diff(full_text, now_text)
			target._read(_parse(snapshot))
			continue
		if target._write().encode_to_text() != snapshot:
			changed += 1
			target._read(_parse(snapshot))
	_e("20,000 mutated codes: %d loaded (only valid ones), %d partially applied, slowest %d ms, total %d ms" % [loaded, changed, slowest, Time.get_ticks_msec() - t0], changed == 0 and slowest < 3000)
	print("  info %d codes loaded; %d multi-bit-flipped codes decoded to a DIFFERENT valid save (gzip CRC is not verified; harmless for copy/paste, noted as S7)" % [loaded, decoded_wrong - typo_loaded])
	_e("a code with ONE mistyped character is never loaded as a different save (%d of ~2000 single-char typos loaded)" % typo_loaded, typo_loaded == 0)
	_e("code fuzz engine errors: %d" % (errlog.count - errs), errlog.count == errs)
	# UX: pasted text that a chat app or web page mangled
	for label: String in ["non-breaking space", "zero-width space", "trailing period", "wrapped in quotes", "curly quotes", "in a markdown code fence"]:
		var mangled: String = {"non-breaking space": good.insert(40, " "), "zero-width space": good.insert(40, "​"), "trailing period": good + ".",
			"wrapped in quotes": "\"" + good + "\"", "curly quotes": "“" + good + "”", "in a markdown code fence": "```\n" + good + "\n```"}[label]
		var res := PROGRESS_SCRIPT.read_code(mangled) != null
		print("  info a code %s: %s" % [label, "loads" if res else "refused (THAT CODE DOESN'T WORK)"])
	_e("a code split over lines / padded with spaces still loads", PROGRESS_SCRIPT.read_code("  " + good.insert(30, "\n").insert(70, " ") + " \r\n") != null)
	target.free()


## A save as sorted "section/key=value" lines (ConfigFile text depends on dictionary insertion order).
func _canon(file: ConfigFile) -> String:
	var lines: Array[String] = []
	for section in file.get_sections():
		for key in file.get_section_keys(section):
			lines.append("%s/%s=%s" % [section, key, var_to_str(file.get_value(section, key))])
	lines.sort()
	return "\n".join(lines)


func _first_diff(a: String, b: String) -> String:
	var la := a.split("\n")
	var lb := b.split("\n")
	var out: Array[String] = []
	for line in la:
		if not line in lb:
			out.append("-" + line.left(60))
	for line in lb:
		if not line in la:
			out.append("+" + line.left(60))
	return " ".join(out.slice(0, 4))


func _parse(text: String) -> ConfigFile:
	var f := ConfigFile.new()
	f.parse(text)
	return f


# ------------------------------------------------------------------ invariants / helpers

## "" if the loaded state is inside every documented range, else what is wrong.
func _insane(p: Node) -> String:
	var bad: Array[String] = []
	if p.levels_cleared < 0 or p.levels_cleared > Levels.COUNT: bad.append("levels_cleared %d" % p.levels_cleared)
	if p.highest_unlocked < 1 or p.highest_unlocked > Levels.COUNT: bad.append("highest_unlocked %d" % p.highest_unlocked)
	if p.current_level < 1 or p.current_level > p.highest_unlocked: bad.append("current_level %d" % p.current_level)
	if p.tickets < 0 or p.tickets > p.TICKETS_MAX: bad.append("tickets %d" % p.tickets)
	if p.tickets_lifetime < 0: bad.append("tickets_lifetime %d" % p.tickets_lifetime)
	if p.volume < 0.0 or p.volume > 1.0 or is_nan(p.volume): bad.append("volume %s" % p.volume)
	if p.fog_brightness < p.FOG_DARK or p.fog_brightness > p.FOG_BRIGHT: bad.append("fog %d" % p.fog_brightness)
	if p.spins < 0 or p.spins > p.SPINS_MAX: bad.append("spins %d" % p.spins)
	if p.random_paid < 0 or p.random_paid > p.RANDOM_PAID_PER_DAY: bad.append("random_paid %d" % p.random_paid)
	if p.random_paid_seeds.size() > p.PAID_SEEDS_MAX: bad.append("paid seeds %d" % p.random_paid_seeds.size())
	for k: int in p.best_times:
		if not is_finite(p.best_times[k]): bad.append("best_time non-finite")
	for k: int in p.medals:
		if p.medals[k] < 1 or p.medals[k] > 3: bad.append("medal %d" % p.medals[k])
	if p.coins() < 0: bad.append("negative coins %d" % p.coins())
	for id: String in p.upgrades:
		if p.upgrades[id] < 1 or p.upgrades[id] > Upgrades.max_level(id): bad.append("upgrade %s=%d" % [id, p.upgrades[id]])
	if p.spin_cost() < 0 or p.spin_cost() > p.SPIN_COST_MAX: bad.append("spin_cost %d" % p.spin_cost())
	if not p.is_skin_unlocked(p.selected_skin): bad.append("locked skin selected %s" % p.selected_skin)
	if p.selected_hat != Hats.NONE and not p.is_hat_unlocked(p.selected_hat): bad.append("locked hat %s" % p.selected_hat)
	# it must be writable and codeable again, and the code must round trip to the same save
	var written: String = p._write().encode_to_text()
	var again := ConfigFile.new()
	if again.parse(written) != OK:
		bad.append("own save does not parse")
	var code: String = p.save_code()
	var back: ConfigFile = PROGRESS_SCRIPT.read_code(code)
	if back == null:
		bad.append("own code does not read")
	else:
		var q := _new("rt")
		q._read(back)
		if _canon(q._write()) != _canon(p._write()):
			bad.append("save -> code -> save is not stable: " + _first_diff(_canon(p._write()), _canon(q._write())))
		q.free()
	return "; ".join(bad)


## Whether process `pid` exists (kill -0; OS.is_process_running only knows our own children and logs an engine error for
## any other pid). Without a `kill` command (Windows) every other pid counts as alive: nothing of other runs is deleted.
func _pid_alive(pid: int) -> bool:
	if pid == OS.get_process_id():
		return true
	if OS.get_name() not in ["macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		return true
	return OS.execute("kill", ["-0", str(pid)], []) == 0


func _new(tag: String) -> Node:
	return _new_at(_scratch(tag))


func _new_at(path: String) -> Node:
	var p: Node = PROGRESS_SCRIPT.new()
	p.save_path = path
	p.saving_enabled = false
	return p


func _scratch(tag: String) -> String:
	var path := "user://qa_robust_%d_%s_%d.cfg" % [OS.get_process_id(), tag, scratch.size() % 5000]
	scratch.append(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return path


func _random_bytes(rng: RandomNumberGenerator, n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	for i in n:
		b[i] = rng.randi() & 0xFF
	return b


func _unique(values: Array) -> int:
	var seen := {}
	for v: Variant in values:
		seen[v] = true
	return seen.size()


func _many_strings(n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append("c%d" % i)
	return a


## Registers a known open bug; returns true so the check using `or _known(...)` is reported, not failed.
func _known(text: String) -> bool:
	known.append(text)
	return not strict


func _e(label: String, ok: bool) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
