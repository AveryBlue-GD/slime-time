extends SceneTree

## Release hardening (docs/qa-release-report.md X2): debug / dev launch flags only work in a debug build (the editor
## binary that tools/play.sh, screenshot.sh and test_all.sh run, or a debug export). An exported RELEASE build
## ignores them all except the UI-layout previews --touch and --web-ui (Progress.game_args / user_args), and a
## release launch with ignored flags is a normal player launch (real save, no throwaway).
## The exported release binary itself is checked by hand (docs/itch-release.md "Release build checks").
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_release_flags.gd

const PROGRESS_SCRIPT := preload("res://scripts/progress.gd")

const DEBUG_FLAGS := ["--unlock-all", "--dev", "--story-complete", "--autoplay", "--autoplay-cinematics", "--autoplay-quit",
	"--speed=8", "--maps=full", "--tickets=99", "--medals=3,3,3", "--upgrades=1,2,3", "--coins=50", "--skin=rainbow",
	"--hat=crown", "--level=10", "--random", "--hard", "--jelly", "--all-coins", "--save-path=user://x.cfg", "--quiet-window"]

var failures := 0


func _initialize() -> void:
	await process_frame
	var all := PackedStringArray(DEBUG_FLAGS + ["--touch", "--web-ui"])
	_check(PROGRESS_SCRIPT.game_args(all, true) == all, "a debug build honors every flag")
	var release: PackedStringArray = PROGRESS_SCRIPT.game_args(all, false)
	_check(release == PackedStringArray(["--touch", "--web-ui"]), "a release build keeps only --touch and --web-ui (%s)" % [release])
	for flag: String in DEBUG_FLAGS:
		_check(not flag in PROGRESS_SCRIPT.game_args(PackedStringArray([flag]), false), "release ignores %s" % flag)
	_check(PROGRESS_SCRIPT.game_args(PackedStringArray(), false).is_empty(), "no flags: nothing")
	# this test runs on the editor binary: a debug build, so the repo's tools keep all their flags
	_check(OS.is_debug_build(), "the editor / test binary is a debug build")
	_check(PROGRESS_SCRIPT.user_args() == OS.get_cmdline_user_args(), "in this debug run user_args() is every flag after --")
	# the game reads flags only through user_args() (a flag read straight from OS would bypass the gate)
	var direct := []
	for path: String in _scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(path)
		if text.contains("OS.get_cmdline_user_args()") and not path.ends_with("progress.gd") and not path.ends_with("dev_log.gd") \
				and not path.ends_with("autoplay/autoplay.gd"):
			direct.append(path)
	_check(direct.is_empty(), "no game script reads OS.get_cmdline_user_args() directly (%s)" % [direct])
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out


func _check(ok: bool, label: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + label)
	if not ok:
		failures += 1
