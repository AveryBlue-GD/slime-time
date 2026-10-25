extends Control

## ACHIEVEMENTS page (IMP-07, from the hub's Esc menu): the pooled MEDALS line ("MEDALS 23 / NEXT REWARD AT 30"),
## then Achievements.PER_PAGE goals per page, a check box before each: gold with a check when unlocked, dim with
## its goal text when locked. NEXT PAGE (right edge of the bottom row) cycles the pages; BACK or Esc / B returns to
## the hub. Layout: header on the line under the title's box, rows ROW_H apart from ROWS_TOP, page count centred
## on the bottom row (all pixel numbers in docs/ui-rules.md terms: EDGE-wide margins, 8 px font).

const ROW_H := 12
const MARK := 7
const HEADER_GAP := 4

var page := 0
var rows: Array[Control] = []
var header: Label
var count_label: Label
var back_button: Button
## Where BACK / Esc goes: the scene that opened this page (SETTINGS sets it), the hub when empty. Read once per visit.
static var back_scene := ""
var _back_to := UIKit.HUB_SCENE
var next_button: Button
## The page arrows beside the page count (touch-sized; LEFT / RIGHT turn too).
var prev_arrow: Button
var next_arrow: Button
var _row_root: Control


## UI-27: a goal's mark, no box: a small gold tick when met (7x7 cell), a small dim dot when not.
class Mark extends Control:
	var on := false

	func _draw() -> void:
		if not on:
			draw_rect(Rect2(MARK / 2 - 1, MARK / 2 - 1, 2, 2), UIKit.TEXT_OFF)
			return
		for p: Vector2i in [Vector2i(0, 3), Vector2i(1, 4), Vector2i(2, 5), Vector2i(3, 4), Vector2i(4, 3), Vector2i(5, 2), Vector2i(6, 1)]:
			draw_rect(Rect2(p.x, p.y, 1, 1), UIKit.GOLD)
		for p: Vector2i in [Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(5, 1)]:
			draw_rect(Rect2(p.x, p.y, 1, 1), UIKit.GOLD.darkened(0.25))  # (the tick's under edge: 2 px thick, not a hairline)


## IMP4-07 (BEN3-06 light): the reward road, one strip above the bottom row: WINS 0..100 as a track (gold up to your
## randomizer wins, dim after), a short tick at each pastel skin's win count, a tall tick and the number at each win
## goal (10 25 50 100), and a bright block where you are. Whole pixels only; 8 px numbers.
class Road extends Control:
	var wins := 0

	func _draw() -> void:
		var y := 3
		var x0 := 0
		var span := int(size.x) - 1
		var here := roundi(float(span) * clampf(float(wins) / ROAD_MAX, 0.0, 1.0))
		draw_rect(Rect2(x0, y, span + 1, 1), UIKit.TEXT_OFF)
		draw_rect(Rect2(x0, y, here, 1), UIKit.GOLD)
		for mark in Skins.pastel_marks():
			var x := roundi(float(span) * float(mark) / ROAD_MAX)
			draw_rect(Rect2(x, y - 1, 1, 3), UIKit.GOLD if wins >= mark else UIKit.TEXT_OFF)
		for mark in ROAD_GOALS:
			var x := roundi(float(span) * float(mark) / ROAD_MAX)
			draw_rect(Rect2(x, y - 2, 1, 5), UIKit.GOLD if wins >= mark else UIKit.TEXT_DIM)
		draw_rect(Rect2(here - 1, y - 2, 3, 5), UIKit.TEXT)  # (you are here)

const ROAD_MAX := 100.0
const ROAD_GOALS: Array[int] = [10, 25, 50, 100]


## A goal with a reward cosmetic is a taller row (a second line: REWARD: <name>); a page holds PAGE_H px of rows.
const REWARD_EXTRA := 9
const PAGE_H := 88  # (was 100: the reward road strip sits under the band, IMP4-07)


## The pages: lists of goal indexes, filled in order until PAGE_H px of rows are used.
static func pages() -> Array:
	var out: Array = []
	var cur: Array[int] = []
	var h := 0
	var all := Achievements.list()
	for i in all.size():
		var row_h := ROW_H + (REWARD_EXTRA if Achievements.reward_for(all[i].id) != "" else 0)
		if h + row_h > PAGE_H and not cur.is_empty():
			out.append(cur)
			cur = []
			h = 0
		cur.append(i)
		h += row_h
	if not cur.is_empty():
		out.append(cur)
	return out


static func page_count() -> int:
	return pages().size()


## The header text: the medals earned (both modes) and the next milestone reward with the count it waits at.
static func header_text(p: Node) -> String:
	var earned := Achievements.medals_earned(p)
	var next := Achievements.next_milestone(earned)
	if next == 0:
		# i18n: ACHIEVEMENTS page header, max 296px, 1 line; {n} = medals earned (every medal milestone reward is won)
		return Loc.t("ach.header_done", "MEDALS {n} / ALL MEDAL REWARDS WON", {n = earned})
	var reward_name := ""
	for m: Dictionary in Achievements.MILESTONES:
		if int(m.medals) == next:
			reward_name = Cosmetics.display_name(m.cosmetic)
	# i18n: ACHIEVEMENTS page header, max 296px, 1 line; {n} = medals earned (any tier, normal + hard), {name} = the next milestone's cosmetic, {next} = its medal count
	return Loc.t("ach.header_next", "MEDALS {n} / NEXT: {name} AT {next}", {n = earned, name = reward_name, next = next})


## The goo panel's top and height: the rows sit panel_v_margins() inside it (clear of the band and its lumps).
static func _band_top() -> int:
	return UIKit.title_bottom() + HEADER_GAP + UIKit.line_h() + UIKit.GAP_L - UIKit.GAP_XS


static func _panel_h() -> int:
	var m := UIKit.panel_v_margins()
	return m.x + PAGE_H + m.y


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("ach.title", "ACHIEVEMENTS"))  # i18n: page title, max 296px, 16 px font
	if back_scene != "":
		_back_to = back_scene
		back_scene = ""
	back_button = UIKit.add_back_button(self, func() -> void: UIKit.go(get_tree(), _back_to))
	var p: Node = get_node("/root/Progress")
	p.mark_achievements_seen()
	header = UIKit.add_label(self, header_text(p), Rect2(0, UIKit.title_bottom() + HEADER_GAP, UIKit.SCREEN.x, UIKit.line_h()), UIKit.FONT, UIKit.TEXT_DIM)
	# UI-07: the list sits in a goo panel (not an unbordered black slab).
	var band_top := _band_top()
	var band := UIKit.add_panel(self, Rect2(UIKit.EDGE, band_top, UIKit.SCREEN.x - 2 * UIKit.EDGE, _panel_h()))
	_row_root = Control.new()
	add_child(_row_root)
	_add_road(p)
	# i18n: button, max 70px, 1 line; shows the next page of achievements (wraps to the first)
	var next_text := Loc.t("ach.next", "NEXT PAGE")
	next_button = UIKit.make_button(next_text, func() -> void: _turn(1), UIKit.button_size(next_text, 0))  # (UI-30: the text plus BUTTON_TEXT_PAD each side)
	add_child(next_button)
	UIKit.place_bottom_row(next_button, 1)
	count_label = UIKit.add_label(self, "", Rect2(0, UIKit.bottom_row_y(), UIKit.SCREEN.x, UIKit.button_h()), UIKit.FONT, UIKit.TEXT)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var arrow_size := Vector2(24, UIKit.button_h())
	prev_arrow = UIKit.make_button("<", func() -> void: _turn(-1), arrow_size)  # i18n: ignore (an arrow glyph)
	next_arrow = UIKit.make_button(">", func() -> void: _turn(1), arrow_size)  # i18n: ignore (an arrow glyph)
	add_child(prev_arrow)
	add_child(next_arrow)
	_show_page()
	(next_button if page_count() > 1 else back_button).grab_focus()


## The reward road strip (see Road), between the list's band and the bottom row.
func _add_road(p: Node) -> void:
	var y := _band_top() + _panel_h() + UIKit.GAP_XS
	var label_w := UIKit.text_w("WINS") + UIKit.GAP_L  # i18n: ignore (measuring only)
	var left := UIKit.EDGE + UIKit.GAP_L
	var road_label := UIKit.add_label(self, Loc.t("ach.road", "WINS"), Rect2(left, y, label_w, UIKit.line_h()), UIKit.FONT, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)  # i18n: ACHIEVEMENTS page, the reward road's label (randomizer wins), max 40px, 1 line
	road_label.set_meta("road", "label")
	var x0 := left + label_w
	var road := Road.new()
	road.wins = p.randoms_won
	road.position = Vector2(x0, y)
	road.size = Vector2(UIKit.SCREEN.x - UIKit.EDGE - UIKit.GAP_L - 10 - x0, UIKit.line_h())
	road.mouse_filter = Control.MOUSE_FILTER_IGNORE
	road.set_meta("road", "track")
	add_child(road)
	for mark in ROAD_GOALS:
		var text := str(mark)  # i18n: ignore (numbers only)
		var w := UIKit.text_w(text)
		var cx := x0 + roundi(road.size.x - 1.0) * mark / int(ROAD_MAX)
		# (UI-30: the numbers sit 2 clear rows under the ticks, which end on row y + 5)
		var number := UIKit.add_label(self, text, Rect2(cx - w / 2 if mark < 100 else cx - w + 1, y + 8, w, UIKit.line_h() - 5), UIKit.FONT, UIKit.GOLD if p.randoms_won >= mark else UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		number.set_meta("road", "number")


func _turn(step: int) -> void:
	page = posmod(page + step, page_count())
	_show_page()


func _show_page() -> void:
	var p: Node = get_node("/root/Progress")
	for r in rows:
		r.queue_free()
	rows.clear()
	var all := Achievements.list()
	var top := _band_top() + UIKit.panel_v_margins().x
	var unlocked := 0
	for a in all:
		if Achievements.met(p, a.id):
			unlocked += 1
	var y := top
	for i: int in pages()[page]:
		var a: Dictionary = all[i]
		var on := Achievements.met(p, a.id)
		var row := Control.new()
		row.set_meta("id", a.id)
		row.set_meta("unlocked", on)
		_row_root.add_child(row)
		row.position = Vector2(0, y)
		var reward := Achievements.reward_for(a.id)
		y += ROW_H + (REWARD_EXTRA if reward != "" else 0)
		if reward != "":
			var x := UIKit.GAP_L * 2 + MARK + UIKit.GAP_L
			# i18n: ACHIEVEMENTS page, a goal's reward line, max 200px, 1 line; {name} = the cosmetic it grants (e.g. NIGHT PAPER)
			var reward_text := Loc.t("ach.reward", "REWARD: {name}", {name = Cosmetics.display_name(reward)})
			var reward_label := UIKit.add_label(row, reward_text, Rect2(x, ROW_H - 3, UIKit.SCREEN.x - x - UIKit.GAP_L * 2, UIKit.line_h()),
				UIKit.FONT, UIKit.GOLD if on else UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
			reward_label.set_meta("reward", true)
		var mark := Mark.new()
		mark.on = on
		mark.size = Vector2(MARK, MARK)
		row.add_child(mark)
		mark.position = Vector2(UIKit.GAP_L * 2, (UIKit.line_h() - MARK) / 2)
		var label := UIKit.add_label(row, a.goal, Rect2(UIKit.GAP_L * 2 + MARK + UIKit.GAP_L, 0, UIKit.SCREEN.x - 2 * UIKit.GAP_L * 2 - MARK - UIKit.GAP_L, UIKit.line_h()),
			UIKit.FONT, UIKit.GOLD if on else UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
		label.set_meta("goal", true)
		var count := Achievements.progress(p, a.id)
		if count.y > 0:  # a goal with a number: "23/50" at the right edge
			var count_text := "%d/%d" % [count.x, count.y]  # i18n: ignore (numbers only)
			var width := UIKit.text_w(count_text)
			UIKit.add_label(row, count_text, Rect2(UIKit.SCREEN.x - UIKit.GAP_L * 2 - width, 0, width, UIKit.line_h()),
				UIKit.FONT, UIKit.GOLD if on else UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		rows.append(row)
	# i18n: ACHIEVEMENTS page footer, max 150px, 1 line; {page} / {pages} = this page and the page count, {n} / {total} = unlocked and all goals
	count_label.text = Loc.t("ach.count", "{n}/{total}  PAGE {page}/{pages}", {n = unlocked, total = all.size(), page = page + 1, pages = page_count()})
	var half := UIKit.text_w(count_label.text) / 2.0 + UIKit.GAP_M
	var arrow_y := float(UIKit.bottom_row_y())
	prev_arrow.position = Vector2(UIKit.SCREEN.x / 2.0 - half - prev_arrow.size.x, arrow_y)
	next_arrow.position = Vector2(UIKit.SCREEN.x / 2.0 + half, arrow_y)
	prev_arrow.visible = page_count() > 1
	next_arrow.visible = page_count() > 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UIKit.go(get_tree(), _back_to)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_turn(1 if event.is_action_pressed("ui_right") else -1)
