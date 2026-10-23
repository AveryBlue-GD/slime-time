class_name Achievements
extends RefCounted

## IMP-07 ACHIEVEMENTS: about 20 offline goals plus the pooled MEDAL MILESTONES. Almost every state is
## derived from saved progress (so an old save lights up correctly); only what can't be derived is stored in
## Progress.ach_flags (the FLAG_ bits below). Progress.check_achievements() toasts and reports each new one
## through PlatformEvents.progress_event ("ach_<id>", 1) so a Steam / Game Center backend can mirror them.

const FLAG_JELLY := 1  ## a see-through (jelly) skin was worn
const FLAG_RIFLE := 2  ## ability used once, by Abilities id
const FLAG_SPLAT := 4
const FLAG_KAZE := 8
const FLAG_CLEAN_WIN := 16  ## a randomizer maze won with abilities in the pocket and none used
const FLAGS_ABILITIES := FLAG_RIFLE | FLAG_SPLAT | FLAG_KAZE

## One page of the list.
const PER_PAGE := 8


## id, goal text (what the page shows; also the toast's second half). Order = the page's order.
static func list() -> Array[Dictionary]:
	var n := Levels.COUNT
	var coins := Levels.total_coins()
	# i18n: achievement goal, max 270px, 1 line, all caps
	return [
		{id = "clear_1", goal = Loc.t("ach.clear_1", "BEAT LEVEL 1")},
		{id = "clear_story", goal = Loc.t("ach.clear_story", "BEAT THE STORY (ALL {n} LEVELS)", {n = n})},  # i18n: achievement goal, max 270px, 1 line; {n} = 10
		{id = "hard_1", goal = Loc.t("ach.hard_1", "BEAT LEVEL 1 ON HARD")},  # i18n: achievement goal, max 270px, 1 line
		{id = "hard_all", goal = Loc.t("ach.hard_all", "BEAT ALL {n} LEVELS ON HARD", {n = n})},  # i18n: achievement goal, max 270px, 1 line; {n} = 10
		{id = "coins_50", goal = Loc.t("ach.coins", "FIND {n} COINS", {n = 50})},  # i18n: achievement goal, max 270px, 1 line; {n} = a coin count
		{id = "coins_100", goal = Loc.t("ach.coins", "FIND {n} COINS", {n = 100})},
		{id = "coins_all", goal = Loc.t("ach.coins_all", "FIND ALL {n} COINS", {n = coins})},  # i18n: achievement goal, max 270px, 1 line; {n} = 165
		{id = "gold_1", goal = Loc.t("ach.gold_1", "WIN YOUR FIRST GOLD MEDAL")},  # i18n: achievement goal, max 270px, 1 line
		{id = "gold_10", goal = Loc.t("ach.gold_n", "WIN {n} GOLD MEDALS", {n = 10})},  # i18n: achievement goal, max 270px, 1 line; {n} = a count
		{id = "gold_30", goal = Loc.t("ach.gold_n", "WIN {n} GOLD MEDALS", {n = 30})},
		{id = "rand_1", goal = Loc.t("ach.rand_1", "WIN A RANDOM MAZE")},  # i18n: achievement goal, max 270px, 1 line
		{id = "rand_10", goal = Loc.t("ach.rand_n", "WIN {n} RANDOM MAZES", {n = 10})},  # i18n: achievement goal, max 270px, 1 line; {n} = a count
		{id = "rand_50", goal = Loc.t("ach.rand_n", "WIN {n} RANDOM MAZES", {n = 50})},
		{id = "rand_100", goal = Loc.t("ach.rand_n", "WIN {n} RANDOM MAZES", {n = 100})},
		{id = "daily_1", goal = Loc.t("ach.daily_1", "WIN A DAILY MAZE")},  # i18n: achievement goal, max 270px, 1 line
		{id = "daily_7", goal = Loc.t("ach.daily_7", "WIN THE DAILY MAZE {n} DAYS IN A ROW", {n = 7})},  # i18n: achievement goal, max 270px, 1 line; {n} = 7
		{id = "wheel_1", goal = Loc.t("ach.wheel_1", "SPIN THE PRIZE WHEEL")},  # i18n: achievement goal, max 270px, 1 line
		{id = "hats_6", goal = Loc.t("ach.hats_n", "OWN {n} HATS", {n = 6})},  # i18n: achievement goal, max 270px, 1 line; {n} = a count
		{id = "jelly", goal = Loc.t("ach.jelly", "WEAR A JELLY SKIN")},  # i18n: achievement goal, max 270px, 1 line
		{id = "abilities", goal = Loc.t("ach.abilities", "USE EACH ABILITY ONCE")},  # i18n: achievement goal, max 270px, 1 line
		{id = "clean_win", goal = Loc.t("ach.clean_win", "WIN A RANDOM MAZE USING NO ABILITY")},  # i18n: achievement goal, max 270px, 1 line
	]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for a in list():
		out.append(a.id)
	return out


## Golds across normal and hard mode (a tier-3 medal each).
static func golds(p: Node) -> int:
	var n := 0
	for key in p.medals:
		if int(p.medals[key]) >= p.TIER_GOLD:
			n += 1
	return n


## Medals earned in all: every tier of every level, normal and hard (any tier counts as that many).
static func medals_earned(p: Node) -> int:
	return p.medals_total(false) + p.medals_total(true)


## Whether achievement `id` is met by `p`'s saved state right now (no stored "unlocked" list involved).
static func met(p: Node, id: String) -> bool:
	var f: int = p.ach_flags
	match id:
		"clear_1": return p.levels_cleared >= 1
		"clear_story": return p.levels_cleared >= Levels.COUNT
		"hard_1": return 1 in p.hard_cleared
		"hard_all": return p.hard_cleared.size() >= Levels.COUNT
		"coins_50": return p.coins_earned() >= 50
		"coins_100": return p.coins_earned() >= 100
		"coins_all": return p.coins_earned() >= Levels.total_coins()
		"gold_1": return golds(p) >= 1
		"gold_10": return golds(p) >= 10
		"gold_30": return golds(p) >= 30
		"rand_1": return p.randoms_won >= 1
		"rand_10": return p.randoms_won >= 10
		"rand_50": return p.randoms_won >= 50
		"rand_100": return p.randoms_won >= 100
		"daily_1": return p.daily_day > 0 or p.daily_best_streak > 0
		"daily_7": return p.daily_best_streak >= 7
		"wheel_1": return p.spins >= 1 or not p.hats_owned.is_empty()
		"hats_6": return p.hats_owned.size() >= 6
		"jelly": return f & FLAG_JELLY != 0 or p.jelly
		"abilities": return f & FLAGS_ABILITIES == FLAGS_ABILITIES
		"clean_win": return f & FLAG_CLEAN_WIN != 0
	return false


## Every goal met right now, as a list of ids.
static func met_ids(p: Node) -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if met(p, id):
			out.append(id)
	return out


## Medals earned per milestone paid, and tickets per milestone.
static func milestones_due(earned: int) -> int:
	return earned / Economy.MEDAL_MILESTONE_STEP


## The next milestone's medal count above `earned`.
static func next_milestone(earned: int) -> int:
	return (earned / Economy.MEDAL_MILESTONE_STEP + 1) * Economy.MEDAL_MILESTONE_STEP
