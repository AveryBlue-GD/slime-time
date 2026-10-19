extends SceneTree

## The demo export's cut list (docs/demo-plan.md), from Demo.full_only_paths() / Demo.export_cut().
##   godot --path . --headless -s res://tools/demo_paths.gd [-- --web] [-- --seeds]
##     one res:// path per line (Demo.full_only_paths), then `EXCLUDE: ...` = Demo.export_cut, comma-joined.
##     `--web`: the web demo's list (Demo.WEB_LEVELS). `--seeds`: also lists randomizer seed candidates for
##     Demo.RANDOM_SEEDS (a middling usage, and the demo theme each would get).
##   ... -- --write-presets   rebuilds the demo presets in export_presets.cfg from their full twins
##                            (tools/demo_export.gd; the full presets are left byte-identical)
##   ... -- --check-presets   exit 1 if export_presets.cfg's demo presets are out of date
##   ... -- --cut-list=FILE   writes Demo.export_cut() for desktop and web (`desktop|web <tab> path` per
##                            line) for tools/pck_check.py (tools/build_demo.*)

const DemoExport := preload("res://tools/demo_export.gd")


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if "--write-presets" in args or "--check-presets" in args:
		quit(_presets("--write-presets" in args))
		return
	for arg in args:
		if arg.begins_with("--cut-list="):
			quit(_cut_list(arg.trim_prefix("--cut-list=")))
			return
	var paths := Demo.full_only_paths("--web" in args)
	for path in paths:
		print(path)
	var cut := Demo.export_cut("--web" in args)
	print("EXCLUDE: " + ", ".join(Array(cut).map(func(p: String) -> String: return p.trim_prefix("res://"))))
	if "--seeds" in args:
		Platform.demo_override = 1
		for s in range(1000, 1200):
			var u := Levels.random_usage_permille(s)
			if u >= 480 and u <= 640:
				print("seed %d usage %d theme %s" % [s, u, Themes.for_seed(s)])
	quit()


func _presets(write: bool) -> int:
	var errors: Array[String] = []
	var expected := DemoExport.expected_text(errors)
	if not errors.is_empty():
		for e in errors:
			printerr("demo presets: " + e)
		return 1
	if expected == DemoExport.current_text():
		print("demo presets: up to date")
		return 0
	if not write:
		printerr("demo presets: OUT OF DATE - run: godot --path . --headless -s res://tools/demo_paths.gd -- --write-presets")
		return 1
	var file := FileAccess.open(DemoExport.PRESETS_PATH, FileAccess.WRITE)
	if file == null:
		printerr("demo presets: can't write " + DemoExport.PRESETS_PATH)
		return 1
	file.store_string(expected)
	file.close()
	print("demo presets: written (%s)" % ", ".join(DemoExport.DEMOS.map(func(d: Dictionary) -> String: return d.name)))
	return 0


func _cut_list(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("can't write " + path)
		return 1
	for web in [false, true]:
		for p in Demo.export_cut(web):
			file.store_line("%s\t%s" % ["web" if web else "desktop", p])
	file.close()
	return 0
