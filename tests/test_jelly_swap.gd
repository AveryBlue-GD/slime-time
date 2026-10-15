extends "res://tests/suite_base.gd"

## The skins screen's JELLY switch swaps the worn skin to its other version (same skin id) when
## that version is unlocked; if it is locked the worn skin stays and the status line says so.
## Dev mode (everything unlocked) always swaps. The choice survives a save/load.
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
	progress.select_skin("mint", true)

	# Both versions of mint unlocked: the toggle swaps in place.
	var screen := await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "mint" and not progress.jelly and Skins.jelly == false, "both unlocked: JELLY OFF wears solid mint")
	_check(screen.jelly_button.text == "JELLY: OFF", "JELLY label flips")
	_check((screen.big_preview.material as ShaderMaterial).get_shader_parameter("translucency") == 0.0, "...previews solid")
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "mint" and progress.jelly, "...and back to jelly mint")
	screen.free()

	# Save and load keep the swapped version.
	progress.select_skin("mint", false)
	progress.save_progress()
	progress.set_jelly(true)
	progress.selected_skin = "lime"
	progress.load_progress()
	_check(progress.selected_skin == "mint" and not progress.jelly, "save/load keeps solid mint")

	# Only the jelly version unlocked (ocean solid needs hard L3): the worn skin stays.
	progress.select_skin("ocean", true)
	screen = await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "ocean" and progress.jelly, "only jelly unlocked: still wearing jelly ocean")
	_check("SOLID LOCKED - HARD CLEAR L3" in screen.status.text, "...signalled locked (%s)" % screen.status.text)
	screen.free()

	# Only the solid version unlocked (rainbow jelly needs every coin; solid needs hard L10).
	progress.hard_cleared.assign([1, 2, 10])
	progress.select_skin(Skins.RAINBOW, false)
	_check(progress.selected_skin == Skins.RAINBOW and not progress.jelly, "setup: solid rainbow worn")
	screen = await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == Skins.RAINBOW and not progress.jelly, "jelly locked: stays solid rainbow")
	_check("LOCKED" in screen.status.text, "...signalled locked (%s)" % screen.status.text)
	screen.free()

	# Dev mode: everything is unlocked, so the toggle always swaps.
	progress.dev_tools = true
	progress.select_skin("ember", true)
	screen = await _open()
	screen.jelly_button.pressed.emit()
	_check(progress.selected_skin == "ember" and not progress.jelly, "dev mode swaps to solid ember")
	screen.free()

	_result()
	quit(1 if failures else 0)


func _open() -> Control:
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	return screen


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
	print("%s: %s" % ["ok" if ok else "FAIL", what])
