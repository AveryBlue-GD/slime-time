extends RefCounted

## The demo export presets (docs/demo-plan.md "Shipping the demo"). Each demo preset is GENERATED from its
## full twin in export_presets.cfg: the same section and options, then the demo's name, the `demo` custom
## feature, its own output under build/demo/, and the twin's exclude_filter plus Demo.export_cut() (the
## full-only files: later levels' data, later themes' art and ambience, the victory screen, the catalogs
## while languages are off). So the cut follows the game: a new level or theme past the demo is cut on the
## next `--write-presets`, and tests/test_demo_export.gd fails while the file is out of date.
##   godot --path . --headless -s res://tools/demo_paths.gd -- --write-presets   (rewrite the demo presets)
##   godot --path . --headless -s res://tools/demo_paths.gd -- --check-presets   (exit 1 if out of date)
## Edit the FULL presets (in the editor or here); never the demo ones (the next write replaces them).
## The file is read and written with ConfigFile, exactly as the Godot editor saves it (a load + save of
## the untouched file is byte-identical), so the full presets stay as they are.

const PRESETS_PATH := "res://export_presets.cfg"

## Full twin -> its demo preset. `web`: the web demo's cut (Demo.WEB_LEVELS). `options`: option values
## the demo changes (product name; macOS bundle id so the system never mixes up the two apps; the save
## folder is project.godot's custom_user_dir_name, the same for both, so progress carries over).
const DEMOS := [
	{twin = "Windows Desktop", name = "Windows Demo", path = "build/demo/windows/DryTryingDemo.exe", web = false,
		options = {"application/product_name": "Dry Trying Demo", "application/file_description": "Dry Trying Demo"}},
	{twin = "Web", name = "Web Demo", path = "build/demo/web/index.html", web = true, options = {}},
	{twin = "macOS", name = "macOS Demo", path = "build/demo/macos/DryTryingDemo.zip", web = false,
		options = {"application/bundle_identifier": "com.slimetime.game.demo"}},
	{twin = "Linux", name = "Linux Demo", path = "build/demo/linux/DryTryingDemo.x86_64", web = false, options = {}},
]
const DEMO_FEATURE := "demo"


## The demo spec (an entry of DEMOS) for demo preset `name`, or {} if `name` isn't one.
static func spec(name: String) -> Dictionary:
	for entry: Dictionary in DEMOS:
		if entry.name == name:
			return entry
	return {}


## The exclude_filter of a demo preset: its twin's filter, then every cut path (without res://).
static func exclude_filter(twin_filter: String, web: bool) -> String:
	var parts := PackedStringArray()
	if twin_filter.strip_edges() != "":
		parts.append(twin_filter.strip_edges())
	for path in Demo.export_cut(web):
		parts.append(path.trim_prefix("res://"))
	return ", ".join(parts)


## The section index ("preset.N") of every preset by name.
static func _indices(cfg: ConfigFile) -> Dictionary:
	var out := {}
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			out[str(cfg.get_value(section, "name", ""))] = section.trim_prefix("preset.").to_int()
	return out


## The export presets as they should be: `cfg` (export_presets.cfg) with every demo preset (re)built from
## its twin. Demo presets keep their index; new ones are appended after the last preset. Full presets
## are never touched. Returns the problems (a missing twin) in `errors`.
static func build(cfg: ConfigFile, errors: Array[String] = []) -> ConfigFile:
	var out := ConfigFile.new()
	out.parse(cfg.encode_to_text())
	var indices := _indices(out)
	var next := 0
	for name: String in indices:
		next = maxi(next, indices[name] + 1)
	for entry: Dictionary in DEMOS:
		if not indices.has(entry.twin):
			errors.append("no full preset named \"%s\" for \"%s\"" % [entry.twin, entry.name])
			continue
		var twin := "preset.%d" % indices[entry.twin]
		var index: int = indices.get(entry.name, next)
		if index == next:
			next += 1
		var section := "preset.%d" % index
		for sec in [section, section + ".options"]:
			if out.has_section(sec):
				out.erase_section(sec)
		for key in out.get_section_keys(twin):
			out.set_value(section, key, out.get_value(twin, key))
		out.set_value(section, "name", entry.name)
		var features := PackedStringArray()
		for feature in str(out.get_value(twin, "custom_features", "")).split(",", false):
			if feature.strip_edges() != DEMO_FEATURE:
				features.append(feature.strip_edges())
		features.append(DEMO_FEATURE)
		out.set_value(section, "custom_features", ",".join(features))
		out.set_value(section, "export_path", entry.path)
		out.set_value(section, "exclude_filter", exclude_filter(str(out.get_value(twin, "exclude_filter", "")), entry.web))
		if out.has_section(twin + ".options"):
			for key in out.get_section_keys(twin + ".options"):
				out.set_value(section + ".options", key, entry.options.get(key, out.get_value(twin + ".options", key)))
	return _ordered(out)


## The same presets in preset.0, preset.0.options, preset.1, ... order (how the editor writes them).
static func _ordered(cfg: ConfigFile) -> ConfigFile:
	var count := 0
	for section in cfg.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			count = maxi(count, section.trim_prefix("preset.").to_int() + 1)
	var out := ConfigFile.new()
	for i in count:
		for section in ["preset.%d" % i, "preset.%d.options" % i]:
			if cfg.has_section(section):
				for key in cfg.get_section_keys(section):
					out.set_value(section, key, cfg.get_value(section, key))
	for section in cfg.get_sections():  # anything else the editor may add, after the presets
		if not out.has_section(section):
			for key in cfg.get_section_keys(section):
				out.set_value(section, key, cfg.get_value(section, key))
	return out


## The text export_presets.cfg should have (as ConfigFile, i.e. the editor, writes it), or "" on errors.
static func expected_text(errors: Array[String] = []) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS_PATH) != OK:
		errors.append("can't read " + PRESETS_PATH)
		return ""
	var built := build(cfg, errors)
	return "" if not errors.is_empty() else built.encode_to_text()


## The file's current text as ConfigFile encodes it (the same as on disk once the editor or
## --write-presets saved it; comparing this, not the raw bytes, ignores CRLF line ends of a checkout).
static func current_text() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PRESETS_PATH) != OK:
		return ""
	return cfg.encode_to_text()
