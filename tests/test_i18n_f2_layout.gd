extends "res://tests/suite_base.gd"

## Layout checks for the i18n fix pass F2 (docs/i18n/review/fixes-F2.md: the HUD intro texts, the result
## panel, the Descent cards, the tutorial key caps), in every locale (Arabic included: the HUD and the
## cards are mirrored, the area texts are centred and the game world is not), measured from the built
## controls' rects and their texts' line boxes (+ marks above, drips below):
## - HUD (L1, L10, L7 hard HEAT 63, L8 assisted, randomizer, Descent pot): the area name and story line
##   clear of the player slime's drawn body (from the slime's own canvas position), TEXT_CLEARANCE under /
##   side_clearance() beside every pod (English 2, fix pass R1), on screen; the level pod GAP_L clear of the timer pod (English's
##   RANDOM MAZE #n  CODE LVx (YOU y) included), each wrapped line within the room.
## - Results: the first panel line's marks start under the goo band's lump row (5 rows under the panel's
##   top); a text-only last row keeps 2 clear rows over the bottom band's lumps; the big NEW RECORD! banner
##   on the L3 win in every locale but those whose panel cannot make room (COMPACT_OK).
## - Descent: the boon card title's ink from row 4 (marks included), the tiles between the PICK ONE line
##   and the status line; the summary's rows inside the panel GAP_L from its sides, the first line's
##   marks under the lump row, the panel on screen.
## - Tutorial: the leap key holds SPACE (the text inside its 1 px edge); W A S D keep the 9 px key.
## - English pinned: area name / story line / panel / banner rects as before F2 (dry-up: +3 rows).
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_f2_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")
const Hud := preload("res://scripts/hud.gd")
const SCREEN := Rect2(0, 0, 320, 180)
## Locales whose L3 win panel (4 tall lines) still needs the compact banner after pairing its lines.
const COMPACT_OK: Array[String] = ["ar", "hi"]
## The goo panel's rows down to its top lump row (GooBox: 3 band rows, the lump row under them), and the
## bottom band's lump row from its rect's end (measured: lumps on end - 3, the band under them).
const GOO_EDGE := 4
const GOO_BOTTOM := 3

var progress: Node
var language: Node
var _code := ""
var _seen := {}


func _initialize() -> void:
	Economy.descent_force = 1
	await process_frame
	progress = root.get_node("Progress")
	language = root.get_node("Language")
	progress.save_path = throwaway_save()
	progress.saving_enabled = false
	progress.enable_story_complete()
	progress.tickets = 60
	Economy.languages_force = 1
	Economy.forced_locale = "en"
	language.enable()
	for code: String in Report.LOCALE_ORDER:
		_code = code
		language.set_locale(code)
		await _hud()
		await _level_pod()
		await _results()
		await _descent()
		_keys()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	progress.hard_mode = false
	progress.heat_mods = 0
	var names := {}
	for key: String in _seen:
		names[key.get_slice("|", 1)] = true
	for name: String in names:
		var bad := PackedStringArray()
		var bad_other := PackedStringArray()  # (other locales: only reported in English-only mode, _check_locale)
		for key: String in _seen:
			if key.get_slice("|", 1) == name and _seen[key] != "":
				var line := "%s (%s)" % [key.get_slice("|", 0), _seen[key]]
				if key.get_slice("|", 0) in ["en", ""]:
					bad.append(line)
				else:
					bad_other.append(line)
		_check(bad.is_empty(), name + ("" if bad.is_empty() else ": " + ", ".join(bad.slice(0, 4))))
		if not bad_other.is_empty():
			_check_locale(false, name + ": " + ", ".join(bad_other.slice(0, 4)))
	_result()
	quit(1 if failures else 0)


## Records one check per locale and name (the first failure's detail is kept).
func _ok(ok: bool, name: String, detail := "") -> void:
	var key := "%s|%s" % [_code, name]
	if not _seen.has(key):
		_seen[key] = ""
	if not ok and _seen[key] == "":
		_seen[key] = detail if detail != "" else "failed"


# ------------------------------------------------------------------ HUD

func _hud() -> void:
	var cases: Array[Dictionary] = [{level = 1}, {level = 10}, {level = 7, hard = true, heat = 63},
		{level = 8, assist = true}, {random = true}, {descent = true}]
	for c: Dictionary in cases:
		var game := await _start(c)
		if c.get("assist", false):
			game.hud.set_assist(true)
		if c.get("descent", false):
			game.hud.set_pot(888, "", 888, 8)
		await _frames(3)
		var hud = game.hud
		var at: Vector2 = (game.slime.global_position - game.camera.get_screen_center_position() + UIKit.SCREEN / 2.0).round()
		var body := Rect2(at - Vector2(7, 7), Vector2(16, 14))  # (the slime's ink, measured: 15 x 14 around its position)
		_ok(hud.player_rect.encloses(body), "hud player rect holds the slime's drawn body", "%s %s" % [hud.player_rect, body])
		for label: Label in [hud.area_label, hud.story_label]:
			if not label.visible or label.text == "":
				continue
			var ink := _text_rect(label)
			var tag := "%s %s" % [label.text.left(16), ink]
			_ok(SCREEN.encloses(ink), "hud area texts on screen", tag)
			_ok(not ink.intersects(body), "hud area texts clear of the player slime", "%s slime %s (%s)" % [tag, body, c])
			var spaced := ink.grow_individual(Hud.side_clearance() - 1, Hud.TEXT_CLEARANCE - 1, Hud.side_clearance() - 1, Hud.TEXT_CLEARANCE - 1)
			for pod: Rect2 in hud.pod_rects():
				_ok(not spaced.intersects(pod), "hud area texts clear of the pods (beside them by side_clearance())", "%s pod %s" % [tag, pod])
		if _code == "en":
			_pin_english_hud(c, hud)
		game.free()
		progress.heat_mods = 0
		progress.hard_mode = false


## English: the area name and story line where they were before F2 (none of them was on the slime).
func _pin_english_hud(c: Dictionary, hud: Node) -> void:
	var tops := {1: [20, 35], 10: [20, 35], 7: [35, 50], 8: [20, 51]}
	if c.get("random", false):
		_ok(hud.area_label.offset_top == 44, "English area texts pinned", "random %d" % hud.area_label.offset_top)
	elif c.get("descent", false):
		_ok(hud.area_label.offset_top == 44 and hud.story_label.offset_top == 56, "English area texts pinned",
			"descent %d / %d" % [hud.area_label.offset_top, hud.story_label.offset_top])
	elif tops.has(c.level):
		var want: Array = tops[c.level]
		_ok(hud.area_label.offset_top == want[0] and (not hud.story_label.visible or hud.story_label.offset_top == want[1]),
			"English area texts pinned", "L%d %d / %d" % [c.level, hud.area_label.offset_top, hud.story_label.offset_top])


## The level pod beside the timer: GAP_L clear of it (a wrapped name, never against it).
func _level_pod() -> void:
	var game := await _start({level = 7, hard = true})
	var hud = game.hud
	var texts: Array[String] = [
		Loc.t("hud.area.level_hard", "LEVEL {level}/{total}  HARD", {level = 7, total = 10}),
		Loc.t("hud.area.random_code", "RANDOM MAZE #{n}  CODE LV{code} (YOU {own})", {n = 12, code = 3, own = 5}),
		Loc.t("hud.area.random_hard", "RANDOM MAZE #{n}  HARD", {n = 12}),
		Loc.t("hud.area.random", "RANDOM MAZE #{n}", {n = 12}),
		Loc.t("hud.area.descent", "DESCENT  FLOOR {floor}", {floor = 12}),
	]
	for text in texts:
		hud.set_level_text(text)
		await _frames(2)
		var timer := _rect(hud.time_label.get_parent().get_parent())
		var pod := _rect(hud.level_label.get_parent().get_parent())
		var gap := pod.position.x - timer.end.x if not UIKit.is_mirrored(hud.level_label) else timer.position.x - pod.end.x
		_ok(gap >= UIKit.GAP_L, "level pod GAP_L clear of the timer", "%s gap %d" % [text.left(24), gap])
		_ok(SCREEN.encloses(pod), "level pod on screen", "%s %s" % [text.left(24), pod])
		for line in hud.level_label.text.split("\n"):
			_ok(line.strip_edges() != "" and not (line.strip_edges().begins_with("#") and not " " in line.strip_edges()), "level pod lines never a lone #n", hud.level_label.text.replace("\n", " / "))
		if _code == "en" and text == texts[0]:
			_ok(hud.level_label.text == text, "English LEVEL 7/10  HARD on one line")
	game.free()
	progress.hard_mode = false


# ------------------------------------------------------------------ results

func _results() -> void:
	for c: Dictionary in [{level = 3, record = true}, {level = 10}, {level = 4, dry = true}, {random = true}]:
		var game := await _start(c)
		if c.get("dry", false):
			game._dry_up(true)
			game.hud.show_rewards({offer = true})
			game._offer_retry()
		else:
			game._on_goal_body_entered(game.slime)
			if c.get("random", false):
				game.hud.show_rewards({tickets = 4, attempt = 2, cap = "replay"})
			elif c.level == 3:
				game.hud.show_rewards({tier = 3, best = 3, new_best = true})
			else:
				game.hud.show_rewards({tier = 1, best = 3, new_best = false})
			if c.get("record", false):
				game.hud.show_record(13.6)
			game._offer_next_steps()
		await _frames(3)
		var hud = game.hud
		var panel := _rect(hud._message_panel)
		var message: Label = hud.message
		var first: String = message.text.split("\n")[0]
		var line_top := _rect(message).position.y + _valign_shift(message)
		var marks := float(UIKit.ink_above(first))
		# (the slimy font's marks and drips; a taller script's line box keeps its own empty rows)
		_ok(UIKit.tall_script() or line_top - marks >= panel.position.y + GOO_EDGE + 1, "result first line's marks under the goo lump row",
			"%s line %d marks %d panel %d" % [first.left(16), line_top, marks, panel.position.y])
		var last: Control = hud._rewards_row2 if hud._rewards_row2 and hud._rewards_row2.visible else hud.rewards_row
		if not UIKit.tall_script() and last.get_children().all(func(n: Node) -> bool: return n is Label or n.is_queued_for_deletion()):
			for l: Label in last.get_children().filter(func(n: Node) -> bool: return n is Label and not n.is_queued_for_deletion()):
				var r := _text_rect(l)
				_ok(r.end.y + 2 <= panel.end.y - GOO_BOTTOM, "result text-only last row: 2 rows over the bottom goo lumps",
					"%s drips end %d panel end %d" % [l.text.left(16), r.end.y, panel.end.y])
		if c.get("record", false):
			_ok(hud._banner_words.vertical or _code in COMPACT_OK, "result L3: the big NEW RECORD! banner",
				"compact; panel %s" % panel)
			_ok(not panel.intersects(_rect(hud.record_banner.get_child(0))), "result panel clear of the banner")
		if _code == "en":
			var want := {3: Rect2(92, 53, 136, 54), 10: Rect2(84, 59, 152, 42)}
			if c.get("dry", false):
				_ok(panel == Rect2(53, 58, 214, 44), "English result panels pinned (dry-up +3 rows)", str(panel))
			elif not c.get("random", false) and want.has(c.level):
				_ok(panel == want[c.level], "English result panels pinned", "L%d %s" % [c.level, panel])
		game.free()


# ------------------------------------------------------------------ Descent

func _descent() -> void:
	seed(20261017)
	progress.start_descent(77)
	var game := await _spawn_game({})
	var card = game._ensure_card()
	card.show_boons(progress.descent_run, progress.descent_offers())
	await _frames(2)
	var title: Label = card.title
	var title_top := _rect(title).position.y - float(UIKit.ink_above(title.text, UIKit.FONT_BIG))
	_ok(title_top >= 4.0, "Descent card title's ink from row 4", "%s top %d" % [title.text, title_top])
	if _code == "en":
		_ok(_rect(title).position.y == 4.0 and _rect(card.tiles[0]).position.y == 47.0 and card.tiles[0].size.y == 78.0, "English Descent card pinned")
	for tile: Button in card.tiles:
		if not tile.visible:
			continue
		var r := _rect(tile)
		_ok(r.position.y >= _rect(title).end.y and r.end.y <= _rect(card.status).position.y, "Descent tiles between the title and the status line", str(r))
		for label: Label in tile.get_children().filter(func(n: Node) -> bool: return n is Label):
			var ink := _text_rect(label)
			_ok(ink.position.x >= r.position.x + 4 and ink.end.x <= r.end.x - 4, "Descent tile lines 4 px inside the tile", "%s %s tile %s" % [label.text.left(16), ink, r])
	card.show_summary({floor = 2, cleared = 1, best_floor = 2, time = 61.0, tickets = 1, pot = 2, boons = {"gulp": 1}})
	await _frames(2)
	var panel := _rect(card.summary_panel)
	_ok(SCREEN.encloses(panel), "Descent summary panel on screen", str(panel))
	if _code == "en":
		_ok(panel.position.x == 40 and panel.size.x == 240, "English Descent summary pinned", str(panel))
	var rows: Array = card.summary_lines.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	for row: Control in rows:
		var parts: Array = [row] if row is Label else row.get_children()
		for part: Control in parts:
			var r := _text_rect(part) if part is Label else _rect(part)
			_ok(r.position.x >= panel.position.x + UIKit.GAP_L and r.end.x <= panel.end.x - UIKit.GAP_L, "Descent summary rows GAP_L inside the panel",
				"%s %s panel %s" % [str(part.get("text")).left(20), r, panel])
	var first: Label = rows[0]
	var marks := float(UIKit.ink_above(first.text))
	_ok(UIKit.tall_script() or _rect(first).position.y - marks >= panel.position.y + GOO_EDGE + 1, "Descent summary first line's marks under the goo lump row",
		"%s line %d panel %d" % [first.text, _rect(first).position.y, panel.position.y])
	game.free()


# ------------------------------------------------------------------ tutorial keys

func _keys() -> void:
	var font := ThemeDB.fallback_font
	for text: String in ["SPACE", "ENTER", "W", "A", "S", "D", "SHIFT", "TAB"]:
		var key := TutorialCues.key_size(font, text, 29.0 if text.length() > 1 else TutorialCues.KEY)
		var w := ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
		_ok(w <= key.x - 2.0, "tutorial key holds its name inside the 1 px edge", "%s w %d key %d" % [text, w, key.x])
		if text.length() == 1 and _code == "en":
			_ok(key == Vector2(TutorialCues.KEY, TutorialCues.KEY), "W A S D keep the 9 px key", text)
	var jump := Loc.t("tutorial.jump", "JUMP")
	var key := TutorialCues.key_size(font, jump, 29.0, true)
	var w := ceilf(font.get_string_size(jump, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	_ok(w + 2.0 * TutorialCues.KEY_PAD <= key.x, "touch JUMP key holds its word with KEY_PAD", "%s w %d key %d" % [jump, w, key.x])


# ------------------------------------------------------------------ helpers

func _start(c: Dictionary) -> Node:
	seed(20261017)
	progress.hard_mode = c.get("hard", false)
	progress.heat_mods = c.get("heat", 0)
	if c.get("descent", false):
		progress.start_descent(77)
		return await _spawn_game({})
	if c.get("random", false):
		progress.start_random()
		return await _spawn_game({})
	progress.start_story(c.level)
	return await _spawn_game({level = c.level})


## A vertically centred label's text starts this far under its rect's top.
func _valign_shift(label: Label) -> float:
	if label.vertical_alignment != VERTICAL_ALIGNMENT_CENTER:
		return 0.0
	var lines := label.text.split("\n").size()
	var h := lines * label.get_theme_font("font").get_height(label.get_theme_font_size("font_size")) + (lines - 1) * label.get_theme_constant("line_spacing")
	return floorf((label.size.y - h) / 2.0)


## Where a Label's text is: its widest line (as aligned) by its line boxes, + the marks drawn above and the
## drips under them, in screen coordinates.
func _text_rect(label: Label) -> Rect2:
	var r := _rect(label)
	var font := label.get_theme_font("font")
	var size := label.get_theme_font_size("font_size")
	var lines := label.text.split("\n")
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		lines.resize(label.get_line_count())
	var w := 0.0
	for line in label.text.split("\n"):
		w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	w = minf(w, r.size.x) if label.autowrap_mode != TextServer.AUTOWRAP_OFF else w
	var line_h := font.get_height(size)
	var h := lines.size() * line_h + (lines.size() - 1) * label.get_theme_constant("line_spacing")
	var x := r.position.x
	var align := label.horizontal_alignment
	if UIKit.is_mirrored(label) and align != HORIZONTAL_ALIGNMENT_CENTER:
		align = HORIZONTAL_ALIGNMENT_RIGHT if align == HORIZONTAL_ALIGNMENT_LEFT else HORIZONTAL_ALIGNMENT_LEFT
	match align:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += floorf((r.size.x - w) / 2.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - w
	var y := r.position.y + _valign_shift(label)
	var marks := UIKit.metrics()
	var small := size == UIKit.FONT
	var drips := float(marks.ink_below) if small else 2.0 * float(marks.ink_below)
	var above := float(UIKit.ink_above(label.text, size))
	return Rect2(x, y - above, w, h + above + drips)


func _rect(control: Control) -> Rect2:
	var xf := control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


func _frames(n: int) -> void:
	for i in n:
		await process_frame
