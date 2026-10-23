extends "res://tests/suite_base.gd"

## The demo EXPORT presets (docs/demo-plan.md "Shipping the demo", tools/demo_export.gd), without exporting:
## 1. export_presets.cfg is up to date: each demo preset equals what `tools/demo_paths.gd --write-presets`
##    builds from its full twin and Demo.export_cut() (so a new level / theme past the demo, or a changed
##    demo knob, fails here until the presets are regenerated);
## 2. the demo presets: the `demo` feature, output under build/demo/ (the web one an index.html for itch),
##    the twin's options but for the listed overrides, the twin's excludes kept; the full presets carry
##    no `demo` feature and none of the cut paths;
## 3. the cut list: every path exists in the repo (no typos), none is a file the demo itself plays
##    (its levels' data, its themes' art and ambience), web and desktop follow their own levels();
## 4. the generator: on a made-up presets file it adds the demo presets after the full ones, leaves the
##    full ones byte-identical, keeps a demo preset's index, drops a stale cut path, and is idempotent;
##    a missing twin is reported.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_demo_export.gd

const DemoExport := preload("res://tools/demo_export.gd")


func _initialize() -> void:
	await process_frame
	_check_up_to_date()
	_check_presets()
	_check_cut_list()
	_check_generator()
	_result()
	quit(0 if failures == 0 else 1)


# ---------------------------------------------------------------- 1. up to date

func _check_up_to_date() -> void:
	var errors: Array[String] = []
	var expected := DemoExport.expected_text(errors)
	_check(errors.is_empty(), "the demo presets can be built from their twins (%s)" % [errors])
	_check(expected != "" and expected == DemoExport.current_text(),
		"export_presets.cfg's demo presets are up to date (if not: godot --path . --headless -s res://tools/demo_paths.gd -- --write-presets)")


# ---------------------------------------------------------------- 2. the presets

func _presets() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(DemoExport.PRESETS_PATH)
	var out := {}
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			out[str(cfg.get_value(section, "name"))] = section
	return {cfg = cfg, by_name = out}


func _check_presets() -> void:
	var p := _presets()
	var cfg: ConfigFile = p.cfg
	var by_name: Dictionary = p.by_name
	for entry: Dictionary in DemoExport.DEMOS:
		var name: String = entry.name
		_check(by_name.has(name), "preset \"%s\" exists" % name)
		if not by_name.has(name) or not by_name.has(entry.twin):
			continue
		var demo: String = by_name[name]
		var twin: String = by_name[entry.twin]
		var features := str(cfg.get_value(demo, "custom_features")).split(",", false)
		_check("demo" in features, "%s: custom feature `demo` (Platform.is_demo)" % name)
		var path := str(cfg.get_value(demo, "export_path"))
		_check(path.begins_with("build/demo/") and path == entry.path, "%s: exports to %s" % [name, path])
		_check(cfg.get_value(demo, "platform") == cfg.get_value(twin, "platform"), "%s: same platform as %s" % [name, entry.twin])
		var steam: bool = entry.get("steam", false)
		_check(("steam" in features) == steam, "%s: custom feature `steam` %s" % [name, "on" if steam else "off"])
		var filter := str(cfg.get_value(demo, "exclude_filter"))
		var twin_filter := DemoExport.base_filter(str(cfg.get_value(twin, "exclude_filter")), steam)
		_check(filter.begins_with(twin_filter + ", "), "%s: keeps %s's excludes (%s)" % [name, entry.twin, twin_filter])
		_check((DemoExport.STEAM_ADDON in filter) != steam, "%s: GodotSteam %s" % [name, "shipped" if steam else "excluded"])
		var cut := Demo.export_cut(entry.web)
		var listed := filter.split(",", false)
		for i in listed.size():
			listed[i] = "res://" + listed[i].strip_edges()
		var missing: Array[String] = []
		for c in cut:
			if not c in listed:
				missing.append(c)
		_check(missing.is_empty(), "%s: excludes all %d cut paths (missing %s)" % [name, cut.size(), missing])
		var same := true
		for key in cfg.get_section_keys(twin + ".options"):
			var want: Variant = entry.options.get(key, cfg.get_value(twin + ".options", key))
			if cfg.get_value(demo + ".options", key) != want:
				same = false
				print("    %s: option %s = %s, expected %s" % [name, key, cfg.get_value(demo + ".options", key), want])
		_check(same and cfg.get_section_keys(demo + ".options").size() == cfg.get_section_keys(twin + ".options").size(),
			"%s: the same options as %s (but %s)" % [name, entry.twin, entry.options.keys()])
		for key in ["script_export_mode", "export_filter", "include_filter", "encrypt_pck", "runnable"]:
			_check(cfg.get_value(demo, key) == cfg.get_value(twin, key), "%s: %s as in %s" % [name, key, entry.twin])
	_check(str(cfg.get_value(by_name.get("Web Demo", ""), "export_path", "")).ends_with("/index.html"),
		"the web demo exports an index.html (what itch serves)")
	for entry: Dictionary in DemoExport.STEAM:
		var name: String = entry.name
		_check(by_name.has(name) and by_name.has(entry.twin), "Steam preset \"%s\" exists" % name)
		if not by_name.has(name) or not by_name.has(entry.twin):
			continue
		var section: String = by_name[name]
		var twin: String = by_name[entry.twin]
		_check(str(cfg.get_value(section, "custom_features")).split(",", false) == PackedStringArray(["steam"]),
			"%s: custom feature `steam` only (Platform.is_steam)" % name)
		_check(str(cfg.get_value(section, "export_path")) == entry.path and entry.path.begins_with("build/steam/"), "%s: exports to %s" % [name, entry.path])
		_check(cfg.get_value(section, "platform") == cfg.get_value(twin, "platform"), "%s: same platform as %s" % [name, entry.twin])
		_check(str(cfg.get_value(section, "exclude_filter")) == DemoExport.base_filter(str(cfg.get_value(twin, "exclude_filter")), true)
			and not DemoExport.STEAM_ADDON in str(cfg.get_value(section, "exclude_filter")), "%s: %s's excludes but ships GodotSteam" % [name, entry.twin])
	var all_cut := Demo.export_cut(false) + Demo.export_cut(true)
	for name: String in by_name:
		if not DemoExport.spec(name).is_empty():
			continue
		if DemoExport.steam_spec(name).is_empty():
			_check(DemoExport.STEAM_ADDON in str(cfg.get_value(by_name[name], "exclude_filter")), "full preset %s: excludes GodotSteam" % name)
		var section: String = by_name[name]
		_check(not "demo" in str(cfg.get_value(section, "custom_features")).split(",", false), "full preset %s: no `demo` feature" % name)
		var filter := str(cfg.get_value(section, "exclude_filter"))
		var hit := ""
		for c in all_cut:
			if c.trim_prefix("res://") in filter:
				hit = c
		_check(hit == "", "full preset %s: cuts no demo path (%s)" % [name, hit])


# ---------------------------------------------------------------- 3. the cut list

func _check_cut_list() -> void:
	for web in [false, true]:
		var label := "web" if web else "desktop"
		var cut := Demo.export_cut(web)
		var absent: Array[String] = []
		for path in cut:
			if not FileAccess.file_exists(path):
				absent.append(path)
		_check(absent.is_empty(), "%s cut list: every path exists in the repo (%d paths; absent %s)" % [label, cut.size(), absent])
		var count := Demo.WEB_LEVELS if web else Demo.LEVELS
		var kept_needed: Array[String] = []
		for level in range(1, count + 1):
			kept_needed.append(Levels.data_path(level))
			var theme := Themes.for_level(level)
			for kind in ["walls", "floors", "fillets", "border"]:
				kept_needed.append(Themes.atlas_path(theme, kind))
			kept_needed.append("res://assets/sounds/ambient_%s.wav" % theme)
		for level in range(1, mini(Demo.HARD_LEVELS, count) + 1):
			kept_needed.append(Levels.data_path(level, true))
		kept_needed.append(Demo.END_SCENE)
		var wrongly: Array[String] = []
		for path in kept_needed:
			if path in cut:
				wrongly.append(path)
		_check(wrongly.is_empty(), "%s cut list keeps what the demo plays (levels 1-%d, their themes, the end screen) (%s)" % [label, count, wrongly])
		_check(Levels.data_path(count + 1) in cut and Levels.data_path(Levels.COUNT) in cut,
			"%s cut list: level %d .. %d data cut" % [label, count + 1, Levels.COUNT])
		for path in Demo.FULL_ONLY_FILES:
			_check(path in cut, "%s cut list: %s" % [label, path.get_file()])
		_check(Economy.LANGUAGES_TEST or Language.CATALOGS.all(func(c: String) -> bool: return c in cut),
			"%s cut list: the catalogs while the languages gate is off" % label)
	for path in Demo.FULL_ONLY_FILES:
		_check(FileAccess.file_exists(path), "FULL_ONLY_FILES: %s exists" % path)


# ---------------------------------------------------------------- 4. the generator

const SAMPLE := """[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
custom_features=""
exclude_filter="tests/*, tools/*"
export_path="build/windows/DryTrying.exe"

[preset.0.options]

binary_format/embed_pck=true
application/product_name="Dry Trying"

[preset.1]

name="Web"
platform="Web"
custom_features="mobile_ui"
exclude_filter="tests/*"
export_path="build/web/index.html"

[preset.1.options]

html/export_icon=true
"""


func _check_generator() -> void:
	var cfg := ConfigFile.new()
	cfg.parse(SAMPLE)
	var errors: Array[String] = []
	var built := DemoExport.build(cfg, errors)
	_check(errors.size() == 7 and errors.all(func(e: String) -> bool: return "\"macOS\"" in e or "\"Linux\"" in e or "\"iOS\"" in e),
		"a missing twin is reported (%s)" % [errors])
	var sections := built.get_sections()
	_check(sections.slice(0, 4) == PackedStringArray(["preset.0", "preset.0.options", "preset.1", "preset.1.options"]),
		"the full presets stay first, in order (%s)" % [sections])
	for section in ["preset.0", "preset.0.options", "preset.1", "preset.1.options"]:
		var same := true
		for key in cfg.get_section_keys(section):
			same = same and built.get_value(section, key) == cfg.get_value(section, key)
		_check(same and built.get_section_keys(section).size() == cfg.get_section_keys(section).size(), "%s untouched" % section)
	_check(built.get_value("preset.2", "name") == "Windows Demo" and built.get_value("preset.3", "name") == "Web Demo",
		"the demo presets are appended (preset.2 Windows Demo, preset.3 Web Demo)")
	_check(built.get_value("preset.3", "custom_features") == "mobile_ui,demo", "a twin's own features are kept, `demo` added")
	_check(built.get_value("preset.4", "name") == "Windows Steam Demo" and built.get_value("preset.4", "custom_features") == "steam,demo"
		and built.get_value("preset.5", "name") == "Windows Steam" and built.get_value("preset.5", "custom_features") == "steam",
		"then the Steam demo (steam,demo) and the Steam full game (steam)")
	_check(built.get_value("preset.5", "exclude_filter") == "tests/*, tools/*", "the Steam full preset: the twin's excludes, no cut")
	_check(built.get_value("preset.2.options", "application/product_name") == "Dry Trying Demo"
		and built.get_value("preset.2.options", "binary_format/embed_pck") == true, "options: the twin's, plus the demo's overrides")
	_check(str(built.get_value("preset.2", "exclude_filter")) == DemoExport.exclude_filter("tests/*, tools/*", false),
		"exclude_filter = the twin's + the cut list")
	# A stale demo preset (an old cut path, edited options) is rebuilt in place, at its index.
	built.set_value("preset.2", "exclude_filter", "tests/*, scripts/level_data/level_02.gd")
	built.set_value("preset.2.options", "application/product_name", "edited")
	var again := DemoExport.build(built)
	_check(again.get_value("preset.2", "name") == "Windows Demo" and again.get_value("preset.2", "exclude_filter") == DemoExport.exclude_filter("tests/*, tools/*", false)
		and again.get_value("preset.2.options", "application/product_name") == "Dry Trying Demo", "a stale demo preset is rebuilt at its index")
	_check(DemoExport.build(again).encode_to_text() == again.encode_to_text(), "the generator is idempotent")
	_check(not "level_02.gd" in str(again.get_value("preset.2", "exclude_filter")), "...and a stale cut path is gone")
