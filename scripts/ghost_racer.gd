class_name GhostRacer
extends Node

## BM-03 GHOSTS: a daily / weekly run records the slime's position every 1 / Economy.GHOST_HZ s (packed ints, see Boards) and
## replays the best earlier run of the same day / week as one translucent slime sprite (a pale palette, 50% alpha through
## `modulate`, whole-pixel positions, one frame below the slime). `step` runs on the game's physics tick with the run clock.

var game: Node2D
var kind := ""  # "daily" / "weekly", or a story level's Boards.story_kind ("story_3" / "hard_3")
var key := 0  # the day / week the board is for (a story level: the level)
var rec: Array[int] = []
## The ghost being raced ({key, ms, pts}), empty = none (nothing recorded yet, or GHOST is off).
var best := {}
var sprite: AnimatedSprite2D = null
## The ghost's translucency and palette (a cool pale blue, so it never reads as the player's own skin).
const GHOST_ALPHA := 0.5
const GHOST_COLOR := Color(0.62, 0.78, 0.95)


## The racer for this run, or null when it is not a daily / weekly with the boards on.
static func create(owner_game: Node2D) -> GhostRacer:
	if not Economy.boards_on() or owner_game == null:
		return null
	var progress: Node = owner_game.progress
	if progress == null or owner_game.training:
		return null
	if not owner_game.is_random():
		return _create_story(owner_game, progress)
	if not (progress.random_daily or progress.random_weekly):
		return null
	var racer := GhostRacer.new()
	racer.game = owner_game
	racer.kind = "weekly" if progress.random_weekly else "daily"
	racer.key = Boards.week_of(progress.daily_run_day) if progress.random_weekly else progress.daily_run_day
	racer.name = "GhostRacer"
	owner_game.add_child(racer)
	if progress.ghost_on:
		racer.best = progress.ghost_for(racer.kind, racer.key)
		if not racer.best.is_empty():
			racer._make_sprite()
	return racer


## IMP3-06: a story level (normal or hard) records the best clear and races it later. Nothing for Descent, the demo, dev
## tools, or a run that does not save (--story, --autoplay, tests without a save file).
static func _create_story(owner_game: Node2D, progress: Node) -> GhostRacer:
	if owner_game.descent or Demo.on() or progress.dev_tools or not progress.saving_enabled:
		return null
	var racer := GhostRacer.new()
	racer.game = owner_game
	racer.kind = Boards.story_kind(owner_game.level, owner_game.hard_mode)
	racer.key = owner_game.level
	racer.name = "GhostRacer"
	owner_game.add_child(racer)
	if progress.ghost_on:
		racer.best = progress.ghost_for(racer.kind, racer.key)
		if not racer.best.is_empty():
			racer._make_sprite()
	return racer


func _make_sprite() -> void:
	var slime: Node2D = game.slime
	sprite = AnimatedSprite2D.new()
	sprite.name = "Ghost"
	sprite.sprite_frames = slime.sprite.sprite_frames
	sprite.material = Skins.make_material(GHOST_COLOR)
	sprite.modulate = Color(1, 1, 1, GHOST_ALPHA)
	sprite.z_index = slime.z_index - 1
	sprite.animation = "idle"
	sprite.frame = 0
	sprite.position = Vector2(Boards.ghost_pos(best.pts, 0.0))
	slime.get_parent().add_child(sprite)


## One physics tick: record a sample for every 0.1 s of run clock not yet recorded, and move the ghost.
func step(t: float, pos: Vector2) -> void:
	while rec.size() < Economy.GHOST_MAX and float(rec.size()) / Economy.GHOST_HZ <= t:
		rec.append(Boards.pack(pos))
	if sprite != null:
		sprite.position = Vector2(Boards.ghost_pos(best.pts, t))


## True when the recording fits the cap (a run longer than GHOST_MAX / GHOST_HZ s keeps no ghost).
func recorded_ok() -> bool:
	return rec.size() >= 1 and rec.size() < Economy.GHOST_MAX


## The win at `ms`: the split against the ghost raced ("" = no ghost), then the run becomes the new best if it is faster.
func finish(ms: int) -> String:
	var split := ""
	if not best.is_empty():
		split = Boards.split_text(ms - int(best.ms))
	if recorded_ok() and not (game.assisted or game.dev_toggled or game.relaxed_run):
		rec.append(Boards.pack(game.slime.position))
		game.progress.record_ghost(kind, key, ms, rec)
	return split


func _exit_tree() -> void:
	if is_instance_valid(sprite):
		sprite.queue_free()
