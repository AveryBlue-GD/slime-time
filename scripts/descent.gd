class_name Descent
extends RefCounted

## DESCENT runs (upgrades v2 batch 3, docs/design/upgrades-v2.md C2): a chain of randomizer-style
## floors from one run seed, the meter carrying over (plus a refill), goo drops, a 1-of-3 boon pick
## after every floor and a ticket pot banked by CASH OUT (all) or a dry-up (half). This file is the
## pure rules (no nodes, no save): floor recipes, refills, the pot, boon offers and effects. Every
## number lives in Economy (DESCENT_*, BOONS). The run itself is a Dictionary kept in memory by
## Progress (`descent_run`; a copy at each floor start and cleared floor is saved as Progress.descent_resume,
## so a killed app or closed window resumes that floor on relaunch: owner decision D6), made by `new_run`:
##   seed     the run seed (1 .. Economy.DESCENT_SEED_MAX)
##   floor    the floor being played (1 = first)
##   meter    the meter (percent of the run's capacity) the current floor starts with
##   boons    {boon id: times picked}
##   bladders BACKUP BLADDER refills still unused
##   pot      tickets in the pot (0 .. DESCENT_POT_MAX)
##   time     seconds played on the floors already cleared
##   wind_used SECOND WIND fired (once per run)
##   tainted  a dev toggle (F1 / F2) was on at some point: the run pays nothing
##   slot     which of the day's paid runs this is (1..DESCENT_PAID_PER_DAY), taken (and saved) when
##            floor 1 is first cleared; 0 = none taken (yet)
##   cleared  floors cleared; `gain` = what the last cleared floor added to the pot
##   ended    the run was banked (cash out / dry-up / quit); `result` = what it paid (Progress)
##   bonus    milestone tickets paid on reaching the current floor (shown once, then 0)

## The boons in table order (picker / HUD order).
const IDS: Array[String] = ["gulp", "tank", "feather", "rubber", "slick", "blaze", "sense", "bladder", "thrift", "greedy", "glass"]
const NAMES := {
	"gulp": "BIG GULP", "tank": "DEEP TANK", "feather": "FEATHER LEAP", "rubber": "RUBBER BODY",
	"slick": "SLICK", "blaze": "BLAZE", "sense": "CHALICE SENSE", "bladder": "BACKUP BLADDER",
	"thrift": "THRIFT", "greedy": "GREEDY GOO", "glass": "GLASS SLIME",
}
## Two short lines each (at most 14 letters a line: they fit a boon tile).
const ABOUT := {
	"gulp": ["+30% SLIME", "RIGHT NOW"],
	"tank": ["TANK +15%", "ALL RUN"],
	"feather": ["LEAPS COST", "LESS SLIME"],
	"rubber": ["SPLATS COST", "NO SLIME"],
	"slick": ["GLIDE +15%", "FASTER"],
	"blaze": ["WIDER LIGHT", "+1 BRIGHTNESS"],
	"sense": ["SEE THE EXIT", "FROM 6 TILES"],
	"bladder": ["EMPTY? REFILL", "TO 25% ONCE"],
	"thrift": ["FLOOR REFILLS", "+15%"],
	"greedy": ["+1 TIX/FLOOR", "TANK -10%"],
	"glass": ["POT X1.5", "SPLATS X2"],
}
const SEED_SALT := 0x2d5c1
const OFFER_SALT := 0x6b0f3
const JITTER_SALT := 0x41a97


static func boon(id: String) -> Dictionary:
	return Economy.BOONS.get(id, {})


static func display_name(id: String) -> String:
	return NAMES.get(id, "")


static func about(id: String) -> Array:
	return ABOUT.get(id, ["", ""])


## A fresh run (floor 1, a full meter, empty pot).
static func new_run(run_seed: int) -> Dictionary:
	return {seed = clampi(run_seed, 1, Economy.DESCENT_SEED_MAX), floor = 1, meter = 100.0, boons = {}, bladders = 0,
		pot = 0, time = 0.0, wind_used = false, tainted = false, slot = 0, cleared = 0, gain = 0, ended = false,
		result = {}, bonus = 0, bonuses = [], new_best = false}


## A random run seed.
static func roll_seed() -> int:
	return randi_range(1, Economy.DESCENT_SEED_MAX)


# ---------------------------------------------------------------- floors

## Floor `floor_no`'s maze seed (run seed x 1000 + floor).
static func floor_seed(run_seed: int, floor_no: int) -> int:
	return run_seed * Economy.DESCENT_FLOOR_SEED + clampi(floor_no, 1, Economy.DESCENT_FLOOR_SEED - 1)


## Floor `floor_no`'s usage in permille: 300 + 50 per floor, capped 850, +-50 seeded jitter (250-850).
static func usage_permille(run_seed: int, floor_no: int) -> int:
	var base := mini(Economy.DESCENT_U_START + Economy.DESCENT_U_STEP * (maxi(floor_no, 1) - 1), Economy.DESCENT_U_MAX)
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed(run_seed, floor_no) ^ JITTER_SALT
	var jitter := rng.randi_range(-Economy.DESCENT_U_JITTER, Economy.DESCENT_U_JITTER)
	return clampi(base + jitter, Economy.DESCENT_U_MIN, Economy.DESCENT_U_MAX)


## The art theme of a floor: the story order, round and round (floor 1 = Dark Dungeon, 11 again).
static func theme_for(floor_no: int) -> String:
	return Themes.for_level((maxi(floor_no, 1) - 1) % Levels.COUNT + 1)


## A floor's recipe for MazeGenerator.generate_random (like Levels.random_config): the route is the
## floor's usage x the player's base meter (136 tiles x the MORE SLIME factor of `slime_level`); the
## size is the randomizer's (Levels.random_cells: sized from the player's slime capacity, never
## small, owner rule 2026-10-14); tile wear grows with depth (floor 10+ = the story's level 10 look).
static func floor_config(run_seed: int, floor_no: int, slime_level := 0) -> Dictionary:
	var level := clampi(slime_level, 0, Levels.max_slime_level())
	var fseed := floor_seed(run_seed, floor_no)
	var permille := usage_permille(run_seed, floor_no)
	return {
		cells = Levels.random_cells(fseed, level),
		seed = fseed,
		usage = permille / 1000.0,
		target = permille / 1000.0,
		route = Levels.random_route_cells_for(permille, level),
		room = Levels.random_max_route_cells(level),
		slime_level = level,
		tile_cost = 100.0 / Levels.random_capacity_tiles(level),
		tile_level = clampi(floor_no, 1, Levels.COUNT),
		floor = floor_no,
		theme = theme_for(floor_no),
	}


## The refill (percent) for entering `floor_no` (+60 / 50 / 40 / 35), before THRIFT.
static func refill(floor_no: int) -> float:
	return float(_step_value(Economy.DESCENT_REFILL, floor_no))


## Pot tickets a cleared `floor_no` adds (+1 / 2 / 3 / 4), before GREEDY GOO.
static func pot_per_floor(floor_no: int) -> int:
	return _step_value(Economy.DESCENT_POT_PER_FLOOR, floor_no)


static func _step_value(table: Array, floor_no: int) -> int:
	var out: int = table[0][1]
	for row: Array in table:
		if floor_no >= int(row[0]):
			out = row[1]
	return out


## The cells for a floor's goo drops: the maze's deep dead ends, one per side branch first, seeded
## like the story's coins (Levels.coin_cells: never the exit), never the start; DESCENT_DROPS of them.
static func drop_cells(maze: Dictionary, maze_seed: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in Levels.coin_cells(maze, Levels.COUNT, maze_seed):
		if cell != maze.start and out.size() < Economy.DESCENT_DROPS:
			out.append(cell)
	return out


# ---------------------------------------------------------------- boons

static func held(boons: Dictionary, id: String) -> int:
	return int(boons.get(id, 0))


## True when `id` may still be offered: a boon held its `max` times (non-stacking: once) is not, nor
## one whose `excludes` boon is held (RUBBER BODY and GLASS SLIME never go together).
static func can_offer(id: String, boons: Dictionary) -> bool:
	var b := boon(id)
	if b.is_empty():
		return false
	if held(boons, String(b.get("excludes", ""))) > 0:
		return false
	var top: int = int(b.get("max", 1))
	return top <= 0 or held(boons, id) < top


## The boons offered after clearing `floor_no`: BOON_OFFERS distinct ones, drawn by weight without
## replacement from those that can still be offered, seeded by the run seed and the floor (the same
## run with the same picks always gets the same offers).
static func offers(run_seed: int, floor_no: int, boons: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for id in IDS:
		if can_offer(id, boons):
			pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = (floor_seed(run_seed, floor_no) * 31 + OFFER_SALT) ^ SEED_SALT
	var out: Array[String] = []
	while out.size() < Economy.BOON_OFFERS and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float(boon(id).weight)
		var roll := rng.randf() * total
		var pick := pool[-1]
		for id in pool:
			roll -= float(boon(id).weight)
			if roll < 0.0:
				pick = id
				break
		out.append(pick)
		pool.erase(pick)
	return out


## The run's meter capacity as a share of the player's base meter: DEEP TANK +15% each, GREEDY GOO
## -10% (one stack only; additive).
static func capacity(boons: Dictionary) -> float:
	return 1.0 + held(boons, "tank") * float(boon("tank").value) + held(boons, "greedy") * float(boon("greedy").value)


## Glide speed factor (SLICK +15% each).
static func speed(boons: Dictionary) -> float:
	return 1.0 + held(boons, "slick") * float(boon("slick").value)


## Leap cost factor (share of gliding the distance flown): FEATHER LEAP 0.35, else `base`.
static func jump_cost(boons: Dictionary, base: float) -> float:
	return float(boon("feather").value) if held(boons, "feather") > 0 else base


## Splat penalty factor: RUBBER BODY 0, GLASS SLIME x2 (never both: they exclude each other).
static func splat_factor(boons: Dictionary) -> float:
	if held(boons, "rubber") > 0:
		return 0.0
	return float(boon("glass").splat) if held(boons, "glass") > 0 else 1.0


## Light reach (px) with BLAZE: one BRIGHTNESS step up from `level` (past the top: BOONS.blaze.value).
static func light_reach(boons: Dictionary, level: int) -> float:
	if held(boons, "blaze") <= 0:
		return Upgrades.light_reach(level)
	if level < Upgrades.max_level("brightness"):
		return Upgrades.light_reach(level + 1)
	return maxf(Upgrades.light_reach(level), float(boon("blaze").value))


## How near (px) the exit shows itself: CHALICE SENSE's reach, else `base`.
static func goal_reveal(boons: Dictionary, base: float) -> float:
	return maxf(base, float(boon("sense").value)) if held(boons, "sense") > 0 else base


## Floor refill (percent) for entering `floor_no` with these boons (THRIFT +15 each).
static func floor_refill(floor_no: int, boons: Dictionary) -> float:
	return refill(floor_no) + held(boons, "thrift") * float(boon("thrift").value)


## Pot tickets a cleared `floor_no` adds with these boons (GREEDY GOO +1 each).
static func floor_gain(floor_no: int, boons: Dictionary) -> int:
	return pot_per_floor(floor_no) + held(boons, "greedy") * int(boon("greedy").tickets)


# ---------------------------------------------------------------- run steps

## The current floor is cleared with `left` percent of the meter after `seconds`: the pot grows
## (capped), the time adds up. Returns the pot gain. Call once per floor.
static func clear_floor(run: Dictionary, left: float, seconds: float) -> int:
	var before: int = run.pot
	run.pot = mini(before + floor_gain(run.floor, run.boons), Economy.DESCENT_POT_MAX)
	run.gain = run.pot - before
	run.time = float(run.time) + maxf(seconds, 0.0)
	run.cleared = int(run.floor)
	run.meter = clampf(left, 0.0, 100.0)
	return run.gain


## Takes boon `id` (one of the offers) and goes down to the next floor: the boon is applied, then the
## meter left on the cleared floor (kept in tiles when the capacity changes) gets the next floor's
## refill (+ THRIFT, + BIG GULP), capped at a full meter.
static func descend(run: Dictionary, id: String) -> void:
	var cap_before := capacity(run.boons)
	if can_offer(id, run.boons):
		run.boons[id] = held(run.boons, id) + 1
		if id == "bladder":
			run.bladders = int(run.bladders) + 1
	var cap_after := capacity(run.boons)
	var meter: float = float(run.meter) * cap_before / cap_after
	if id == "gulp":
		meter += float(boon("gulp").value)
	run.floor = int(run.floor) + 1
	meter += floor_refill(run.floor, run.boons)
	run.meter = clampf(meter, 0.0, 100.0)
	run.gain = 0


## The tickets a run's pot banks before the daily / slime / dev caps: the whole pot on CASH OUT,
## half (rounded down) on a dry-up or quit; GLASS SLIME x1.5 (rounded down); never above the pot cap.
static func bank(pot: int, cashed: bool, boons: Dictionary) -> int:
	var tickets := pot if cashed else pot / 2
	if held(boons, "glass") > 0:
		tickets = floori(tickets * float(boon("glass").pot))
	return clampi(tickets, 0, Economy.DESCENT_POT_MAX)


## The milestone bonus for first reaching `floor_no` (0 if none).
static func milestone(floor_no: int) -> int:
	return int(Economy.DESCENT_MILESTONES.get(floor_no, 0))


## The bit of `floor_no` in the saved milestone mask (-1 if it isn't a milestone floor).
static func milestone_bit(floor_no: int) -> int:
	var floors: Array = Economy.DESCENT_MILESTONES.keys()
	floors.sort()
	return floors.find(floor_no)
