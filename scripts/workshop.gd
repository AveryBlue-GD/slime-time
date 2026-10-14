class_name Workshop
extends RefCounted

## The ticket WORKSHOP (upgrades v2 batch 2, docs/design/upgrades-v2.md B.2): five utility tracks of
## 3 levels each, bought with tickets in the cauldron's TICKETS tab (Progress.buy_workshop; not
## refundable). Numbers live in Economy.WORKSHOP. They are handling and forgiveness, never power over
## the route: they don't change par, routes, the randomizer's usage u or seed codes, and they are OFF
## in hard mode (game.gd `_workshop`). Autoplay starts from a clean state (all 0).
##   SECOND WIND  once per run, the meter refills to 15 / 25 / 35 % when it hits 0 on the ground
##                (story: only on levels already cleared on normal; randomizer: firing it costs one
##                attempt step of the payout)
##   QUICK CHARGE a full leap charge in 1.2 / 0.95 / 0.7 s (1.5)
##   STICKY       splat penalty x0.75 / 0.55 / 0.40, splat stun 0.2 / 0.12 / 0.06 s (0.3)
##   MAGNET       coins within 18 / 26 / 34 px (10) fly in, if on revealed floor in plain sight
##   GOO NOSE     fog glimmers x1.5 / x2 / x3 as often, reaching 200 / 240 / 300 px (160)

const LIST := [
	{id = "wind", name = "SECOND WIND"},
	{id = "charge", name = "QUICK CHARGE"},
	{id = "sticky", name = "STICKY"},
	{id = "magnet", name = "MAGNET"},
	{id = "nose", name = "GOO NOSE"},
]


static func _track(id: String) -> Dictionary:
	return Economy.WORKSHOP.get(id, {})


static func ids() -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in LIST:
		out.append(item.id)
	return out


static func display_name(id: String) -> String:
	for item: Dictionary in LIST:
		if item.id == id:
			return item.name
	return ""


static func max_level(id: String) -> int:
	var track := _track(id)
	return track.costs.size() if not track.is_empty() else 0


## Tickets for the next level up from `level` (0 when maxed or unknown).
static func cost(id: String, level: int) -> int:
	var track := _track(id)
	if track.is_empty() or level < 0 or level >= track.costs.size():
		return 0
	return track.costs[level]


## Tickets a track at `level` cost in all.
static func total_cost(id: String, level: int) -> int:
	var track := _track(id)
	var total := 0
	if not track.is_empty():
		for i in clampi(level, 0, track.costs.size()):
			total += int(track.costs[i])
	return total


## Tickets for the whole workshop (423).
static func full_cost() -> int:
	var total := 0
	for id in ids():
		total += total_cost(id, max_level(id))
	return total


## The track's `key` table ("values" or a per-track extra like "stun") at `level` (level 0 = base).
static func value(id: String, level: int, key := "values") -> float:
	var track := _track(id)
	if track.is_empty():
		return 0.0
	var base_key := "base" if key == "values" else key + "_base"
	var l := clampi(level, 0, (track[key] as Array).size())
	return float(track[base_key]) if l == 0 else float(track[key][l - 1])


## SECOND WIND: the meter share (0-1) it refills to (0 = none).
static func wind_refill(level: int) -> float:
	return value("wind", level)


## QUICK CHARGE: seconds for a full leap charge.
static func charge_time(level: int) -> float:
	return value("charge", level)


## STICKY: the splat penalty factor and the splat stun (s).
static func splat_factor(level: int) -> float:
	return value("sticky", level)


static func splat_stun(level: int) -> float:
	return value("sticky", level, "stun")


## MAGNET: coin pickup reach (px).
static func magnet_reach(level: int) -> float:
	return value("magnet", level)


## GOO NOSE: how many times as often glimmers come, and how far they reach (px).
static func nose_rate(level: int) -> float:
	return value("nose", level)


static func nose_reach(level: int) -> float:
	return value("nose", level, "reach")


## The row's effect line: now -> next (or MAXED), e.g. "REFILL AT EMPTY 15% -> 25%".
static func effect_text(id: String, level: int) -> String:
	var maxed := level >= max_level(id)
	var tail := func(now: String, next: String) -> String: return now + ("  MAXED" if maxed else " -> " + next)
	match id:
		"wind":
			var pct := func(l: int) -> String: return "NONE" if l == 0 else "%d%%" % roundi(wind_refill(l) * 100.0)
			return "REFILL AT EMPTY " + tail.call(pct.call(level), pct.call(level + 1))
		"charge":
			return "FULL CHARGE " + tail.call("%.2fS" % charge_time(level), "%.2fS" % charge_time(level + 1))
		"sticky":
			return "SPLAT COST " + tail.call("X%.2f" % splat_factor(level), "X%.2f" % splat_factor(level + 1))
		"magnet":
			return "COIN REACH " + tail.call("%d PX" % roundi(magnet_reach(level)), "%d PX" % roundi(magnet_reach(level + 1)))
		"nose":
			return "GLIMMERS " + tail.call("X%s %d PX" % [_times(nose_rate(level)), roundi(nose_reach(level))],
				"X%s %d PX" % [_times(nose_rate(level + 1)), roundi(nose_reach(level + 1))])
	return ""


static func _times(rate: float) -> String:
	return str(int(rate)) if is_equal_approx(rate, roundf(rate)) else "%.1f" % rate
