extends SceneTree

## The demo export's exclude list (docs/demo-plan.md), from Demo.full_only_paths(): one res:// path per
## line, then a comma-joined line ready for an export preset's exclude_filter.
##   godot --path . --headless -s res://tools/demo_paths.gd [-- --web] [-- --seeds]
## `--web`: the web demo's list (Demo.WEB_LEVELS). `--seeds`: also lists randomizer seed candidates for
## Demo.RANDOM_SEEDS (a middling usage, and the demo theme each would get).


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var paths := Demo.full_only_paths("--web" in args)
	for path in paths:
		print(path)
	print("EXCLUDE: " + ", ".join(Array(paths).map(func(p: String) -> String: return p.trim_prefix("res://"))))
	if "--seeds" in args:
		Platform.demo_override = 1
		for s in range(1000, 1200):
			var u := Levels.random_usage_permille(s)
			if u >= 480 and u <= 640:
				print("seed %d usage %d theme %s" % [s, u, Themes.for_seed(s)])
	quit()
