extends "res://tests/suite_base.gd"

## Save codes: the whole save as a "SLIME2-" code (gzipped, base64) that can be copied out and
## pasted back in. A code restores exactly what was saved; broken, cut-off or foreign codes are
## refused without touching the progress; the settings screen's SAVE CODE panel shows your code,
## refuses a bad one and only loads a good one on the second LOAD press. Never touches a real save.
## Run: .\tools\godot.ps1 --path . --headless --fixed-fps 60 --quit-after 30000 -s res://tests/test_save_code.gd

var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.saving_enabled = false

	# --- Some progress worth keeping
	progress.levels_cleared = 6
	progress.highest_unlocked = 7
	progress.current_level = 7
	progress.hard_cleared.assign([1, 2])
	progress.best_times = {1: 12.5, 3: 31.25, 101: 18.0}
	progress.medals = {1: 1, 3: 2, 101: 1}  # (a save with best times always has its medals section)
	progress.coins_found = {1: ["2,3", "5,1", "9,3"], 4: ["7,7", "1,9"]}
	progress.upgrades = {"slime": 2}  # 1 + 4 coins spent of the 5 found
	progress.custom_color = Color(0.2, 0.6, 0.9)
	progress.selected_skin = "mint"  # its jelly version needs hard level 1, which is beaten (D14)
	progress.set_jelly(true)
	progress.set_binding("jump", KEY_J)
	var before: String = progress._write().encode_to_text()
	var code: String = progress.save_code()
	_check(code.begins_with("SLIME2-") and code.length() < 2000, "your save becomes a code (%d characters)" % code.length())

	# --- Back to nothing, then the code brings it all back
	progress.reset_progress()
	progress.reset_bindings()
	_check(progress.levels_cleared == 0 and progress.coins_found.is_empty(), "(progress wiped, like a cleared browser)")
	_check(progress.load_code(code), "pasting the code loads it")
	_print_diff(before, progress._write().encode_to_text())
	_check(_same(progress._write().encode_to_text(), before), "...and everything comes back exactly: levels, records, coins, upgrades, skin, keys")
	_check(progress.selected_skin == "mint" and progress.jelly and progress.bindings.jump == KEY_J and progress.upgrade_level("slime") == 2,
		"...(Mint, jelly, J to jump, slime upgrade 2)")
	_check(progress.load_code("  " + code + "\n"), "spaces or a line break around the pasted code are fine")

	# --- Bad codes are refused and change nothing
	var bad := ["", "hello", "SLIME2-", "SLIME2-not a code!", code.substr(0, code.length() / 2), "SLIME1-" + code.trim_prefix("SLIME2-"),
		"SLIME2-" + Marshalls.raw_to_base64("just some text".to_utf8_buffer())]
	var refused := true
	for attempt: String in bad:
		if progress.load_code(attempt):
			refused = false
	_check(refused and _same(progress._write().encode_to_text(), before), "broken, cut-off or foreign codes are refused and the progress stays")

	# --- The settings screen's SAVE CODE panel
	var screen: Control = load("res://scenes/controls.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen._open_codes()
	_check(screen.code_panel.visible and screen.code_out.text == progress.save_code(), "SAVE CODE shows your code to copy")
	screen._copy_code()
	_check(screen.code_status.text == screen.copied_message() and screen.code_out.get_selected_text() == screen.code_out.text, "COPY copies the code and says so")
	var js: String = screen.web_copy_js(code)
	_check(js.ends_with("})(\"%s\")" % code) and "execCommand('copy')" in js, "the web copy script carries the code as a JS string")
	_check(screen.web_copy_js("a\"b\\c\n</script>").ends_with("})(%s)" % JSON.stringify("a\"b\\c\n</script>")), "the web copy script escapes odd text")
	screen.code_in.text = "SLIME2-garbage"
	screen._load_code()
	_check("DOESN'T WORK" in screen.code_status.text, "a bad code says so (%s)" % screen.code_status.text)
	progress.levels_cleared = 2  # pretend the progress moved on since the code was made
	var box_right: float = screen.code_in.position.x + screen.code_in.size.x
	_check(screen.paste_button.visible and screen.paste_button.position.x >= box_right and screen.paste_button.position.x + screen.paste_button.size.x <= screen.load_button.position.x,
		"a PASTE button sits between the box and LOAD")
	screen._set_pasted("  " + code + "\n")  # what PASTE (or a paste into the page) hands over
	_check(screen.code_in.text == code and "PASTED" in screen.code_status.text and not screen.load_armed,
		"pasting fills the box with the code, trimmed, and says to press LOAD (%s)" % screen.code_status.text)
	screen._set_pasted("")
	_check("NOTHING TO PASTE" in screen.code_status.text and screen.code_in.text == code, "an empty clipboard says so and keeps the box as it was")
	screen._load_code()
	_check(screen.load_armed and "PRESS LOAD AGAIN" in screen.code_status.text and progress.levels_cleared == 2,
		"a good code asks first: it would replace your progress")
	screen._load_code()
	_check(progress.levels_cleared == 6, "the second LOAD loads it")
	screen.free()

	# --- Legacy saves (no tutorial_seen key), settings keys and reset
	var old := ConfigFile.new()
	old.set_value("progress", "levels_cleared", 3)
	progress.reset_progress()
	progress._read(old)
	_check(progress.has_seen_tutorial(Progress.TUTORIAL_MOVE) and progress.has_seen_tutorial(Progress.TUTORIAL_LEAP), "a returning save without the key has seen the cues")
	var fresh := ConfigFile.new()
	fresh.set_value("progress", "levels_cleared", 0)
	progress._read(fresh)
	_check(progress.tutorial_seen == 0, "a fresh save without the key still gets the cues")
	progress.reduce_motion = true
	progress.fog_brightness = Progress.FOG_BRIGHT
	progress._read(old)
	_check(progress.reduce_motion and progress.fog_brightness == Progress.FOG_BRIGHT, "a load without settings keys keeps the current settings")
	progress.tutorial_seen = 3
	progress.dry_ups = {1: 2}
	progress.reset_progress()
	_check(progress.tutorial_seen == 0 and progress.dry_ups.is_empty(), "reset clears tutorial_seen and dry_ups")
	progress.reduce_motion = false
	progress.fog_brightness = Progress.FOG_NORMAL
	progress.reset_bindings()
	_result()
	quit(1 if failures else 0)


## Two saves hold the same settings (lines in any order: loading reads them by name).
func _same(a: String, b: String) -> bool:
	var la := Array(a.split("\n"))
	var lb := Array(b.split("\n"))
	la.sort()
	lb.sort()
	return la == lb


## Prints the save lines that differ (so a failed round trip says what was lost).
func _print_diff(before: String, after: String) -> void:
	var a := before.split("\n")
	var b := after.split("\n")
	for line in a:
		if not line in b:
			print("  lost:    ", line)
	for line in b:
		if not line in a:
			print("  changed: ", line)


