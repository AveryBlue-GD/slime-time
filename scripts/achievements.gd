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
		{id = "gold_20", goal = Loc.t("ach.gold_n", "WIN {n} GOLD MEDALS", {n = 20})},
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
		"gold_20": return golds(p) >= 20
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


## The count a goal with a number shows on the page: Vector2i(done, of) with `done` capped at `of`; (0, 0) = a goal
## without a number.
static func progress(p: Node, id: String) -> Vector2i:
	var pair := Vector2i.ZERO
	match id:
		"clear_story": pair = Vector2i(p.levels_cleared, Levels.COUNT)
		"hard_all": pair = Vector2i(p.hard_cleared.size(), Levels.COUNT)
		"coins_50": pair = Vector2i(p.coins_earned(), 50)
		"coins_100": pair = Vector2i(p.coins_earned(), 100)
		"coins_all": pair = Vector2i(p.coins_earned(), Levels.total_coins())
		"gold_10": pair = Vector2i(golds(p), 10)
		"gold_20": pair = Vector2i(golds(p), 20)
		"rand_10": pair = Vector2i(p.randoms_won, 10)
		"rand_50": pair = Vector2i(p.randoms_won, 50)
		"rand_100": pair = Vector2i(p.randoms_won, 100)
		"daily_7": pair = Vector2i(p.daily_best_streak, 7)
		"hats_6": pair = Vector2i(p.hats_owned.size(), 6)
		"abilities":
			var used := 0
			for bit: int in [FLAG_RIFLE, FLAG_SPLAT, FLAG_KAZE]:
				used += 1 if p.ach_flags & bit != 0 else 0
			pair = Vector2i(used, 3)
	pair.x = clampi(pair.x, 0, pair.y)
	return pair


## Every goal met right now, as a list of ids.
static func met_ids(p: Node) -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if met(p, id):
			out.append(id)
	return out


## IMP2-03: a goal's reward, an existing cosmetic (Cosmetics id: a map paper or a trail; never a skin), granted once when the
## goal is met and shown on the page as "REWARD: <name>".
const REWARDS := {
	"clear_story": "goldleaf",
	"hard_1": "night",
	"hard_all": "prism_paper",
	"coins_50": "clover_paper",
	"gold_10": "butter_paper",
	"rand_10": "ink",
	"rand_50": "plum_paper",
	"daily_7": "candy",
}

## The pooled medal milestones (medals earned, normal + hard): each grants a named cosmetic, or MEDAL_MILESTONE_TICKETS
## tickets (one wheel spin) when that cosmetic is already owned. The bit of each in Progress.medal_ms_mask is its index.
const MILESTONES := [
	{medals = 15, cosmetic = "blueprint"},
	{medals = 30, cosmetic = "starry"},
	{medals = 45, cosmetic = "gold"},
	{medals = 60, cosmetic = "bubblegum_paper"},
]


## Goal `id`'s reward cosmetic ("" = none).
static func reward_for(id: String) -> String:
	return REWARDS.get(id, "")


## The milestone indexes reached at `earned` medals.
static func milestones_reached(earned: int) -> Array[int]:
	var out: Array[int] = []
	for i in MILESTONES.size():
		if earned >= int(MILESTONES[i].medals):
			out.append(i)
	return out


## The next milestone's medal count above `earned` (0 once every one is reached).
static func next_milestone(earned: int) -> int:
	for m: Dictionary in MILESTONES:
		if earned < int(m.medals):
			return int(m.medals)
	return 0


## Randomizer wins until the next thing a win unlocks (the next pastel skin, the next win goal), 0 when none is left.
static func wins_to_next_unlock(wins: int) -> int:
	var best := 0
	var marks: Array[int] = [1, 10, 50, 100]
	for id: String in Skins.PRESETS.map(func(preset: Dictionary) -> String: return preset.id) + [Skins.RAINBOW]:
		marks.append(Skins.pastel_wins(id))
	for mark in marks:
		if mark > wins and (best == 0 or mark - wins < best):
			best = mark - wins
	return best
