extends "res://tests/suite_base.gd"

## The skins screen's JELLY switch swaps the worn skin to its other version (same skin id) when
## that version is unlocked; if it is locked the worn skin stays and the status line says so.
## Opaque = the normal-mode skins and the default; jelly = the hard-mode reward (D14). Dev mode
## (everything unlocked) always swaps. The choice survives a save/load, and a saved look that is
## not unlocked under these rules loads as that skin's opaque version (or opaque Lime).
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_jelly_swap.gd

var progress: Node


var test_save := throwaway_save()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = true
	progress.save_path = test_save
	progress.dev_tools = false
	progress.levels_cleared = 3
	progress.hard_cleared.assign([1, 2])
	progress.coins_found = {}
	progress.select_skin("mint", false)
	_check(progress.selected_skin == "mint" and not progress.jelly and Skins.jelly == false, "setup: opaque mint (the normal-mode version) worn")

	# Both versions of mint unlocked: the toggle swaps in place.
	var screen := await _open()
	_check(screen.jelly_button.text == "JELLY: OFF" and screen._rule.text == screen.rule_text("skins"), "the screen opens on the opaque skins")
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "mint" and progress.jelly and Skins.jelly == true, "both unlocked: JELLY ON wears jelly mint")
	_check(screen.jelly_button.text == "JELLY: ON" and screen._rule.text == screen.rule_text("jelly"), "JELLY label and rule flip (%s)" % screen._rule.text)
	_check((screen.big_preview.material as ShaderMaterial).get_shader_parameter("translucency") == 1.0, "...previews jelly")
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "mint" and not progress.jelly, "...and back to opaque mint")
	screen.free()

	# Save and load keep the swapped version.
	progress.select_skin("mint", true)
	progress.save_progress()
	progress.set_jelly(false)
	progress.selected_skin = "lime"
	progress.load_progress()
	_check(progress.selected_skin == "mint" and progress.jelly, "save/load keeps jelly mint")

	# Only the opaque version unlocked (ocean jelly needs hard L3): the worn skin stays.
	progress.select_skin("ocean", false)
	screen = await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "ocean" and not progress.jelly, "only opaque unlocked: still wearing opaque ocean")
	_check("JELLY LOCKED - HARD CLEAR L3" in screen.status.text, "...signalled locked (%s)" % screen.status.text)
	screen.free()

	# Only the jelly version unlocked (rainbow opaque needs every coin; jelly needs hard L10).
	progress.hard_cleared.assign([1, 2, 10])
	progress.select_skin(Skins.RAINBOW, true)
	_check(progress.selected_skin == Skins.RAINBOW and progress.jelly, "setup: jelly rainbow worn")
	screen = await _open()
	_check(screen.view_jelly, "the screen opens on the version worn (jelly)")
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == Skins.RAINBOW and progress.jelly, "opaque locked: stays jelly rainbow")
	_check("LOCKED - FIND EVERY COIN" in screen.status.text, "...signalled locked (%s)" % screen.status.text)
	screen.free()

	# The stopwatch is the exception: both versions open together with all 30 medals, and its
	# locked text names the medals in either view.
	progress.medals = {}
	screen = await _open()
	for view in [true, false]:
		if screen.view_jelly != view:
			screen._toggle_jelly()
		screen._on_tile(Skins.STOPWATCH)
		_check("EARN ALL" in screen.status.text and "HARD CLEAR" not in screen.status.text,
			"stopwatch locked (%s view): %s" % ["jelly" if view else "opaque", screen.status.text])
	screen.free()
	_check(Skins.is_unlocked(Skins.STOPWATCH, 0, [], true, 0, true) and Skins.is_unlocked(Skins.STOPWATCH, 0, [], false, 0, true),
		"stopwatch: both versions unlock with all medals, no hard clear needed")

	# Old-rule saves (in-epoch): the stored look is recomputed under the new rules. A save that
	# wears jelly ember (the old default look) without hard L9 falls back to opaque ember; one
	# wearing a skin not unlocked at all falls back to Lime (opaque).
	progress.select_skin("lime", false)
	progress.levels_cleared = 10
	progress.hard_cleared.assign([1])
	progress.save_progress()
	_patch_save("ember", true)
	progress.load_progress()
	_check(progress.selected_skin == "ember" and not progress.jelly and not Skins.jelly, "old jelly ember without hard L9 loads as opaque ember")
	_patch_save("lime", true)
	progress.load_progress()
	_check(progress.selected_skin == "lime" and progress.jelly, "jelly lime with hard L1 cleared stays jelly")
	progress.levels_cleared = 2
	progress.save_progress()
	_patch_save("ember", false)
	progress.load_progress()
	_check(progress.selected_skin == Skins.DEFAULT and not progress.jelly, "a locked skin falls back to opaque Lime")
	_patch_save("rainbow", true)
	progress.load_progress()
	_check(progress.selected_skin == Skins.DEFAULT and not progress.jelly, "locked rainbow (either version) falls back to opaque Lime")
	_patch_save("mint", null)
	progress.load_progress()
	_check(progress.selected_skin == "mint" and not progress.jelly, "a save without the jelly key loads opaque")

	# Dev mode: everything is unlocked, so the toggle always swaps.
	progress.dev_tools = true
	progress.select_skin("ember", false)
	screen = await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "ember" and progress.jelly, "dev mode swaps to jelly ember")
	screen.free()

	_result()
	quit(1 if failures else 0)


func _open() -> Control:
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	return screen


## Rewrites the test save's [skin] section (selected skin; jelly true / false / null = key absent).
func _patch_save(skin: String, jelly: Variant) -> void:
	var file := ConfigFile.new()
	_check(file.load(test_save) == OK, "test save readable")
	file.set_value("skin", "selected", skin)
	if jelly == null:
		if file.has_section_key("skin", "jelly"):
			file.erase_section_key("skin", "jelly")
	else:
		file.set_value("skin", "jelly", jelly)
	file.save(test_save)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["ok" if ok else "FAIL", what])
