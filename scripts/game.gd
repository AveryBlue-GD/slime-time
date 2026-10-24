extends Node2D

## One maze: the map starts black, the slime's goo trail reveals it, moving drains the slime
## meter, and touching the goal wins: the golden chalice in a story level, the gold ticket voucher
## (TicketGoal) in a randomizer maze. Plays a story level or a randomizer maze.
##
## Jumps leave no trail in the air, only a splat where they land. A jump costs JUMP_COST_FACTOR
## of gliding the distance flown; hitting a wall adds a penalty (SPLAT_PENALTY_MIN for a tiny hop
## up to SPLAT_PENALTY_MAX for a full-power leap), shakes the screen and stains the wall.
##
## Reveal works on a fine grid (FOG_CELL px). Two RGBA8 images cover the map (kept as raw bytes,
## _trail_bytes / _fog_bytes, and uploaded from them):
## - trail_image: goo (in the skin's colors) where the slime has been
## - fog_image:   per cell, when it was last lit, when it was first revealed, and floor vs wall,
##   packed into a plain RGBA8 image (see _fog_color) so every device can use it -- many phone
##   GPUs can't load float textures. fog.gdshader decodes it and draws soft drifting mist. Revealed cells near the slime stay lit; once it moves away they fade
##   back toward darkness in steps (FADE_AFTER / FADE_ALPHA). Walls follow the same steps at
##   the same moments, just a constant WALL_FOG_ALPHA darker, so everything dims together.

const TILE := 16
const FOG_CELL := 2
## Wider than the corridor, so the trail paints the floor wall to wall.
const TRAIL_RADIUS := 9.0
## How far past the trail's edge walls get revealed.
const WALL_REVEAL_REACH := 4.0
## How much darker revealed walls are than the floor beside them (0-1 of the remaining light).
const WALL_FOG_ALPHA := 0.3
## The goal (chalice or randomizer ticket) shows itself within this many px of the slime.
const CHALICE_REVEAL_DISTANCE := 24.0
const JUMP_COST_FACTOR := 0.5
## Extra percent of slime lost when a jump hits a wall, scaled by how hard it was charged.
const SPLAT_PENALTY_MIN := 2.0
const SPLAT_PENALTY_MAX := 5.0
const LANDING_RADIUS := 11.0
const STAIN_RADIUS := 6.0

## Revealed cells within this distance of the slime are kept fully lit.
const LIGHT_RADIUS := 20.0
## Fade layers: a cell last lit less than FADE_AFTER[i] seconds ago has darkness FADE_ALPHA[i];
## older than the last step, it settles at the final FADE_ALPHA (a dim memory of the path).
## Hard mode: a cell older than the last step is covered by fog again.
const FADE_AFTER: Array[float] = [1.5, 3.5, 6.0, 9.0]
const FADE_ALPHA: Array[float] = [0.0, 0.3, 0.5, 0.65, 0.78]
## Fog brightness setting (Progress.fog_brightness: Dark, Normal, Bright). Normal is the game's
## standard look (FADE_ALPHA / WALL_FOG_ALPHA above). Bright follows docs/archive/advisor/graphics-shading.md
## (lighter memory and unexplored mist); Dark is a bit heavier than Normal. `fade`/`wall` feed both
## the shader and fog_alpha_at, so they always agree.
const FOG_LOOKS: Array[Dictionary] = [
	{fade = [0.0, 0.33, 0.55, 0.72, 0.86], wall = 0.36, deep_gain = 0.4, mist_gain = 0.34, far_dim = 0.3, vig_max = 0.45, light_outer = 110.0},
	{fade = FADE_ALPHA, wall = WALL_FOG_ALPHA, deep_gain = 0.55, mist_gain = 0.45, far_dim = 0.22, vig_max = 0.35, light_outer = 115.0},
	{fade = [0.0, 0.25, 0.42, 0.54, 0.64], wall = 0.2, deep_gain = 0.75, mist_gain = 0.55, far_dim = 0.14, vig_max = 0.25, light_outer = 125.0},
]
## Economy.DARK_FOG: the same looks with the unrevealed mist crushed to near-black (Bright is left alone).
const FOG_LOOKS_DARK: Array[Dictionary] = [
	{fade = [0.0, 0.33, 0.55, 0.72, 0.86], wall = 0.36, deep_gain = 0.12, mist_gain = 0.1, far_dim = 0.3, vig_max = 0.45, light_outer = 110.0},
	{fade = FADE_ALPHA, wall = WALL_FOG_ALPHA, deep_gain = 0.16, mist_gain = 0.13, far_dim = 0.22, vig_max = 0.35, light_outer = 115.0},
]
const UNREVEALED := Color(0, 0, 0, 0)
## Fog times are stored as 16-bit counts of 1/FOG_TICKS seconds (up to ~68 minutes).
const FOG_TICKS := 16.0

## (Trail goo alpha and halo strength now live in Cosmetics: GOO_ALPHA / TRAIL_GLOW, per trail style.)
const GOO_ALPHA := Cosmetics.GOO_ALPHA
## Rainbow skin: the trail's hue advances this many full rainbows per second of play.
const RAINBOW_TRAIL_SPEED := 0.08
const CLEAR := Color(0, 0, 0, 0)
const HUB_SCENE := "res://scenes/hub.tscn"
## Seconds the "first run: playing as ..." notice stays up.
const FORCED_SKIN_NOTICE := 2.5
const VICTORY_SCENE := "res://scenes/victory.tscn"
## The demo's end screen script (scripts/ui/demo_end.gd, DemoEnd), loaded by path when used: naming the
## class here made a load cycle that left game.gd's static vars unset.
const DEMO_END_SCRIPT := "res://scripts/ui/demo_end.gd"
const UPGRADES_SCENE := "res://scenes/upgrades.tscn"
const MAPS_SCENE := "res://scenes/maps.tscn"
## After a win, the replay / next buttons appear after this long (so a held key can't press one).
const CHOICE_DELAY := 0.6
## A dry-up offers its retry buttons sooner: failing should cost a moment, not a pause.
const DRY_CHOICE_DELAY := 0.25
## Descent: the run summary card follows a dry-up after this long (the dry-up is seen first).
const DESCENT_SUMMARY_DELAY := 1.0
## The chalice fanfare plays about a third quieter than other sounds (-3.5 dB = 67% amplitude).
const CHALICE_VOLUME_DB := -3.5
## Screen shake on a splat: lasts SHAKE_TIME, up to SHAKE_MAX px for a full-power leap.
const SHAKE_TIME := 0.25
const SHAKE_MAX := 3.0
## The slime's own soft light on the floor and walls around it (diameter px, strength 0-1).
## Strength of the additive halo over the goo trail.
const TRAIL_GLOW := Cosmetics.TRAIL_GLOW
const SLIME_LIGHT_SIZE := 112
## Drawn above the fog (z 11), so it lights the unexplored ground around the slime a little.
const SLIME_LIGHT_STRENGTH := 0.14
## Camera kick on a splat: px pushed toward the wall at full power (decays with the shake).
const KICK_MAX := 3.0
## The low-slime warning: a heartbeat every HEARTBEAT_SLOW s at LOW_PERCENT, speeding to HEARTBEAT_FAST at 0.
const HEARTBEAT_SLOW := 1.3
const HEARTBEAT_FAST := 0.55
## Camera look-ahead: leads the slime by its velocity * LOOK_AHEAD_TIME, up to LOOK_AHEAD_MAX px.
const LOOK_AHEAD_TIME := 0.3
const LOOK_AHEAD_MAX := 24.0
const LOOK_AHEAD_SPEED := 3.0
const CHALICE_GOLD := Color8(255, 205, 117)
## Ambience (tools/make_ambience.py). Every theme loops a bed (assets/sounds/ambient_<theme>.wav):
## very faint (AMBIENT_FAINT_DB) except the Sunken Shrine's waves and the Sandstone Sanctum's
## sandstorm (AMBIENT_BED_DB). On top, distant one-off sounds (ambient_<theme>_<n>.wav) play at
## random every AMBIENT_EVENT_GAP seconds, at a random level within AMBIENT_EVENT_DB.
const AMBIENT_FAINT_DB := -25.0
const AMBIENT_BED_DB := {"sunken": -17.0, "sandstone": -17.0}
const AMBIENT_FADE := 2.0
const AMBIENT_EVENT_GAP := Vector2(10.0, 24.0)
const AMBIENT_EVENT_DB := Vector2(-25.0, -17.0)
## Extra quietness for some themes' events (the catacombs' scream is meant to be barely there).
const AMBIENT_EVENT_TRIM := {"catacombs": -7.0}
## Glimmers: every so often a faint twinkle shows through the fog over a coin still waiting there.
## They come with distance traveled (gliding or leaping), not time: one per this many px (picked
## at random in the range each time).
const GLIMMER_EVERY := Vector2(180.0, 360.0)
## A glimmer's coin may sit this far outside the visible view (px).
const GLIMMER_VIEW_MARGIN := 8.0
## Only coins within this many px of the slime glimmer (about a screen away).
const GLIMMER_REACH := 160.0
## The maze's edge is doubled by a ring of BORDER wall tiles just outside it (covered by the fog
## image too, so it's revealed like any wall); past that the fog simply carries on, and the
## camera may look EDGE_FOG tiles beyond the ring so you can see where the maze ends.
const BORDER := 1
const EDGE_FOG := 2
const BORDER_PX := Vector2(TILE * BORDER, TILE * BORDER)

signal level_finished(won: bool)
## SPLASHDOWN training maze only (Progress.MODE_TRAINING; docs/tutorial/design.md section 14): a beat of
## the training happened (training_beat). Names: "start", "straight", "fork", "first_drain", "dry",
## "restart", "chalice". Chunk C's training cues and the HUD pulse listen to it.
signal training_cue(name: String)

## Story level to play (1-10). 0 = ask the Progress autoload (or 1 without it).
@export var level := 0
## Non-zero: play a randomizer maze from this seed instead of a story level.
@export var random_seed := 0
## DESCENT (upgrades v2 batch 3): this maze is a floor of the Descent run in Progress.descent_run
## (set in _ready from Progress.mode). The goal is the chalice (the floor's exit), the meter starts
## where the last floor left it (+ the refill), two goo drops wait at dead ends, boons apply
## (`_apply_descent`), and clearing the floor opens the boon card (DescentCard); a dry-up ends the run.
var descent := false
## SPLASHDOWN, the first-session training maze (Progress.MODE_TRAINING, Training): the hand-made layout,
## the attempt meter (low on attempt 1), a practice coin that is never saved, no medals / records /
## survey / dry-up count / tickets / upgrades / workshop / first-run skin, RESTART-only dry-up row and a
## HUB-only win row. `training_attempt` = Training.attempt for this run; `_beats` = beats emitted on it.
var training := false
var training_attempt := 0
var _beats := {}
## Seconds left of the meter's visible fill at the start of attempt 2 on (Training.FILL_TIME).
var _meter_fill := 0.0
## The practice coin's cell (the maze's `coin`), and the fork's forced glimmers still to come.
var _practice_coin := Vector2i(-1, -1)
var _fork_glimmers := 0
var _fork_glimmer_at := 0.0
## The direction line showing ("" none; Training.line names) and its seconds left (INF: until replaced), and
## the chalice line's seconds left (attempt 2 on: it comes back after "coin_use" while time is left).
var training_line := ""
var _line_left := INF
var _chalice_left := 0.0
## The run (Progress.descent_run, shared: the game writes the floor's results into it).
var descent_run := {}
## The floor's goo drops still waiting (GooDrop), and the between-floor / end-of-run card.
var drops: Array[GooDrop] = []
var descent_card: DescentCard
## DESCEND or CASH OUT was pressed on this floor's card: any second action is ignored (one per card).
var _descent_acted := false
## BACKUP BLADDER refills left this run, and slime still to be added by one firing.
var bladders := 0
var _bladder_left := 0.0
## Leap cost (share of gliding the distance flown; FEATHER LEAP lowers it) and how near the goal
## shows itself (CHALICE SENSE widens it).
var jump_cost_factor := JUMP_COST_FACTOR
var goal_reveal_distance := CHALICE_REVEAL_DISTANCE

## (Par time: Levels.par_for_path.)

## Percent of slime used per tile glided; set per maze so a perfect run uses its target (story), or
## fixed per player (randomizer: 100 / Levels.RANDOM_METER_TILES / the MORE SLIME factor).
var slime_cost_per_tile := 1.0
## Randomizer: the share of the meter (0-1) a perfect glide to the ticket uses in this maze.
var perfect_usage := 0.0
var slime_remaining := 100.0
var finished := false
var maze: Dictionary
## Damage level (0-3) of each wall tile, by tile coordinate.
var wall_damage := {}
## The fog and trail images as they are now (fresh snapshots of _fog_bytes / _trail_bytes).
var fog_image: Image:
	get:
		return Image.create_from_data(_cells.x, _cells.y, false, Image.FORMAT_RGBA8, _fog_bytes)
var trail_image: Image:
	get:
		return Image.create_from_data(_cells.x, _cells.y, false, Image.FORMAT_RGBA8, _trail_bytes)
## The fog and trail cells as raw RGBA8 bytes, row-major ((cy * width + cx) * 4): the per-tick fog
## work reads and writes these directly, and the textures are uploaded from them.
var _fog_bytes := PackedByteArray()
var _trail_bytes := PackedByteArray()
## Width and height of the fog/trail images in cells.
var _cells := Vector2i.ZERO
## Plain fog filling everything outside the maze and its border ring.
var outer_fog: Sprite2D
var revealed_walls := {}
var fog_dirty := false
var trail_dirty := false
## Relight writes that only restart cells lit at most LAZY_RELIGHT_TICKS ago don't need an upload
## at once: the fog shader draws a cell the same (the first fade band) until it is FADE_AFTER[0] old,
## so the texture's older time still looks identical. The upload waits until _fog_lazy_due (the
## oldest such old time + LAZY_RELIGHT_TICKS, 0.25 s before it could show) or the next real change.
const LAZY_RELIGHT_TICKS := 20
var _fog_lazy := false
var _fog_lazy_due := INF
## Last 1/FOG_TICKS tick, slime cell and light radius _relight ran for (it only has work when one changes).
var _relit_tick := -1
var _relit_cell := Vector2i(-99999, -99999)
var _relit_radius := -1.0
## The row spans (first, last cell per row from _span_row0) the last _relight / _reveal_light /
## gliding _paint_cells covered, and its radius: the next call with the same radius (same tick for
## _relight) only needs the cells outside them (see _disc_runs).
var _relit_spans := PackedInt32Array()
var _relit_row0 := 0
var _revealed_spans := PackedInt32Array()
var _revealed_row0 := 0
var _revealed_radius := -1.0
var _painted_spans := PackedInt32Array()
var _painted_row0 := 0
var _painted_radius := -1.0
var last_slime_pos: Vector2
## Where the slime spawned, until it first moves off it (then the HUD's intro texts stop keeping clear of
## that spot: hud.release_player_rect).
var _spawn_at := Vector2.INF
## Distance traveled since the last glimmer, the distance the next one comes at, and where the
## slime was last frame (for measuring).
var glimmer_travel := 0.0
## How near a hidden coin must be to glimmer (px; GLIMMER_REACH, tests widen it).
var glimmer_reach := GLIMMER_REACH
## Glimmers only pick coins inside the visible view (+ GLIMMER_VIEW_MARGIN); tests turn it off.
var glimmer_view_only := true
var _next_glimmer := 0.0
var _glimmer_from := Vector2.ZERO
## Seconds since the maze started; the fog's clock.
var elapsed := 0.0
## Slime spent on the most recent jump (for tests and tuning).
var last_jump_cost := 0.0
var skin_color: Color = Skins.get_preset(Skins.DEFAULT).color
var goo := Color(0, 0, 0)
## The worn trail style (Progress.trail_style, Cosmetics) and how it paints (Cosmetics.trail_look);
## `trail_travel` = px moved on the ground this run (the CANDY style's stripes).
var trail_style := Cosmetics.DEFAULT_TRAIL
var trail_look := {}
var trail_travel := 0.0
## The ticket workshop this run (Workshop; all 0 in hard mode and without Progress). SECOND WIND:
## `wind_state` "" (not on this run) / "ready" / "refilling" / "used"; `wind_fired` = it fired this
## run (a randomizer win then pays one attempt step less, pay_attempt).
var workshop := {}
var wind_state := ""
var wind_fired := false
var _wind_target := 0.0
## SECOND WIND: slime still to be added during the refill.
var _wind_left := 0.0
## STICKY's splat penalty factor, MAGNET's coin reach (px) and GOO NOSE's glimmer rate.
var splat_factor := 1.0
var coin_reach := Coin.REACH
var glimmer_rate := 1.0
var rainbow := false
## The skin's hue the fog and ambient motes lean toward (Skins.atmosphere_color).
var atmosphere_tint := Color(0, 0, 0, 0)
## The stopwatch skin is on (a clock inside the slime).
var stopwatch := false
## Hard mode: fully dimmed areas turn back into unexplored fog.
var hard_mode := false
## Seconds spent on this maze (stops on pause and when the maze ends).
var run_time := 0.0
## Wall splats this run, the par time the medal tiers are measured against (seconds; the solution path at the base gliding speed plus slack, so speed
## upgrades don't move it), whether this attempt is played with the slime reserve (ASSIST: no
## medals, records or tickets), and what the win paid (Progress.record_clear / complete_random).
var splats := 0
var par_time := 0.0
var assisted := false
var reward := {}
## True once this maze has been won (R then replays it rather than moving on).
var won := false
var shake_left := 0.0
var shake_strength := 0.0
## How long the current shake lasts in all (SHAKE_TIME, or longer for a SLIMAKAZE impact: shake()).
var shake_span := SHAKE_TIME
## Camera kick toward a wall that was just hit (px), fading with the shake.
var kick := Vector2.ZERO
var _heartbeat_left := 0.0
var _was_low := false
var slime_light: Sprite2D
var motes: Ambient
## The hat the slime is wearing, if any (see Hat).
var hat: Hat
## Coins still waiting in this story level (see Coin; never in randomizer mazes).
var coins: Array[Coin] = []
## Coin catch test: the coin shows still running (oldest first; see _catch_coin).
var coin_catches: Array[CoinCatch] = []
## How many coins this level hides in total.
var coins_here := 0
## The demo's FULL GAME PREVIEW maze (Demo.PREVIEW, Progress.begin_demo_preview): a randomizer maze with no
## attempts, pickups, pay or records; its card first (the first load only), and its win or dry-up offers only
## CONTINUE, into the randomizer's end screen (as does the pause menu's QUIT).
var preview := false
## True while the preview's card is up (the run waits under it: no clock, no drain).
var preview_card_up := false
## Randomizer: the ticket pickups still out in this maze (see TicketPickup).
var tickets: Array[TicketPickup] = []
## True while the MAP ability's mid-run map is up (toggle_run_map).
var _map_mid_run := false
## The goal touching which wins: the chalice in a story level, the TicketGoal in a randomizer maze
## (which has no chalice node at all: it is freed in _ready).
var goal: Area2D
## The MORE SLIME level this randomizer maze was built for (the second half of its seed code).
var seed_level := 0
## Randomizer: which start of this maze this is (1 = first; dry-up retries, restarts and replays
## count, NEW MAZE starts over; Progress.random_attempts) and the key it is counted under.
var attempt := 1
var attempt_key := ""
## Economy.PICKUPS_ON_WIN: the tickets the pickups taken this run are worth, paid with the win.
var held_tickets := 0
## IMP2-05: the daily win's share line (what the result row's COPY puts on the clipboard), "" outside a recorded daily win.
var daily_share := ""
## What the attempt pod shows for this run (-1 until it first shows).
var _pod_offer := -1
var _dev_pod_text := ""  # DevLog only
## What the pod was last derived from (_pod_inputs).
var _pod_inputs_shown: Array = []
## Coins picked up this run while assisted: shown on screen, but never saved.
var assisted_coins := 0
## Asks RESTART / UPGRADES / CANCEL when R is pressed mid-run.
var restart_prompt: RestartPrompt
## The ability tutorial (AbilityCoach) on this run: null once every ability here was shown (or without any).
var coach: AbilityCoach
## ABILITIES v1 (AbilityRunner): the ticket abilities on this run; null outside randomizer mazes and Descent / without any.
var abilities: AbilityRunner
## The seed this maze was built from (config.seed; the SLIMAKAZE splatter is seeded from it).
var maze_seed := 0
## Brightness upgrade: extra reach (px) of the slime's light (see Upgrades.light_reach).
var light_reach := 0.0
## Dev wall power (see Upgrades): damage left on walls, by tile (100 = intact).
var wall_power := 0
var wall_health := {}
## Art theme id (see Themes): one per story level, random per randomizer maze.
var theme := Themes.DUNGEON
var _look_ahead := Vector2.ZERO
## The slime's drawn body around its position (15 x 12 px of ink, a squash or the shadow 1 px more), and
## the room a hat takes over its head (Hats.HEAD: up to 11 rows): the area texts keep clear of them.
const SLIME_SCREEN_HALF := Vector2(9, 8)
const HAT_SCREEN_H := 11.0
## The pixel-locked camera (see _set_pixel_cam): on, its eased position, and "start it on the slime".
var _pixel_cam := false
var _cam_smooth := Vector2.ZERO
var _cam_fresh := true
## Plays the theme's continuous ambient loop (follows the sound on/off setting).
var ambient: AudioStreamPlayer
## The theme's one-off ambient sounds, and the player and countdown for the next one.
var ambient_events: Array[AudioStream] = []
var ambient_event_player: AudioStreamPlayer
var _next_ambient_event := 0.0
var _last_ambient_event := -1
## Dev toggles (dev mode only, see set_dev_bright / set_dev_no_drain): FULL BRIGHT hides the fog
## layers (the fog bytes and reveal logic carry on untouched underneath), NO DRAIN stops the meter
## draining. `dev_toggled` = one was on at some point this run, so the run sets no medal, record or
## ticket. `_bright_shown`: nodes FULL BRIGHT shows (the goal) -> their real visibility.
var dev_bright := false
var dev_no_drain := false
var dev_toggled := false
## SETTINGS RELAXED was on when this run began (no idle drain; no medal, record or ticket, like ASSIST).
var relaxed_run := false
## BM-01 (Economy.LURKERS_TEST): this run's lurkers (null = none).
var lurkers: Lurkers
## BM-03: the daily / weekly's ghost recorder and racer (null elsewhere), and the split against it shown on the result.
var ghost: GhostRacer = null
## IMP3-06: the BOARD place / ghost split tail of the share line, and how long COPY shows the line on the result (s).
var share_extra := ""
const COPY_SHOW_TIME := 3.0
## Seconds the slime has been still on the ground (the idle drain's grace, Economy.IDLE_GRACE).
var _still_time := 0.0
var _bright_shown := {}
## Trail map survey of this run (story levels only, see Survey / Progress.record_survey): one byte
## per maze tile, 1 once revealed (set where the fog is revealed, so it costs a byte write per newly
## revealed fog cell); the maze cells walked as move codes; the cell the slime was last in; whether
## the goal came into view. Recorded once, when the run ends (`_commit_survey`), and only for a real
## run (the running scene) that is not assisted, dev-toggled, in dev mode or a randomizer maze.
var survey_tiles := PackedByteArray()
var survey_moves := PackedByteArray()
var survey_goal := false
## Map coin reveal (Economy.map_coin_reveal_on): the cells of uncollected coins this run's
## light revealed (center within the slime's light, LIGHT_RADIUS + light_reach, walls ignored; every coin
## while FULL BRIGHT is on), recorded with the survey. `_coin_reveal`: the test is on for this run.
var survey_coins: Array[Vector2i] = []
var _coin_reveal := false
var _survey_cell := Vector2i.ZERO
var _survey_live := false
var _survey_done := false

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
## The border outside the maze (MazeTiles.add_border): the colliding ring and the bedrock past it, each
## on its own layer so their atlases never break the walls' (or each other's) draw batches.
@onready var border_layer: TileMapLayer = $Border
@onready var bedrock_layer: TileMapLayer = $Bedrock
@onready var fillet_layer: TileMapLayer = $Fillets
@onready var trail_sprite: Sprite2D = $Trail
@onready var fog_sprite: Sprite2D = $Fog
@onready var slime: Slime = $Slime
## The story chalice (null in a randomizer maze, whose goal is the ticket).
@onready var chalice: Area2D = $Chalice
@onready var hud: CanvasLayer = $HUD
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var camera: Camera2D = $Slime/Camera2D
@onready var progress: Node = get_node_or_null("/root/Progress")


func _ready() -> void:
	if level == 0 and random_seed == 0:
		if progress and progress.mode == progress.MODE_TRAINING:
			training = true
		elif progress and progress.mode == progress.MODE_DESCENT and not progress.descent_run.is_empty():
			descent = true
			descent_run = progress.descent_run
		elif progress and progress.mode == progress.MODE_RANDOM:
			random_seed = progress.random_seed
			preview = progress.in_demo_preview()
		else:
			level = progress.current_level if progress else 1
	hard_mode = progress.hard_mode if progress and not descent and not training and not (progress.mode == progress.MODE_RANDOM and (progress.random_daily or progress.random_weekly)) else false  # (the daily and the weekly: normal rules for everyone; a stale flag must not soften a hard story level) # Descent, training: normal rules only
	var config: Dictionary
	if training:
		training_attempt = Training.begin_run()
		config = Training.config()
		maze = Training.build_maze()
		_practice_coin = maze.coin
		hud.set_level_text(Training.display_name())
	elif descent:
		seed_level = clampi(progress.upgrade_level("slime"), 0, Levels.max_slime_level())
		config = Descent.floor_config(descent_run.seed, descent_run.floor, seed_level)
		maze = _random_maze(config)
		# i18n: HUD area line, max 200px, 1 line; the two spaces are spacing, not words
		hud.set_level_text(Loc.t("hud.area.descent", "DESCENT  FLOOR {floor}", {floor = int(descent_run.floor)}))
	elif is_random():
		var own_level: int = progress.upgrade_level("slime") if progress else 0
		seed_level = own_level
		if progress and progress.mode == progress.MODE_RANDOM and progress.random_seed == random_seed:
			if progress.random_level < 0:
				progress.random_level = own_level  # a replay of this maze keeps its size even after an upgrade
			seed_level = progress.random_level
		if hard_mode:
			seed_level = 0
		seed_level = clampi(seed_level, 0, Levels.max_slime_level())  # (a stray saved level stays valid)
		config = Levels.random_config(random_seed, hard_mode, seed_level)
		maze = _random_maze(config)
		var maze_n: int = (progress.randoms_cleared if progress else 0) + 1
		# i18n: HUD area line, max 296px, 1 line; {n} = which random maze this is; double spaces are
		# spacing, not words. CODE LV{code} = the slime level the maze code was made at, YOU {own} = the player's.
		if preview:
			# i18n: HUD area line, max 296px, 1 line (the demo's last maze: a taste of the full game)
			hud.set_level_text(Loc.t("hud.area.preview", "FULL GAME PREVIEW"))
		elif progress and progress.random_daily:
			# i18n: HUD area line, max 296px, 1 line (today's daily maze)
			hud.set_level_text(Loc.t("hud.area.daily", "DAILY MAZE"))
		elif is_weekly():
			# i18n: HUD area line, max 296px, 1 line; {n} = the weekly's number (this week's maze, the same for everyone)
			hud.set_level_text(Loc.t("hud.area.weekly", "WEEKLY #{n}", {n = Boards.weekly_number(Boards.week_of(progress.daily_run_day))}))
		elif hard_mode:
			hud.set_level_text(Loc.t("hud.area.random_hard", "RANDOM MAZE #{n}  HARD", {n = maze_n}))
		elif seed_level != own_level:
			hud.set_level_text(Loc.t("hud.area.random_code", "RANDOM MAZE #{n}  CODE LV{code} (YOU {own})",
				{n = maze_n, code = seed_level, own = own_level}))
		else:
			hud.set_level_text(Loc.t("hud.area.random", "RANDOM MAZE #{n}", {n = maze_n}))
	else:
		if not Demo.level_open(level, hard_mode):  # (the demo: a full-game level is never built; its data isn't there)
			level = Demo.last_level(hard_mode)
		config = Levels.get_config(level, hard_mode)
		maze = Levels.story_maze(level, hard_mode)  # a deep copy of the cached build
		# i18n: HUD area line, max 200px, 1 line; the two spaces before HARD are spacing, not words
		if hard_mode:
			hud.set_level_text(Loc.t("hud.area.level_hard", "LEVEL {level}/{total}  HARD", {level = level, total = Levels.COUNT}))
		else:
			hud.set_level_text(Loc.t("hud.area.level", "LEVEL {level}/{total}", {level = level, total = Levels.COUNT}))
	maze_seed = int(config.seed)
	_make_goal()
	survey_tiles.resize(maze.size.x * maze.size.y)
	_coin_reveal = progress != null and not training and Economy.map_coin_reveal_on(progress.dev_tools)
	_survey_cell = maze.start
	# The slime grabs the goal when their shapes touch, a little short of its center.
	var grab_reach: float = goal.get_node("CollisionShape2D").shape.radius + Slime.RADIUS
	var path_tiles: float = maze.goal_steps * MazeGenerator.CELL_SPAN - grab_reach / TILE
	# Story and randomizer alike are calibrated on the real start-to-chalice route (SpawnPicker), so a
	# perfect glide always uses `target` of the meter and the exploration allowance (meter / route =
	# 1 / target) is the level's own, wherever the slime starts.
	if training:
		slime_cost_per_tile = 100.0 / Training.FULL_METER_TILES  # the meter is set directly (Training)
	else:
		slime_cost_per_tile = config.target * 100.0 / path_tiles
	if config.has("meter_tiles"):
		# Hard story levels: the meter is set directly (Levels.hard_meter_tiles = the v4 hard meter x
		# HARD_SLIME_MULT) and the maze's route was built to fit it (same as target / route).
		slime_cost_per_tile = 100.0 / config.meter_tiles
	if (is_random() or descent) and not hard_mode:
		# The randomizer is the other way round: the player's meter is fixed (RANDOM_METER_TILES tiles,
		# x MORE SLIME below) and the route was built to the seed's usage x that meter (Levels.random_config).
		slime_cost_per_tile = 100.0 / Levels.RANDOM_METER_TILES
	par_time = Levels.par_for_path(path_tiles, slime.max_speed)  # before upgrades change the speed
	if not training:  # (training plays the bare slime: its staged dry-up must not depend on the save)
		_apply_upgrades()
		_apply_workshop()
	if descent:
		_apply_descent()
	if is_random() and path_tiles * slime_cost_per_tile > Levels.RANDOM_MAX_USAGE * 100.0:
		# A code built for a higher MORE SLIME level than the player's: never more than 95% (always winnable).
		slime_cost_per_tile = Levels.RANDOM_MAX_USAGE * 100.0 / path_tiles
	perfect_usage = path_tiles * slime_cost_per_tile / 100.0
	# The slime reserve, if the player chose it on the dry-up screen: a little more to spend.
	if progress and not is_random() and not descent and not training and progress.take_assist(level):
		assisted = true
		slime_cost_per_tile /= 1.0 + Progress.ASSIST_BONUS
		hud.set_assist(true)
	# RELAXED as the one assist: extra slime too, growing with the dry-ups on this level (not in training / Descent).
	if Economy.one_assist() and progress and progress.relaxed_on(level) and not training and not descent:
		slime_cost_per_tile /= 1.0 + progress.relaxed_bonus(level, is_random())

	# A new story level's very first attempt equips the skin just earned (see Progress).
	var equipped := ""
	if progress:
		if not is_random() and not descent and not hard_mode and not training:
			equipped = progress.equip_first_run_skin(level)
		LookRoller.roll_for_run(equipped != "" or training or preview or descent or progress.in_demo_preview())  # (RANDOM LOOK: a new look per run; not when a story level just equipped its earned skin)
		skin_color = progress.skin_color()
		rainbow = progress.is_rainbow()
		stopwatch = progress.is_stopwatch()
	atmosphere_tint = Skins.atmosphere_color(progress.active_skin(), skin_color) if progress else Color(0, 0, 0, 0)
	var shades := Skins.shades(skin_color)
	goo = Color(shades.mid, GOO_ALPHA / 255.0)
	trail_style = progress.trail_style if progress else Cosmetics.DEFAULT_TRAIL
	trail_look = Cosmetics.trail_look(trail_style, skin_color, rainbow)
	slime.apply_skin(skin_color, rainbow, stopwatch)
	slime.set_translucency(1.0 if progress and progress.jelly else 0.0)
	hud.set_skin_color(skin_color, rainbow)

	if equipped != "":
		# i18n: result-area notice, max 296px, 1 line; {name} = a skin name
		hud.flash_message(Loc.t("result.skin_equipped", "NEW SKIN EQUIPPED: {name}", {name = Skins.display_name(equipped)}), FORCED_SKIN_NOTICE)


	if descent or training:
		theme = config.theme
	else:
		theme = Themes.for_seed(random_seed) if is_random() else Themes.for_level(level)
	wall_damage = MazeTiles.fill(floor_layer, wall_layer, maze, config.seed, config.get("tile_level", level), fillet_layer, theme)
	MazeTiles.add_border(border_layer, bedrock_layer, maze, BORDER, BORDER + EDGE_FOG, config.seed, theme)
	if training:
		hud.show_area_name(Training.display_name(), Training.banner_line())
	elif descent:
		# i18n: line under the area name, max 296px
		hud.show_area_name(Themes.display_name(theme), Loc.t("hud.area.floor", "FLOOR {floor}", {floor = int(descent_run.floor)}))
	else:
		# i18n: line under the area name (the demo's preview maze), max 296px
		var area_line := Loc.t("hud.area.preview", "FULL GAME PREVIEW") if preview else ("" if is_random() else Story.level_line(level))
		hud.show_area_name(Themes.display_name(theme), area_line)
	_start_ambience()
	_build_overlays()
	_place_coins(config.seed)
	_count_attempt()
	_place_tickets()
	if training:
		_setup_training()
	if descent:
		_place_drops(config.seed)
		slime_remaining = clampf(float(descent_run.meter), 0.0, 100.0)
		_refresh_descent_pod()

	slime.position = MazeGenerator.cell_center(maze.start, TILE)
	slime.reset_physics_interpolation()  # placed, not moved: never drawn sweeping in from (0, 0)
	last_slime_pos = slime.position
	_spawn_at = slime.position
	_glimmer_from = slime.position
	_next_glimmer = _glimmer_gap()
	goal.position = MazeGenerator.cell_center(maze.goal, TILE)
	goal.visible = false
	goal.body_entered.connect(_on_goal_body_entered)
	slime.jump_landed.connect(_on_jump_landed)
	slime.bounced.connect(_on_bounced)
	restart_prompt = RestartPrompt.new()
	restart_prompt.game = self
	add_child(restart_prompt)
	_put_on_hat()
	abilities = AbilityRunner.create(self)
	coach = AbilityCoach.create(self) if abilities and not training else null
	if progress and not is_random() and not descent and not hard_mode and level <= TutorialCues.MAX_LEVEL \
			and level > progress.levels_cleared and progress.randoms_won == 0:
		var cues := TutorialCues.new()
		cues.setup(self, slime, progress)
		slime.add_child(cues)

	var edge := (BORDER + EDGE_FOG) * TILE
	camera.limit_left = -edge
	camera.limit_top = -edge
	camera.limit_right = maze.size.x * TILE + edge
	camera.limit_bottom = maze.size.y * TILE + edge
	camera.reset_smoothing()
	_cam_fresh = true
	hud.set_player_rect(_slime_screen_rect())  # (the level's name and story line keep clear of the slime)

	_paint_goo(slime.position, TRAIL_RADIUS)
	_flush_textures()
	relaxed_run = progress != null and progress.relaxed_on(level) and not training
	lurkers = Lurkers.create(self)  # (BM-01: the fog's creatures, in some random mazes)
	ghost = GhostRacer.create(self)  # (BM-03: records a daily / weekly run, races the best earlier one)
	if dev_enabled():  # the dev toggles stay as they were across restarts (never saved)
		set_dev_bright(progress.dev_bright)
		set_dev_no_drain(progress.dev_no_drain)
	_ease_in.call_deferred()
	_arm_survey.call_deferred()
	if preview and not progress.preview_card_shown:
		_show_preview_card()
	if descent:
		if progress.descent_active() and int(descent_run.cleared) >= int(descent_run.floor):
			# A run resumed on its boon card (saved right after clearing this floor, D6): the floor stays
			# cleared and its card (the same offers, from the run seed) comes back.
			finished = true
			won = true
			slime.frozen = true
			touch_controls.hide_controls()
			_refresh_descent_pod()
			_open_boon_card.call_deferred()
		elif progress.descent_active():
			_announce_floor()
		else:
			# The run was already banked (e.g. CASH OUT landed while DESCEND's reload was queued): no
			# floor to play, only its summary (NEW RUN / HUB).
			finished = true
			slime.frozen = true
			_show_descent_summary.call_deferred()


## Restarts and next levels ease in from under a sheet of goo (only when actually playing).
func _ease_in() -> void:
	if not _is_running_scene():  # (a reload raced by a scene change: already out of the tree)
		return
	var transition := get_node_or_null("/root/Transition")
	if transition:
		transition.reveal()
	_background_check = true


## Set by _ease_in: once the screen change into this level is over, an app that went to the background during its
## goo wipe (pause_for_background skipped it then) pauses the level (_process).
var _background_check := false


func _pause_if_backgrounded() -> void:
	if not _background_check or _leaving():
		return
	_background_check = false
	var events := get_node_or_null("/root/PlatformEvents")
	if events and events.in_background and events.pause_wanted:
		pause_for_background()


func _exit_tree() -> void:
	_commit_survey()  # a run left mid-way (restart, quit to hub, upgrades) still adds what it saw
	if progress:
		progress.skin_override = ""


func is_random() -> bool:
	return random_seed != 0


func _physics_process(delta: float) -> void:
	elapsed += delta
	var pos := slime.position
	if _spawn_at != Vector2.INF and pos != _spawn_at:
		_spawn_at = Vector2.INF
		hud.release_player_rect()  # (the intro texts' slime room was for the spawn spot only)
	_relight(pos)
	if training:
		_training_lines_step(delta)
	if finished or preview_card_up or slime.hold:
		return  # (the preview's card, the ability tutorial's hold: no clock, no drain)
	_survey_step(pos)
	run_time += delta
	hud.set_time(run_time)
	if ghost != null:
		ghost.step(run_time, pos)
	if slime.is_airborne():
		last_slime_pos = pos
		if attempt_key != "" and progress != null:
			progress.random_moved = true  # (leap-only scouting counts as trying the maze too)
	else:
		var moved := pos.distance_to(last_slime_pos)
		_idle_drain(moved, delta)
		if moved > 0.0:
			last_slime_pos = pos
			if attempt_key != "" and progress != null:
				progress.random_moved = true  # (this maze now counts as tried: abandoning it spends the attempt)
			if not slime.knocked_back and not dev_no_drain:  # a splat's knockback slide is already paid for
				slime_remaining = maxf(slime_remaining - moved * slime_cost_per_tile / TILE, 0.0)
			trail_travel += moved
			_paint_goo(pos, TRAIL_RADIUS)
			if light_reach > 0.0:
				_reveal_light(pos)
	if lurkers != null:
		lurkers.step(delta)
	_pick_up_coins(pos)
	if not tickets.is_empty():
		_pick_up_tickets(pos)
	if training:
		_training_step(pos, delta)
	if _coin_reveal and not coins.is_empty():
		_reveal_coins(pos)
	if not drops.is_empty():
		_pick_up_drops(pos)
	_count_glimmer_travel(pos)
	if not _shown(goal) and pos.distance_to(goal.position) <= goal_reveal_distance:
		_show(goal)
		survey_goal = true
	if wind_state == "refilling":
		var add := minf(_wind_target / Economy.WIND_REFILL_TIME * delta, _wind_left)
		slime_remaining += add  # a fixed amount: slime spent meanwhile is not topped up
		_wind_left -= add
		if _wind_left <= 0.001:
			wind_state = "used"
			hud.set_wind(wind_state)
	if _bladder_left > 0.0:
		var add := minf(float(Economy.BOONS.bladder.value) / Economy.WIND_REFILL_TIME * delta, _bladder_left)
		slime_remaining += add
		_bladder_left -= add
		if _bladder_left <= 0.001:
			_bladder_left = 0.0
	if _meter_fill > 0.0:  # training, attempt 2 on: the full meter fills up visibly first
		_meter_fill = maxf(_meter_fill - delta, 0.0)
		hud.set_slime(lerpf(slime_remaining, Training.start_percent(1), _meter_fill / Training.FILL_TIME))
	else:
		hud.set_slime(slime_remaining)
	_low_slime_warning(delta)
	if Economy.orchestra_on():
		_orchestra_frame(delta)
	if slime_remaining <= 0.0 and not slime.is_airborne():
		if wind_state == "ready":
			_second_wind()
		elif wind_state != "refilling" and _bladder_left <= 0.0 and bladders > 0:
			_backup_bladder()
		elif wind_state != "refilling" and _bladder_left <= 0.0:
			_dry_up()


## Audible low-slime warning: a falling bloop when the meter drops under the red mark, then a
## quiet heartbeat that speeds up as it empties (the HUD pulse alone is easy to miss in the dark).
func _low_slime_warning(delta: float) -> void:
	var low: bool = slime_remaining < hud.LOW_PERCENT and slime_remaining > 0.0
	if not low:
		_was_low = false
		_heartbeat_left = 0.0
		return
	if not _was_low:
		_was_low = true
		_sfx("lowwarn", -6.0)
		_heartbeat_left = HEARTBEAT_SLOW
	_heartbeat_left -= delta
	if _heartbeat_left <= 0.0:
		_sfx("heartbeat", -9.0)
		_heartbeat_left = lerpf(HEARTBEAT_FAST, HEARTBEAT_SLOW, slime_remaining / hud.LOW_PERCENT)


## BM-08 GOO ORCHESTRA per frame: tells the music if the slime moves and if the run is tense (the meter is LOW, or
## the chalice was first revealed within 12 tiles in the last ORCH_TENSE_TIME s). The first sighting, once per
## attempt, plays the chalice sting and sparks a few gold motes at the chalice (the visual twin for muted
## players; the LOW meter's twin is the HUD's red pulsing bar).
const ORCH_SEE_DIST := 192.0
const ORCH_TENSE_TIME := 8.0
const ORCH_MOVING_SPEED := 6.0
var _orch_seen := false
var _music_node: Node  # (cached for _orchestra_frame)
var _orch_tense_left := 0.0


func _orchestra_frame(delta: float) -> void:
	if _music_node == null or not is_instance_valid(_music_node):
		_music_node = get_node_or_null("/root/Music")
	var music := _music_node
	if music == null or finished:
		return
	# Only once the chalice is actually revealed, so the sting and sparks never hint at it through the fog.
	if not _orch_seen and is_instance_valid(goal) and slime.position.distance_to(goal.position) <= ORCH_SEE_DIST \
			and is_revealed_at(goal.position):
		_orch_seen = true
		_orch_tense_left = ORCH_TENSE_TIME
		music.play_orchestra_sting("chalice")
		Fx.burst(self, goal.position, CHALICE_GOLD, 6, 22.0)
	_orch_tense_left = maxf(_orch_tense_left - delta, 0.0)
	var low: bool = slime_remaining < hud.LOW_PERCENT and slime_remaining > 0.0
	music.orchestra_state(slime.velocity.length() > ORCH_MOVING_SPEED, low or _orch_tense_left > 0.0)


func _process(_delta: float) -> void:
	_pause_if_backgrounded()
	if is_random() or descent:
		# The attempt / pot pod follows the run's state (never stale): re-derived on the first frame
		# any of its inputs differs from the last time, instead of rebuilding it every frame.
		var pod_inputs := _pod_inputs()
		if pod_inputs != _pod_inputs_shown:
			_pod_inputs_shown = pod_inputs
			_refresh_attempt_pod()
			if descent:
				_refresh_descent_pod()
	var fog_material := fog_sprite.material as ShaderMaterial
	fog_material.set_shader_parameter("now", elapsed)
	(outer_fog.material as ShaderMaterial).set_shader_parameter("now", elapsed)
	# Where the slime is drawn (between ticks when interpolating), so the hole stays on the sprite.
	slime_light.position = (slime.position + slime.sprite.position + slime.drawn_shift()).round()
	fog_material.set_shader_parameter("slime_px", slime_light.position)
	var view_center := get_viewport().get_canvas_transform().affine_inverse() * (get_viewport_rect().size * 0.5)
	fog_material.set_shader_parameter("view_center", view_center.round())
	if motes:
		motes.follow(view_center)
	if Economy.light_life_on():
		_light_life_frame(_delta)
	var outer_material := outer_fog.material as ShaderMaterial
	outer_material.set_shader_parameter("slime_px", slime_light.position)
	outer_material.set_shader_parameter("view_center", view_center.round())
	if rainbow:
		slime_light.modulate = Color(hud.goo_color, SLIME_LIGHT_STRENGTH)
	_lead_camera(_delta)
	_update_ambience(_delta)
	_shake_camera(_delta)
	_flush_textures()


## Seconds since the win's sunrise began (-1 = not yet); frames of hit-stop still to go.
var _sunrise_t := -1.0
var _hitstop_frames := 0


## LIGHT & LIFE per frame: the goal's rays and the sunrise ring into the fog, and the end of the win's hit-stop.
func _light_life_frame(delta: float) -> void:
	if _hitstop_frames > 0:
		_hitstop_frames -= 1
		if _hitstop_frames == 0:
			_hitstop_set(false)
	if _sunrise_t >= 0.0:
		_sunrise_t += delta
	LightLife.frame(fog_sprite.material as ShaderMaterial, _sunrise_t, motion_scale() > 0.0)


## LIGHT & LIFE on the win: the sunrise ring starts and the game holds still for 2 frames.
func _light_life_win() -> void:
	_sunrise_t = 0.0
	if motion_scale() > 0.0:  # (Reduce Motion: no hit-stop)
		_hitstop_frames = 2
		_hitstop_set(true)


## The hit-stop pauses only this level's physics (never Engine.time_scale, which would also stop the
## timers that restore it); _process keeps running and counts the 2 frames down.
func _hitstop_set(on: bool) -> void:
	set_physics_process(not on)
	if is_instance_valid(slime):
		slime.set_physics_process(not on)


## Loads the theme's ambience: its continuous bed (looping, fading in) if it has one, and its
## one-off sounds.
func _start_ambience() -> void:
	if Economy.orchestra_on() and has_node("/root/Music"):
		get_node("/root/Music").set_orchestra_theme(theme)  # (BM-08: the layers play at this theme's pitch)
	var bed_path := "res://assets/sounds/ambient_%s.wav" % theme
	if ResourceLoader.exists(bed_path):
		var stream := load(bed_path) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		ambient = AudioStreamPlayer.new()
		ambient.stream = stream
		ambient.volume_db = -60.0
		ambient.bus = Progress.SFX_BUS
		add_child(ambient)
		create_tween().tween_property(ambient, "volume_db", AMBIENT_BED_DB.get(theme, AMBIENT_FAINT_DB), AMBIENT_FADE)
	var k := 0
	while ResourceLoader.exists("res://assets/sounds/ambient_%s_%d.wav" % [theme, k]):
		ambient_events.append(load("res://assets/sounds/ambient_%s_%d.wav" % [theme, k]))
		k += 1
	ambient_event_player = AudioStreamPlayer.new()
	ambient_event_player.bus = Progress.SFX_BUS
	add_child(ambient_event_player)
	_next_ambient_event = randf_range(3.0, AMBIENT_EVENT_GAP.x)
	_update_ambience(0.0)


## Keeps the bed in step with the sound on/off setting and plays a one-off sound now and then.
func _update_ambience(delta: float) -> void:
	var sound_on: bool = progress == null or progress.sound_on
	if ambient:
		if sound_on and not ambient.playing:
			ambient.play()
		elif not sound_on and ambient.playing:
			ambient.stop()
	if ambient_events.is_empty() or not sound_on:
		return
	_next_ambient_event -= delta
	if _next_ambient_event > 0.0:
		return
	_next_ambient_event = randf_range(AMBIENT_EVENT_GAP.x, AMBIENT_EVENT_GAP.y)
	# Any of the theme's sounds except the one just played, so it never repeats back to back.
	var pick := randi() % ambient_events.size()
	if ambient_events.size() > 1 and pick == _last_ambient_event:
		pick = (pick + 1 + randi() % (ambient_events.size() - 1)) % ambient_events.size()
	_last_ambient_event = pick
	ambient_event_player.stream = ambient_events[pick]
	ambient_event_player.volume_db = randf_range(AMBIENT_EVENT_DB.x, AMBIENT_EVENT_DB.y) + AMBIENT_EVENT_TRIM.get(theme, 0.0)
	ambient_event_player.pitch_scale = randf_range(0.9, 1.08)
	ambient_event_player.play()


## The slime's rect on screen (with its hat) where the camera starts a level: centred on the slime,
## held inside the camera's limits as Camera2D does (no zoom, no offset at the start).
func _slime_screen_rect() -> Rect2:
	var view := UIKit.SCREEN
	var corner := slime.global_position - view / 2.0
	corner.x = maxf(minf(corner.x, camera.limit_right - view.x), camera.limit_left)
	corner.y = maxf(minf(corner.y, camera.limit_bottom - view.y), camera.limit_top)
	var at := (slime.global_position - corner).round()
	var body := Rect2(at - SLIME_SCREEN_HALF, SLIME_SCREEN_HALF * 2.0)
	if hat:  # a hat sits on the head and can stand HAT_SCREEN_H over it
		body = body.merge(Rect2(at.x - SLIME_SCREEN_HALF.x - 4.0, at.y - SLIME_SCREEN_HALF.y - HAT_SCREEN_H, SLIME_SCREEN_HALF.x * 2.0 + 8.0, HAT_SCREEN_H))
	return body


## Eases the camera ahead of the slime in the direction it's gliding.
func _lead_camera(delta: float) -> void:
	var target := (slime.velocity * LOOK_AHEAD_TIME).limit_length(LOOK_AHEAD_MAX)
	if finished:
		target = Vector2.ZERO
	_look_ahead = _look_ahead.lerp(target, 1.0 - exp(-LOOK_AHEAD_SPEED * delta))
	if slime.is_physics_interpolated_and_enabled() != _pixel_cam:
		_set_pixel_cam(not _pixel_cam)
	if not _pixel_cam:
		camera.position = _look_ahead.round()
		_cam_fresh = false  # (Camera2D eases on from here; a later switch carries its eased view on)
		return
	# The same ease as Camera2D's smoothing (position_smoothing_speed), but the camera moves in whole
	# pixels in step with the slime's own: the slime-to-screen offset never flickers by a pixel when
	# the two would round differently (a 1 px twitch 20-30 times a second at 120-240 Hz).
	var follow := slime.position + slime.drawn_shift(false) + _look_ahead.round()
	if _cam_fresh:
		_cam_fresh = false
		_cam_smooth = follow
	_cam_smooth = _cam_smooth.lerp(follow, minf(camera.position_smoothing_speed * delta, 1.0))
	camera.global_position = follow.round() + (_cam_smooth - follow).round()


## The pixel-locked camera (_lead_camera) is used while the slime is drawn between ticks (physics
## interpolation, above 60 Hz: see Transition); otherwise the Camera2D follows as a child of the
## slime with its own smoothing, exactly as without interpolation.
## A switch mid-level carries the eased view across (no snap onto the slime): turning on, the pixel
## camera's ease starts where Camera2D's has the view (its screen center less the shake offset);
## turning off, Camera2D's own ease starts where the pixel camera left it (with smoothing off it
## tracked the camera's position every frame), so no reset_smoothing.
func _set_pixel_cam(on: bool) -> void:
	_pixel_cam = on
	if on and not _cam_fresh:
		_cam_smooth = camera.get_screen_center_position() - camera.offset
	camera.top_level = on
	camera.position_smoothing_enabled = not on
	if not on:
		camera.position = _look_ahead.round()


func _shake_camera(delta: float) -> void:
	if shake_left <= 0.0 or motion_scale() <= 0.0:
		shake_left = 0.0
		shake_span = SHAKE_TIME
		kick = Vector2.ZERO
		camera.offset = Vector2.ZERO
		return
	shake_left = maxf(shake_left - delta, 0.0)
	var fade := minf(shake_left / maxf(shake_span, 0.001), 1.0)
	var strength := ceilf(shake_strength * fade)
	camera.offset = (Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) + kick * fade).round()


## A screen shake of `strength` px fading over `time` s with a `push` (px) toward a side; nothing
## with Reduce Motion (see _shake_camera). Every shake goes through here, so each new one restarts
## the fade over its own span (a landing right after an ability shake fades over SHAKE_TIME).
func shake(strength: float, time: float, push := Vector2.ZERO) -> void:
	shake_left = time
	shake_span = time
	shake_strength = strength
	kick = push


## Adds the distance moved since last frame; past the next mark, a glimmer appears.
func _count_glimmer_travel(pos: Vector2) -> void:
	glimmer_travel += pos.distance_to(_glimmer_from)
	_glimmer_from = pos
	if glimmer_travel >= _next_glimmer:
		glimmer_travel = 0.0
		_next_glimmer = _glimmer_gap()
		_spawn_glimmer()


## The distance to the next glimmer: GLIMMER_EVERY, shortened by GOO NOSE (x1.4 / x1.8 / x2.3 as often).
func _glimmer_gap() -> float:
	return randf_range(GLIMMER_EVERY.x, GLIMMER_EVERY.y) / glimmer_rate


## A twinkle over a coin that's still waiting in the fog near the slime (picked at random), in
## that coin's metal: a hint of treasure. No coins left nearby (or none in the level), no glimmer.
func _spawn_glimmer() -> void:
	var hidden: Array[Node2D] = []
	var half := get_viewport_rect().size * 0.5 + Vector2.ONE * GLIMMER_VIEW_MARGIN
	var center := camera.get_screen_center_position() if camera != null else slime.position
	var view := Rect2(center - half, half * 2.0)
	var waiting: Array[Node2D] = []
	waiting.append_array(coins)
	waiting.append_array(drops)  # Descent goo drops twinkle too (GOO NOSE included)
	for coin in waiting:
		if not is_instance_valid(coin):
			continue
		if coin.position.distance_to(slime.position) > glimmer_reach or fog_alpha_at(coin.position) < 0.99:
			continue
		if glimmer_view_only and not view.has_point(coin.position):
			continue  # a twinkle you can't see would waste the glimmer
		hidden.append(coin)
	if hidden.is_empty():
		return
	_glimmer_at(hidden.pick_random())


## A glimmer over `coin` (a Coin or a Descent GooDrop), in its metal.
func _glimmer_at(coin: Node2D) -> void:
	var glimmer := Glimmer.new()
	glimmer.position = coin.position.round()
	if coin is GooDrop:
		glimmer.color = Skins.shades(skin_color).light.lightened(0.3)
	else:
		glimmer.color = Coin.GLOW[maxi(Themes.BY_LEVEL.find(theme), 0) % Coin.GLOW.size()].lightened(0.35)
	glimmer.still = motion_scale() <= 0.0
	glimmer.z_index = fog_sprite.z_index + 1  # seen through the fog
	glimmer.add_to_group("glimmer")
	add_child(glimmer)


## A tiny four-pointed twinkle that swells and fades (additive, so it reads as light in the fog).
class Glimmer extends Node2D:
	const LIFE := 0.9
	var color := Color.WHITE
	## Reduce Motion: a steady dot for its life instead of the swell and fade.
	var still := false
	var _age := 0.0
	var _light: Sprite2D

	func _ready() -> void:
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive
		_light = Fx.make_light(14, Color(color, 0.0))
		add_child(_light)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= LIFE:
			queue_free()
			return
		if still:
			_light.modulate.a = 0.15
			return
		_light.modulate.a = 0.3 * sin(_age / LIFE * PI)
		queue_redraw()

	func _draw() -> void:
		# A bright center pixel with arms (up to 3 px) that grow and shrink with the twinkle.
		var strength := 0.8 if still else sin(_age / LIFE * PI)
		var arm := 1 if still else roundi(strength * 3.0)
		draw_rect(Rect2(0, 0, 1, 1), Color(color, 0.7 * strength))
		for i in range(1, arm + 1):
			var c := Color(color, (0.5 if i == 1 else 0.25) * strength)
			for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				draw_rect(Rect2(Vector2(dir * i), Vector2.ONE), c)


func is_wall_tile(tile: Vector2i) -> bool:
	return MazeGenerator.is_wall(maze, tile)


## Fog opacity (0 = fully lit, 1 = covered) at a pixel position right now; matches fog.gdshader's
## per-cell value, without its cosmetic extras (soft edges, clearing fade-in).
func fog_alpha_at(pos: Vector2) -> float:
	var at := _cell_at(pos)
	if not Rect2i(Vector2i.ZERO, _cells).has_point(at):
		return 1.0  # the outer fog
	var v := _fog_bytes.decode_u32((at.y * _cells.x + at.x) * 4)
	var packed := ((v >> 16) & 255) * 256 + ((v >> 24) & 255)
	if packed == 0:
		return 1.0
	var age: float = elapsed - ((v & 255) * 256 + ((v >> 8) & 255)) / FOG_TICKS
	if hard_mode and age >= FADE_AFTER[-1]:
		return 1.0
	var look := fog_look()
	var alpha := fade_alpha(age, look.fade)
	if packed % 2 == 1:
		alpha += (1.0 - alpha) * look.wall
	return alpha


## Packs one fog cell into RGBA8: r,g = last-lit time; b,a = (first-revealed time + 1) * 2 + is_wall,
## both in 1/FOG_TICKS second steps. b,a = 0 means never revealed. fog.gdshader decodes the same way.
static func _fog_color(lit: float, revealed: float, wall: bool) -> Color:
	return _fog_color_ticks(int(lit * FOG_TICKS), int(revealed * FOG_TICKS), wall)


## Allocation-free field readers for per-cell loops (same packing as _fog_decode).
static func _fog_packed(color: Color) -> int:
	return color.b8 * 256 + color.a8


static func _fog_lit_ticks(color: Color) -> int:
	return color.r8 * 256 + color.g8


static func _fog_color_ticks(lit_ticks: int, revealed_ticks: int, wall: bool) -> Color:
	lit_ticks = clampi(lit_ticks, 0, 65535)
	var packed := (clampi(revealed_ticks, 0, 32766) + 1) * 2 + (1 if wall else 0)
	return Color8(lit_ticks >> 8, lit_ticks & 255, packed >> 8, packed & 255)


static func _fog_decode(color: Color) -> Dictionary:
	var packed := color.b8 * 256 + color.a8
	return {
		revealed = packed > 0,
		wall = packed % 2 == 1,
		lit = (color.r8 * 256 + color.g8) / FOG_TICKS,
		first_revealed = ((packed >> 1) - 1) / FOG_TICKS,
	}


## Extra slime lost when a jump planned to cover intended_distance px hits a wall.
static func splat_penalty(intended_distance: float) -> float:
	var power := inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance)
	return lerpf(SPLAT_PENALTY_MIN, SPLAT_PENALTY_MAX, clampf(power, 0.0, 1.0))


## Darkness of a revealed floor cell last lit `age` seconds ago.
static func fade_alpha(age: float, table: Array = FADE_ALPHA) -> float:
	for i in FADE_AFTER.size():
		if age < FADE_AFTER[i]:
			return table[i]
	return table[-1]


## The fog look chosen in Settings (an entry of FOG_LOOKS).
func fog_look() -> Dictionary:
	var level_index: int = progress.fog_brightness if progress else Progress.FOG_NORMAL
	if Economy.DARK_FOG and level_index < FOG_LOOKS_DARK.size():
		return FOG_LOOKS_DARK[maxi(level_index, 0)]
	return FOG_LOOKS[clampi(level_index, 0, FOG_LOOKS.size() - 1)]


## 0 with Reduce Motion on, else 1: scales screen shake, the camera kick and hit-stop.
func motion_scale() -> float:
	return 0.0 if progress and progress.reduce_motion else 1.0


## The fog/trail image cell at a world position, and a cell's center back in the world: the
## images start BORDER tiles up and left of the maze, to cover the border ring too.
func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(((pos + BORDER_PX) / FOG_CELL).floor())


func _cell_pos(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * FOG_CELL - BORDER_PX


## The fog cells covering one tile.
func _tile_cells(tile: Vector2i) -> Rect2i:
	return Rect2i((tile + Vector2i.ONE * BORDER) * TILE / FOG_CELL, Vector2i.ONE * (TILE / FOG_CELL))


func _build_overlays() -> void:
	var cells: Vector2i = (maze.size + Vector2i.ONE * BORDER * 2) * TILE / FOG_CELL
	_cells = cells
	var fog := Image.create_empty(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	fog.fill(UNREVEALED)
	var trail := Image.create_empty(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	trail.fill(CLEAR)
	fog_sprite.texture = ImageTexture.create_from_image(fog)
	trail_sprite.texture = ImageTexture.create_from_image(trail)
	_fog_bytes = fog.get_data()
	_trail_bytes = trail.get_data()
	_relit_tick = -1
	_relit_spans.clear()
	_revealed_spans.clear()
	_revealed_radius = -1.0
	_painted_spans.clear()
	_painted_radius = -1.0
	fog_dirty = false
	_fog_lazy = false
	_fog_lazy_due = INF
	fog_sprite.scale = Vector2(FOG_CELL, FOG_CELL)
	trail_sprite.scale = Vector2(FOG_CELL, FOG_CELL)
	fog_sprite.position = -BORDER_PX
	trail_sprite.position = -BORDER_PX
	var trail_material := ShaderMaterial.new()
	trail_material.shader = preload("res://assets/shaders/trail.gdshader")
	trail_material.set_shader_parameter("animate", motion_scale())
	trail_sprite.material = trail_material
	trail_material.set_shader_parameter("stars", 1.0 if trail_look.get("stars", false) else 0.0)
	trail_material.set_shader_parameter("fx", trail_look.get("fx", 0.0))
	_build_trail_glow()

	var fog_material := ShaderMaterial.new()
	fog_material.shader = preload("res://assets/shaders/fog.gdshader")
	var look := fog_look()
	fog_material.set_shader_parameter("fade_after", Vector4(FADE_AFTER[0], FADE_AFTER[1], FADE_AFTER[2], FADE_AFTER[3]))
	fog_material.set_shader_parameter("refog_after", FADE_AFTER[-1])
	fog_material.set_shader_parameter("fade_alpha", Vector4(look.fade[0], look.fade[1], look.fade[2], look.fade[3]))
	fog_material.set_shader_parameter("fade_alpha_last", look.fade[4])
	fog_material.set_shader_parameter("wall_shade", look.wall)
	fog_material.set_shader_parameter("deep_gain", look.deep_gain)
	fog_material.set_shader_parameter("mist_gain", look.mist_gain)
	fog_material.set_shader_parameter("far_dim", look.far_dim)
	fog_material.set_shader_parameter("vig_max", look.vig_max)
	fog_material.set_shader_parameter("light_outer", look.light_outer)
	fog_material.set_shader_parameter("map_size", Vector2(cells * FOG_CELL))
	fog_material.set_shader_parameter("origin", -BORDER_PX)
	fog_material.set_shader_parameter("hard_mode", hard_mode)
	var fog_colors := Themes.fog_colors(theme, atmosphere_tint)
	if not fog_colors.is_empty():
		fog_material.set_shader_parameter("fog_deep", fog_colors[0])
		fog_material.set_shader_parameter("fog_mist", fog_colors[1])
	fog_sprite.material = fog_material
	if Economy.light_life_on():
		LightLife.setup(fog_material, theme, skin_color, trail_sprite.texture)
	_build_outer_fog(fog_material, Rect2(-BORDER_PX, Vector2(cells * FOG_CELL)))

	slime_light = Fx.make_light(SLIME_LIGHT_SIZE + int(light_reach * 2.0), Color(skin_color, SLIME_LIGHT_STRENGTH))
	slime_light.z_index = 11  # above the fog (z 10), so the lantern shows on unexplored ground
	add_child(slime_light)
	motes = Ambient.create(theme, progress != null and progress.reduce_motion, atmosphere_tint)
	if motes:
		add_child(motes)
		move_child(motes, bedrock_layer.get_index() + 1)  # on the floor: under trail, chalice and slime


## An additive, smoothed copy of the trail drawn over it (child of the trail sprite, same
## texture, so it updates with it): the 2 px cells blur into a faint halo and the goo glows.
func _build_trail_glow() -> void:
	for old in trail_sprite.get_children():
		old.queue_free()
	var glow := Sprite2D.new()
	glow.texture = trail_sprite.texture
	glow.centered = false
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = material
	glow.modulate = Color(1, 1, 1, trail_look.get("glow", TRAIL_GLOW))
	trail_sprite.add_child(glow)


## Fog beyond the maze and its border ring: one unrevealed cell stretched over a wide area,
## drawn with the same mist (lined up by `origin`) and a hole where the maze's fog is.
func _build_outer_fog(inner: ShaderMaterial, inner_rect: Rect2) -> void:
	var reach := Vector2(SLIME_LIGHT_SIZE + 400, SLIME_LIGHT_SIZE + 400)
	var area := Rect2(inner_rect.position - reach, inner_rect.size + reach * 2.0)
	var cell := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	cell.fill(UNREVEALED)
	outer_fog = Sprite2D.new()
	outer_fog.texture = ImageTexture.create_from_image(cell)
	outer_fog.centered = false
	outer_fog.position = area.position
	outer_fog.scale = area.size
	outer_fog.z_index = fog_sprite.z_index
	# A fresh material with the inner one's settings (duplicate() drops color parameters, from
	# both copies, in this Godot version).
	var material := ShaderMaterial.new()
	material.shader = inner.shader
	for param in ["fade_after", "fade_alpha", "fade_alpha_last", "wall_shade", "hard_mode", "refog_after", "fog_deep", "fog_mist",
			"deep_gain", "mist_gain", "far_dim", "vig_max", "light_inner", "light_outer"]:
		var value: Variant = inner.get_shader_parameter(param)
		if value != null:
			material.set_shader_parameter(param, value)
	material.set_shader_parameter("map_size", area.size)
	material.set_shader_parameter("origin", area.position)
	material.set_shader_parameter("hole", Vector4(inner_rect.position.x, inner_rect.position.y, inner_rect.size.x, inner_rect.size.y))
	material.set_shader_parameter("solid", true)  # one unrevealed cell: the soft edge is always 1.0
	outer_fog.material = material
	add_child(outer_fog)


## Paints goo on the floor in a disc around pos, then reveals walls next to it.
func _paint_goo(pos: Vector2, radius: float) -> void:
	_paint_cells(pos, radius, false)
	var center: Variant = Cosmetics.trail_center(trail_look, trail_travel)
	if center != null:  # TREASURE: red dashes down the middle of the trail, over the painted cells
		var c := _cell_at(pos)
		var bytes := _rgba8(center)
		for cy in range(maxi(c.y - 1, 0), mini(c.y + 1, _cells.y - 1) + 1):
			for cx in range(maxi(c.x - 1, 0), mini(c.x + 1, _cells.x - 1) + 1):
				var i := (cy * _cells.x + cx) * 4
				var mid := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * FOG_CELL - BORDER_PX
				if _trail_bytes[i + 3] != 0 and mid.distance_to(pos) <= 2.0:
					_trail_bytes.encode_u32(i, bytes)
					trail_dirty = true
	_reveal_walls_near(pos, radius)


## Splat stain on the wall the slime just hit; lit like the floor so it stands out.
func _stain_wall(pos: Vector2, wall_normal: Vector2) -> void:
	_paint_cells(pos - wall_normal * (Slime.RADIUS + 1.0), STAIN_RADIUS, true)


## Sets goo + lights fog cells within radius of pos, on floor cells or wall cells only.
## Cells are visited row by row over exact disc spans (_disc_runs); a floor paint with the same
## radius as the last one only visits the cells outside the last disc (those inside are all painted
## already, or walls). Same cells, same order, same bytes as testing every cell of the square.
func _paint_cells(pos: Vector2, radius: float, on_walls: bool) -> void:
	var first := _cell_at(pos - Vector2(radius, radius)).max(Vector2i.ZERO)
	var last := _cell_at(pos + Vector2(radius, radius)).min(_cells - Vector2i.ONE)
	var fog := _rgba8(_fog_color(elapsed, elapsed, false))
	var goo_light := _rgba8(_goo_color(false))
	var goo_deep := _rgba8(_goo_color(true))
	var per_cell: bool = trail_look.get("per_cell", false) and not on_walls
	var walls: PackedByteArray = maze.walls
	var size: Vector2i = maze.size
	var runs: PackedInt32Array
	if on_walls:
		runs = _disc_runs(pos, radius, false, first, last, PackedInt32Array(), 0)
	else:
		runs = _disc_runs(pos, radius, false, first, last, _painted_spans if radius == _painted_radius else PackedInt32Array(), _painted_row0)
		_painted_spans = _last_spans
		_painted_row0 = first.y
		_painted_radius = radius
	for r in range(0, runs.size(), 3):
		var cy := runs[r]
		var ty := floori(((cy + 0.5) * FOG_CELL - BORDER_PX.y) / TILE)
		var i := (cy * _cells.x + runs[r + 1]) * 4
		for cx in range(runs[r + 1], runs[r + 2] + 1):
			var tx := floori(((cx + 0.5) * FOG_CELL - BORDER_PX.x) / TILE)
			var wall := tx < 0 or ty < 0 or tx >= size.x or ty >= size.y or walls[ty * size.x + tx] == 1
			if wall == on_walls and (on_walls or _trail_bytes[i + 3] == 0):
				if on_walls:
					_reveal_wall(Vector2i(tx, ty))
				else:
					survey_tiles[ty * size.x + tx] = 1
				if per_cell:  # a PREVIEW trail style: its color depends on the cell (Cosmetics.trail_cell_at)
					_trail_bytes.encode_u32(i, _rgba8(Cosmetics.trail_cell_at(trail_look, posmod(hash(Vector2i(cx, cy)), 5) == 0, trail_travel, Vector2i(cx, cy))))
				else:
					_trail_bytes.encode_u32(i, goo_deep if posmod(hash(Vector2i(cx, cy)), 5) == 0 else goo_light)
				_fog_bytes.encode_u32(i, fog)
				fog_dirty = true
				trail_dirty = true
			i += 4


## Trail color for a newly painted cell, by the worn trail style (Cosmetics.trail_cell): the skin's
## goo, or for the rainbow skin (default style) a hue that shifts as you go, so the trail lays down
## rainbow bands along your path; INK / GLOW / GOLD recolor it, CANDY stripes it by distance.
func _goo_color(dark: bool) -> Color:
	if trail_look.is_empty():
		trail_look = Cosmetics.trail_look(trail_style, skin_color, rainbow)
	return Cosmetics.trail_cell(trail_look, dark, trail_travel, fposmod(elapsed * RAINBOW_TRAIL_SPEED, 1.0) * 0.83)


## Keeps already-revealed cells around the slime fully lit (restarts their fade). The
## Brightness upgrade widens it.
func _relight(pos: Vector2) -> void:
	var radius := LIGHT_RADIUS + light_reach
	var tick := int(elapsed * FOG_TICKS)
	var slime_cell := _cell_at(pos)
	if tick == _relit_tick and slime_cell == _relit_cell and radius == _relit_radius:
		return  # nothing new can be lit: same fog tick, same cell, same reach
	# Within one tick (same radius) only cells new to the disc can need it: the rest were relit
	# already, or were unrevealed then (anything revealed since was lit this tick).
	var same_tick := tick == _relit_tick and radius == _relit_radius
	_relit_tick = tick
	_relit_cell = slime_cell
	_relit_radius = radius
	var r := Vector2(radius, radius)
	var first := _cell_at(pos - r).max(Vector2i.ZERO)
	var last := _cell_at(pos + r).min(_cells - Vector2i.ONE)
	var runs := _disc_runs(pos, radius, true, first, last, _relit_spans if same_tick else PackedInt32Array(), _relit_row0)
	_relit_spans = _last_spans
	_relit_row0 = first.y
	# Same bytes as _fog_color_ticks(tick, revealed, wall): only the lit time (r, g) changes.
	var lit := clampi(tick, 0, 65535)
	var lit_bytes := (lit >> 8) | ((lit & 255) << 8)
	var oldest := -1
	for k in range(0, runs.size(), 3):
		var i := (runs[k] * _cells.x + runs[k + 1]) * 4
		for cx in range(runs[k + 1], runs[k + 2] + 1):
			var v := _fog_bytes.decode_u32(i)
			if v >= 0x10000:  # revealed (b, a not both 0)
				var was := (v & 255) * 256 + ((v >> 8) & 255)
				if was < tick:
					_fog_bytes.encode_u32(i, (v & 0xFFFF0000) | lit_bytes)
					if oldest < 0 or was < oldest:
						oldest = was
			i += 4
	if oldest >= 0:
		_fog_lazy = true
		_fog_lazy_due = minf(_fog_lazy_due, (oldest + LAZY_RELIGHT_TICKS) / FOG_TICKS)


## Brightness upgrade: the slime's own light reveals unexplored floor (and the walls beside it)
## a little beyond its goo trail, without laying goo there. With the same radius as last time only
## the cells outside the last disc are visited (those inside are revealed already, or walls).
func _reveal_light(pos: Vector2) -> void:
	var radius := TRAIL_RADIUS + light_reach
	var first := _cell_at(pos - Vector2(radius, radius)).max(Vector2i.ZERO)
	var last := _cell_at(pos + Vector2(radius, radius)).min(_cells - Vector2i.ONE)
	var runs := _disc_runs(pos, radius, false, first, last, _revealed_spans if radius == _revealed_radius else PackedInt32Array(), _revealed_row0)
	_revealed_spans = _last_spans
	_revealed_row0 = first.y
	_revealed_radius = radius
	var fog := _rgba8(_fog_color(elapsed, elapsed, false))
	var walls: PackedByteArray = maze.walls
	var size: Vector2i = maze.size
	for k in range(0, runs.size(), 3):
		var cy := runs[k]
		var ty := floori(((cy + 0.5) * FOG_CELL - BORDER_PX.y) / TILE)
		if ty < 0 or ty >= size.y:
			continue  # the border ring: all wall
		var i := (cy * _cells.x + runs[k + 1]) * 4
		for cx in range(runs[k + 1], runs[k + 2] + 1):
			var tx := floori(((cx + 0.5) * FOG_CELL - BORDER_PX.x) / TILE)
			if tx >= 0 and tx < size.x and walls[ty * size.x + tx] != 1 and _fog_bytes.decode_u32(i) < 0x10000:
				_fog_bytes.encode_u32(i, fog)
				fog_dirty = true
				survey_tiles[ty * size.x + tx] = 1
			i += 4
	_reveal_walls_near(pos, radius)


## The span of each row of the disc (cells whose centers pass the original per-cell test:
## distance_squared_to <= radius^2 when `squared`, else distance_to <= radius) inside first..last.
## Returns the cells to visit as (row, from, to) triples, leaving out each row's `old` span (the
## previous disc's, rows from old_row0; empty = none); this disc's spans are left in _last_spans.
## A row's inside cells are always one unbroken run, because the rounded distance only grows away
## from pos, so testing the ends finds it exactly.
var _last_spans := PackedInt32Array()


func _disc_runs(pos: Vector2, radius: float, squared: bool, first: Vector2i, last: Vector2i,
		old: PackedInt32Array, old_row0: int) -> PackedInt32Array:
	var runs := PackedInt32Array()
	var spans := PackedInt32Array()
	if first.x > last.x or first.y > last.y:
		_last_spans = spans
		return runs
	spans.resize((last.y - first.y + 1) * 2)
	var mid0 := clampi(floori((pos.x + BORDER_PX.x) / FOG_CELL), first.x, last.x)  # nearest column
	var radius_sq := radius * radius
	for cy in range(first.y, last.y + 1):
		var row_y := (cy + 0.5) * FOG_CELL - BORDER_PX.y
		var lo := 1
		var hi := 0
		if _in_disc(mid0, row_y, pos, radius, radius_sq, squared):
			var dy := row_y - pos.y
			var half := sqrt(maxf(radius_sq - dy * dy, 0.0))
			lo = clampi(floori((pos.x - half + BORDER_PX.x) / FOG_CELL), first.x, mid0)
			while lo > first.x and _in_disc(lo - 1, row_y, pos, radius, radius_sq, squared):
				lo -= 1
			while not _in_disc(lo, row_y, pos, radius, radius_sq, squared):
				lo += 1
			hi = clampi(floori((pos.x + half + BORDER_PX.x) / FOG_CELL), mid0, last.x)
			while hi < last.x and _in_disc(hi + 1, row_y, pos, radius, radius_sq, squared):
				hi += 1
			while not _in_disc(hi, row_y, pos, radius, radius_sq, squared):
				hi -= 1
		var s := (cy - first.y) * 2
		spans[s] = lo
		spans[s + 1] = hi
		if lo > hi:
			continue
		var o := (cy - old_row0) * 2
		if o < 0 or o >= old.size() or old[o] > old[o + 1]:
			runs.append_array([cy, lo, hi])
			continue
		if lo < old[o]:
			runs.append_array([cy, lo, mini(hi, old[o] - 1)])
		if hi > old[o + 1]:
			runs.append_array([cy, maxi(lo, old[o + 1] + 1), hi])
	_last_spans = spans
	return runs


## The original per-cell disc test for the cell in column cx of the row whose centers are at row_y.
static func _in_disc(cx: int, row_y: float, pos: Vector2, radius: float, radius_sq: float, squared: bool) -> bool:
	var center := Vector2((cx + 0.5) * FOG_CELL - BORDER_PX.x, row_y)
	if squared:
		return center.distance_squared_to(pos) <= radius_sq
	return center.distance_to(pos) <= radius


## The bytes Image.set_pixel stores for a color in an RGBA8 image, as one little-endian u32.
static var _pixel := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


static func _rgba8(color: Color) -> int:
	_pixel.set_pixel(0, 0, color)
	return _pixel.get_data().decode_u32(0)


func _reveal_walls_near(pos: Vector2, radius: float) -> void:
	var reach := radius + WALL_REVEAL_REACH
	var first := Vector2i(((pos - Vector2(reach, reach)) / TILE).floor())
	var last := Vector2i(((pos + Vector2(reach, reach)) / TILE).floor())
	for ty in range(first.y, last.y + 1):
		for tx in range(first.x, last.x + 1):
			var tile := Vector2i(tx, ty)
			if not is_wall_tile(tile) or tx < -BORDER or ty < -BORDER or tx >= maze.size.x + BORDER or ty >= maze.size.y + BORDER:
				continue
			var rect := Rect2(Vector2(tile * TILE), Vector2(TILE, TILE))
			if pos.clamp(rect.position, rect.end).distance_to(pos) <= reach:
				_reveal_wall(tile)


## Marks a whole wall tile revealed (lit now) the first time it's seen.
func _reveal_wall(tile: Vector2i) -> void:
	if revealed_walls.has(tile):
		return
	revealed_walls[tile] = true
	_fill_fog(_tile_cells(tile), _fog_color(elapsed, elapsed, true))
	if tile.x >= 0 and tile.y >= 0 and tile.x < maze.size.x and tile.y < maze.size.y:
		survey_tiles[tile.y * maze.size.x + tile.x] = 1


## ABILITIES: reveals a whole tile at once, lit now (so it shows bright, then fades like the trail):
## a floor tile's fog cells (unrevealed ones revealed, revealed ones relit) and the survey, plus with
## `walls_around` the walls bordering it (as the goo trail's reveal does); a wall tile just as a wall.
func reveal_tile(tile: Vector2i, walls_around := true) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= maze.size.x or tile.y >= maze.size.y:
		return
	if is_wall_tile(tile):
		_reveal_wall(tile)
		return
	var rect := _tile_cells(tile).intersection(Rect2i(Vector2i.ZERO, _cells))
	var fresh := _rgba8(_fog_color(elapsed, elapsed, false))
	var lit := clampi(int(elapsed * FOG_TICKS), 0, 65535)
	var lit_bytes := (lit >> 8) | ((lit & 255) << 8)
	for cy in range(rect.position.y, rect.end.y):
		var i := (cy * _cells.x + rect.position.x) * 4
		for cx in rect.size.x:
			var v := _fog_bytes.decode_u32(i)
			_fog_bytes.encode_u32(i, fresh if v < 0x10000 else (v & 0xFFFF0000) | lit_bytes)
			i += 4
	survey_tiles[tile.y * maze.size.x + tile.x] = 1
	fog_dirty = true
	if not finished and not _shown(goal) and tile == Vector2i((goal.position / TILE).floor()):
		_show(goal)  # (as when the slime comes near it: the chalice / ticket shows, the trail map marks it)
		survey_goal = true
	if walls_around:
		_reveal_walls_near((Vector2(tile) + Vector2(0.5, 0.5)) * TILE, TILE / 2.0)


## ABILITIES: a thin goo streak (radius `radius` px) along the segment a..b (floor cells only).
func paint_streak(a: Vector2, b: Vector2, radius := 2.0) -> void:
	var steps := maxi(ceili(a.distance_to(b) / 2.0), 1)
	for i in steps + 1:
		_paint_cells(a.lerp(b, float(i) / steps), radius, false)


## Standing still drains too (owner, 2026-10-22): Economy.IDLE_DRAIN percent of the meter a second
## while the slime is on the ground and not moving (not while charging a leap, before its first move,
## in training, with dev NO DRAIN, or while a SLIME SENSE peek is up: peeking is free).
func _idle_drain(moved: float, delta: float) -> void:
	if dev_no_drain or training or _spawn_at != Vector2.INF or random_map_view != null or not Economy.idle_drain_on():
		return
	if moved > 0.0 or slime.state != Slime.State.GLIDE:
		_still_time = 0.0
		return
	if relaxed_run or slime.aim_lock:
		return  # RELAXED: no idle drain; aiming an ability is thinking time, not waiting
	_still_time += delta
	if _still_time > Economy.IDLE_GRACE:
		slime_remaining = maxf(slime_remaining - Economy.IDLE_DRAIN * delta, 0.0)


## SLIME SENSE's peek (randomizer mazes): the maze so far over the screen while the run goes on (the
## slime held still, the meter not draining); its key, Esc or B close it.
func toggle_run_map() -> void:
	if random_map_view != null:
		if _map_mid_run:
			random_map_view.close()
		return
	if finished or _leaving() or progress == null:
		return
	var survey := _survey_so_far()
	_map_mid_run = true
	slime.aim_lock = true
	_open_map_view(survey)
	random_map_view.closed.connect(func() -> void:
		_map_mid_run = false
		slime.set_deferred("aim_lock", false))


## Closes a SLIME SENSE peek if one is up.
func _close_run_map() -> void:
	if random_map_view != null and _map_mid_run:
		random_map_view.close()


## ABILITIES: takes `percent` of the meter (not with dev NO DRAIN).
func spend_slime(percent: float) -> void:
	if not dev_no_drain:
		slime_remaining = maxf(slime_remaining - percent, 0.0)
	hud.set_slime(slime_remaining)


## Image.fill_rect on the fog bytes (clipped to the image).
func _fill_fog(rect: Rect2i, color: Color) -> void:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, _cells))
	var value := _rgba8(color)
	for cy in range(rect.position.y, rect.end.y):
		var i := (cy * _cells.x + rect.position.x) * 4
		for cx in rect.size.x:
			_fog_bytes.encode_u32(i, value)
			i += 4
	fog_dirty = true


## True when the fog texture must be uploaded this frame: a visible change, or a lazy relight
## (see LAZY_RELIGHT_TICKS) whose old time is about to leave the first fade band.
func _fog_upload_due() -> bool:
	return fog_dirty or (_fog_lazy and elapsed >= _fog_lazy_due)


## Uploads the changed textures from the bytes (a short-lived Image shares the bytes, so nothing
## is copied here and the next write doesn't copy either).
func _flush_textures() -> void:
	if _fog_upload_due():
		(fog_sprite.texture as ImageTexture).update(Image.create_from_data(_cells.x, _cells.y, false, Image.FORMAT_RGBA8, _fog_bytes))
		fog_dirty = false
		_fog_lazy = false
		_fog_lazy_due = INF
	if trail_dirty:
		(trail_sprite.texture as ImageTexture).update(Image.create_from_data(_cells.x, _cells.y, false, Image.FORMAT_RGBA8, _trail_bytes))
		trail_dirty = false


func _on_jump_landed(intended_distance: float, hit_wall: bool, wall_normal: Vector2) -> void:
	if finished:
		return
	last_jump_cost = slime.last_jump_traveled / TILE * slime_cost_per_tile * jump_cost_factor
	if lurkers != null:
		lurkers.on_landing(slime.position)  # (a leap landed on a lurker bonks it)
	_paint_goo(slime.position, LANDING_RADIUS)
	if hit_wall and slime.last_hit_glancing:  # soft bounce test: the same penalty, a soft touch
		splats += 1
		last_jump_cost += splat_penalty(intended_distance) * splat_factor
		_stain_wall(slime.position, wall_normal)
		Fx.burst(self, slime.position - wall_normal * Slime.RADIUS, skin_color, Economy.SOFT_BOUNCE_DROPLETS,
			Economy.SOFT_BOUNCE_DROPLET_SPEED, wall_normal, 70.0, rainbow)
		_damage_wall(slime.position, wall_normal,
			inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance))
	elif hit_wall:
		splats += 1
		last_jump_cost += splat_penalty(intended_distance) * splat_factor
		_stain_wall(slime.position, wall_normal)
		var hit_power := inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance)
		shake(lerpf(1.0, SHAKE_MAX, hit_power), SHAKE_TIME, -wall_normal * roundf(lerpf(1.0, KICK_MAX, hit_power)))  # a shove into the wall that was hit
		Fx.burst(self, slime.position - wall_normal * Slime.RADIUS, skin_color, 18, 70.0, wall_normal, 70.0, rainbow)
		_damage_wall(slime.position, wall_normal,
			inverse_lerp(Slime.jump_distance_for(0.0), Slime.jump_distance_for(100.0), intended_distance))
	else:
		Fx.burst(self, slime.position, skin_color, 10, 35.0, Vector2.UP, 180.0, rainbow)
	last_slime_pos = slime.position
	if not dev_no_drain:
		slime_remaining = maxf(slime_remaining - last_jump_cost, 0.0)
	hud.set_slime(slime_remaining)


## The MORE SLIME factor applied to this run (1 in hard mode, which has no upgrades).
func _applied_slime_factor() -> float:
	if is_weekly():
		return Upgrades.slime_factor(Economy.WEEKLY_SLIME)  # (BM-03: the weekly's fixed loadout)
	return 1.0 if progress == null or hard_mode else Upgrades.slime_factor(progress.upgrade_level("slime"))


## Applies the bought upgrades (see Upgrades): more slime to spend, faster gliding, a wider
## light, and (dev only) wall power.
func _apply_upgrades() -> void:
	if progress == null or hard_mode:  # hard mode is played without upgrades
		return
	slime_cost_per_tile /= _applied_slime_factor()
	var weekly := is_weekly()  # (BM-03: the weekly's loadout is fixed, SPEED and BRIGHTNESS too)
	var speed := Upgrades.speed_factor(Economy.WEEKLY_SPEED if weekly else progress.upgrade_level("speed"))
	slime.max_speed *= speed
	slime.acceleration *= speed
	light_reach = Upgrades.light_reach(Economy.WEEKLY_BRIGHTNESS if weekly else progress.upgrade_level("brightness"))
	wall_power = 0 if weekly else progress.upgrade_level("power")


## The ticket workshop's level of `id` on this run: 0 in hard mode (it is the pure skill track) and
## without Progress.
func workshop_level(id: String) -> int:
	return int(workshop.get(id, 0))


## Applies the ticket workshop (Workshop): QUICK CHARGE and STICKY on the slime, STICKY's splat
## factor, MAGNET's reach, GOO NOSE's glimmers, SECOND WIND's readiness (story: only on a level
## already cleared on normal). None of it touches par (set before), the route or the meter.
func _apply_workshop() -> void:
	workshop = {}
	if progress == null or hard_mode or is_weekly():
		return  # (the weekly is a fixed loadout for everyone: no workshop levels either)
	for id in Workshop.ids():
		if progress.workshop_level(id) > 0:
			workshop[id] = progress.workshop_level(id)
	slime.charge_time = Workshop.charge_time(workshop_level("charge"))
	slime.splat_stun = Workshop.splat_stun(workshop_level("sticky"))
	splat_factor = Workshop.splat_factor(workshop_level("sticky"))
	coin_reach = maxf(Coin.REACH, Workshop.magnet_reach(workshop_level("magnet")))
	glimmer_rate = Workshop.nose_rate(workshop_level("nose"))
	if workshop_level("nose") > 0:
		glimmer_reach = maxf(glimmer_reach, Workshop.nose_reach(workshop_level("nose")))
	if workshop_level("wind") > 0 and (is_random() or descent or level <= progress.levels_cleared):
		wind_state = "ready"  # (Descent: once per run, see _apply_descent)
	hud.set_wind(wind_state)


## SECOND WIND fires: the meter refills to its level's share over WIND_REFILL_TIME (once per run),
## with a gulp and a ring of goo. In the randomizer the win now pays one attempt step less.
func _second_wind() -> void:
	wind_state = "refilling"
	wind_fired = true
	if descent:
		descent_run.wind_used = true  # once per run, not per floor
	_wind_target = Workshop.wind_refill(workshop_level("wind")) * 100.0
	_wind_left = _wind_target
	hud.set_wind(wind_state)
	_sfx("upgrade", -4.0)
	Fx.burst(self, slime.position, skin_color, 24, 50.0, Vector2.UP, 180.0, rainbow)
	DevLog.log_event(get_tree(), "second wind", self)


# ---------------------------------------------------------------- SPLASHDOWN (training maze)

## The training run's own setup (from _ready, after the coin is placed): the attempt's meter (low on
## attempt 1, full and visibly filling from attempt 2 on), no timer pod (no par, medals or records here),
## the training cues (chunk C's scripts/training_cues.gd, when present) and the "start" beat.
func _setup_training() -> void:
	slime_remaining = Training.start_percent(training_attempt)
	if training_attempt > 1 and motion_scale() > 0.0:
		_meter_fill = Training.FILL_TIME
	hud.set_slime(Training.start_percent(1) if _meter_fill > 0.0 else slime_remaining)
	var timer_pod := hud.time_label.get_parent().get_parent() as Control
	timer_pod.visible = false
	if ResourceLoader.exists(TRAINING_CUES_SCRIPT):
		var cues: Node = (load(TRAINING_CUES_SCRIPT) as GDScript).new()
		if cues.has_method("setup"):
			cues.call("setup", self, slime, progress)
		slime.add_child(cues)
	_begin_training_beats.call_deferred()


## Chunk C's training cues (a node under the slime that listens to training_cue); optional.
const TRAINING_CUES_SCRIPT := "res://scripts/training_cues.gd"


func _begin_training_beats() -> void:
	if not is_inside_tree():
		return
	training_beat("start")
	if training_attempt > 1:
		training_beat("restart")
		_chalice_left = Training.CHALICE_LINE_TIME
		_training_line("chalice")
	elif not Training.coin_taken:
		_training_line("coin_ahead")


## Emits training_cue(`beat_name`) once per name per attempt (the contract in docs/tutorial/design.md
## section 14). Only in the training maze.
func training_beat(beat_name: String) -> void:
	if not training or _beats.has(beat_name):
		return
	_beats[beat_name] = true
	DevLog.log_event(get_tree(), "training beat " + beat_name, self)
	training_cue.emit(beat_name)


## Per tick while running: the straight, the fork (two forced glimmers over the practice coin while it
## waits) and the first drain of the meter.
func _training_step(pos: Vector2, delta: float) -> void:
	var tile := Vector2i((pos / TILE).floor())
	if Training.on_straight(tile):
		training_beat("straight")
	if tile == Training.FORK and not _beats.has("fork"):
		training_beat("fork")
		_fork_glimmers = 2 if not coins.is_empty() else 0
		_fork_glimmer_at = 0.0
		if not Training.coin_taken and training_line != "chalice":
			_training_line("coin_up")
	if _fork_glimmers > 0:
		_fork_glimmer_at -= delta
		if _fork_glimmer_at <= 0.0:
			_fork_glimmers -= 1
			_fork_glimmer_at = Training.GLIMMER_REPEAT
			if not coins.is_empty() and is_instance_valid(coins[0]):
				_glimmer_at(coins[0])
	if slime_remaining < Training.start_percent(training_attempt) - 0.001:
		training_beat("first_drain")


## Shows the direction line `which` (Training.line; "" hides it) for `seconds` (INF: until replaced).
func _training_line(which: String, seconds := INF) -> void:
	training_line = which
	_line_left = seconds
	if which == "":
		hud.hide_training_line()
	else:
		hud.show_training_line(Training.line(which))


## Per tick in training (running or not): the line's hold, the chalice line's own clock (back after "what coins
## buy" while it has time left), and the slime's spot on screen (the line keeps off it).
func _training_lines_step(delta: float) -> void:
	_chalice_left = maxf(_chalice_left - delta, 0.0)
	if training_line == "chalice" and (_chalice_left <= 0.0 or won):
		_training_line("")  # (it goes at the chalice, or after a while)
	if finished and training_line in ["coin_ahead", "coin_up"]:
		_training_line("")  # (dried up: the next attempt has its own line)
	if training_line != "" and _line_left != INF:
		_line_left -= delta
		if _line_left <= 0.0:
			_training_line("chalice" if _chalice_left > 0.0 and not won else "")
	var at := slime.get_global_transform_with_canvas().origin.round()
	var body := Rect2(at - SLIME_SCREEN_HALF, SLIME_SCREEN_HALF * 2.0)
	if hat:
		body = body.merge(Rect2(at.x - SLIME_SCREEN_HALF.x - 4.0, at.y - SLIME_SCREEN_HALF.y - HAT_SCREEN_H, SLIME_SCREEN_HALF.x * 2.0 + 8.0, HAT_SCREEN_H))
	hud.training_slime_rect = body
	hud.training_joy_rect = touch_controls.joystick_rect()


## The practice coin at its dead end, unless this run already picked it up (it stays found across
## RESTART). The HUD's pods count it as one coin here; nothing of it is saved.
func _place_practice_coin() -> void:
	coins_here = 1
	if not Training.coin_taken:
		var coin := Coin.new()
		coin.z_index = 6  # under the fog: found by exploring
		coin.position = MazeGenerator.cell_center(_practice_coin, TILE)
		add_child(coin)
		coin.setup(maxi(Themes.BY_LEVEL.find(theme), 0), _practice_coin)
		coins.append(coin)
	_show_practice_coin(0, false)


## The practice coin is picked up: the same show as a real coin (catch, or the fly-in), never saved.
func _take_practice_coin(coin: Coin) -> void:
	Training.coin_taken = true
	_training_line("coin_use", Training.COIN_INFO_TIME)
	if Economy.coin_catch_on():
		_catch_coin(coin)
		return
	_sfx("coin", -4.0)
	if progress and progress.jelly:
		coin.dissolve_into(slime, Skins.shades(skin_color).light)
	else:
		_fly_coin_in(coin)
	_show_practice_coin(0, true)


## The coin pods in training: the balance plus the practice coin while it lasts, and 1 coin here.
func _show_practice_coin(showing: int, pop: bool) -> void:
	var found := (1 if Training.coin_taken else 0) - showing
	hud.set_coins((progress.coins() if progress else 0) + found, found, coins_here, pop)


## The win row's HUB: the training ends (Progress.finish_training saves its bit, not on a replay) and the
## hub (its tour) opens.
func _training_to_hub() -> void:
	if _leaving():
		return
	DevLog.route(get_tree(), "training HUB", self)
	UIKit.go(get_tree(), leave_training(false))


## Ends the training run (`skipped`: the pause menu's SKIP TRAINING) and returns the scene to go to.
func leave_training(skipped: bool) -> String:
	if progress:
		progress.training_coin = Training.coin_taken  # (the hub tour's coin bag line)
	Training.attempt = 1
	Training.coin_taken = false
	if progress:
		return progress.finish_training(skipped)
	return HUB_SCENE


# ---------------------------------------------------------------- coins

## The cells holding this level's coins (Levels.coin_cells: deep dead ends first, never the start
## or the chalice's cell), picked with the level's seed so they're always in the same places.
func coin_cells(maze_seed: int) -> Array[Vector2i]:
	if not is_random() and not hard_mode and maze_seed == Levels.get_config(level).seed:
		return Levels.story_coin_cells(level)  # this level's own maze, before any wall broke
	return Levels.coin_cells(maze, level, maze_seed)


## The last randomizer maze built, by its config, so RESTART / REPLAY of the same maze skips the
## build; the game gets a deep copy (walls can break in it).
static var _random_cache := {}


static func _random_maze(config: Dictionary) -> Dictionary:
	var key := var_to_str(config)
	if not _random_cache.has(key):
		_random_cache = {key: MazeGenerator.generate_random(config)}
	return _random_cache[key].duplicate(true)


## Puts out the coins of a story level that haven't been collected yet.
func _place_coins(maze_seed: int) -> void:
	if training:
		_place_practice_coin()
		return
	if is_random() or descent or hard_mode or progress == null:  # coins live in the normal story mazes
		hud.set_coins(progress.coins() if progress else 0, 0, 0)
		return
	var theme_index := Themes.BY_LEVEL.find(theme)
	var cells := coin_cells(maze_seed)
	coins_here = cells.size()
	for cell in cells:
		if progress.has_coin(level, cell):
			continue
		var coin := Coin.new()
		coin.z_index = 6  # under the fog: found by exploring
		coin.position = MazeGenerator.cell_center(cell, TILE)
		add_child(coin)
		coin.setup(theme_index, cell)
		coins.append(coin)
	hud.set_coins(progress.coins(), progress.coins_found_in(level), coins_here)


## Randomizer mazes: puts out the maze's ticket pickups not yet taken (TicketPickup; none on a typed or
## replayed seed, in Descent or training).
func _place_tickets() -> void:
	if not is_random() or descent or training or progress == null or attempt_key == "" or not progress.random_seed_fresh:
		return
	for cell in TicketPickup.cells_for(maze, random_seed, Economy.random_tickets()):
		if progress.random_ticket_taken(attempt_key, cell):
			continue
		var ticket := TicketPickup.new()
		ticket.z_index = 6  # under the fog, like a coin: found by exploring (or an ability's reveal)
		ticket.still = motion_scale() <= 0.0
		add_child(ticket)
		ticket.setup(cell, MazeGenerator.cell_center(cell, TILE))
		tickets.append(ticket)


## The ticket pickups' cells still out in this maze (for its MAP).
func ticket_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for ticket in tickets:
		cells.append(ticket.cell)
	return cells


func _pick_up_tickets(pos: Vector2) -> void:
	for ticket in tickets.duplicate():
		if pos.distance_to(ticket.position) > TicketPickup.REACH:
			continue
		tickets.erase(ticket)
		var hold: bool = Economy.pickups_on_win()
		var paid: int = progress.take_random_ticket(attempt_key, ticket.cell, no_credit() or daily_repeat(), hold)
		if hold:
			held_tickets += paid  # (shown as "+N" now, paid when the maze is won)
		ticket.collect(self)
		_sfx("coin", -4.0)
		if paid > 0:
			_float_text("+%d" % paid, ticket.position, TicketPickup.GLOW)  # i18n: ignore (a number)


## A little "+N" that rises from `at` and fades (in the world, so it never covers the HUD or the slime
## for long).
func _float_text(text: String, at: Vector2, color: Color) -> void:
	var label := UIKit.make_label(text, UIKit.FONT, color)
	label.z_index = 13  # over the fog and the abilities' glow
	label.position = (at + Vector2(-8, -14)).round()
	label.size = Vector2(16, 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 8.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)


## Map coin reveal: notes the uncollected coins within the light's reach (straight
## line, walls ignored), or all of them under FULL BRIGHT.
func _reveal_coins(pos: Vector2) -> void:
	var reach := LIGHT_RADIUS + light_reach  # the light round the slime (as _relight)
	for coin in coins:
		if (dev_bright or pos.distance_to(coin.position) <= reach) and not coin.cell in survey_coins:
			survey_coins.append(coin.cell)


func _pick_up_coins(pos: Vector2) -> void:
	for coin in coins.duplicate():
		var d := pos.distance_to(coin.position)
		if d > coin_reach:
			continue
		if d > Coin.REACH and not (is_revealed_at(coin.position) and clear_line(pos, coin.position)):
			continue  # MAGNET pulls only coins on revealed floor in plain sight
		coins.erase(coin)
		if training:
			_take_practice_coin(coin)
			continue
		progress.collect_coin(level, coin.cell, assisted)
		if assisted:
			assisted_coins += 1
		if Economy.coin_catch_on():  # coin catch test: the same credit, a slower show (CoinCatch)
			_catch_coin(coin)
			if progress.coins_earned() >= Levels.total_coins():
				hud.flash_message(_every_coin_text(), 3.0)
				_sfx("unlock")
			continue
		_sfx("coin", -4.0)
		if progress.jelly:
			coin.dissolve_into(slime, Skins.shades(skin_color).light)  # seen sinking into the body
		else:
			_fly_coin_in(coin)
		hud.set_coins(progress.coins(), progress.coins_found_in(level) + assisted_coins, coins_here, true)
		if progress.coins_earned() >= Levels.total_coins():  # the very last coin: the rainbow skin
			hud.flash_message(_every_coin_text(), 3.0)
			_sfx("unlock")


## Coin catch test: the coin's show (tossed up, caught, dissolved), already counted in the save. The
## HUD counter holds the coins still dissolving back and pops up by one as each one finishes.
func _catch_coin(coin: Coin) -> void:
	while coin_catches.size() >= Economy.COIN_CATCH_MAX:
		coin_catches[0].finish()  # too many at once: the oldest finishes now
	var calm: bool = progress.reduce_motion
	if calm:
		_sfx("coin", Economy.COIN_CATCH_COIN_DB)  # no toss to catch: the sound at once
	var catch := CoinCatch.begin(slime, coin, progress.jelly, calm, Skins.shades(skin_color).light, rainbow,
		[0.0, -3.0, 3.0][coin_catches.size() % 3])
	catch.done.connect(_on_coin_caught)
	coin_catches.append(catch)
	_show_coins()


func _on_coin_caught(catch: CoinCatch) -> void:
	coin_catches.erase(catch)
	_show_coins(true)
	if not finished:
		_sfx("coin_fizz", Economy.COIN_CATCH_FIZZ_DB)


## Ends every coin catch at once (a win or a dry-up): the counter shows the full count.
func _end_coin_catches() -> void:
	for catch in coin_catches.duplicate():
		catch.finish()
	slime.cancel_catch_hop()


## The HUD's coin pods: the balance and this level's count, less the coins still dissolving.
func _show_coins(pop := false) -> void:
	var showing := coin_catches.size()
	if training:
		_show_practice_coin(showing, pop)
		return
	hud.set_coins(progress.coins() - showing, progress.coins_found_in(level) + assisted_coins - showing, coins_here, pop)


## A solid slime has no see-through body: the coin glides into it, then pops.
func _fly_coin_in(coin: Coin) -> void:
	if coin.position.distance_to(slime.position) <= Coin.REACH:
		Fx.burst(self, coin.position, Color8(255, 214, 110), 14, 45.0)
		coin.queue_free()
		return
	var tween := coin.create_tween()
	tween.tween_property(coin, "global_position", slime.global_position, 0.12)
	tween.tween_callback(func() -> void:
		Fx.burst(self, slime.position, Color8(255, 214, 110), 14, 45.0)
		coin.queue_free())


## True once the fog cell at `pos` has been revealed (ever).
func is_revealed_at(pos: Vector2) -> bool:
	var at := _cell_at(pos)
	if not Rect2i(Vector2i.ZERO, _cells).has_point(at):
		return false
	var v := _fog_bytes.decode_u32((at.y * _cells.x + at.x) * 4)
	return ((v >> 16) & 255) * 256 + ((v >> 24) & 255) > 0


## True if no wall tile lies on the straight line from `a` to `b` (a tile raycast, 2 px steps).
func clear_line(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(ceili(a.distance_to(b) / 2.0), 1)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		if is_wall_tile(Vector2i(floori(p.x / TILE), floori(p.y / TILE))):
			return false
	return true


# ---------------------------------------------------------------- goal and attempts

## The maze's goal: the scene's chalice in a story level. A randomizer maze has no chalice: it is
## freed and a TicketGoal takes its place in the tree (same grab circle, drawn at the same depth).
func _make_goal() -> void:
	if not is_random() or Economy.RANDOM_CHALICE:
		goal = chalice
		return
	var ticket := TicketGoal.new()
	ticket.still = motion_scale() <= 0.0
	add_child(ticket)
	move_child(ticket, chalice.get_index())
	remove_child(chalice)
	chalice.free()
	chalice = null
	goal = ticket


## Randomizer: counts this start of the maze (an attempt) and shows it with what a win would pay.
## Runs in _ready, so the restarted run's very first frame already shows the new count.
func _count_attempt() -> void:
	if not is_random() or progress == null or preview:  # (the preview counts no attempts: no pod, pickups or map)
		return
	attempt_key = progress.random_attempt_key(random_seed, seed_level, hard_mode)
	attempt = progress.begin_random_attempt(attempt_key)
	DevLog.log_event(get_tree(), "maze built (via %s)" % (DevLog.last_route if DevLog.last_route != "" else "fresh"), self)
	DevLog.last_route = ""
	touch_controls.pause_rect.position.y = touch_controls.pause_y_random()  # under the two-line attempt pod
	_refresh_attempt_pod()
	if attempt > 1 and attempt == progress.random_attempt_base + 1:  # the first start of a maze that opens past attempt 1: say why
		# i18n: short HUD line when a fresh random maze starts on a later attempt because the last maze was left unfinished; max 140px
		hud.flash_message(Loc.t("hud.left_last_maze", "LEFT LAST MAZE: ATTEMPT {n}", {n = mini(attempt, 99)}), 2.5)


## Randomizer: what a win on this run would pay right now and why ({tickets, table, cap}, see
## Progress.random_payout), from this run's attempt number; tickets 0 once dev toggles or the
## assist were used. The ONE computation behind both the attempt pod and the payout (a win pays
## exactly payout().tickets, in dev mode too, where it only isn't saved).
func payout() -> Dictionary:
	if not is_random() or progress == null:
		return {tickets = 0, table = 0, cap = ""}
	var due: Dictionary = progress.random_payout(pay_attempt(), random_seed, pay_factor(), progress.random_daily)
	if daily_repeat():
		due = {tickets = 0, table = due.table, cap = "paid"}
	if no_credit():
		due.tickets = 0
	return due


## The maze's pay factor: its length factor, x Economy.LURKER_PAY when a NORMAL maze has lurkers (BM-01; hard pays
## only its flat HARD_LENGTH_FACTOR, IMP3-01).
func pay_factor() -> float:
	var factor: float = progress.random_length_factor(random_seed, seed_level, hard_mode)
	return factor * Economy.LURKER_PAY if lurkers != null and not hard_mode else factor


## The attempt a randomizer win is paid for: this run's attempt, one more once SECOND WIND fired
## (the extra slime costs one attempt step of the payout; spec B.2).
func pay_attempt() -> int:
	if progress != null and progress.random_daily:
		return 1  # (the daily's first win of the day pays like attempt 1, whatever the retries)
	return attempt + (1 if wind_fired else 0)


## A daily maze already won today: this win pays nothing (its pickups neither).
func daily_repeat() -> bool:
	# (compared with the day this run STARTED on: a daily won after UTC midnight must not pay twice)
	return progress != null and progress.random_daily and progress.daily_won_on(progress.daily_run_day)


## An assisted, dev-toggled or RELAXED run earns no medal, record or ticket.
func no_credit() -> bool:
	return assisted or dev_toggled or relaxed_run or is_weekly()


## BM-03: this run is the WEEKLY maze (a board time only: no pay, no record, no abilities).
func is_weekly() -> bool:
	return Economy.boards_on() and progress != null and progress.random_weekly and is_random()


## The tickets a win on this run would pay right now (payout().tickets).
func ticket_offer() -> int:
	return payout().tickets


## The tickets the maze's pickups still out would pay (none once the run is over, or for an assisted
## or dev-toggled run): the attempt pod's TIX AVAILABLE adds them, so it counts down as they're taken.
func pickup_offer() -> int:
	if finished or no_credit() or daily_repeat():
		return 0
	return tickets.size() * Economy.RANDOM_TICKET_PAY + held_tickets


## The HUD's attempt pod, derived afresh from `attempt` and ticket_offer() (on the run's first frame
## and then whenever any of its inputs changes, see _pod_inputs, so it can never go stale; the HUD
## only touches the label when the text changes). The run's first showing pops the pod when its number differs from what it last showed
## for this maze (a restart that lowered it), unless Reduce Motion is on.
func _refresh_attempt_pod() -> void:
	if not is_random() or progress == null or attempt_key == "":
		return
	var offer := ticket_offer() + pickup_offer()  # (the chalice's tickets and the pickups still out)
	var pop := false
	if _pod_offer < 0:
		var before: int = progress.random_offer_shown.get(attempt_key, -1)
		pop = before >= 0 and before != offer and motion_scale() > 0.0
	_pod_offer = offer
	progress.random_offer_shown[attempt_key] = offer
	hud.set_attempt(attempt, offer, pop, lurkers != null)
	if hud.attempt_label.text != _dev_pod_text:
		_dev_pod_text = hud.attempt_label.text
		DevLog.log_event(get_tree(), "pod text changed", self)


# ---------------------------------------------------------------- trail map survey

## Records this run's survey from here on if it is a real story run (deferred from _ready, once the
## scene is the running one): never in a randomizer maze (fresh each time), a Descent floor (level 0:
## it would land on level 1's map), dev mode (unless the map coin reveal is on: _commit_survey)
## or a test's loose game node.
func _arm_survey() -> void:
	_survey_live = progress != null and not is_random() and not descent and not training and (not progress.dev_tools or _coin_reveal) \
		and _is_running_scene()


## Follows the slime through the maze's cells: each time its center enters a new cell's open tile,
## the step is added to the route (one byte; no allocation otherwise). Cells only meet through the
## passage tile between them, so steps are always to a neighbor; anything else (never seen in play)
## is bridged by the shortest path.
func _survey_step(pos: Vector2) -> void:
	var tx := floori(pos.x / TILE)
	var ty := floori(pos.y / TILE)
	if (tx & 1) == 0 or (ty & 1) == 0:
		return  # a passage or wall tile: not inside a cell
	var cell := Vector2i(tx >> 1, ty >> 1)
	if cell != _survey_cell and tx >= 0 and ty >= 0:
		_survey_enter(cell)


## Adds the step(s) from the last cell to `cell` to the route.
func _survey_enter(cell: Vector2i) -> void:
	if cell == _survey_cell or cell.x >= maze.cells.x or cell.y >= maze.cells.y:
		return
	if survey_moves.size() < Survey.MAX_MOVES:
		var code := MazeGenerator.DIRS.find(cell - _survey_cell)
		if code >= 0:
			survey_moves.append(code)
		else:
			survey_moves.append_array(Survey.moves_along(MazeGenerator.shortest_path(maze, _survey_cell, cell)))
	_survey_cell = cell


## Adds this run to the level's survey (once: at the win or dry-up, or when the run is left).
## Assisted and dev-toggled runs (F1 FULL BRIGHT / F2 NO DRAIN) record nothing. Exception: with the
## map coin reveal on (Economy.map_coin_reveal_on) every dev run records, F1 / F2 ones
## too, into the session's memory only (dev mode never saves), with the coins it revealed.
func _commit_survey() -> void:
	if not _survey_done and _random_map_live():
		_survey_done = true
		if won:
			progress.discard_random_map()  # (cleared: its map is gone)
		else:
			progress.record_random_map(attempt_key, maze, survey_tiles, survey_moves, survey_goal, ticket_cells())
		return
	if _survey_done or not _survey_live:
		return
	_survey_done = true
	if _coin_reveal and progress.dev_tools:
		progress.record_survey(level, hard_mode, maze, survey_tiles, survey_moves, won, run_time, survey_goal, survey_coins)
		return
	if assisted or dev_toggled or progress.dev_tools:
		return
	progress.record_survey(level, hard_mode, maze, survey_tiles, survey_moves, won, run_time, survey_goal, survey_coins)


# ---------------------------------------------------------------- DESCENT

## Applies the run's boons (Descent) on top of the upgrades and the workshop: capacity (DEEP TANK,
## GREEDY GOO), speed (SLICK), leap cost (FEATHER LEAP), splats (RUBBER BODY, GLASS SLIME), light
## (BLAZE), the exit's reveal reach (CHALICE SENSE), BACKUP BLADDER refills; SECOND WIND only if it
## hasn't fired this run; a dev toggle on an earlier floor keeps the run unpaid.
func _apply_descent() -> void:
	var boons: Dictionary = descent_run.boons
	slime_cost_per_tile /= Descent.capacity(boons)
	var speed := Descent.speed(boons)
	slime.max_speed *= speed
	slime.acceleration *= speed
	jump_cost_factor = Descent.jump_cost(boons, JUMP_COST_FACTOR)
	splat_factor *= Descent.splat_factor(boons)
	light_reach = Descent.light_reach(boons, progress.upgrade_level("brightness") if progress else 0)
	goal_reveal_distance = Descent.goal_reveal(boons, CHALICE_REVEAL_DISTANCE)
	bladders = int(descent_run.bladders)
	if descent_run.wind_used and wind_state == "ready":
		wind_state = "used"
		hud.set_wind(wind_state)
	dev_toggled = dev_toggled or descent_run.tainted
	hud.set_boons(boons, bladders)
	touch_controls.pause_rect.position.y = touch_controls.pause_y_random()  # under the two-line pot pod
	if is_inside_tree():
		get_tree().process_frame.connect(_place_touch_pause, CONNECT_ONE_SHOT)


## Touch: the pause button goes under the pot pod and the boon strip (once their sizes are known).
func _place_touch_pause() -> void:
	var bottom: float = hud.attempt_pod.get_global_rect().end.y if hud.attempt_pod.visible else 0.0
	if hud.boon_pod.visible:
		bottom = maxf(bottom, hud.boon_pod.get_global_rect().end.y)
	touch_controls.pause_rect.position.y = maxf(touch_controls.pause_y_random(), ceilf(bottom) + 3.0)


## The meter just hit 0 on the goal (a SLIMAKAZE paying there): SECOND WIND or BACKUP BLADDER fires
## as it would in play and, since the run ends now, its refill lands at once. False if neither is left.
func _rescue_empty_meter() -> bool:
	if wind_state == "ready":
		_second_wind()
		slime_remaining += _wind_left
		_wind_left = 0.0
		wind_state = "used"
		hud.set_wind(wind_state)
	elif wind_state != "refilling" and _bladder_left <= 0.0 and bladders > 0:
		_backup_bladder()
		slime_remaining += _bladder_left
		_bladder_left = 0.0
	else:
		return false
	hud.set_slime(slime_remaining)
	return true


## BACKUP BLADDER fires (the meter hit 0 after SECOND WIND, if any): +25% over WIND_REFILL_TIME.
func _backup_bladder() -> void:
	bladders -= 1
	descent_run.bladders = bladders
	_bladder_left = float(Economy.BOONS.bladder.value)
	hud.set_boons(descent_run.boons, bladders)
	_sfx("upgrade", -4.0)
	Fx.burst(self, slime.position, skin_color, 20, 45.0, Vector2.UP, 180.0, rainbow)
	DevLog.log_event(get_tree(), "backup bladder", self)


## The floor's goo drops (Descent.drop_cells: deep dead ends, seeded), under the fog like coins.
func _place_drops(maze_seed: int) -> void:
	for cell in Descent.drop_cells(maze, maze_seed):
		var drop := GooDrop.new()
		drop.z_index = 6  # under the fog: found by exploring (glimmers mark them)
		drop.position = MazeGenerator.cell_center(cell, TILE)
		drop.cell = cell
		drop.color = skin_color
		drop.still = motion_scale() <= 0.0
		add_child(drop)
		drops.append(drop)


## Touching a goo drop (or MAGNET pulling one in plain sight) adds DESCENT_DROP_REFILL % of the meter.
func _pick_up_drops(pos: Vector2) -> void:
	for drop in drops.duplicate():
		var d := pos.distance_to(drop.position)
		if d > coin_reach:
			continue
		if d > Coin.REACH and not (is_revealed_at(drop.position) and clear_line(pos, drop.position)):
			continue
		drops.erase(drop)
		slime_remaining = minf(slime_remaining + Economy.DESCENT_DROP_REFILL, 100.0)
		hud.set_slime(slime_remaining)
		_sfx("coin", -4.0)
		Fx.burst(self, drop.position, skin_color, 14, 40.0, Vector2.UP, 180.0, rainbow)
		drop.queue_free()


## Everything the attempt pod (payout(), Progress.random_payout) and the pot pod (_refresh_descent_pod,
## Progress.descent_payout) are derived from, as a cheap value to compare frame to frame: the run's
## own state, the UTC day and the day's paid counts, the caps' inputs, and the Descent run's pot.
func _pod_inputs() -> Array:
	if progress == null:
		return []
	return [attempt, wind_fired, dev_toggled, assisted, finished, won, tickets.size(), held_tickets, progress.utc_day(), progress.dev_tools,
		progress.upgrades.get("slime", 0), progress.random_paid, progress.random_pay_day,
		progress.random_paid_seeds.hash(), progress.random_seed_fresh, progress.descent_paid, progress.descent_pay_day,
		descent_run.get("pot"), descent_run.get("gain"), descent_run.get("slot"), descent_run.get("ended"),
		descent_run.get("tainted"), descent_run.get("result", {}).size()]


## The HUD's pot pod: the pot and what it would pay ("PRACTICE" once today's paying runs are used).
func _refresh_descent_pod() -> void:
	if not descent or progress == null:
		return
	if descent_run.get("ended", false):
		# Banked: show what the run was paid as (the summary's), not what today would pay now.
		var result: Dictionary = descent_run.get("result", {})
		hud.set_pot(int(descent_run.pot), String(result.get("cap", "")), 0, int(result.get("slot", 0)))
		return
	var due: Dictionary = progress.descent_payout(true, dev_toggled)
	hud.set_pot(int(descent_run.pot), due.cap, int(descent_run.get("gain", 0)) if finished and won else 0, int(due.slot))


## The floor's first frames: a milestone reached for the first time says what it paid.
func _announce_floor() -> void:
	var bonus := int(descent_run.get("bonus", 0))
	if bonus <= 0:
		return
	descent_run.bonus = 0  # shown once
	# i18n: flash message, max 296px, 1 line; {count} = tickets paid, {floor} = the floor reached
	var lines := [Loc.n("result.floor_bonus", "FLOOR {floor} BONUS +{count} TICKETS", "FLOOR {floor} BONUS +{count} TICKETS",
		bonus, {floor = int(descent_run.floor)})]
	if int(descent_run.floor) == Economy.DESCENT_ABYSS_FLOOR:
		# i18n: max 296px, 1 line; {name} = a trail name
		lines.append(Loc.t("result.new_trail", "NEW TRAIL: {name}", {name = Cosmetics.display_name("abyss")}))
	hud.flash_message(Loc.lines(lines), 3.0)
	_sfx("unlock")


func _ensure_card() -> DescentCard:
	if descent_card == null:
		descent_card = DescentCard.new()
		descent_card.game = self
		add_child(descent_card)
	return descent_card


## After a cleared floor: the boon card (pick 1 of 3, then DESCEND; or CASH OUT).
func _open_boon_card() -> void:
	hud.message.visible = false
	_ensure_card().show_boons(descent_run, progress.descent_offers() if progress else [])


## The run is over (dry-up, CASH OUT): its summary (NEW RUN / HUB).
func _show_descent_summary() -> void:
	hud.message.visible = false
	_ensure_card().show_summary(descent_run.get("result", {}))


## DESCEND with boon `id`: the next floor (the scene is rebuilt from the run).
func descend_with(id: String) -> void:
	if _leaving() or _descent_acted or progress == null or not progress.descend(id):
		return
	_descent_acted = true  # one action per card: a CASH OUT in the same frame does nothing
	DevLog.route(get_tree(), "DESCEND " + id, self)
	if _is_running_scene():
		get_tree().reload_current_scene()


## CASH OUT: banks the whole pot and shows the summary.
func cash_out() -> void:
	if _leaving() or _descent_acted or progress == null or not progress.descent_active():
		return
	_descent_acted = true
	progress.end_descent(true, dev_toggled or assisted)  # (F1 / F2 may have been switched on over the card)
	_show_descent_summary()


## NEW RUN (from the summary): a fresh run from floor 1.
func new_descent_run() -> void:
	if _leaving() or progress == null:
		return
	progress.start_descent()
	DevLog.route(get_tree(), "NEW RUN", self)
	if _is_running_scene():
		get_tree().reload_current_scene()


## Leaving a Descent floor for the hub (pause menu QUIT TO HUB): mid-floor it counts as a dry-up
## (half the pot), on the boon card (floor cleared) as a CASH OUT; an ended run is left as it is.
func quit_descent() -> void:
	if not descent or progress == null or not progress.descent_active():
		return
	if finished and won:
		progress.end_descent(true, dev_toggled or assisted)
	else:
		progress.end_descent(false, dev_toggled or assisted, run_time)


# ---------------------------------------------------------------- dev: wall power

## Wall power (dev only): a splat chips away at the wall it hits, harder the stronger the leap.
## Walls crack through the art's damage stages as they weaken and crumble away at zero. The
## maze's outer edge can't be broken.
func _damage_wall(pos: Vector2, wall_normal: Vector2, charge: float) -> void:
	if wall_power <= 0:
		return
	var tile := Vector2i(((pos - wall_normal * (Slime.RADIUS + 2.0)) / TILE).floor())
	if not is_wall_tile(tile) or _is_edge(tile):
		return
	var health: float = wall_health.get(tile, 100.0 - 25.0 * wall_damage.get(tile, 0))
	health -= Upgrades.wall_damage(wall_power, charge)
	if health <= 0.0:
		_break_wall(tile)
		return
	wall_health[tile] = health
	var stage := clampi(3 - int(health / 25.0), 0, 3)
	if stage > wall_damage.get(tile, 0):
		wall_damage[tile] = stage
		var row := wall_layer.get_cell_atlas_coords(tile).y
		wall_layer.set_cell(tile, MazeTiles.WALL_SOURCE,
			Vector2i(wall_layer.get_cell_atlas_coords(tile).x, (row / 12) * 12 + stage * 3 + row % 3))


func _is_edge(tile: Vector2i) -> bool:
	return tile.x <= 0 or tile.y <= 0 or tile.x >= maze.size.x - 1 or tile.y >= maze.size.y - 1


## Knocks a wall out: it becomes rubble-strewn floor, and the walls and corner fillets around it
## re-fit their edges to the new opening.
func _break_wall(tile: Vector2i) -> void:
	maze.walls[tile.y * maze.size.x + tile.x] = 0
	wall_layer.erase_cell(tile)
	wall_damage.erase(tile)
	wall_health.erase(tile)
	revealed_walls.erase(tile)
	floor_layer.set_cell(tile, MazeTiles.FLOOR_SOURCE, Vector2i(MazeTiles.FLOOR_RUBBLE, 0))
	_fill_fog(_tile_cells(tile), _fog_color(elapsed, elapsed, false))
	# The tile is floor now: cells of the last painted / revealed discs may need painting after all.
	_painted_radius = -1.0
	_revealed_radius = -1.0
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var near := tile + offset
		if near.x < 0 or near.y < 0 or near.x >= maze.size.x or near.y >= maze.size.y:
			continue
		if is_wall_tile(near):
			var row := wall_layer.get_cell_atlas_coords(near).y
			wall_layer.set_cell(near, MazeTiles.WALL_SOURCE, Vector2i(MazeTiles.wall_mask(maze, near), row))
		else:
			var mask := MazeTiles.wall_mask(maze, near)
			if MazeTiles.has_corner(mask):
				fillet_layer.set_cell(near, MazeTiles.FILLET_SOURCE, Vector2i(mask, 0))
			else:
				fillet_layer.erase_cell(near)
	var center := (Vector2(tile) + Vector2(0.5, 0.5)) * TILE
	Fx.burst(self, center, Color8(148, 140, 150), 24, 60.0)
	shake(SHAKE_MAX, SHAKE_TIME, kick)  # (keeps the landing's shove)
	_sfx("crumble")


## Puts the selected hat on the slime: it pops off on every leap and comes back down on its head.
func _put_on_hat() -> void:
	if progress == null or progress.selected_hat == Hats.NONE:
		return
	hat = Hat.new()
	hat.z_index = slime.z_index + 1
	add_child(hat)
	hat.setup(progress.selected_hat, slime.sprite, slime, progress.hat_dye_of(progress.selected_hat))
	slime.launched.connect(hat.pop)


## A knockback ricochet: a smaller splat (stain, goo spray, a shake that scales with the hit).
func _on_bounced(wall_normal: Vector2, impact: float) -> void:
	var power := clampf(impact / 200.0, 0.0, 1.0)
	_stain_wall(slime.position, wall_normal)
	Fx.burst(self, slime.position - wall_normal * Slime.RADIUS, skin_color, int(lerpf(4, 12, power)), lerpf(25.0, 60.0, power), wall_normal, 70.0, rainbow)
	if power > 0.3:
		shake(lerpf(1.0, SHAKE_MAX - 1.0, power), SHAKE_TIME * 0.6, -wall_normal * roundf(lerpf(1.0, KICK_MAX - 1.0, power)))


func _on_goal_body_entered(body: Node2D) -> void:
	if body != slime or finished:
		return
	if slime.state == Slime.State.DASH and abilities:
		# SLIMAKAZE into the goal: the dash ends here and pays its cost first (the carried Descent
		# meter included). Emptied, it is a dry-up, not a win (SECOND WIND / BACKUP BLADDER still save it).
		abilities.settle_at_goal()
		if slime_remaining <= 0.0 and not _rescue_empty_meter():
			_dry_up()
			return
	_show(goal)
	var no_record := no_credit()
	if progress:
		progress.relaxed_level = 0  # (RELAXED for one level ends with its win; this run keeps relaxed_run for its payout)
	slime.play_celebrate()
	if Economy.light_life_on():
		_light_life_win()
	if Economy.orchestra_on() and has_node("/root/Music"):
		get_node("/root/Music").play_orchestra_sting("win")
		get_node("/root/Music").orchestra_state(false, false)
	if hat:
		hat.pop(Vector2.ZERO, 0.45)  # tossed up in celebration
	if training:
		# SPLASHDOWN's chalice: the fanfare, nothing recorded or paid, then the HUB-only row.
		Fx.burst(self, goal.position, CHALICE_GOLD, 28, 60.0)
		_sfx("chalice", CHALICE_VOLUME_DB)
		# i18n: result lines, max 296px each, 1 line each (the training maze's win)
		_finish(true, Loc.lines([Loc.t("result.chalice", "CHALICE CONSUMED!"),
			Loc.t("result.training_won", "THE REAL MAZES ARE UP THERE")]))
		return
	if descent:
		# The floor's exit: the chalice fanfare, the floor's tickets into the pot, then the boon card.
		Fx.burst(self, goal.position, CHALICE_GOLD, 28, 60.0)
		_sfx("chalice", CHALICE_VOLUME_DB)
		var gain: int = progress.clear_descent_floor(slime_remaining, run_time, dev_toggled) if progress else 0
		DevLog.log_event(get_tree(), "descent floor cleared", self, "pot+%d" % gain)
		# i18n: result title, max 296px, 1 line
		_finish(true, Loc.t("result.floor_cleared", "FLOOR {floor} CLEARED", {floor = int(descent_run.get("floor", 1))}))
		return
	if is_random():
		var title := Loc.t("result.chalice", "CHALICE CONSUMED!")
		if goal is TicketGoal:
			# The ticket is the prize: it pops into gold sparks and the ticket chime plays.
			Fx.burst(self, goal.position, TicketGoal.GLOW.lightened(0.25), 28, 60.0)
			_bright_shown.erase(goal)  # taken: FULL BRIGHT going off later doesn't bring it back
			goal.visible = false
			_sfx("unlock", CHALICE_VOLUME_DB)
			title = Loc.t("result.ticket_claimed", "TICKET CLAIMED!")  # i18n: result title, max 296px, 1 line
		else:  # (Economy.RANDOM_CHALICE: the story's chalice, paying the same tickets)
			Fx.burst(self, goal.position, CHALICE_GOLD, 28, 60.0)
			_sfx("chalice", CHALICE_VOLUME_DB)
		var random_lines: Array = [title]
		# IMP3-07: the daily / weekly line carries the time (DAILY #n  M:SS.cc  STREAK s), so no TIME line over it
		var time_in_line: bool = progress != null and _is_running_scene() and not preview and ((progress.random_daily and not no_record) 			or (is_weekly() and not (assisted or dev_toggled or relaxed_run)))
		if not time_in_line:
			random_lines.append(Loc.t("result.time", "TIME {time}", {time = UIKit.format_time(run_time)}))  # i18n: max 296px; {time} = M:SS.cc
		if not (progress and progress.random_daily):  # (the daily's seed is the date: a SEED line says nothing, IMP2-02)
			random_lines.append(Loc.t("result.seed", "SEED {code}", {code = Levels.seed_code(random_seed, seed_level)}))  # i18n: max 296px; {code} = a maze code
		var random_text := Loc.lines(random_lines)
		if preview:
			# i18n: result title (the demo's preview maze won; nothing is paid), max 296px, 1 line
			title = Loc.t("result.preview_cleared", "PREVIEW CLEARED!")
			random_text = Loc.lines([title, Loc.t("result.time", "TIME {time}", {time = UIKit.format_time(run_time)})])
		elif progress and _is_running_scene() and is_weekly():
			random_text = _weekly_result(random_text)
		elif progress and _is_running_scene():
			var due := payout()  # before the win is recorded: exactly what the pod shows
			var repeat := daily_repeat()
			var paid: int = progress.complete_random(no_record or repeat, random_seed, pay_attempt(), pay_factor(), (not repeat or Economy.REPEAT_DAILY_COUNTS) and (not relaxed_run or Economy.RELAXED_COUNTS_WINS), progress.random_daily)
			if repeat:
				held_tickets = 0
			if abilities != null and abilities.uses == 0 and not no_record and (not repeat or Economy.REPEAT_DAILY_COUNTS):
				progress.note_clean_random_win()
			if progress.random_daily and not no_record:
				var day: Dictionary = progress.record_daily(roundi(run_time * 1000.0), progress.daily_run_day)
				# i18n: result line, max 296px, 1 line; {n} = the daily's number, {time} = the day's best M:SS.cc, {streak} = days in a row; the spaces are spacing, not words
				var daily_line := Loc.t("result.daily", "DAILY #{n}  {time}  STREAK {streak}",
					{n = day.number, time = UIKit.format_time(run_time), streak = day.streak})
				if roundi(run_time * 1000.0) != int(day.best_ms):  # a slower replay: this run's time, and the day's best in place of the streak
					# i18n: result line, max 296px, 1 line; {n} = the daily's number, {time} = this run M:SS.cc, {best} = the day's best M:SS.cc
					daily_line = Loc.t("result.daily_best", "DAILY #{n}  {time}  BEST {best}",
						{n = day.number, time = UIKit.format_time(run_time), best = UIKit.format_time(day.best_ms / 1000.0)})
				random_text = Loc.lines([random_text, daily_line])
				random_text = _board_result(random_text, "daily", roundi(run_time * 1000.0))
				# i18n: the line COPY puts on the clipboard to paste to friends, 1 line; keep the game's name; {n} = the daily's number, {time} = M:SS.cc, {streak} = days in a row
				daily_share = Loc.t("result.daily_share", "Dry Trying DAILY #{n} {time} streak {streak}",
					{n = day.number, time = UIKit.format_time(run_time), streak = day.streak}) + share_extra
				if day.saved:
					# IMP3-07: a top toast (Transition's notice path), not a line of the result panel
					# i18n: toast, max 296px, 1 line (the week's one free streak saver covered a missed day)
					progress.notify_once("daily_saved_%d" % progress.daily_run_day, Loc.t("result.daily_saved", "STREAK SAVED"))
				if day.bonus > 0:
					# i18n: result line, max 296px, 1 line; {n} = tickets, {days} = the streak
					random_text = Loc.lines([random_text, Loc.t("result.daily_bonus", "{days} DAY STREAK: +{n} TICKETS", {days = day.streak, n = day.bonus})])
			var pastel_skin := Skins.pastel_unlocked_at(progress.randoms_won)
			if pastel_skin != "" and progress.is_skin_unlocked(pastel_skin, false, true):
				# i18n: result line, max 296px, 1 line; {name} = a skin name (its pastel version just unlocked)
				random_text = Loc.lines([random_text, Loc.t("result.new_pastel_skin", "NEW PASTEL SKIN: {name}", {name = Skins.display_name(pastel_skin)})])
			var wins_left := Achievements.wins_to_next_unlock(progress.randoms_won)
			if wins_left > 0 and not relaxed_run and not progress.random_daily and Economy.ACHIEVEMENTS and not Demo.on() and (not repeat or Economy.REPEAT_DAILY_COUNTS):
				# i18n: result line, max 296px, 1 line; {n} = randomizer wins until the next pastel skin or win goal
				random_text = Loc.lines([random_text, Loc.n("result.next_unlock", "NEXT UNLOCK IN {n} WIN", "NEXT UNLOCK IN {n} WINS", wins_left, {n = wins_left})])
			DevLog.log_event(get_tree(), "win", self, "paid=%d" % paid)
			assert(paid == due.tickets, "a randomizer win pays what the attempt pod shows")
			if held_tickets > 0:  # the held pickups, paid now (Economy.PICKUPS_ON_WIN)
				paid += progress.add_tickets(held_tickets)
				held_tickets = 0
				progress.random_tickets_held.clear()  # (paid: a replay of this maze doesn't put them back)
			if paid > 0:
				reward = {tickets = paid, attempt = attempt, cap = due.cap}
				hud.show_rewards(reward)
				get_tree().create_timer(0.9).timeout.connect(func() -> void: _sfx("coin", -6.0))
			elif dev_toggled:
				hud.show_rewards({dev = true})
			elif relaxed_run:
				hud.show_rewards({relaxed = true})
			elif assisted:
				hud.show_rewards({assisted = true})
			elif due.cap == "paid":
				hud.show_rewards({repeat = true})
			else:
				hud.show_rewards({capped = true})
		_finish(true, random_text)
		return
	Fx.burst(self, goal.position, CHALICE_GOLD, 28, 60.0)
	_sfx("chalice", CHALICE_VOLUME_DB)
	# The result text, one whole translated line per entry (Loc.lines joins them in _finish's call).
	# i18n: result title lines, max 296px each, 1 line each
	var lines := [Loc.t("result.chalice", "CHALICE CONSUMED!"),
		Loc.t("result.level_cleared", "LEVEL {level} CLEARED", {level = level})]
	# Read before the clear is recorded: these name what this win unlocks for the first time.
	var first_hard_clear: bool = progress != null and hard_mode and not no_credit() and not level in progress.hard_cleared
	var first_story_clear: bool = progress != null and progress.levels_cleared < level
	# Records: a first clear just sets the record; only beating an existing one celebrates.
	var best: float = progress.best_time(level) if progress else -1.0
	var time_line := Loc.t("result.time", "TIME {time}", {time = UIKit.format_time(run_time)})
	if progress and _is_running_scene():
		reward = progress.record_clear(level, run_time, par_time, no_record, true)
		hud.show_rewards(reward.merged({dev = true}) if dev_toggled else (reward.merged({relaxed = true}) if relaxed_run else reward))
		if reward.get("new_best", false):
			get_tree().create_timer(0.9).timeout.connect(func() -> void: _sfx("coin", -6.0))
	if no_record:
		pass  # no record to beat or show
	elif best >= 0.0 and run_time < best:
		hud.show_record(run_time)
		get_tree().create_timer(0.4).timeout.connect(func() -> void: _sfx("unlock"))
	elif best >= 0.0:
		# i18n: max 296px, 1 line; {time} / {best} = M:SS.cc; the three spaces are spacing, not words
		time_line = Loc.t("result.time_best", "TIME {time}   BEST {best}", {time = UIKit.format_time(run_time), best = UIKit.format_time(best)})
	lines.append(time_line)
	if level >= Levels.COUNT:
		# The last level: one title line instead of CHALICE CONSUMED / LEVEL n CLEARED (lines 0-1).
		# i18n: result title, max 296px, 1 line; {count} = number of story levels
		lines = [Loc.n("result.escaped_all", "YOU ESCAPED ALL {count} MAZE!", "YOU ESCAPED ALL {count} MAZES!", Levels.COUNT), time_line]
	if first_hard_clear:
		var jelly := _skins_unlocked_jelly_by(level)
		if not jelly.is_empty():
			# i18n: list separator between skin names, e.g. "A, B"
			var names := Loc.t("common.list_sep", ", ").join(jelly)
			# i18n: max 296px, 1 line; {names} = one or more skin names; {count} = how many
			lines.append(Loc.n("result.new_jelly_skin", "NEW JELLY SKIN: {names}", "NEW JELLY SKIN: {names}", jelly.size(), {names = names}))
			get_tree().create_timer(0.6).timeout.connect(func() -> void: _sfx("unlock"))
	elif first_story_clear:
		var unlocked := Skins.unlocked_by_level(level)
		if level >= Levels.COUNT:
			# i18n: max 296px; wraps onto 2 lines past that (broken at a space), lines 2; {name} = the color-picker skin's name
			lines.append(Loc.t("result.unlocked_custom", "UNLOCKED: {name} (ANY COLOR YOU LIKE)!", {name = Skins.display_name(Skins.CUSTOM)}))
		elif unlocked != "":
			# i18n: max 296px, 1 line; {name} = a skin name
			lines.append(Loc.t("result.new_skin", "NEW SKIN: {name}", {name = unlocked}))
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _sfx("unlock"))
	# The last gold medal: the stopwatch skin (once, saved like the other skin notices).
	if reward.get("new_best", false) and progress.all_medals() and progress.take_skin_notice(Progress.STOPWATCH_NOTICE):
		# i18n: max 296px, 1 line; {name} = a skin name
		lines.append(Loc.t("result.all_medals_skin", "ALL MEDALS! NEW SKIN: {name}", {name = Skins.display_name(Skins.STOPWATCH)}))
		get_tree().create_timer(1.0).timeout.connect(func() -> void: _sfx("unlock"))
	if ghost != null:
		# IMP3-06: the best earlier clear of this level (and mode) raced as the pale ghost; a faster clear becomes the new ghost
		var split := ghost.finish(roundi(run_time * 1000.0))
		if split != "":
			var at := lines.find(time_line)
			if at >= 0 and (time_line == Loc.t("result.time", "TIME {time}", {time = UIKit.format_time(run_time)}) or lines.size() >= 5):
				# BUG4-04-3: folded into the TIME line, so a five-line record result (medal + skin + coins) never drops it
				# i18n: result line, max 296px, 1 line; {time} = M:SS.cc, {split} = the time against your ghost, e.g. +1.2s (slower) or -0.8s (faster); the two spaces are spacing
				lines[at] = Loc.t("result.time_ghost", "TIME {time}  {split} VS GHOST", {time = UIKit.format_time(run_time), split = split})
			else:
				# i18n: result line, max 296px, 1 line; {split} = the time against your ghost, e.g. +1.2s (slower) or -0.8s (faster)
				lines.append(Loc.t("result.ghost_split", "VS GHOST {split}", {split = split}))
	_finish(true, Loc.lines(lines))


## The every-coin notice (both coin paths): the rainbow skin it unlocks.
func _every_coin_text() -> String:
	# i18n: flash message, max 296px, 1 line each; {name} = a skin name
	return Loc.lines([Loc.t("result.every_coin", "EVERY COIN FOUND!"),
		Loc.t("result.new_skin", "NEW SKIN: {name}", {name = Skins.display_name(Skins.RAINBOW)})])


## Skins whose see-through jelly version beating `level` on hard mode unlocks (D14).
func _skins_unlocked_jelly_by(level: int) -> Array[String]:
	var names: Array[String] = []
	var ids: Array = Skins.PRESETS.map(func(p: Dictionary) -> String: return p.id) + [Skins.CUSTOM, Skins.RAINBOW]
	for id: String in ids:
		if Skins.jelly_level(id) == level:
			names.append(Skins.display_name(id))
	return names


func _dry_up() -> void:
	slime.play_dry_up()
	if descent:
		# The run is over: half the pot is banked (Progress.end_descent), the summary card follows.
		if progress:
			progress.end_descent(false, dev_toggled, run_time)
		# i18n: result title, max 296px, 1 line
		_finish(false, Loc.t("result.dried_up_floor", "DRIED UP ON FLOOR {floor}", {floor = int(descent_run.get("floor", 1))}))
		return
	if progress and not is_random() and not training:
		progress.dry_ups[level] = int(progress.dry_ups.get(level, 0)) + 1
	# i18n: result title, max 296px, 1 line
	_finish(false, Loc.t("result.dried_up", "DRIED UP"))


## Freezes play and shows the result. When this is the running scene (not a test), records the
## result. After a dry-up it retries automatically (a story level again, or a freshly shuffled
## random maze); after a win it offers REPLAY or NEXT (see _offer_next_steps).
func _finish(did_win: bool, text: String) -> void:
	finished = true
	_close_run_map()  # (a glide that carries on after M can end the run: the result must not sit under the map)
	_end_coin_catches()
	won = did_win
	if did_win:
		survey_goal = true
		if _survey_live:
			_survey_enter(maze.goal)  # the goal is grabbed from just short of its cell
	_commit_survey()
	slime.frozen = true
	touch_controls.hide_controls()
	hud.result_slime_rect = _slime_screen_rect()  # (a re-fitted result panel covers or clears the slime)
	hud.show_message(text)
	level_finished.emit(did_win)
	if not _is_running_scene():
		return
	if not did_win:
		# The delay pauses with the game (false = not while paused), and the buttons are skipped
		# if the player has left for the menu meanwhile.
		await get_tree().create_timer(DESCENT_SUMMARY_DELAY if descent else DRY_CHOICE_DELAY, false).timeout
		if _is_running_scene() and not _leaving():
			_offer_retry()
		return
	if progress:
		if not is_random() and not descent and not training and no_credit():
			# An unassisted clear was already recorded with its payment (record_clear, finish).
			progress.complete_level(level, true, false)
	await get_tree().create_timer(CHOICE_DELAY, false).timeout
	if _is_running_scene() and not _leaving():
		_offer_next_steps()


## Dry-ups in one story level after which the dry-up row points at UPGRADES (when the coins are there).
const UPGRADE_HINT_DRY_UPS := 2


## The 2nd dry-up with the coins for the next MORE SLIME level in hand shows the UPGRADES hint first; RELAXED? waits for the 3rd.
func _upgrade_hint_first() -> bool:
	return int(progress.dry_ups.get(level, 0)) == UPGRADE_HINT_DRY_UPS and not progress.slime_upgrade_offer().is_empty()


## RELAXED? YES: RELAXED goes on for this level only (until you leave it or win; the SETTINGS toggle is the saved one)
## and the level restarts with the extra slime.
func accept_calm() -> void:
	progress.relaxed_level = level
	retry("relaxed")


## RELAXED? NO: the plain dry-up buttons, and no more asking about this level this session.
func decline_calm() -> void:
	progress.calm_declined[level] = true
	_offer_retry()


## The buttons shown after drying up: try again, or go spend coins on upgrades first (the
## upgrades screen's PLAY button comes back here).
func _offer_retry() -> void:
	# RESTART has the focus: one press of SPACE / Enter / R tries the same maze again.
	if descent:
		_show_descent_summary()  # a dry-up ends the run: its summary (NEW RUN / HUB)
		return
	if training:
		# RESTART only (no UPGRADES / MAP: the hub isn't introduced yet): the next attempt, full meter.
		hud.show_choices([[Loc.t("result.choice.restart", "RESTART"), retry]], 0)
		if training_line != "coin_use":  # (what coins buy may finish its hold over the row, up top)
			_training_line("")
		training_beat("dry")
		return
	if preview:
		hud.show_choices([[Loc.t("result.choice.continue", "CONTINUE"), leave_preview]], 0)
	elif is_random():
		# i18n: result choice buttons, max 62px each, 1 line (four share the row: 72 px buttons)
		hud.show_choices([[Loc.t("result.choice.restart", "RESTART"), retry], [Loc.t("result.choice.new_maze", "NEW MAZE"), play_next],
			[Loc.t("result.choice.upgrades", "UPGRADES"), go_to_upgrades], [Loc.t("result.choice.map", "MAP"), open_random_map]], 0)
	elif progress and progress.calm_offered(level) and not _upgrade_hint_first():
		# i18n: result choice buttons, max 62px each, 1 line (YES / NO answer the RELAXED question above them)
		hud.show_choices([[Loc.t("result.choice.yes", "YES"), accept_calm], [Loc.t("result.choice.no", "NO"), decline_calm]], 1)
		hud.show_rewards({calm_offer = true})
	elif progress and progress.assist_offered(level):
		# Three dry-ups here: the slime reserve is on offer (optional; RESTART stays the default).
		# i18n: result choice buttons, max 62px each, 1 line (four share the row: 72 px buttons)
		hud.show_choices([[Loc.t("result.choice.restart", "RESTART"), retry], [Loc.t("result.choice.assist", "ASSIST"), retry_assisted],
			[Loc.t("result.choice.upgrades", "UPGRADES"), go_to_upgrades], _map_choice()], 0)
		hud.show_rewards({assisted = false, offer = true})
	else:
		# The 2nd dry-up here with the coins for the next MORE SLIME level in hand: UPGRADES is the highlighted button
		# and a line says what it buys (IMP2-04; never a nag before that, never without the coins).
		var offer: Dictionary = progress.slime_upgrade_offer() if progress and int(progress.dry_ups.get(level, 0)) >= UPGRADE_HINT_DRY_UPS else {}
		hud.show_choices([[Loc.t("result.choice.restart", "RESTART"), retry], [Loc.t("result.choice.upgrades", "UPGRADES"), go_to_upgrades],
			_map_choice()], 1 if not offer.is_empty() else 0)
		if not offer.is_empty():
			hud.show_rewards({upgrade_hint = true, percent = offer.percent, cost = offer.cost})


## Whether this run feeds the random maze's map (Progress.random_map): a randomizer maze (not
## Descent, training or a test's loose game node).
func _random_map_live() -> bool:
	return progress != null and is_random() and not descent and not training and attempt_key != "" and _is_running_scene()


## The random maze's map while it's open (RandomMapView), else null.
var random_map_view: RandomMapView


## The random maze's map over the result row (the dry-up row's MAP; the run is already in it).
func open_random_map() -> void:
	if _leaving() or progress == null:
		return
	var survey: Dictionary = dev_full_map() if dev_bright else progress.random_map_for(attempt_key)
	if survey.is_empty():
		return
	_open_map_view(survey)


## Dev mode (the pause menu's DEV MAP): this maze's map now, any maze (story or random). With FULL BRIGHT
## on the whole maze and its goal (dev_full_map), else what this run and the maze's earlier tries saw.
func open_dev_map() -> void:
	if not dev_enabled() or _leaving() or random_map_view != null:
		return
	_open_map_view(dev_full_map() if dev_bright else _survey_so_far())


## This maze's map as far as this run (and, in a random maze, its earlier tries) has seen it.
func _survey_so_far() -> Dictionary:
	var survey := Survey.blank(maze)
	var before: Dictionary = progress.random_map_for(attempt_key) if is_random() else {}
	if not before.is_empty():
		Survey.merge_seen(survey, before.seen)
	Survey.merge_seen(survey, survey_tiles)
	survey.goal = survey_goal or before.get("goal", false)
	if survey.goal:
		Survey.mark_seen(survey, maze.goal * 2 + Vector2i.ONE)
	survey.moves = survey_moves.slice(0, Survey.MAX_MOVES)
	survey.tickets = ticket_cells()
	return survey


## Dev mode: a map of this whole maze, every tile seen and the goal (chalice / ticket) marked, with this
## run's route so far.
func dev_full_map() -> Dictionary:
	var survey := Survey.blank(maze)
	for y in maze.size.y:
		for x in maze.size.x:
			Survey.mark_seen(survey, Vector2i(x, y))
	survey.goal = true
	survey.moves = survey_moves.slice(0, Survey.MAX_MOVES)
	survey.tickets = ticket_cells()
	return survey


## Dev mode (the pause menu's DEV DRAIN): empties the meter, so the slime dries up as it would
## (a SECOND WIND or a backup bladder still steps in first). The run counts as dev-toggled.
func dev_drain() -> void:
	if not dev_enabled() or finished:
		return
	dev_toggled = true
	slime_remaining = 0.0
	_refresh_dev_badge()


func _open_map_view(survey: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	random_map_view = RandomMapView.new()
	layer.add_child(random_map_view)
	random_map_view.closed.connect(func() -> void:
		random_map_view = null
		layer.queue_free()
		var buttons: Array = hud.choice_buttons
		var focus := get_viewport().gui_get_focus_owner()
		if buttons.size() > 3 and is_instance_valid(buttons[3]) and not (focus in buttons):
			(buttons[3] as Button).grab_focus())  # (back on MAP, even when it was clicked)
	random_map_view.open(maze, survey, theme, progress.map_paper, progress.skin_color())
	DevLog.log_event(get_tree(), "random maze map opened", self)


## The dry-up row's MAP button (story levels only): opens the MAP TABLE on this level.
func _map_choice() -> Array:
	# i18n: result choice button, max 62px, 1 line (maps table shortcut; four share the row: 72 px buttons)
	return [Loc.t("result.choice.map", "MAP"), go_to_map]


## Opens the MAP TABLE at this level and mode (the run is already in its survey: _finish committed it).
func go_to_map() -> void:
	if _leaving() or not progress:
		return
	_commit_survey()
	DevLog.log_event(get_tree(), "to MAP TABLE", self)
	progress.hard_mode = hard_mode
	progress.current_level = level
	progress.return_to_game = true  # the table's BACK returns to this level
	UIKit.go(get_tree(), MAPS_SCENE)


## Tries again: the same story level or the same random maze (a new one is the NEW MAZE button).
func retry(via := "dry-up RESTART") -> void:
	if _leaving():  # a screen change is already underway (its wipe would race the reload)
		return
	DevLog.route(get_tree(), via, self)
	if progress:
		progress.keep_look_once = true  # (a retry of the same attempt keeps the look)
	if training:
		# After a dry-up: the next attempt (full meter, the coin kept). R / pause RESTART mid-run: the same
		# attempt again (attempt 1 keeps its low meter, so the staged dry-up isn't skipped).
		Training.mark_restart(finished and not won)
	get_tree().reload_current_scene()


## Tries again with the slime reserve: a bit more slime, but no medals, records or tickets.
func retry_assisted() -> void:
	if _leaving():
		return
	if progress and progress.accept_assist(level):
		DevLog.route(get_tree(), "ASSIST", self)
		progress.keep_look_once = true
		get_tree().reload_current_scene()
	else:
		retry()


func go_to_upgrades() -> void:
	if _leaving():  # e.g. clicked while QUIT TO HUB's wipe runs: the flag would stick
		return
	DevLog.log_event(get_tree(), "to UPGRADES", self)
	if progress:
		progress.return_to_game = true
	UIKit.go(get_tree(), UPGRADES_SCENE)


## BM-03: posts the win to the board of `kind` (the caller made sure the run counts: not RELAXED, assisted or dev), keeps the
## ghost and adds the BOARD place and the split against the ghost raced to the result text.
func _board_result(text: String, kind: String, ms: int) -> String:
	if not Economy.boards_on() or progress == null:
		return text
	var post: Dictionary = progress.post_board(kind, ms, progress.daily_run_day)
	share_extra = ""
	if post.rank > 0:
		# i18n: part of the share line COPY puts on the clipboard, plain ASCII; {place} = 1..5, the place on your local board
		share_extra = " " + Loc.t("result.share_board", "BOARD #{place}", {place = post.rank})
		# i18n: result line, max 296px, 1 line; {place} = 1..5, your place on today's / this week's board of your own times
		text = Loc.lines([text, Loc.t("result.board_place", "BOARD PLACE {place}", {place = post.rank})])
	if ghost != null:
		var split := ghost.finish(ms)
		if split != "":
			# i18n: result line, max 296px, 1 line; {split} = the time against your ghost, e.g. +1.2s (slower) or -0.8s (faster)
			text = Loc.lines([text, Loc.t("result.ghost_split", "VS GHOST {split}", {split = split})])
			# i18n: part of the share line COPY puts on the clipboard, plain ASCII; {split} = the time against your ghost, e.g. -0.8s
			share_extra += " " + Loc.t("result.share_ghost", "vs ghost {split}", {split = split})
	return text


## BM-03: the weekly's win (nothing is paid or counted): its board time, share line and ghost.
func _weekly_result(text: String) -> String:
	progress.mark_weekly_played(Boards.week_of(progress.daily_run_day))  # (even a RELAXED / assisted win: the sign stops saying NEW)
	if assisted or dev_toggled or relaxed_run:
		return text
	var ms := roundi(run_time * 1000.0)
	text = _board_result(text, "weekly", ms)
	var n := Boards.weekly_number(Boards.week_of(progress.daily_run_day))
	# i18n: result line, max 296px, 1 line; {n} = the weekly's number, {time} = this run's M:SS.cc
	text = Loc.lines([text, Loc.t("result.weekly", "WEEKLY #{n}  {time}", {n = n, time = UIKit.format_time(ms / 1000.0)})])
	# i18n: the line COPY puts on the clipboard to paste to friends, 1 line; keep the game's name; {n} = the weekly's number, {time} = M:SS.cc
	daily_share = Loc.t("result.weekly_share", "Dry Trying WEEKLY #{n} {time}", {n = n, time = UIKit.format_time(ms / 1000.0)}) + share_extra
	return text


## COPY on the daily result row: the share line goes on the clipboard from this very button press (the web needs a user
## gesture for it), and the button says COPIED.
func copy_daily_share() -> void:
	if daily_share == "":
		return
	DisplayServer.clipboard_set(daily_share)
	hud.show_share_line(daily_share, COPY_SHOW_TIME)  # (BEN3-11: the line stays readable even when a browser blocks the clipboard)
	var button: Button = hud.choice_buttons[0] if not hud.choice_buttons.is_empty() else null
	if button != null and is_instance_valid(button):
		button.text = Loc.t("result.choice.copied", "COPIED")  # i18n: result choice button after COPY was pressed, max 62px, 1 line
		_sfx("coin", -6.0)


## BOARDS on a daily / weekly result row: the page opens, BACK returns to the hub (the result row is not a place to come back to).
func open_boards() -> void:
	if _leaving():
		return
	(load("res://scripts/ui/boards_screen.gd") as GDScript).set("back_scene", HUB_SCENE)
	(load("res://scripts/hub.gd") as GDScript).set("return_to", "random")
	UIKit.go(get_tree(), "res://scenes/boards.tscn")


## The buttons shown after a win.
func _offer_next_steps() -> void:
	# The middle button (carry on) has the focus, so SPACE / Enter just keeps going.
	if descent:
		_open_boon_card()
		return
	if training:
		hud.show_choices([[Loc.t("result.choice.hub", "HUB"), _training_to_hub]], 0)
		_training_line("")
		training_beat("chalice")
		return
	if preview:
		hud.show_choices([[Loc.t("result.choice.continue", "CONTINUE"), leave_preview]], 0)
	elif is_random() and daily_share != "":
		# A recorded daily / weekly win: COPY first (it is pressed by the player, which a browser needs to allow the clipboard), then
		# REPLAY, BOARDS (IMP3-03: the top times) and HUB; the NEW MAZE button makes room (the portal is a step from the hub).
		# i18n: result choice buttons, max 62px each, 1 line (four share the row: 72 px buttons)
		var row := [[Loc.t("result.choice.copy", "COPY"), copy_daily_share], [Loc.t("result.choice.replay", "REPLAY"), replay]]
		if Economy.boards_on():
			# i18n: result choice button on a daily / weekly win, max 62px, 1 line; opens the BOARDS page (your best times)
			row.append([Loc.t("result.choice.boards", "BOARDS"), open_boards])
		else:
			row.append([Loc.t("result.choice.new_maze", "NEW MAZE"), play_next])
		row.append([Loc.t("result.choice.hub", "HUB"), go_to_hub])
		hud.show_choices(row, 1)
	elif is_random():
		# i18n: result choice buttons, max 76px each, grows to 88px (tab_widths: the three alike), 1 line
		hud.show_choices([[Loc.t("result.choice.replay_maze", "REPLAY MAZE"), replay], [Loc.t("result.choice.new_maze", "NEW MAZE"), play_next],
			[Loc.t("result.choice.hub", "HUB"), go_to_hub]], 1)
	elif Demo.on() and level >= Demo.last_level(hard_mode) and progress and not progress.has_seen_story(Demo.END_SEEN_BIT):
		# The demo's last level, the first time: CONTINUE only, into the end screen (every finisher sees it).
		hud.show_choices([[Loc.t("result.choice.continue", "CONTINUE"), play_next]], 0)
	elif level >= Levels.COUNT or (Demo.on() and level >= Demo.last_level(hard_mode)):
		hud.show_choices([[Loc.t("result.choice.replay", "REPLAY"), replay], [Loc.t("result.choice.continue", "CONTINUE"), play_next],
			[Loc.t("result.choice.hub", "HUB"), go_to_hub]], 1)
	else:
		hud.show_choices([[Loc.t("result.choice.replay", "REPLAY"), replay], [Loc.t("result.choice.next_level", "NEXT LEVEL"), play_next],
			[Loc.t("result.choice.hub", "HUB"), go_to_hub]], 1)


## The preview's card over its first frame: what this maze is, then PLAY (the run waits under it).
func _show_preview_card() -> void:
	progress.preview_card_shown = true
	preview_card_up = true
	slime.frozen = true
	_card_touch = touch_controls.visible
	touch_controls.hide_controls()
	# i18n: the demo's preview card (its last maze), max 296px each line, 1 line each
	hud.show_message(Loc.lines([Loc.t("preview.title", "FULL GAME PREVIEW"),
		Loc.t("preview.abilities", "EVERY ABILITY UNLOCKED"),
		Loc.t("preview.look", "A RANDOM LOOK FROM THE FULL GAME")]))
	hud.show_choices([[Loc.t("preview.play", "PLAY"), _close_preview_card]], 0)  # i18n: button, max 76px


var _card_touch := false


func _close_preview_card() -> void:
	if not preview_card_up or _leaving():
		return
	preview_card_up = false
	hud.clear_result()
	slime.frozen = false
	touch_controls.visible = _card_touch
	hud.show_area_name(Themes.display_name(theme), Loc.t("hud.area.preview", "FULL GAME PREVIEW"))


## The preview is over (its CONTINUE): the randomizer's end screen (DemoEnd puts the save's own state back).
func leave_preview() -> void:
	if _leaving():
		return
	DevLog.route(get_tree(), "CONTINUE (demo preview end)", self)
	load(DEMO_END_SCRIPT).open(get_tree(), "random")


## Where the pause menu's QUIT goes from the preview: the randomizer's end screen (its reason set here).
func preview_exit() -> String:
	var end: GDScript = load(DEMO_END_SCRIPT)
	end.set("from", "random")
	return end.get("SCENE")  # i18n: ignore (a constant's name)


## Back to the hub, in front of the station this run came from (the archway or the portal).
func go_to_hub() -> void:
	if _leaving():
		return
	DevLog.log_event(get_tree(), "quit to hub (after win/dry-up)", self)
	(load("res://scripts/hub.gd") as GDScript).set("return_to", "random" if is_random() or descent else "story")
	UIKit.go(get_tree(), HUB_SCENE)


## Plays this same maze again (for a random maze, the same seed).
func replay(via := "REPLAY MAZE") -> void:
	if _leaving():
		return
	DevLog.route(get_tree(), via, self)
	if progress:
		progress.keep_look_once = via == "R"  # (R = the same attempt again; REPLAY MAZE on a result rolls anew)
	if progress and not is_random():
		progress.start_story(level)
	get_tree().reload_current_scene()


## Moves on: the next story level, a new random maze, or the victory screen after the last level.
func play_next() -> void:
	if _leaving():
		return
	if is_random():
		if Demo.on() and won and progress and progress.randoms_won >= Demo.RANDOM_WINS \
				and not progress.has_seen_story(Demo.RANDOM_END_SEEN_BIT):
			# The demo's RANDOM_WINS-th randomizer win (or the first NEW MAZE after it, if the player left by
			# HUB / REPLAY on that win): the end screen's pitch (endless mazes), once.
			if progress.demo_preview_due():
				# First the FULL GAME PREVIEW maze (Demo.PREVIEW); its CONTINUE opens the end screen.
				DevLog.route(get_tree(), "NEW MAZE (demo preview)", self)
				progress.begin_demo_preview()
				get_tree().reload_current_scene()
				return
			DevLog.route(get_tree(), "NEW MAZE (demo end)", self)
			load(DEMO_END_SCRIPT).open(get_tree(), "random")
			return
		if progress:
			progress.new_random_maze()
		DevLog.route(get_tree(), "NEW MAZE", self)
		get_tree().reload_current_scene()
	elif Demo.on() and level >= Demo.last_level(hard_mode):
		DevLog.route(get_tree(), "CONTINUE (demo end)", self)
		load(DEMO_END_SCRIPT).open(get_tree(), "story")
	elif level >= Levels.COUNT:
		if progress and not progress.dev_tools and not progress.has_seen_story(progress.STORY_FINALE):
			Story.play(get_tree(), "finale", VICTORY_SCENE)
		else:
			UIKit.go(get_tree(), VICTORY_SCENE)
	else:
		if progress:
			progress.start_story(level + 1)
		get_tree().reload_current_scene()


func _is_running_scene() -> bool:
	return is_inside_tree() and get_tree().current_scene == self


## True while a screen change is underway (e.g. quitting to the title from the pause menu).
func _leaving() -> bool:
	var transition := get_node_or_null("/root/Transition")
	return transition != null and transition.busy


## The app lost focus or went to the background (PlatformEvents): a run in progress opens its pause menu, so
## the run clock stops (it only ticks while the tree runs) and coming back waits for
## RESUME. Nothing happens over a result, a menu already open or a screen change. True if it paused.
func pause_for_background() -> bool:
	if not _is_running_scene() or _leaving() or finished or get_tree().paused:
		return false
	_close_run_map()  # (its focus lock would leave the pause menu without focus, under the map)
	pause_menu.open()
	DevLog.log_event(get_tree(), "pause (app in the background)", self)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _is_running_scene() or _leaving():
		return
	if dev_key_pressed(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		pause_menu.open()
		DevLog.log_event(get_tree(), "pause opened", self)
	elif event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		if descent:
			return  # a floor can't be restarted (the meter carries over); the run ends by dry-up or CASH OUT
		if training:
			if finished and not won:
				retry("R")
			elif not finished:
				restart_prompt.open(false)  # RESTART / CANCEL (no UPGRADES in training)
			return  # (after the chalice: the HUB button is the way on)
		if won:
			replay("R")
		elif finished:
			retry("R")  # the dry-up buttons already offer the upgrades
		elif not Economy.r_always_restarts() and progress and not hard_mode and progress.coins() > 0 and (not Demo.on() or progress.upgrade_buyable()):
			restart_prompt.open()  # coins in hand: restart, or spend them on upgrades first
			DevLog.log_event(get_tree(), "R prompt opened", self)
		else:
			retry("R")  # R always restarts at once (Economy.R_ALWAYS_RESTARTS); spending is on the dry-up screen


# ---------------------------------------------------------------- dev toggles

## Dev mode only (--unlock-all): F1 = FULL BRIGHT, F2 = NO DRAIN (also buttons in the pause menu).
## Function keys: never one of the default controls, F11 (fullscreen) or Esc / P (pause).
const DEV_BRIGHT_KEY := KEY_F1
const DEV_DRAIN_KEY := KEY_F2


## True in dev mode (Progress.dev_tools, from --unlock-all): only then do the dev toggles exist.
func dev_enabled() -> bool:
	return progress != null and progress.dev_tools


## Handles F1 / F2 in dev mode (true if the event was one of them). A key that is also bound to a
## control (someone remapped one onto it) is left to that control.
func dev_key_pressed(event: InputEvent) -> bool:
	if not dev_enabled() or not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	var key: Key = (event as InputEventKey).keycode
	if key != DEV_BRIGHT_KEY and key != DEV_DRAIN_KEY:
		return false
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and event.is_action(action, true):
			return false
	if key == DEV_BRIGHT_KEY:
		set_dev_bright(not dev_bright)
	else:
		set_dev_no_drain(not dev_no_drain)
	return true


## FULL BRIGHT (dev only): hides the fog layers and the HUD vignette and shows the goal (chalice or
## ticket), so the whole maze is seen at full brightness. Nothing underneath changes: the fog bytes,
## reveal and fade carry on as usual, and switching it off shows exactly the normal fog again (the
## goal goes back to whether it had really been seen meanwhile).
func set_dev_bright(on: bool) -> void:
	if not dev_enabled() or on == dev_bright:
		return
	dev_bright = on
	progress.dev_bright = on
	if on:
		dev_toggled = true
		if goal and not finished:
			_bright_shown[goal] = goal.visible
			goal.visible = true
	else:
		for node: Variant in _bright_shown:
			if is_instance_valid(node):
				(node as CanvasItem).visible = _bright_shown[node]
		_bright_shown.clear()
	fog_sprite.visible = not on
	if outer_fog:
		outer_fog.visible = not on
	hud.set_vignette(not on)
	_refresh_dev_badge()


## NO DRAIN (dev only): gliding and leaping cost no slime while it is on (so the slime never dries
## up); switched off, the meter drains on from where it is.
func set_dev_no_drain(on: bool) -> void:
	if not dev_enabled() or on == dev_no_drain:
		return
	dev_no_drain = on
	progress.dev_no_drain = on
	if on:
		dev_toggled = true
	_refresh_dev_badge()


## PASTEL (dev only, Progress.pastel): the slime wears the pastel version of its skin, where it has
## one (Skins.has_pastel). Looks only (the trail keeps this run's color), so the run still counts.
func set_dev_pastel(on: bool) -> void:
	if not dev_enabled() or on == Skins.pastel or (on and not Skins.has_pastel(progress.active_skin())):
		return
	progress.set_pastel(on)
	skin_color = progress.skin_color()
	slime.apply_skin(skin_color, rainbow, stopwatch)


func _refresh_dev_badge() -> void:
	var tags: Array[String] = []
	if dev_bright:
		tags.append("BRIGHT")
	if dev_no_drain:
		tags.append("NO DRAIN")
	hud.set_dev_badge(" ".join(tags))
	_refresh_attempt_pod()  # a dev-toggled run pays nothing


## Whether the goal has really been seen (FULL BRIGHT only shows it for the moment).
func _shown(node: CanvasItem) -> bool:
	return _bright_shown.get(node, node.visible)


func _show(node: CanvasItem) -> void:
	if _bright_shown.has(node):
		_bright_shown[node] = true
	node.visible = true


func _sfx(sound_name: String, volume_db := 0.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.play(sound_name, volume_db)
