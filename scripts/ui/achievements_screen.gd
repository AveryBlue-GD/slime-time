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
var next_button: Button
## The page arrows beside the page count (touch-sized; LEFT / RIGHT turn too).
var prev_arrow: Button
var next_arrow: Button
var _row_root: Control


## A 7x7 check box: outline, and a pixel-art check inside when `on`.
class Mark extends Control:
	var on := false

	func _draw() -> void:
		var c := UIKit.GOLD if on else UIKit.TEXT_OFF
		draw_rect(Rect2(0, 0, MARK, 1), c)
		draw_rect(Rect2(0, MARK - 1, MARK, 1), c)
		draw_rect(Rect2(0, 0, 1, MARK), c)
		draw_rect(Rect2(MARK - 1, 0, 1, MARK), c)
		if on:
			for p: Vector2i in [Vector2i(1, 3), Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 2), Vector2i(5, 1)]:
				draw_rect(Rect2(p.x, p.y, 1, 1), c)
			draw_rect(Rect2(2, 3, 1, 1), c)
			draw_rect(Rect2(3, 4, 1, 1), c)


## A goal with a reward cosmetic is a taller row (a second line: REWARD: <name>); a page holds PAGE_H px of rows.
const REWARD_EXTRA := 9
const PAGE_H := 100


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


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("ach.title", "ACHIEVEMENTS"))  # i18n: page title, max 296px, 16 px font
	back_button = UIKit.add_back_button(self)
	var p: Node = get_node("/root/Progress")
	p.mark_achievements_seen()
	header = UIKit.add_label(self, header_text(p), Rect2(0, UIKit.title_bottom() + HEADER_GAP, UIKit.SCREEN.x, UIKit.line_h()), UIKit.FONT, UIKit.TEXT_DIM)
	# A dark band behind the list, so the dim goals read against the room's colour.
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.5)
	var band_top := UIKit.title_bottom() + HEADER_GAP + UIKit.line_h() + UIKit.GAP_L - UIKit.GAP_XS
	band.position = Vector2(UIKit.EDGE, band_top)
	band.size = Vector2(UIKit.SCREEN.x - 2 * UIKit.EDGE, PAGE_H + 2 * UIKit.GAP_XS)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_row_root = Control.new()
	add_child(_row_root)
	# i18n: button, max 70px, 1 line; shows the next page of achievements (wraps to the first)
	next_button = UIKit.make_button(Loc.t("ach.next", "NEXT PAGE"), func() -> void: _turn(1))
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


func _turn(step: int) -> void:
	page = posmod(page + step, page_count())
	_show_page()


func _show_page() -> void:
	var p: Node = get_node("/root/Progress")
	for r in rows:
		r.queue_free()
	rows.clear()
	var all := Achievements.list()
	var top := UIKit.title_bottom() + HEADER_GAP + UIKit.line_h() + UIKit.GAP_L
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
		UIKit.go(get_tree(), UIKit.HUB_SCENE)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_turn(1 if event.is_action_pressed("ui_right") else -1)
