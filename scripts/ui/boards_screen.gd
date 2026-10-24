extends Control

## BOARDS page (BM-03, Economy.BOARDS_TEST; local only): today's top 5 daily times and this week's top 5 weekly times (yours), your
## best daily ever, and the buttons that start either maze plus the GHOST on/off toggle. Reached from the hub's DAILY sign and
## SETTINGS; BACK / Esc / B returns there. Columns: two COL_W-wide lists under the title, one ROW_H row per place.

const ROW_H := 12
const COL_W := 148
const HEADER_GAP := 4
const GAME_SCENE := "res://scenes/main.tscn"

## Where BACK / Esc goes: the scene that opened this page (SETTINGS sets it), the hub when empty. Read once per visit.
static var back_scene := ""
var _back_to := UIKit.HUB_SCENE
var back_button: Button
var daily_button: Button
var weekly_button: Button
var ghost_button: Button
var rows: Array[Label] = []
var footer: Label
var empty_note: Label


## The text of one place on a board: "1  0:32.40  10-24" ("-" while empty). `weekly`: the date is the day of the week it was set.
static func row_text(rank: int, board: Array, key: int, weekly: bool) -> String:
	if rank > board.size():
		return "%d  -" % rank  # i18n: ignore (a place number and a dash)
	var e: int = board[rank - 1]
	var date := Time.get_date_dict_from_unix_time(Boards.entry_day(e, key, weekly) * 86400)
	# i18n: boards row, month-day of a time you set; {m} = month 1-12, {d} = day 1-31; 8 chars at most
	var day_text := Loc.t("boards.date", "{m}-{d}", {m = date.month, d = date.day})
	return "%d  %s  %s" % [rank, UIKit.format_time(Boards.entry_ms(e) / 1000.0), day_text]  # i18n: ignore (place, time, date)


static func ghost_text(on: bool) -> String:
	# i18n: boards button, max 70px, 1 line; the ghost of your best run (a translucent slime racing you) is shown
	return Loc.t("boards.ghost_on", "GHOST ON") if on else Loc.t("boards.ghost_off", "GHOST OFF")  # i18n: boards button, max 70px, 1 line; the ghost is hidden


func _ready() -> void:
	UIKit.setup_screen(self, Loc.t("boards.title", "BOARDS"))  # i18n: page title, max 296px, 16 px font
	if back_scene != "":
		_back_to = back_scene
		back_scene = ""
	back_button = UIKit.add_back_button(self, func() -> void: UIKit.go(get_tree(), _back_to))
	var p: Node = get_node("/root/Progress")
	var today: int = p.utc_day()
	var week := Boards.week_of(today)
	var top := UIKit.title_bottom() + HEADER_GAP
	var safe := UIKit.safe_rect()
	var x_left := safe.position.x + UIKit.EDGE + UIKit.GAP_L
	var x_right := safe.end.x - UIKit.EDGE - UIKit.GAP_L - COL_W
	# i18n: boards column header, max 140px, 1 line; {n} = today's daily number
	_column(x_left, top, Loc.t("boards.daily", "DAILY #{n}", {n = p.daily_number(today)}), p.board_for("daily", today), today, false)
	# i18n: boards column header, max 140px, 1 line; {n} = this week's weekly number
	var days_left: int = clampi(Boards.week_start(week) + 7 - today, 1, 7)  # (the weekly's last day is Sunday: 1 = today)
	# i18n: boards column header, max 148px, 1 line; {n} = this week's weekly number, {d} = days left in the week incl. today (1..7)
	_column(x_right, top, Loc.t("boards.weekly_ends", "WEEKLY #{n}  ENDS IN {d}D", {n = Boards.weekly_number(week), d = days_left}), p.board_for("weekly", week), week, true)
	if p.board_for("daily", today).is_empty() and p.board_for("weekly", week).is_empty():
		var row_y := top + UIKit.line_h() + HEADER_GAP + 2 * ROW_H + 2
		# i18n: boards page when no time is kept yet, max 296px, 1 line
		empty_note = UIKit.add_label(self, Loc.t("boards.empty", "YOUR BEST TIMES LIVE HERE. PLAY DAILY TO START"), Rect2(0, row_y, UIKit.SCREEN.x, UIKit.line_h()), UIKit.FONT, UIKit.TEXT_DIM)
	var best_y := top + UIKit.line_h() + HEADER_GAP + Economy.BOARD_TOP * ROW_H + UIKit.GAP_L
	var best_text := UIKit.format_time(p.board_best_daily_ms / 1000.0) if p.board_best_daily_ms > 0 else "-"  # i18n: ignore (a time or a dash)
	# i18n: boards footer, max 296px, 1 line; {time} = your best daily time ever (M:SS.cc, or a dash)
	footer = UIKit.add_label(self, Loc.t("boards.best", "BEST DAILY {time}", {time = best_text}), Rect2(0, best_y, UIKit.SCREEN.x, UIKit.line_h()), UIKit.FONT, UIKit.GOLD)
	# i18n: boards button, max 70px, 1 line; starts today's daily maze
	daily_button = _bottom_button(Loc.t("boards.play_daily", "PLAY DAILY"), _play_daily, 70)
	# i18n: boards button, max 80px, 1 line; starts this week's weekly maze
	weekly_button = _bottom_button(Loc.t("boards.play_weekly", "PLAY WEEKLY"), _play_weekly, 80)
	ghost_button = _bottom_button(ghost_text(p.ghost_on), _toggle_ghost, 62)
	# the bottom row, right to left: PLAY WEEKLY, PLAY DAILY, GHOST (BACK is on the left)
	var y := float(UIKit.bottom_row_y())
	var x := safe.end.x - UIKit.EDGE
	for b: Button in [weekly_button, daily_button, ghost_button]:
		x -= b.size.x
		b.position = Vector2(x, y)
		x -= UIKit.GAP_M
	daily_button.grab_focus()


func _bottom_button(text: String, on_press: Callable, min_w: int) -> Button:
	var b := UIKit.make_button(text, on_press, UIKit.button_size(text, min_w))
	UIKit.note_text_w(b, [text], min_w)
	add_child(b)
	b.size = b.custom_minimum_size
	return b


func _column(x: float, top: float, header: String, board: Array, key: int, weekly: bool) -> void:
	UIKit.add_label(self, header, Rect2(x, top, COL_W, UIKit.line_h()), UIKit.FONT, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	var y := top + UIKit.line_h() + HEADER_GAP
	for rank in range(1, Economy.BOARD_TOP + 1):
		var label := UIKit.add_label(self, row_text(rank, board, key, weekly), Rect2(x, y, COL_W, UIKit.line_h()),
			UIKit.FONT, UIKit.TEXT if rank <= board.size() else UIKit.TEXT_OFF, HORIZONTAL_ALIGNMENT_LEFT)
		label.set_meta("rank", rank)
		label.visible = rank <= board.size() + 1  # (the first empty place shows, the ones after it wait)
		rows.append(label)
		y += ROW_H


func _play_daily() -> void:
	var p: Node = get_node("/root/Progress")
	p.start_daily()
	UIKit.go(get_tree(), GAME_SCENE)


func _play_weekly() -> void:
	var p: Node = get_node("/root/Progress")
	p.start_weekly()
	UIKit.go(get_tree(), GAME_SCENE)


func _toggle_ghost() -> void:
	var p: Node = get_node("/root/Progress")
	p.ghost_on = not p.ghost_on
	ghost_button.text = ghost_text(p.ghost_on)
	p.save_progress()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		UIKit.go(get_tree(), _back_to)
