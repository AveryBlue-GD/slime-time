class_name Boards
extends RefCounted

## BM-03 BOARDS & GHOSTS (Economy.BOARDS_TEST): the pure parts. Days are UTC day numbers (days since 1970, Progress.utc_day),
## weeks run Monday to Sunday (ISO weeks; week 0 = Mon 1969-12-29). A board entry is one int, `ms * 8 + weekday`
## (weekday 0 = Monday), a board is a sorted Array[int] of at most Economy.BOARD_TOP of them. A ghost is the best run of a
## day / week: one packed (x, y) per 1 / GHOST_HZ s (positions only), kept in the side file user://ghosts.cfg.

const SaveText := preload("res://scripts/save_text.gd")
## Weekly seeds are daily seeds of a number no day reaches, so they never equal a daily's.
const WEEK_SEED_BASE := 500000
const KEEP_DAYS := 30
const KEEP_WEEKS := 12
const POS_BIAS := 8192


static func week_of(day: int) -> int:
	return floori((day + 3) / 7.0)


## 0 = Monday ... 6 = Sunday.
static func weekday(day: int) -> int:
	return posmod(day + 3, 7)


## The Monday of `week` as a UTC day number.
static func week_start(week: int) -> int:
	return week * 7 - 3


## "WEEKLY #n", counted from the week of DAILY #1.
static func weekly_number(week: int) -> int:
	return maxi(week - week_of(Economy.DAILY_EPOCH_DAY) + 1, 1)


## The weekly maze's seed: the same for everyone that week.
static func weekly_seed(week: int) -> int:
	# (the same integer hash as Progress.daily_seed, copied: this script is compiled before the autoloads exist)
	var x: int = ((week + WEEK_SEED_BASE) * 2654435761 + 40503) & 0xFFFFFFFF
	x = ((x ^ (x >> 15)) * 2246822519) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 3266489917) & 0xFFFFFFFF
	x ^= x >> 16
	return x % 2_000_000_000 + 1


static func entry(ms: int, day: int) -> int:
	return ms * 8 + weekday(day)


static func entry_ms(e: int) -> int:
	return e >> 3


## The UTC day an entry was set on: a daily board's key is the day itself, a weekly board's the week.
static func entry_day(e: int, key: int, weekly: bool) -> int:
	return week_start(key) + (e & 7) if weekly else key


## `board` with `ms` inserted (ties go after older equal times), cut to the top Economy.BOARD_TOP.
static func inserted(board: Array, ms: int, day: int) -> Array[int]:
	var out: Array[int] = []
	for e: Variant in board:
		if typeof(e) == TYPE_INT:
			out.append(e)
	var at := out.size()
	for i in out.size():
		if entry_ms(out[i]) > ms:
			at = i
			break
	out.insert(at, entry(ms, day))
	while out.size() > Economy.BOARD_TOP:
		out.pop_back()
	return out


## 1-based place of `ms` on `board` after it was inserted (0 = it fell off the top 5).
static func rank_of(board: Array, ms: int, day: int) -> int:
	return board.find(entry(ms, day)) + 1


## The split text at the chalice: "+1.2s" when slower than the ghost, "-0.8s" when faster ("0.0s" when level).
static func split_text(delta_ms: int) -> String:
	var tenths := roundi(absf(delta_ms) / 100.0)
	if tenths == 0:
		return "0.0s"
	return "%s%d.%ds" % ["+" if delta_ms > 0 else "-", tenths / 10, tenths % 10]


static func pack(pos: Vector2) -> int:
	var x := clampi(roundi(pos.x) + POS_BIAS, 0, 65535)
	var y := clampi(roundi(pos.y) + POS_BIAS, 0, 65535)
	return x | (y << 16)


static func unpack(v: int) -> Vector2i:
	return Vector2i((v & 0xFFFF) - POS_BIAS, ((v >> 16) & 0xFFFF) - POS_BIAS)


## Where a ghost sample list puts the slime `t` seconds into the run: a whole-pixel position (the last sample once it is over).
static func ghost_pos(pts: Array, t: float) -> Vector2i:
	if pts.is_empty():
		return Vector2i.ZERO
	var f := maxf(t, 0.0) * Economy.GHOST_HZ
	var i := floori(f)
	if i >= pts.size() - 1:
		return unpack(pts[pts.size() - 1])
	var a := Vector2(unpack(pts[i]))
	var b := Vector2(unpack(pts[i + 1]))
	return Vector2i(a.lerp(b, f - i).round())


# ---------------------------------------------------------------- the ghosts file

## Ghost kinds: the daily / weekly, and one best clear per story level and mode ("story_3", "hard_3": the key is the level).
static func story_kind(level: int, hard: bool) -> String:
	return "%s_%d" % ["hard" if hard else "story", level]


static func valid_kind(kind: String) -> bool:
	if kind == "daily" or kind == "weekly":
		return true
	for prefix: String in ["story_", "hard_"]:
		if kind.begins_with(prefix) and kind.substr(prefix.length()).is_valid_int():
			var n := kind.substr(prefix.length()).to_int()
			return n >= 1 and n <= Levels.COUNT and str(n) == kind.substr(prefix.length())
	return false


## The ghosts file must stay under SaveText.MAX_BYTES (256 KB) to be read back; 22 ghosts of a normal length (a 90 s clear
## is ~900 samples, ~11 KB) fit, and past this size the largest story ghosts are dropped.
const MAX_FILE_BYTES := 240 * 1024


## The saved ghosts: {"daily": {key, ms, pts}, "weekly": {...}, "story_3": {...}, "hard_3": {...}} (a kind with no valid ghost is missing).
static func read_ghosts(path: String) -> Dictionary:
	var out := {}
	if not FileAccess.file_exists(path):
		return out
	var file := SaveText.parse(FileAccess.get_file_as_bytes(path))  # allow-list first, like the save
	if file == null:
		return out
	for kind: String in file.get_sections():
		if not valid_kind(kind):
			continue
		var pts := SaveFile.ints(file.get_value(kind, "pts", []))
		var ms := SaveFile.get_int(file, kind, "ms", 0)
		var key := SaveFile.get_int(file, kind, "key", 0)
		if key > 0 and ms > 0 and pts.size() > 1 and pts.size() <= Economy.GHOST_MAX:
			out[kind] = {key = key, ms = ms, pts = pts}
	return out


static func _ghosts_text(ghosts: Dictionary) -> String:
	var file := ConfigFile.new()
	for kind: String in ghosts:
		var g: Dictionary = ghosts[kind]
		file.set_value(kind, "key", g.key)
		file.set_value(kind, "ms", g.ms)
		var pts: Array[int] = []
		pts.assign(g.pts)
		file.set_value(kind, "pts", pts)
	return file.encode_to_text()


## Writes the file; when it would pass MAX_FILE_BYTES the longest story ghosts are dropped from `ghosts` first.
static func write_ghosts(path: String, ghosts: Dictionary) -> bool:
	var text := _ghosts_text(ghosts)
	while text.length() > MAX_FILE_BYTES:
		var worst := ""
		for kind: String in ghosts:
			if kind != "daily" and kind != "weekly" and (worst == "" or ghosts[kind].pts.size() > ghosts[worst].pts.size()):
				worst = kind
		if worst == "":
			break
		ghosts.erase(worst)
		text = _ghosts_text(ghosts)
	# (tmp + rename like the save, so a crash mid-write never leaves half a file; a ghost is only a replay, a failed write
	# just means no ghost). The Progress autoload comes via the tree: a global-class script can't name it directly.
	return (Engine.get_main_loop() as SceneTree).root.get_node("Progress").write_atomic(path, text)
