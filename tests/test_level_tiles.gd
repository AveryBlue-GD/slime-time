extends SceneTree

## Level select tiles: the level number's letter pixels and (on locked tiles) the lock icon's own
## pixels are centered on the tile, within 1 px, for all 10 tiles, locked and unlocked, normal and
## hard; unlocking only removes the lock and leaves the number where it was; medal pips, the
## record time and the check never overlap the number or the lock. Geometric (headless has no
## renderer); the rendered pixels are measured with tools/measure_tiles.py.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_level_tiles.gd

const TEST_SAVE := "user://test_save.cfg"

var failures := 0
var progress: Node


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	progress.save_path = TEST_SAVE
	progress.dev_tools = false
	progress.reset_progress()

	var number_boxes := {}
	for hard in [false, true]:
		progress.hard_mode = hard
		for unlocked in [1, 4, 10]:
			progress.highest_unlocked = unlocked
			progress.levels_cleared = unlocked - 1
			progress.medals = {1: 3, 2: 2, 3: 1, 101: 1, 102: 2, 103: 3}
			progress.best_times = {1: 12.3, 101: 12.3}
			progress.hard_cleared.assign(range(1, unlocked))
			var screen: Control = load("res://scenes/level_select.tscn").instantiate()
			root.add_child(screen)
			await process_frame
			await process_frame
			_check(screen.level_buttons.size() == 10, "10 tiles")
			for level in range(1, 11):
				var tile: Button = screen.level_buttons[level - 1]
				var locked: bool = level > unlocked
				var tag := "%s tile %d (%d open)" % ["hard" if hard else "normal", level, unlocked]
				_check(tile.disabled == locked, tag + ": disabled only when locked")
				_check(tile.size.x >= 44.0 and tile.size.y >= 32.0, tag + ": touch target stays >= 44x32 (%s)" % tile.size)
				var center := tile.size / 2.0
				var number: Label = tile.get_node("Number")
				var ink := _number_ink(number)
				_check(ink.get_center().distance_to(center) <= 1.0, tag + ": number ink centered (ink %s, tile center %s)" % [ink, center])
				var key := "%d" % level
				if number_boxes.has(key):
					_check(number_boxes[key] == ink, tag + ": number sits at the same place locked or not")
				number_boxes[key] = ink
				var lock := tile.get_node_or_null("Lock")
				_check((lock != null) == locked, tag + ": lock only on locked tiles")
				if locked:
					var icon: TextureRect = lock.get_child(1)
					var lock_ink := UIKit.icon_ink_rect("lock")
					var box := Rect2(Vector2(lock_ink.position) + icon.position, Vector2(lock_ink.size))
					_check(box.get_center().distance_to(center) <= 1.0, tag + ": lock ink centered (%s vs %s)" % [box, center])
					_check(lock.get_index() > number.get_index(), tag + ": lock drawn over the number")
				else:
					for child in tile.get_children():
						if child == number or not (child is Control):
							continue
						var rect := Rect2(child.position, child.size)
						if child is ColorRect:  # medal pips: right of the number's ink
							_check(rect.position.x >= ink.end.x + 2.0, tag + ": pip clear of the number")
						else:  # record time / check: below the number's ink
							_check(rect.position.y >= ink.end.y, tag + ": status line below the number (%s)" % rect)
							_check(rect.position.y + 7.0 <= tile.size.y - 3.0, tag + ": status line inside the goo bands")
			screen.free()
	progress.reset_progress()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)


## The number's letter pixels within its tile. The big font has a 14 px line box that is exactly
## its letter body (digits fill it top to bottom), 1 px gap on each side of every glyph, and the
## label centers the advance width, so the ink is the advance minus the two outer gaps.
func _number_ink(number: Label) -> Rect2:
	var font: Font = number.get_theme_font("font")
	var advance := font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var left := number.position.x + floorf((number.size.x - advance) / 2.0) + 1.0
	return Rect2(left, number.position.y, advance - 2.0, 14.0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)
