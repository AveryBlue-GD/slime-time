extends "res://tests/suite_base.gd"

## The iOS personal-install port (docs/ios-personal-install.md), without exporting (an iOS export only builds the
## Xcode project off a Mac):
## 1. the `iOS` preset in export_presets.cfg: full game (no `demo` / `steam` feature, no committed `skip_demo`),
##    tests / tools / docs / GodotSteam left out, iOS 15+, the 1024 icon present and scaled NEAREST (pixel art is
##    never filtered: the exporter's default Lanczos blurs every smaller icon), Xcode project only, the placeholder
##    team that tools/ios_build.sh fills; the project's sensor-landscape orientation;
## 2. tools/ios_build.sh still names that preset and the exact lines its sed / awk rewrite;
## 3. Progress.skip_demo_levels (the `skip_demo` test feature): the demo's levels cleared with every coin, intro and
##    tutorial seen, nothing past them; a save already past them left as is.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_ios_port.gd

var progress: Node
var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = test_save
	_check_preset()
	_check_build_script()
	_check_skip_demo()
	_result()
	quit(0 if failures == 0 else 1)


func _ios_section() -> String:
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		return ""
	for section in presets.get_sections():
		if section.ends_with(".options"):
			continue
		if presets.get_value(section, "name", "") == "iOS":
			return section
	return ""


func _check_preset() -> void:
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var section := _ios_section()
	_check(section != "", "an iOS preset exists")
	if section == "":
		return
	var options := section + ".options"
	_check(presets.get_value(section, "platform", "") == "iOS", "iOS preset: platform iOS")
	_check(presets.get_value(section, "custom_features", "x") == "", "iOS preset: full game, no committed feature (demo / steam / skip_demo)")
	var excluded: String = presets.get_value(section, "exclude_filter", "")
	for path in ["tests/*", "tools/*", "docs/*", "addons/godotsteam/*"]:
		_check(path in excluded, "iOS preset leaves out %s" % path)
	for path in ["scripts/*", "scenes/*", "assets/*", "locale/*"]:
		_check(not path in excluded, "iOS preset keeps %s" % path)
	_check(presets.get_value(options, "application/min_ios_version", "") == "15.0", "iOS preset: iOS 15+")
	_check(presets.get_value(options, "application/export_project_only", false) == true, "iOS preset: Xcode project only (ios_build.sh builds it)")
	_check(presets.get_value(options, "application/app_store_team_id", "") == "ABCDE12345", "iOS preset: the placeholder team ios_build.sh fills")
	_check(presets.get_value(options, "application/icon_interpolation", 4) == 0, "iOS preset: icons scaled nearest-neighbor (never filtered)")
	for key in ["icons/icon_1024x1024", "icons/app_store_1024x1024"]:
		var icon: String = presets.get_value(options, key, "")
		_check(icon == "res://assets/ios/icon_1024.png" and FileAccess.file_exists(icon), "iOS preset: %s is the 1024 icon" % key)
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ios/icon_1024.png"))
	_check(image != null and image.get_size() == Vector2i(1024, 1024) and not image.detect_alpha(), "the iOS icon is 1024x1024 without alpha")
	_check(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "sensor landscape (both landscape sides)")


func _check_build_script() -> void:
	var script := FileAccess.get_file_as_string("res://tools/ios_build.sh")
	_check(script != "", "tools/ios_build.sh exists")
	_check("--export-debug \"iOS\" build/ios/DryTrying.ipa" in script, "ios_build.sh exports the iOS preset to build/ios")
	_check("build/ios/DryTrying.xcodeproj" in script, "ios_build.sh builds the Xcode project the export writes")
	var text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(text.count("\napplication/app_store_team_id=\"ABCDE12345\"\n") == 1, "the team line ios_build.sh's sed rewrites is there once")
	# (the awk for SKIP_DEMO=1 rewrites the first custom_features="" after name="iOS": it must be the iOS preset's own)
	var at := text.find("\nname=\"iOS\"\n")
	var next := text.find("\n[preset.", at + 1)
	var feature := text.find("\ncustom_features=\"\"\n", at)
	_check(at >= 0 and feature > at and (next < 0 or feature < next), "the iOS preset's custom_features line is where ios_build.sh's SKIP_DEMO awk looks")
	_check(progress.SKIP_DEMO_FEATURE == "skip_demo" and "custom_features=\\\"skip_demo\\\"" in script, "ios_build.sh sets the feature Progress checks")


func _check_skip_demo() -> void:
	progress.reset_progress()
	progress.saving_enabled = true
	progress.levels_cleared = 0
	progress.coins_found.clear()
	progress.story_seen = 0
	progress.tutorial_seen = 0
	progress.hard_mode = false
	progress.skip_demo_levels()
	_check(progress.levels_cleared == Demo.LEVELS, "skip_demo: the demo's %d levels cleared, no more (%d)" % [Demo.LEVELS, progress.levels_cleared])
	var all_coins := true
	for level in range(1, Demo.LEVELS + 1):
		all_coins = all_coins and progress.coins_found.get(level, []).size() == Levels.coin_keys(level).size()
	_check(all_coins, "skip_demo: every coin of those levels found")
	_check(not progress.coins_found.has(Demo.LEVELS + 1), "skip_demo: nothing past them")
	_check(progress.has_seen_story(progress.STORY_INTRO), "skip_demo: intro seen")
	_check(progress.has_seen_tutorial(progress.TUTORIAL_HUB) and progress.has_seen_tutorial(progress.TUTORIAL_TRAINING), "skip_demo: tutorial and hub tour seen")
	_check(progress.hard_cleared.is_empty(), "skip_demo: no hard-mode clears")
	_check(FileAccess.file_exists(test_save), "skip_demo: saved")
	progress.levels_cleared = Demo.LEVELS + 3
	progress.coins_found.erase(1)
	progress.skip_demo_levels()
	_check(progress.levels_cleared == Demo.LEVELS + 3 and not progress.coins_found.has(1), "skip_demo: a save already past the demo is left as is")
	progress.saving_enabled = false
