extends "res://tests/suite_base.gd"

## Fix pass R3 (docs/i18n/review/fixes-R3.md), checked in every locale (Arabic included) from the built
## controls and the station / font ink:
## - hub notice: two lines in es / pt_BR / fr / it / de (no line broken); GAP_XS+ clear of every side
##   station's ink in its resting frame (the one straight behind it doesn't count; GAP_S where its padding
##   is still PANEL_PAD), an idle animation that would come nearer (the wardrobe's door) held until the
##   notice has faded; GAP_S over the wheel; inside the screen; its side padding NOTICE_MIN_PAD+ (the text's
##   ink 1 clear column off the side lumps). English pinned.
## - upgrades COINS hint: a taller script's first ink GAP_XS clear rows under the last row's drips (the panel's
##   outline on _rows_bottom, its drips on the next row; the slimy font's line box under them), its last ink
##   over the bottom row; a note too wide for the
##   column broken at a balanced space (no one-word line in a language that spaces its words).
## - wardrobe try-on stage: in Arabic the slime's place mirrors about the stage (x' = w - x) and each east /
##   west step plays the sheet's west / east animation; the art is never flipped; English as it was.
## Throwaway save; the real save is never read or written.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 200000 -s res://tests/test_i18n_r3_layout.gd

const Report := preload("res://tests/i18n_report.gd")
const SCREEN := Rect2(0, 0, 320, 180)
const TWO_LINES := ["en", "es", "pt_BR", "fr", "it", "de"]
const NO_SPACES := ["ja", "zh_CN", "zh_TW", "th"]

var progress: Node
var language: Node
var _code := ""


func _initialize() -> void:
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
		await _hub_notice()
		await _coins_hint()
		await _showcase()
	language.set_locale("en")
	language.disable()
	Economy.languages_force = -1
	Economy.forced_locale = ""
	_result()
	quit(1 if failures else 0)


func _open(path: String) -> Node:
	var screen: Node = load(path).instantiate()
	root.add_child(screen)
	await _frames(3)
	return screen


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tag(what: String) -> String:
	return "%s: %s" % [_code, what]


# ------------------------------------------------------------------ hub notice

func _hub_notice() -> void:
	progress.tree_refund_notice = 888
	var hub := await _open("res://scenes/hub.tscn")
	hub.set_physics_process(false)
	var notice: PanelContainer = hub.tree_notice
	var box := Rect2(notice.global_position, notice.size)
	var labels: Array = notice.get_child(0).get_children()
	if _code in TWO_LINES:
		var broken := labels.any(func(label: Label) -> bool: return label.text.contains("\n"))
		_check(not broken, _tag("hub notice: two lines (no line broken)"))
	var top := int(box.position.y)
	var bottom := int(box.end.y)
	var clear := true
	var held := true
	var what := ""
	for station: Dictionary in hub.stations:
		if station.flat:
			continue
		var rest: Array = [0] if not station.anims.is_empty() else range(maxi(1, station.frames))
		var cols: Vector2 = hub._station_ink_cols(station, top, bottom, rest)
		if cols.x > cols.y or (cols.x <= 160.0 and cols.y >= 160.0):
			continue  # (no ink on its rows, or the station straight behind it)
		var gap: int = UIKit.GAP_S if notice.get_theme_stylebox("panel").get_margin(SIDE_LEFT) == UIKit.PANEL_PAD else UIKit.GAP_XS
		if not (cols.y + gap < box.position.x or cols.x - gap >= box.end.x):
			clear = false
			what = "%s ink %s" % [station.id, cols]
		for anim: Dictionary in station.anims:
			var frames: Array = range(maxi(1, station.frames))
			if anim.has("seq"):
				frames = anim.seq.map(func(step: Array) -> int: return step[0])
			var reach: Vector2 = hub._station_ink_cols(station, top, bottom, frames)
			if reach.x <= reach.y and not (reach.y + UIKit.GAP_XS < box.position.x or reach.x - UIKit.GAP_XS >= box.end.x):
				held = held and anim.next >= hub.TREE_NOTICE_TIME
	_check(clear, _tag("hub notice %s clear of the side stations' resting ink %s" % [box, what]))
	_check(held, _tag("hub notice: an idle animation reaching near it waits until it has faded"))
	var wheel_top: float = hub.rotor.position.y + hub.rotor.offset.y
	_check(box.end.y <= wheel_top - UIKit.GAP_S and SCREEN.encloses(box), _tag("hub notice %s inside the screen, GAP_S over the wheel (%d)" % [box, wheel_top]))
	var style := notice.get_theme_stylebox("panel")
	_check(style.get_margin(SIDE_LEFT) >= hub.NOTICE_MIN_PAD and style.get_margin(SIDE_RIGHT) >= hub.NOTICE_MIN_PAD, _tag("hub notice: side padding NOTICE_MIN_PAD+"))
	if _code == "en":
		_check(box == Rect2(98, 24, 124, 30) and style.get_margin(SIDE_LEFT) == UIKit.PANEL_PAD, _tag("hub notice: the English box %s" % box))
	hub.free()
	progress.tree_refund_notice = 0


# ------------------------------------------------------------------ upgrades COINS hint

func _coins_hint() -> void:
	var upg := await _open("res://scenes/upgrades.tscn")
	upg.show_page("coins")
	await _frames(2)
	var hint: Label = upg.hint
	var lines := hint.text.split("\n")
	var font := hint.get_theme_font("font")
	var rows_bottom: int = upg._rows_bottom["coins"]
	var y := hint.global_position.y
	if hint.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var line_h := int(font.get_height(UIKit.FONT)) if hint.has_theme_font_override("font") else UIKit.line_h()
		var first := int(y) + UIKit.ink_rows([lines[0]], font).x
		var last := int(y) + (lines.size() - 1) * (line_h + UIKit.line_spacing()) + UIKit.ink_rows([lines[-1]], font).y
		if UIKit.tall_script():  # (a script font's ink as shaped; the slimy font's marks: line box under the drips)
			_check(first >= rows_bottom + 2 + UIKit.GAP_XS, _tag("upgrades COINS hint: first ink row %d, GAP_XS clear under the drips (row %d)" % [first, rows_bottom + 1]))
		else:
			_check(y >= rows_bottom + 2, _tag("upgrades COINS hint: line box from row %d, under the drips (row %d)" % [y, rows_bottom + 1]))
		_check(last < UIKit.bottom_row_y(), _tag("upgrades COINS hint: last ink row %d over the bottom row (%d)" % [last, UIKit.bottom_row_y()]))
		var column := UIKit.SCREEN.x - 2.0 * UIKit.EDGE
		for line in lines:
			_check(UIKit.text_w(line) <= column, _tag("upgrades COINS hint: line inside the column"))
			if _code not in NO_SPACES and lines.size() > 2:
				_check(line.strip_edges().contains(" "), _tag("upgrades COINS hint: no one-word line (%s)" % line))
	upg.free()


# ------------------------------------------------------------------ wardrobe try-on stage

func _showcase() -> void:
	var skins := await _open("res://scenes/skins.tscn")
	skins.show_page("skins")
	await _frames(2)
	var stage: SkinShowcase = skins.showcase
	var mirrored := _code == "ar"
	var ok := true
	var t := 0.0
	for step: Array in SkinShowcase.ROUTINE:
		stage._time = t + step[1] * 0.5
		stage._pose()
		var x: float = roundf(lerpf(step[2], step[3], 0.5))
		var want_x: float = SkinShowcase.STAGE_SIZE.x - x if mirrored else x
		var anim: String = step[0]
		if mirrored:
			anim = SkinShowcase._mirror_anim(anim)
		ok = ok and is_equal_approx(stage.slime.position.x, roundf(want_x)) and stage.slime.animation == anim
		ok = ok and not stage.slime.flip_h and stage.slime.scale.x > 0.0
		t += step[1]
	_check(ok, _tag("wardrobe try-on: the slime's place %s, the art unflipped" % ("mirrored" if mirrored else "as English")))
	skins.free()
