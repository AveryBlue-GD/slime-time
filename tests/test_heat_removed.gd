extends "res://tests/suite_base.gd"

## HEAT (hard mode's modifiers) was scrapped on 2026-10-20 (docs/heat-removed.md). Saves written while
## it existed may hold [settings] heat_mods, a [heat] section (level_N best heats, paid) and the EMBER
## trail (owned / worn). Such a save must still load cleanly: everything else in it is kept (tickets
## the bounties paid included), the HEAT keys are ignored and dropped by the next save, an owned or worn
## EMBER trail falls back to the default trail, and the save version is unchanged.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_heat_removed.gd

var progress: Node
var save_file := ""


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	save_file = throwaway_save()
	progress.save_path = save_file
	_check(progress.save_path != progress.REAL_SAVE_PATH, "a throwaway save")
	_old_save_loads()
	_no_heat_left()
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
	_result()
	quit(1 if failures else 0)


func _text() -> String:
	return FileAccess.get_file_as_bytes(save_file).get_string_from_utf8()


## A save from a build with HEAT: write a normal save, then add what that build wrote for HEAT.
func _old_save_loads() -> void:
	progress.saving_enabled = true
	progress.reset_progress()
	progress.dev_tools = false
	progress.levels_cleared = Levels.COUNT
	progress.highest_unlocked = Levels.COUNT
	progress.hard_cleared.assign(range(1, Levels.COUNT + 1))
	progress.tickets = 137
	progress.cosmetics_owned.assign(["gold"])
	_check(progress.save_progress(), "setup: the save is written")
	var file := ConfigFile.new()
	_check(file.load(save_file) == OK, "setup: the save reads back")
	file.set_value("settings", "heat_mods", 37)
	for level in range(1, Levels.COUNT + 1):
		file.set_value("heat", "level_%d" % level, 7)
	file.set_value("heat", "paid", 150)
	file.set_value("cosmetics", "owned", ["ember", "gold"])
	file.set_value("cosmetics", "trail", "ember")
	_check(file.save(save_file) == OK, "setup: HEAT keys added the way the HEAT build wrote them")
	var before := _text()
	_check(before.contains("[heat]") and before.contains("heat_mods") and before.contains("\"ember\""), "setup: the file holds HEAT data")

	progress.saving_enabled = false  # (reset_progress saves: keep the file as the HEAT build left it)
	progress.reset_progress()
	progress.saving_enabled = true
	_check(_text() == before, "setup: the file is untouched before the load")
	progress.load_progress(save_file)
	_check(progress.levels_cleared == Levels.COUNT and progress.hard_cleared.size() == Levels.COUNT, "the old save's story and hard clears load")
	_check(progress.tickets == 137, "tickets the bounties paid are kept (%d)" % progress.tickets)
	_check(progress.owns_cosmetic("gold") and not progress.owns_cosmetic("ember"), "other trails are kept; EMBER is gone")
	_check(progress.trail_style == Cosmetics.DEFAULT_TRAIL, "a worn EMBER trail falls back to the default trail")
	_check(not "heat_mods" in progress and not "heat_best" in progress, "Progress keeps no HEAT state")

	_check(progress.save_progress(), "the loaded save writes")
	var after := _text()
	_check(not after.contains("[heat]") and not after.contains("heat_mods") and not after.contains("ember"), "the next save drops every HEAT key")
	var reread := ConfigFile.new()
	_check(reread.load(save_file) == OK and int(reread.get_value("meta", "version", -1)) == progress.SAVE_VERSION, "same save version (%d)" % progress.SAVE_VERSION)

	# A save code from the HEAT build reads the same way.
	file.set_value("meta", "epoch", progress.RELEASE_EPOCH)
	progress.saving_enabled = false
	progress.reset_progress()
	progress._read(file, true)
	progress.saving_enabled = true
	_check(progress.levels_cleared == Levels.COUNT and not progress.owns_cosmetic("ember") and progress.trail_style == Cosmetics.DEFAULT_TRAIL, "a save code with HEAT data reads cleanly")


## Nothing of HEAT is left for the game to show.
func _no_heat_left() -> void:
	_check(not ResourceLoader.exists("res://scripts/heat.gd") and not ResourceLoader.exists("res://scripts/ui/heat_panel.gd"), "heat.gd and heat_panel.gd are gone")
	_check(not "ember" in Cosmetics.trail_ids() and Cosmetics.get_item("ember").is_empty(), "no EMBER trail")
	var classes: Array[String] = []
	for cls: Dictionary in ProjectSettings.get_global_class_list():
		classes.append(String(cls["class"]))
	_check(not "Heat" in classes and not "HeatPanel" in classes, "no Heat / HeatPanel class")
	var level_select: GDScript = load("res://scripts/ui/level_select.gd")
	for text: String in [level_select.info_text(false), level_select.info_text(true)]:
		_check(not "HEAT" in text, "the level select's info names no HEAT (%s)" % text.replace("\n", " / "))
