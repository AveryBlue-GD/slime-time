extends "res://tests/suite_base.gd"

## Ticket store checks (upgrades v2 batch 2, docs/design/upgrades-v2.md C + D): economy totals (wheel
## 520, workshop 423, papers 350), the prize wheel live for players (27 spins = 12 hats + 15 trails, never a
## duplicate, rainbow pity), hat dyes (hats are never sold; 10 tickets a dye for a won dyeable hat,
## worn at once, its own color free, saved), workshop and cosmetic purchases (exact balance, one short,
## double buy, max level, not refundable, dev mode free), equip / unequip / fallback, save round trips
## (file and code, size), hostile values, RESET PROGRESS, the release epoch; the UI: the cauldron's
## TICKETS tab, the prize wheel's SHOP (buy through the confirm, Esc ladder), the wardrobe's TRAILS
## page and the map view's PAPER button. Every write goes to this run's throwaway save.
## Run: ./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_store.gd

var progress: Node


const ErrLog := preload("res://tests/err_log.gd")


var errlog := ErrLog.new()


func _initialize() -> void:
	await process_frame
	progress = root.get_node("Progress")
	OS.add_logger(errlog)
	Economy.workshop_force = 1  # the workshop is switched off in the game; these suites test it
	_check(progress.save_path != progress.REAL_SAVE_PATH, "tests save to a throwaway file (%s)" % progress.save_path)
	_totals()
	_hats()
	_dyes()
	_workshop()
	_cosmetics()
	_saves()
	await _ui_upgrades()
	await _ui_wheel()
	await _ui_wardrobe()
	await _ui_maps()
	progress.reset_progress()
	_check(errlog.count == 0, "no engine or script errors (%d)%s" % [errlog.count, "" if errlog.lines.is_empty() else ": " + errlog.lines[0]])
	_result()
	quit(0 if failures == 0 else 1)


func _fresh(tickets := 0) -> void:
	progress.reset_progress()
	progress.dev_tools = false
	Hats.available = true
	progress.tickets = tickets
	progress.tickets_lifetime = tickets


# ---------------------------------------------------------------- totals

func _totals() -> void:
	var wheel := 0
	for taken in Hats.LIST.size() + Cosmetics.wheel_ids().size():
		wheel += progress.spin_cost_after(taken)
	_check(wheel == 520, "all 27 prizes on the wheel (12 hats, 15 trails) cost 0 + 26 x 20 = 520 (got %d)" % wheel)
	_check(Workshop.full_cost() == 423 and Workshop.total_cost("wind", 3) == 95 and Workshop.total_cost("magnet", 3) == 82,
		"the workshop costs 95 + 4 x 82 = 423 (got %d)" % Workshop.full_cost())
	var cosmetics := 0
	for id in Cosmetics.ids():
		cosmetics += Cosmetics.price(id)
	_check(cosmetics == 350 and Cosmetics.ids(Cosmetics.TRAIL).is_empty() and Cosmetics.ids(Cosmetics.PAPER).size() == 11
		and not "rainbow_paper" in Cosmetics.ids(), "no trail is sold; 11 paper bundles (90 + 7 x 30 + PRISM 50) cost 350 (got %d)" % cosmetics)
	_check(wheel + Workshop.full_cost() + cosmetics == 1293, "everything but the hat dyes costs 1293 tickets")
	_check(Economy.DYE_PRICE == 10
		and progress.SPIN_COST == Economy.SPIN_COST and progress.RANDOM_ATTEMPT_PAY == Economy.RANDOM_ATTEMPT_PAY,
		"store numbers live in Economy (Progress aliases them)")
	var values := [Workshop.wind_refill(1), Workshop.wind_refill(3), Workshop.charge_time(0), Workshop.charge_time(3),
		Workshop.splat_factor(2), Workshop.splat_stun(0), Workshop.splat_stun(3), Workshop.magnet_reach(0), Workshop.magnet_reach(3),
		Workshop.nose_rate(3), Workshop.nose_reach(0), Workshop.nose_reach(2)]
	_check(values == [0.15, 0.35, 1.5, 0.7, 0.55, 0.3, 0.06, 10.0, 34.0, 2.3, 160.0, 240.0],
		"workshop tables: wind 15..35%%, charge 1.5 -> 0.7 s, sticky x0.55 / stun 0.3 -> 0.06, magnet 10 -> 34, nose x2.3 / 160 -> 240 (%s)" % [values])
	_check(is_equal_approx(Workshop.charge_time(0), Slime.CHARGE_TIME) and is_equal_approx(Workshop.splat_stun(0), Slime.SPLAT_STUN)
		and is_equal_approx(Workshop.magnet_reach(0), Coin.REACH) and is_equal_approx(Workshop.nose_reach(0), 160.0),
		"every workshop base equals the game's own constant (level 0 changes nothing)")


# ---------------------------------------------------------------- hats

func _hats() -> void:
	_fresh(0)
	_check(progress.can_spin_hats() and progress.spin_cost() == 0, "hats are live: a new player's first spin is free")
	_fresh(1000)
	var seen := {}
	var paid := 0
	var rainbow_at := -1
	var prizes := Hats.LIST.size() + Cosmetics.wheel_ids().size()
	for i in prizes:
		var before: int = progress.tickets
		var hat: String = progress.spin_hat(randf())
		paid += before - progress.tickets
		if hat == "rainbow":
			rainbow_at = i + 1
		seen[hat] = true
	_check(seen.size() == prizes and progress.hats_owned.size() == Hats.LIST.size() and progress.cosmetics_owned.size() == Cosmetics.wheel_ids().size()
		and Cosmetics.wheel_ids().size() == 15 and progress.hats_left().is_empty() and paid == 520 and progress.tickets_spent == 520,
		"27 spins win 12 different hats and 15 different trails (no duplicates) for 520 tickets (paid %d)" % paid)
	_check(rainbow_at > 0, "the rainbow hat comes by spin 27 at the latest (spin %d)" % rainbow_at)
	_check(not progress.can_spin_hats() and progress.spin_hat() == "" and progress.tickets == 480, "an empty wheel can't spin and takes nothing")
	# Pity: every miss fattens the rainbow wedge; landing on it resets.
	_fresh(1000)
	progress.cosmetics_owned.assign(Cosmetics.wheel_ids())  # (trails won: the rainbow hat is the last wedge)
	progress.spin_hat(0.0)  # the top hat (first in wheel order), a miss
	progress.spin_hat(0.0)
	_check(progress.rainbow_pity == 2 and progress.wheel_weight("rainbow", 2) > progress.wheel_weight("rainbow", 0), "misses build pity (%d)" % progress.rainbow_pity)
	progress.spin_hat(0.99999)  # the last wedge: the rainbow hat
	_check(progress.rainbow_pity == 0 and "rainbow" in progress.hats_owned, "landing on the rainbow hat resets its pity")
	# Atomic: paid, won and saved before the wheel turns (read back from the file).
	_fresh(30)
	progress.spins = 1
	progress.saving_enabled = true
	var hat: String = progress.spin_hat(0.5)
	var file := ConfigFile.new()
	var ok := file.load(progress.save_path) == OK
	_check(ok and hat != "" and int(file.get_value("wallet", "globs", -1)) == 10
		and (hat in file.get_value("hats", "owned", []) or hat in file.get_value("cosmetics", "owned", []))
		and int(file.get_value("hats", "spins", 0)) == 2 and int(file.get_value("wallet", "tickets_spent", 0)) == 20,
		"a spin is paid, won and saved at once (10 left, %s owned, spent 20 in the file)" % hat)
	progress.saving_enabled = false


func _dyes() -> void:
	_fresh(25)
	_check(not progress.has_method("buy_hat") and not progress.has_method("tailor_price"), "hats are never sold (no TAILOR)")
	var count := 0
	for hat in Hats.ids():
		count += Hats.dyes_for(hat).size()
	_check(count == 123 and Hats.dyes_for("tophat").size() == 10 and Hats.dyes_for("cowboy").size() == 11 and Hats.dyes_for("nothat").is_empty()
		and not "midnight" in Hats.dyes_for("tophat") and "rainbow" in Hats.dyes_for("rainbow"),
		"123 dyes: all 12 hats, each without its own color, each with PRISM and RAINBOW (%d)" % count)
	var sheet_dyes := 0
	for entry: Dictionary in Hats.DYES:
		if not entry.has("block"):
			sheet_dyes += 1
	var sheet: Texture2D = preload("res://assets/sprites/hat_dyes.png")
	_check(sheet.get_height() == sheet_dyes * Hats.DYE_BLOCK and sheet.get_width() == preload("res://assets/sprites/hats.png").get_width(),
		"the imported hat_dyes.png has a block per drawn dye (%d px high; re-import after tools/make_hats.py)" % sheet.get_height())
	_check(progress.dye_price("clover") == 10 and progress.dye_price("rainbow") == 99 and progress.dye_price("prism") == 50
		and Hats.sheet_block("prism") == Hats.sheet_block("rainbow") and Hats.sheet_block("rainbow") == 9
		and Hats.material_for("beanie", "rainbow").get_shader_parameter("gradient") and not Hats.material_for("beanie", "prism").get_shader_parameter("gradient") and Hats.material_for("beanie", "rainbow") != null
		and Hats.material_for("beanie", "clover") == null and Hats.material_for("nothat", "rainbow") == null and "rainbow" in Hats.dyes_for("viking") and not "butter" in Hats.dyes_for("viking"), "RAINBOW 99 (a gradient), PRISM 50 (turns as one), both from the rainbow block; the others 10")
	_check(not progress.can_buy_dye("beanie", "clover") and not progress.buy_dye("beanie", "clover") and progress.tickets == 25, "no dye for a hat not won")
	progress.win_hat("beanie")
	progress.win_hat("crown")
	_check(not progress.buy_dye("beanie", "cherry") and not progress.buy_dye("crown", "butter") and not progress.buy_dye("beanie", "nope"),
		"no dye a hat doesn't come in (its own color, a plain hat, an unknown dye)")
	progress.selected_hat = "crown"
	_check(progress.buy_dye("beanie", "clover") and progress.tickets == 15 and progress.owns_dye("beanie", "clover")
		and progress.selected_hat == "beanie" and progress.hat_dye_of("beanie") == "clover", "a dye costs 10, and the hat is put on in it")
	_check(not progress.buy_dye("beanie", "clover") and progress.tickets == 15, "no double buy")
	progress.tickets = 9
	_check(not progress.buy_dye("beanie", "plum") and progress.tickets == 9 and not progress.owns_dye("beanie", "plum"), "one short: no buy, nothing taken")
	progress.tickets = 10
	_check(progress.buy_dye("beanie", "plum") and progress.tickets == 0, "exactly 10: bought")
	progress.tickets = 98
	_check(not progress.buy_dye("beanie", "rainbow") and progress.tickets == 98, "RAINBOW at 98 of 99: no buy")
	progress.tickets = 99
	_check(progress.buy_dye("beanie", "rainbow") and progress.tickets == 0 and progress.wear_dye("beanie", "clover"), "RAINBOW at exactly 99: bought")
	_check(progress.wear_dye("beanie", "") and progress.hat_dye_of("beanie") == "" and progress.wear_dye("beanie", "clover")
		and progress.hat_dye_of("beanie") == "clover", "the hat's own color is free to go back to; an owned dye is worn again")
	_check(not progress.wear_dye("beanie", "snow") and progress.hat_dye_of("beanie") == "clover", "an unowned dye can't be worn")
	var file: ConfigFile = progress._write()
	progress.reset_progress()
	_check(progress.hat_dyes_owned.is_empty() and progress.hat_dye_of("beanie") == "", "RESET PROGRESS clears the dyes")
	progress._read(file)
	_check(progress.owns_dye("beanie", "clover") and progress.owns_dye("beanie", "plum") and progress.hat_dye_of("beanie") == "clover",
		"dyes round-trip through the save")
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 6)
	bad.set_value("meta", "epoch", 1)
	bad.set_value("hats", "owned", ["beanie"])
	bad.set_value("hats", "dyes", ["beanie:clover", "beanie:clover", "beanie:cherry", "crown:butter", "beanie", 7, "x:y:z"])
	bad.set_value("hats", "dyes_worn", ["beanie:plum", "tophat:clover"])
	progress._read(bad)
	_check(str(progress.hat_dyes_owned) == str(["beanie:clover"]) and progress.hat_dye_of("beanie") == "",
		"hostile dyes: real ones once each, a worn dye only if owned (%s)" % [progress.hat_dyes_owned])
	progress.dev_tools = true
	progress.tickets = 0
	_check(progress.dye_price() == 0 and progress.owns_dye("tophat", "clover"), "dev mode owns every dye")
	progress.dev_tools = false


# ---------------------------------------------------------------- workshop and cosmetics

func _workshop() -> void:
	_fresh(0)
	_check(not progress.workshop_open() and not progress.buy_workshop("charge"), "the workshop is shut before the first ticket ever")
	_fresh(15)
	_check(progress.workshop_open() and progress.buy_workshop("wind") and progress.tickets == 0 and progress.workshop_level("wind") == 1,
		"SECOND WIND 1 at exactly 15: bought, 0 left")
	progress.tickets = 29
	_check(not progress.buy_workshop("wind") and progress.tickets == 29 and progress.workshop_level("wind") == 1, "level 2 at 29 of 30: nothing")
	progress.tickets = 1000
	_check(progress.buy_workshop("wind") and progress.buy_workshop("wind") and progress.workshop_level("wind") == 3 and progress.tickets == 920,
		"levels 2 and 3 (30 + 50)")
	_check(not progress.buy_workshop("wind") and progress.tickets == 920 and progress.workshop_cost("wind") == 0, "maxed: no fourth level")
	_check(not progress.buy_workshop("lantern") and not progress.has_method("refund_workshop"), "unknown tracks can't be bought; no refunds")
	_check(progress.tickets_spent == 95, "tickets spent counted (%d)" % progress.tickets_spent)
	progress.dev_tools = true
	progress.tickets = 0
	_check(progress.buy_workshop("nose") and progress.tickets == 0, "dev mode buys free")
	progress.dev_tools = false


func _cosmetics() -> void:
	_fresh(30)
	_check(progress.trail_style == Cosmetics.DEFAULT_TRAIL and progress.map_paper == Cosmetics.DEFAULT_PAPER
		and progress.owns_cosmetic(Cosmetics.DEFAULT_TRAIL) and not progress.owns_cosmetic("gold"), "defaults are worn and owned; nothing else")
	_check(not progress.equip_cosmetic("gold") and progress.trail_style == Cosmetics.DEFAULT_TRAIL, "an unowned style can't be worn")
	_check(not progress.buy_cosmetic("gold") and progress.tickets == 30 and not progress.owns_cosmetic("gold") and Cosmetics.price("gold") == 0,
		"trails aren't sold (prize wheel only): GOLD can't be bought, nothing taken")
	progress.win_hat("gold")
	_check(progress.owns_cosmetic("gold") and progress.trail_style == "gold" and progress.tickets == 30, "GOLD won on the wheel: owned and worn")
	progress.tickets = 100
	_check(progress.buy_cosmetic("blueprint") and progress.tickets == 75, "the BLUEPRINT paper: bought for 25")
	_check(not progress.buy_cosmetic("blueprint") and progress.tickets == 75, "no double buy")
	progress.tickets = 24
	_check(not progress.buy_cosmetic("night") and progress.tickets == 24 and progress.map_paper == "blueprint", "a paper one ticket short: nothing (BLUEPRINT still worn)")
	progress.tickets = 25
	_check(progress.buy_cosmetic("night") and progress.map_paper == "night" and progress.trail_style == "gold", "the NIGHT paper: bought, worn beside the trail")
	progress.unequip_cosmetic("gold")
	_check(progress.trail_style == Cosmetics.DEFAULT_TRAIL and "gold" in progress.cosmetics_owned, "taken off: back to the skin's goo, still owned")
	_check(progress.equip_cosmetic("gold") and progress.trail_style == "gold", "...and back on")
	_check(not progress.buy_cosmetic("skin") and not progress.buy_cosmetic("tophat"), "defaults and hats aren't cosmetics for sale")
	progress.dev_tools = true
	_check(progress.owns_cosmetic("starry") and progress.cosmetic_price("starry") == 0, "dev mode owns every cosmetic")
	progress.dev_tools = false


# ---------------------------------------------------------------- saves

func _saves() -> void:
	_fresh(500)
	progress.spin_hat(0.0)
	progress.spin_hat(0.0)
	progress.spin_hat(0.0)
	progress.win_hat("chef")
	progress.buy_dye("chef", "clover")
	progress.buy_workshop("charge")
	progress.buy_workshop("sticky")
	progress.buy_workshop("sticky")
	progress.win_hat("candy")
	progress.buy_cosmetic("blueprint")
	var want := [progress.tickets, progress.tickets_spent, progress.workshop.duplicate(), progress.cosmetics_owned.duplicate(),
		progress.trail_style, progress.map_paper, progress.hats_bought, progress.spins, progress.hats_owned.duplicate(), progress.hat_dyes_owned.duplicate()]
	var file: ConfigFile = progress._write()
	progress.reset_progress()
	progress._read(file)
	var got := [progress.tickets, progress.tickets_spent, progress.workshop, progress.cosmetics_owned, progress.trail_style,
		progress.map_paper, progress.hats_bought, progress.spins, progress.hats_owned, progress.hat_dyes_owned]
	_check(str(got) == str(want), "the store round-trips through the save (%s)" % [got])
	var code: String = progress.save_code()
	progress.reset_progress()
	_check(progress.load_code(code) and progress.workshop_level("sticky") == 2 and progress.trail_style == "candy" and progress.owns_dye("chef", "clover"),
		"...and through a save code (%d chars)" % code.length())
	# A full store (every hat, workshop maxed, every cosmetic worn) still makes a short code.
	progress.hats_owned.assign(Hats.ids())
	for id in Workshop.ids():
		progress.workshop[id] = Workshop.max_level(id)
	progress.cosmetics_owned.assign(Cosmetics.ids())
	for hat in Hats.ids():
		for dye in Hats.dyes_for(hat):
			progress.hat_dyes_owned.append("%s:%s" % [hat, dye])
	progress.hats_bought = 11
	progress.tickets_spent = 873
	var full: String = progress.save_code()
	_check(full.length() < 2000 and full.length() < progress.MAX_SAVE_CODE_LENGTH, "a full store's save code stays small (%d chars)" % full.length())
	_check(progress.RELEASE_EPOCH == 1 and progress.SAVE_VERSION == 6 and full.begins_with("SLIME2-"), "epoch 1, save version 6, SLIME2- codes: unchanged")
	# A save from before the store: every key defaults.
	var old := ConfigFile.new()
	old.set_value("meta", "version", 6)
	old.set_value("meta", "epoch", 1)
	old.set_value("progress", "levels_cleared", 3)
	progress._read(old)
	_check(progress.workshop.is_empty() and progress.cosmetics_owned.is_empty() and progress.trail_style == Cosmetics.DEFAULT_TRAIL
		and progress.map_paper == Cosmetics.DEFAULT_PAPER and progress.hats_bought == 0 and progress.tickets_spent == 0, "an older save gets store defaults")
	# Hostile values.
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 6)
	bad.set_value("meta", "epoch", 1)
	bad.set_value("progress", "levels_cleared", 10)
	bad.set_value("workshop", "wind", 99)
	bad.set_value("workshop", "charge", -5)
	bad.set_value("workshop", "sticky", "3")
	bad.set_value("workshop", "magnet", 2.7)
	bad.set_value("workshop", "lantern", 3)
	bad.set_value("cosmetics", "owned", ["gold", "gold", "abyss", 7, "tophat", "night"])
	bad.set_value("cosmetics", "trail", "starry")
	bad.set_value("cosmetics", "paper", "gold")
	bad.set_value("hats", "bought", 1 << 40)
	bad.set_value("wallet", "tickets_spent", -50)
	progress._read(bad)
	_check(progress.workshop == {"wind": 3, "magnet": 2}, "workshop levels clamped, wrong types and unknown tracks dropped (%s)" % progress.workshop)
	_check(str(progress.cosmetics_owned) == str(["gold", "night"]), "owned cosmetics: allow-listed ids once each (%s)" % [progress.cosmetics_owned])
	_check(progress.trail_style == Cosmetics.DEFAULT_TRAIL and progress.map_paper == Cosmetics.DEFAULT_PAPER,
		"an unowned trail / a trail as paper fall back to the defaults")
	_check(progress.hats_bought == Hats.LIST.size() and progress.tickets_spent == 0, "bought / spent clamped")
	# The text validator passes a real store save (string arrays, ints).
	progress.workshop = {"wind": 2}
	progress.cosmetics_owned.assign(["ink", "goldleaf"])
	progress.trail_style = "ink"
	var text: String = progress._write().encode_to_text()
	var parsed: ConfigFile = progress.SaveText.parse(text.to_utf8_buffer())
	_check(parsed != null and parsed.get_value("cosmetics", "owned") == ["ink", "goldleaf"] and parsed.get_value("workshop", "wind") == 2,
		"the save allow-list reads the new sections")
	progress.reset_progress()
	_check(progress.workshop.is_empty() and progress.cosmetics_owned.is_empty() and progress.trail_style == Cosmetics.DEFAULT_TRAIL
		and progress.map_paper == Cosmetics.DEFAULT_PAPER and progress.hats_bought == 0 and progress.tickets_spent == 0,
		"RESET PROGRESS clears the store")


# ---------------------------------------------------------------- UI

func _ui_upgrades() -> void:
	_fresh(0)
	var script: GDScript = load("res://scripts/ui/upgrades_screen.gd")
	script.set("open_tab", "tickets")
	var screen: Control = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	_check(screen.page == "tickets" and screen.ticket_page.visible and not screen.coin_page.visible and screen.ticket_rows.size() == 5,
		"the cauldron's TICKETS tab: 5 workshop rows")
	var all_shut := true
	for id: String in screen.ticket_rows:
		all_shut = all_shut and screen.ticket_rows[id].plus.disabled
	_check(all_shut and "EARN TICKETS" in screen.hint.text and screen.tickets_tab.has_focus(), "locked before any ticket: + off, the hint says how, focus on the tab")
	screen.free()
	_fresh(20)
	screen = load("res://scenes/upgrades.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var rows: Dictionary = screen.ticket_rows
	_check(screen.page == "coins", "the next opening is COINS again (the tab isn't sticky)")
	screen.show_page("tickets")
	_check(rows.wind.cost.text == "15" and rows.wind.icon.visible and not rows.wind.plus.disabled and rows.charge.cost.text == "12"
		and rows.wind.about.text == "REFILL AT EMPTY NONE -> 15%" and screen.coin_label.text == "20" and rows.wind.plus.has_focus(),
		"prices with the ticket icon, effects now -> next, the pod shows tickets, focus on the first +")
	rows.wind.plus.pressed.emit()
	_check(progress.workshop_level("wind") == 0 and screen.confirm.visible and screen.confirm_back.has_focus()
		and "BUY SECOND WIND 1?" in screen.confirm_label.text and screen.confirm_price.text == "15",
		"+ asks first (BUY / BACK, focus on BACK, focus locked); nothing is spent yet")
	_check(rows.wind.plus.focus_mode == Control.FOCUS_NONE and screen.confirm_buy.focus_mode != Control.FOCUS_NONE, "focus is locked to the confirm")
	# Esc closes the confirm first (the screen stays), then nothing is bought.
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	_check(not screen.confirm.visible and progress.tickets == 20 and is_instance_valid(screen) and rows.wind.plus.has_focus(),
		"Esc closes the confirm (focus back on the +), no tickets spent")
	rows.wind.plus.pressed.emit()
	screen.confirm_buy.pressed.emit()
	screen.confirm_buy.pressed.emit()  # a double tap on BUY
	rows.wind.plus.pressed.emit()  # ...and a quick extra tap on +
	screen.confirm_buy.pressed.emit()
	_check(progress.workshop_level("wind") == 1 and not screen.confirm.visible and progress.tickets == 5, "a double tap buys exactly once (guard 0.3 s)")
	for i in 12:  # 0.2 s of engine time: still guarded
		await process_frame
	var still_guarded: bool = screen._buy_guarded
	for i in 12:  # 0.4 s: the guard is over
		await process_frame
	_check(still_guarded and not screen._buy_guarded, "the guard lasts 0.3 s of engine time (fixed-fps runs play out the same on any machine)")
	_check(progress.workshop_level("wind") == 1 and progress.tickets == 5 and screen.coin_label.text == "5" and rows.wind.cost.text == "30"
		and rows.wind.plus.disabled and rows.charge.plus.disabled, "pressing + buys a level; the rows update (5 left: nothing else affordable)")
	var boxes: Array[Rect2] = []
	for id: String in rows:
		for key in ["plus", "about", "cost"]:
			var node: Control = rows[id][key]
			boxes.append(Rect2(node.global_position, node.size.max(node.get_combined_minimum_size())))
	var overlap := false
	for i in boxes.size():
		overlap = overlap or not Rect2(10, 20, 300, 130).encloses(boxes[i])
		for j in range(i + 1, boxes.size()):
			overlap = overlap or boxes[i].intersects(boxes[j])
	_check(not overlap, "workshop rows fit above the bottom buttons without overlaps")
	screen.coins_tab.pressed.emit()
	_check(screen.page == "coins" and screen.coin_label.text == str(progress.coins()) and screen.rows.slime.plus.has_focus(), "the COINS tab shows the coin tree again")
	screen.free()


func _ui_wheel() -> void:
	_fresh(100)
	progress.spins = 3
	var hub: Node2D = load("res://scenes/hub.tscn").instantiate()
	root.add_child(hub)
	current_scene = hub
	for i in 5:
		await process_frame
	hub.open_hat_wheel()
	await process_frame
	var wheel: Control = hub.hat_wheel
	_check(wheel.visible and wheel.tab == "wheel" and wheel.spin_button.has_focus() and "SPIN  20" in wheel.spin_button.text and wheel.spin_button.icon != null,
		"the wheel opens on WHEEL, focus on SPIN with its price and the ticket icon (%s)" % wheel.spin_button.text)
	wheel.shop_tab.pressed.emit()
	var dyeable := Hats.ids().filter(func(h: String) -> bool: return Hats.is_dyeable(h))
	_check(wheel.tab == "shop" and wheel.shop_page.visible and not wheel.wheel_page.visible and wheel.shop_tiles.keys() == dyeable
		and dyeable.size() == 12 and wheel.section_buttons["hats"].text == "DYES", "SHOP opens on DYES: every dyeable hat on show, none won yet")
	_check(wheel.shop_tiles["tophat"].has_focus() and wheel.status.text == "TOP HAT" and wheel.status_line.text == "WIN IT ON THE PRIZE WHEEL",
		"...a hat not won yet says where to get it (%s / %s)" % [wheel.status.text, wheel.status_line.text])
	var lock_icons := func(tile: Button) -> int:
		return tile.find_children("*", "TextureRect", true, false).filter(func(t: TextureRect) -> bool: return t.texture == load("res://assets/ui/icon_lock.png")).size()
	_check(dyeable.all(func(h: String) -> bool: return lock_icons.call(wheel.shop_tiles[h]) == 1), "...each one locked (a lock icon)")
	wheel.shop_tiles["tophat"].pressed.emit()
	_check(wheel.dye_hat == "" and not wheel.shop_tiles.has("tophat:") and not wheel.confirm.visible and progress.tickets == 100,
		"...pressing a locked hat opens no colors, buys nothing")
	hub.close_hat_wheel()
	progress.win_hat("tophat")
	progress.win_hat("crown")
	hub.open_hat_wheel()
	await process_frame
	wheel.shop_tab.pressed.emit()
	_check(wheel.shop_tiles.keys() == dyeable and wheel.shop_tiles["tophat"].has_focus() and "PICK" in wheel.status_line.text,
		"DYES still lists every hat, focus on the first (won)")
	_check(lock_icons.call(wheel.shop_tiles["tophat"]) == 0 and lock_icons.call(wheel.shop_tiles["crown"]) == 0
		and lock_icons.call(wheel.shop_tiles["beanie"]) == 1, "...the won ones unlocked, the rest still locked")
	wheel.shop_tiles["tophat"].pressed.emit()
	_check(wheel.dye_hat == "tophat" and wheel.shop_tiles.has("tophat:") and wheel.shop_tiles.has("tophat:clover")
		and not wheel.shop_tiles.has("tophat:midnight") and wheel.shop_tiles.size() == 11 and wheel.shop_tiles.has("tophat:rainbow") and wheel.shop_tiles.has("tophat:prism"),
		"a hat's tile opens its colors: ORIGINAL + 10 dyes (PRISM, RAINBOW last)")
	var teal: Button = wheel.shop_tiles["tophat:clover"]
	teal.grab_focus()
	teal.pressed.emit()
	_check(wheel.confirm.visible and wheel.confirm_back.has_focus() and "CLOVER DYE" in wheel.confirm_label.text and wheel.confirm_price.text == "10",
		"buying asks once: BUY CLOVER DYE? 10, focus on BACK")
	_check(not wheel.spin() and progress.tickets == 100, "no spin from the SHOP / under the confirm")
	_check(wheel.back() and not wheel.confirm.visible and progress.tickets == 100 and wheel.dye_hat == "tophat", "Esc (back) closes the confirm first, nothing bought")
	teal.pressed.emit()
	wheel.confirm_buy.pressed.emit()
	await process_frame
	_check(progress.tickets == 90 and progress.owns_dye("tophat", "clover") and progress.selected_hat == "tophat" and hub.hat != null
		and hub.hat.dye == "clover" and hub.hat.texture == preload("res://assets/sprites/hat_dyes.png") and not wheel.confirm.visible,
		"BUY: paid 10, the hub slime wears the top hat in clover")
	wheel.shop_tiles["tophat:"].pressed.emit()
	_check(progress.hat_dye_of("tophat") == "" and hub.hat.dye == "", "ORIGINAL puts its own color back on")
	_check(wheel.back() and wheel.dye_hat == "" and wheel.shop_tiles.has("tophat") and wheel.shop_tiles["tophat"].has_focus(), "Esc goes back to the hats first")
	progress.tickets = 55
	wheel.refresh("F")
	_check(not wheel.section_buttons.has("trails") and wheel.section_buttons.keys() == ["hats", "papers"], "the SHOP sells no trails: DYES and PAPERS only")
	wheel.section_buttons["papers"].pressed.emit()
	_check(wheel.section == "papers" and wheel.shop_tiles.size() == 11, "PAPERS: 11 tiles")
	wheel.shop_tiles["night"].pressed.emit()
	wheel.confirm_buy.pressed.emit()
	_check(progress.tickets == 30 and progress.map_paper == "night", "a paper bought through the confirm is worn")
	wheel.shop_tiles["goldleaf"].pressed.emit()
	_check(not wheel.confirm.visible and progress.tickets == 30 and "NEED 40" in wheel.status_line.text, "one it can't afford: no confirm, the line says why")
	wheel.shop_tiles["night"].pressed.emit()
	_check(progress.map_paper == Cosmetics.DEFAULT_PAPER and "night" in progress.cosmetics_owned, "pressing the worn paper takes it off")
	_check(not wheel.back(), "Esc with no confirm: the hub closes the overlay")
	hub.close_hat_wheel()
	_check(not wheel.visible and not hub.slime.frozen, "closed: the slime moves again")
	# Every prize won: the wheel is empty and the overlay opens on the SHOP.
	progress.hats_owned.assign(Hats.ids())
	progress.cosmetics_owned.append_array(Cosmetics.wheel_ids())
	hub.open_hat_wheel()
	await process_frame
	_check(wheel.tab == "shop" and wheel.shop_page.visible and wheel.get_viewport().gui_get_focus_owner() != null
		and wheel.is_ancestor_of(wheel.get_viewport().gui_get_focus_owner()), "every prize won: opens on the SHOP, focus inside")
	wheel.section_buttons["hats"].pressed.emit()
	_check(wheel.shop_tiles.size() == 12 and wheel.dye_hat == "", "...its DYES section lists all 12 hats")
	wheel.wheel_tab.pressed.emit()
	_check(wheel.hats.is_empty() and wheel.spin_button.disabled and "EVERY PRIZE" in wheel.result.text and wheel.wheel_tab.has_focus(),
		"...the WHEEL tab shows an empty wheel that can't spin")
	hub.close_hat_wheel()
	current_scene = null
	hub.free()


func _ui_wardrobe() -> void:
	_fresh(0)
	progress.cosmetics_owned.assign(["ink"])
	var screen: Control = load("res://scenes/skins.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.show_page("hats")
	_check(screen.color_button.visible and screen.color_button.disabled and not screen.jelly_button.visible, "hats page: COLOR in JELLY's place, off with no hat dyes")
	progress.win_hat("beanie")
	progress.hat_dyes_owned.assign(["beanie:clover", "beanie:plum"])
	screen._refresh_hats()
	_check(not screen.color_button.disabled, "...on once the worn hat has a dye")
	screen.color_button.pressed.emit()
	_check(screen._picker != null and screen.picker_tiles.keys() == ["", "clover", "plum"] and screen.picker_tiles[""].has_focus(),
		"COLOR opens a picker of the hat's own color and every owned dye, focus on the worn one")
	screen.picker_tiles["plum"].pressed.emit()
	_check(screen._picker == null and progress.hat_dye_of("beanie") == "plum" and screen.hat_tiles["beanie"].get_meta("hat").dye == "plum"
		and "PLUM" in screen.status.text and screen.color_button.has_focus(), "picking a color wears it (tile and status too) and closes the picker")
	screen.color_button.pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._unhandled_input(esc)
	_check(screen._picker == null and screen.is_inside_tree() and progress.hat_dye_of("beanie") == "plum", "Esc closes the picker first, nothing changed")
	screen.page_button.pressed.emit()
	_check(screen.page == "trails" and screen.trail_tiles.size() == 16 and screen.page_button.text == "PAPERS" and screen._title.text == "TRAILS",
		"the wardrobe's page button goes SKINS -> HATS -> TRAILS -> PAPERS (16 tiles, the 10 wheel trails too: ABYSS is hidden while Descent is off, D11)")
	_check(screen.trail_tiles[Cosmetics.DEFAULT_TRAIL].has_focus() and "WEARING" in screen.status.text, "focus on the worn trail")
	screen.trail_tiles["gold"].pressed.emit()
	_check(progress.trail_style == Cosmetics.DEFAULT_TRAIL and "PRIZE WHEEL" in screen.status.text and not "TIX" in screen.status.text,
		"an unowned trail says to win it on the prize wheel (no price), isn't worn")
	screen.trail_tiles["ink"].pressed.emit()
	_check(progress.trail_style == "ink" and "WEARING" in screen.status.text, "an owned trail is worn")
	screen.page_button.pressed.emit()
	_check(screen.page == "papers" and screen.paper_tiles.size() == 12 and screen.page_button.text == "HUB" and screen._title.text == "PAPERS",
		"...then PAPERS (12 tiles: parchment and the eleven sold papers)")
	# Papers are bundles, worn whole: pressing an owned one wears its sheet, walls and route.
	progress.cosmetics_owned.append_array(["night", "prism_paper"])
	screen.show_page("papers")
	screen.paper_tiles["prism_paper"].pressed.emit()
	_check(progress.map_paper == "prism_paper" and Cosmetics.style_flows(progress.map_paper) and "WEARING" in screen.status.text
		and (screen.paper_tiles["prism_paper"].get_child(0) as TextureRect).material != null, "an owned paper is worn whole; PRISM's tile flows")
	screen.page_button.pressed.emit()
	_check(screen.page == "hub" and screen.hub_tiles.size() == 14 and screen.hub_tiles[""].has_focus() and "BEAT THE STORY" in screen._rule.text,
		"...then HUB (AUTO + 13 skins), shut before normal mode is beaten")
	screen.hub_tiles["mint"].pressed.emit()
	_check(progress.hub_skin_in_use() == "" and progress.hub_color() == progress.skin_color(), "...a skin can't be picked yet: the hub follows the worn skin")
	progress.levels_cleared = Levels.COUNT
	progress.selected_skin = "lime"
	screen.show_page("hub")
	_check(not "BEAT" in screen._rule.text, "normal mode beaten: the HUB page opens")
	screen.hub_tiles["frost"].pressed.emit()
	_check(progress.hub_skin_in_use() == "frost" and progress.hub_color() == Skins.get_preset("frost").color and progress.skin_color() == Skins.get_preset("lime").color
		and "WEARING" in screen.status.text, "an unlocked skin colors the hub; the slime keeps its own")
	screen.hub_tiles[Skins.RAINBOW].pressed.emit()
	_check(progress.hub_skin_in_use() == "frost", "a locked skin (rainbow: every coin) can't be the hub's")
	var file: ConfigFile = progress._write()
	progress.hub_skin = ""
	progress._read(file)
	_check(progress.hub_skin_in_use() == "frost", "the hub's color is saved")
	screen.hub_tiles[""].pressed.emit()
	_check(progress.hub_skin_in_use() == "" and progress.hub_color() == progress.skin_color(), "AUTO: the hub follows the worn skin again")
	screen.page_button.pressed.emit()
	_check(screen.page == "skins", "...and back round to SKINS")
	# A skin picked on the skins page shows on the hats page at once.
	screen._on_tile("mint")
	screen.show_page("hats")
	var tint := Color.BLACK
	for child in screen.hat_tiles[Hats.NONE].get_children():
		if child is AnimatedSprite2D:
			tint = (child.material as ShaderMaterial).get_shader_parameter("mid")
	_check(tint.is_equal_approx(Skins.shades(Skins.get_preset("mint").color).mid), "a skin just picked shows on the hats page at once")
	screen.free()


func _ui_maps() -> void:
	_fresh(0)
	progress.seed_full_surveys()
	var screen: Control = load("res://scenes/maps.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.open_view(1)
	_check(screen.viewing and not screen.view_paper.visible, "no paper owned: no PAPER button")
	screen.close_view()
	progress.cosmetics_owned.assign(["blueprint", "goldleaf"])
	screen.open_view(1)
	var before: Image = (screen.view_map.texture as ImageTexture).get_image()
	_check(screen.view_paper.visible, "papers owned: PAPER shows")
	screen.view_paper.pressed.emit()
	var after: Image = (screen.view_map.texture as ImageTexture).get_image()
	_check(progress.map_paper == "blueprint" and before.get_data() != after.get_data() and screen.view_paper.has_focus() and "BLUEPRINT" in screen.view_line.text,
		"PAPER redraws the map on the blueprint paper")
	screen.view_paper.pressed.emit()
	screen.view_paper.pressed.emit()
	_check(progress.map_paper == Cosmetics.DEFAULT_PAPER, "...cycling the owned papers back to the parchment")
	var pal: Dictionary = MapView.palette("dungeon", "night", Color8(239, 125, 47))
	_check(pal.route == MapView.ROUTE and pal.floor == Color8(46, 44, 72) and pal.wall.r > pal.wall.b, "NIGHT: dark paper, skin-colored ink, the route still red")
	screen.free()
	progress.maps = {}


