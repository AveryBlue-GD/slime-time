extends "res://tests/suite_base.gd"

## Fix pass R1 (docs/i18n/review/fixes-R1.md), in every locale (Arabic included):
## - pause SEED: English keeps its old 92 px cutoff (a "SEED code" of 91-92 px still shows SEED), a
##   translation BUTTON_TEXT_PAD each side (90 px);
## - HUD intro texts: beside a pod side_clearance() (English 2 = TEXT_CLEARANCE, else 12); once the slime
##   has left its spawn (release_player_rect) a re-placement (a pod change, the pause menu or the restart
##   prompt closing) never moves them up or onto another place; th L10's story line above the slime,
##   its glyphs' ink >= 2 rows over the slime's drawn top, as before F2;
## - results: every result panel covers the slime's drawn body whole or does not touch the slime's rect
##   (randomizer win, L3 / L10 wins, dry-up);
## - pause (Descent): the note's first ink NOTE_ROOM (English's 18) under the panel, its last ink by row 176;
##   the VOLUME slider as long as English's (the column widens for LAUTSTÄRKE);
## - Descent boon card: the 2x icons in every Latin / Cyrillic / Vietnamese locale for the captured offer
##   (pl, vi drew 1x), every face inside its tile (icon from row 3, drips over the bottom band), a slash
##   run never broken at its slash (id `+1 TIKET/LANTAI`); zh_TW's title digit in its script font's height;
## - RESTART?: its box GAP_L clear of every HUD pod beside it, the panel 2 px under the title, by row 176.
## English pinned: the pause Descent note at 150, SEED cutoff 92, RESTART? at 30, the HUD intro tops.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_r1_layout.gd
## English-only mode (tests/i18n_mode.gd): a check made while a non-English locale is set is reported, not failed.
const I18N_PER_LOCALE := true

const Report := preload("res://tests/i18n_report.gd")
const Hud := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const BOTTOM := 176.0
## The boon offer the captures show (tests/test_i18n_screens.gd, seed 20261017 / run 77).
const CAPTURED_OFFER: Array[String] = ["rubber", "sense", "greedy"]
## Locales whose captured boon faces cannot hold a 2x icon even with PICK ONE on the status line
## (pseudo: six-line faces, 88 rows of content in an 89-row tile less its marks and drips).
const SMALL_ICON_OK: Array[String] = ["pseudo"]
## Result states whose panel can neither cover the slime's idle body (rows at-7 .. at+6) nor clear it inside
## its room (pods above, the banner's marks or the choice row below), checked in the captures instead:
## vi / hi L3 end 3 rows over the idle body's last row and hide the drawn celebrate pose whole; ar's
## and hi randomizer wins show the slime's top over the panel (their two-line pods push it to row 74-75).
## "en dry" / "id dry": the one-line DRIED UP panel (since HEAT's two-line OUT OF TIME! went, 2026-10-20) overlaps the
## slime's top rows here only because the test's slime never left the spawn cell; same placement as before HEAT.
const SLIME_ROOM_OK: Array[String] = ["vi L3", "hi L3", "ar random", "hi random", "en dry", "id dry"]

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
		await _seed_cutoff()
		await _intro_texts()
		await _results()
		await _pause_note()
		await _boon_card()
		await _restart_prompt()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	Economy.descent_force = -1
	progress.hard_mode = false
	var names := {}
	for key: String in _seen:
		names[key.get_slice("|", 1)] = true
	for name: String in names:
		var bad := PackedStringArray()
		for key: String in _seen:
			if key.get_slice("|", 1) == name and _seen[key] != "":
				bad.append("%s (%s)" % [key.get_slice("|", 0), _seen[key]])
		_check(bad.is_empty(), name + ("" if bad.is_empty() else ": " + ", ".join(bad.slice(0, 4))))
	_result()
	quit(1 if failures else 0)


## One check per locale and name (the first failure's detail is kept).
func _ok(ok: bool, name: String, detail := "") -> void:
	var key := "%s|%s" % [_code, name]
	if not _seen.has(key):
		_seen[key] = ""
	if not ok and _seen[key] == "":
		_seen[key] = detail if detail != "" else "failed"


# ------------------------------------------------------------------ (a) SEED cutoff

func _seed_cutoff() -> void:
	var want := 92 if _code == "en" else 90
	_ok(PauseMenu.seed_text_max() == want, "pause SEED cutoff: English 92 px, a translation 90", str(PauseMenu.seed_text_max()))
	if _code != "en":
		return
	# A code whose "SEED code" is 91 or 92 px: English still shows SEED (it fits its old 4 px margins).
	var found := ""
	for ones in range(0, 12):
		for zeros in range(0, 12):
			for tail in ["", "-1", "-0"]:
				var c: String = "1".repeat(ones) + "0".repeat(zeros) + tail
				var w := UIKit.text_w(Loc.t("pause.seed", "SEED {code}", {code = c}))
				if w > 90 and w <= 92:
					found = c
	_ok(found != "", "pause SEED: a 91-92 px text exists to try")
	if found != "":
		seed(20261017)
		progress.start_random()
		var game := await _spawn_game({})
		var menu = game.pause_menu
		_ok(menu.seed_text(found).begins_with("SEED"), "pause SEED: English keeps SEED up to 92 px", "%s %d" % [found, UIKit.text_w("SEED " + found)])
		_ok(menu.seed_text("4294967295-7") == "4294967295-7", "pause SEED: a 10-digit seed shows the code alone")
		game.free()


# ------------------------------------------------------------------ (b) (c) HUD intro texts

func _intro_texts() -> void:
	_ok(Hud.side_clearance() == (Hud.TEXT_CLEARANCE if _code == "en" else Hud.TEXT_SIDE_CLEARANCE), "HUD side clearance: English 2, a translation 12")
	for c: Dictionary in [{level = 1}, {level = 10}, {level = 8, assist = true}, {level = 7, hard = true}]:
		var game := await _start(c)
		if c.get("assist", false):
			game.hud.set_assist(true)
		await _frames(3)
		var hud = game.hud
		var area: float = hud.area_label.offset_top
		var story: float = hud.story_label.offset_top
		# The slime leaves its spawn; then the pause menu, the restart prompt and a pod change re-place
		# the texts: they keep their rows (no pod moved).
		game.slime.position += Vector2(16, 0)
		await physics_frame
		await physics_frame
		_ok(not hud.player_rect_live, "HUD: the spawn rect released once the slime moves")
		game.pause_menu.open()
		await _frames(1)
		game.pause_menu.resume()
		paused = false
		game.restart_prompt.open()
		await _frames(1)
		game.restart_prompt.close()
		paused = false
		hud._pods_changed()
		await _frames(1)
		_ok(hud.area_label.offset_top == area and hud.story_label.offset_top == story, "HUD: intro texts stay put after the slime left its spawn",
			"L%d %d/%d -> %d/%d" % [c.level, area, story, hud.area_label.offset_top, hud.story_label.offset_top])
		# A pod showing mid-level only ever moves them down (here: ASSIST where it was not shown).
		if not c.get("assist", false):
			hud.set_assist(true)
			await _frames(1)
			_ok(hud.area_label.offset_top >= area and hud.story_label.offset_top >= story, "HUD: a pod showing mid-level never moves the texts up",
				"L%d %d/%d -> %d/%d" % [c.level, area, story, hud.area_label.offset_top, hud.story_label.offset_top])
		if _code == "th" and c.level == 10:
			var rect: Rect2 = hud.player_rect
			var texts: Array[String] = [hud.story_label.text]
			var rows := UIKit.ink_rows(texts, hud.story_label.get_theme_font("font"), UIKit.FONT, true)
			_ok(story + rows.y + 1 + Hud.TEXT_CLEARANCE <= rect.position.y + 1, "th L10: the story line above the slime (as before F2)",
				"story %d ink to %d, slime from %d" % [story, story + rows.y, rect.position.y + 1])
		game.free()
		progress.hard_mode = false


# ------------------------------------------------------------------ results

func _results() -> void:
	for c: Dictionary in [{level = 3, record = true}, {level = 10}, {level = 4, dry = true}, {random = true}]:
		var game := await _start(c)
		if c.get("dry", false):
			game._dry_up()
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
		var slime: Rect2 = hud.result_slime_rect
		var at: Vector2 = (game.slime.global_position - game.camera.get_screen_center_position() + UIKit.SCREEN / 2.0).round()
		var body := Rect2(at - Vector2(7, 7), Vector2(16, 14))  # (the slime's ink, measured: as test_i18n_f2_layout)
		_ok(slime.encloses(body), "result: the slime rect holds its drawn body", "%s %s" % [slime, body])
		var panel := _rect(hud._message_panel)
		var covers := panel.position.y <= body.position.y and panel.end.y >= body.end.y \
			and panel.position.x <= body.position.x and panel.end.x >= body.end.x
		var tag := "%s %s" % [_code, "random" if c.get("random", false) else ("dry" if c.get("dry", false) else "L%d" % c.level)]
		_ok(covers or not panel.intersects(slime) or tag in SLIME_ROOM_OK, "result panel covers the slime whole or keeps clear of it",
			"%s panel %s slime %s" % [c, panel, slime])
		game.free()


# ------------------------------------------------------------------ pause (Descent) note

func _pause_note() -> void:
	seed(20261017)
	progress.start_descent(77)
	var game := await _spawn_game({})
	await _frames(2)
	var menu = game.pause_menu
	menu.open()
	await _frames(2)
	var panel := _rect(menu._panel)
	var ink: Vector2i = menu._note_ink()
	var first: float = menu.descent_note.position.y + ink.x
	var last: float = menu.descent_note.position.y + ink.y
	_ok(first - panel.end.y >= PauseMenu.NOTE_ROOM, "pause: the Descent note NOTE_ROOM (English 18) under the panel",
		"panel end %d note ink %d..%d" % [panel.end.y, first, last])
	_ok(last <= BOTTOM, "pause: the Descent note by row 176", "note ink %d..%d" % [first, last])
	var slider: Control = menu.volume_row.get_meta("slider")
	var english := PauseMenu.COLUMN_W - PauseMenu.VOLUME_BOX_EXTRA - ceili(UIKit.font_for(UIKit.FONT).get_string_size("VOLUME", HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.FONT).x)
	_ok(slider.size.x >= english - 1 or menu._col_w == menu._column_w(menu.get_child(0)) and menu._col_w > PauseMenu.COLUMN_W,
		"pause: the VOLUME slider as long as English's", "slider %d english %d column %d" % [slider.size.x, english, menu._col_w])
	print("  pause %s: VOLUME slider %d px (English %d), column %d" % [_code, slider.size.x, english, menu._col_w])
	if _code == "en":
		_ok(menu.descent_note.position.y == PauseMenu.NOTE_Y and panel == Rect2(100, 55, 120, 77) and PauseMenu.NOTE_ROOM == 18,
			"pause: English Descent note and panel pinned", "%s note %d" % [panel, menu.descent_note.position.y])
	menu.resume()
	paused = false
	game.free()


# ------------------------------------------------------------------ Descent boon card

func _boon_card() -> void:
	seed(20261017)
	progress.start_descent(77)
	var game := await _spawn_game({})
	var card = game._ensure_card()
	card.show_boons(progress.descent_run, CAPTURED_OFFER)
	await _frames(2)
	var big := true
	for tile: Button in card.tiles:
		var r := _rect(tile)
		for child in tile.get_children():
			if child.is_queued_for_deletion():
				continue
			if child is TextureRect:
				big = big and child.size == Vector2(16, 16)
				_ok(UIKit.tall_script() or child.position.y >= 3, "boon card: the icon under the tile's goo lumps (row 3+)", "%s" % child.position)
			elif child is Label:
				var label := child as Label
				var lines := label.text.split("\n")
				for line in lines:
					_ok(not (line.ends_with("/") and lines.size() > 1), "boon card: a slash run kept whole", label.text.replace("\n", " | "))
				if not UIKit.tall_script() and "/" in label.text and UIKit.text_w(label.text.replace("\n", " ")) > TILE_ROOM:
					_ok("\n" in label.text and label.autowrap_mode == TextServer.AUTOWRAP_OFF, "boon card: a wide slash line broken at its spaces", label.text)
				var n := label.get_line_count()
				var bottom := _rect(label).position.y + n * UIKit.line_h() + (n - 1) * label.get_theme_constant("line_spacing") + float(UIKit.metrics().ink_below)
				_ok(UIKit.tall_script() or bottom <= r.end.y - 3, "boon card: the face's last drips over the tile's bottom band", "%s %d tile %s" % [label.text.left(12), bottom, r])
	if not UIKit.tall_script() and not _code in SMALL_ICON_OK:
		_ok(big, "boon card: 2x icons (the captured offer)")
	if _code == "en":
		_ok(_rect(card.tiles[0]).position.y == 47.0 and card.tiles[0].size.y == 78.0 and not card._pick_in_status, "boon card: English pinned")
	if _code == "zh_TW":
		var texts: Array[String] = ["1"]
		var rows := UIKit.ink_rows(texts, card.title.get_theme_font("font"), UIKit.FONT_BIG)
		_ok(rows.y - rows.x + 1 >= 16 and not Loc.SCRIPT_GAP in card.title.text, "boon card: zh_TW title digit in the script font (18 rows, not the slimy 14)",
			"rows %s" % rows)
	game.free()


const TILE_ROOM := 80.0


# ------------------------------------------------------------------ RESTART?

func _restart_prompt() -> void:
	for c: Dictionary in [{level = 3}, {random = true}]:
		var game := await _start(c)
		await _frames(2)
		var prompt: RestartPrompt = game.restart_prompt
		prompt.open()
		await _frames(2)
		var title := _rect(prompt._title)
		var w := float(UIKit.text_w(prompt._title.text, UIKit.FONT_BIG))
		var box := Rect2(floorf((320.0 - w) / 2.0), title.position.y - UIKit.mark_rows(prompt._title.text, UIKit.FONT_BIG), w, UIKit.title_h())
		if _code != "en":
			for pod: Rect2 in game.hud.pod_rects():
				_ok(not box.grow_individual(UIKit.GAP_L, 0, UIKit.GAP_L, 0).intersects(pod), "RESTART? GAP_L clear of the HUD pods beside it", "%s pod %s" % [box, pod])
		var panel := _rect(prompt._panel)
		_ok(panel.position.y == title.position.y + UIKit.title_h() + 2 and panel.end.y <= BOTTOM, "RESTART? panel 2 px under the title, by row 176", "%s %s" % [title, panel])
		if _code == "en":
			_ok(title.position.y == RestartPrompt.TITLE_Y, "RESTART? English title pinned at 30")
		prompt.close()
		paused = false
		game.free()


# ------------------------------------------------------------------ helpers

func _start(c: Dictionary) -> Node:
	seed(20261017)
	progress.hard_mode = c.get("hard", false)
	if c.get("random", false):
		progress.start_random()
		return await _spawn_game({})
	progress.start_story(c.level)
	return await _spawn_game({level = c.level})


func _rect(control: Control) -> Rect2:
	var xf := control.get_global_transform_with_canvas()
	return Rect2(xf.origin, control.size * xf.get_scale())


func _frames(n: int) -> void:
	for i in n:
		await process_frame
