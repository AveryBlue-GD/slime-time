extends Node

## Autoload "Progress": levels cleared/unlocked, the chosen skin, key bindings, and which
## mode the game scene should start in. Saved to user://save.cfg.
## Debug (after `--` on the command line, never saved): `--level=N` starts on level N,
## `--unlock-all` unlocks every level, skin and hat, `--story-complete` starts as a player who beat the story on normal and hard with every coin (see enable_story_complete), `--skin=ID` picks a skin, `--random` plays randomizer mazes, `--demo-preview` (with `--demo`) starts the demo's FULL GAME PREVIEW maze (open scenes/main.tscn), `--descent` (or `--descent=SEED`) starts a Descent run (in memory, like every run), `--hard` turns on hard mode, `--touch` shows touch controls, `--hat=ID` wears a hat, `--dye=ID` gives every dyeable hat that dye (e.g. rainbow), `--tickets=N` sets the ticket balance, `--jelly` tries the see-through slime (only demo_coin_catch reads it), `--upgrades=a,b,c` / `--coins=N` set upgrade levels (MORE SLIME 0-7, SPEED 0-4, BRIGHTNESS 0-3) and coins (for promo shots), `--workshop=w,c,s,m,n` sets the ticket workshop's levels (0-3), `--abilities=r,s,k` sets the ticket abilities' levels (SLIME RIFLE, SLIME SPLAT, SLIMAKAZE, 0-3), `--trail=ID` / `--paper=ID` own and wear a trail style / map paper, `--softbounce` tries the soft wall bounce (Economy.SOFT_BOUNCE_TEST), `--coincatch` forces the coin catch on (now the default), `--nocoincatch` the old instant pickup (Economy.COIN_CATCH_TEST), `--pastel` wears the PASTEL version of the skin (Progress.pastel), `--nocoinreveal` turns off the dev map coin reveal (Economy.MAP_COIN_REVEAL_TEST: revealed uncollected coins on the maps, dev only), `--languages` turns on the translations test (Economy.LANGUAGES_TEST: the saved language or the OS locale), `--lang=xx` also forces locale xx for this run, over the saved language (never saved; `--lang=pseudo` = pseudo-localization), `--tutorial` plays the first-session tutorial test (Economy.TUTORIAL_TEST, docs/tutorial/design.md) on a clean in-memory fresh save: the launch intro, then the SPLASHDOWN training maze, then the hub tour (the real save is never read or written; see enable_tutorial_test), `--tutorial=maze` starts in the training maze and `--tutorial=hub` in the hub tour, `--quiet-window` (from tools/play.ps1) cleans up after a no-focus start, `--save-path=user://x.cfg` saves to that file. Any debug flag, test, headless or movie run saves to a per-process throwaway file, never user://save.cfg. All of these work only in debug builds (the editor binary): an exported release build ignores every flag but `--touch` and `--web-ui` (see game_args).

const MODE_STORY := "story"
const MODE_RANDOM := "random"
const MODE_DESCENT := "descent"
## The SPLASHDOWN training maze (Economy.TUTORIAL_TEST; docs/tutorial/design.md): set by
## prepare_training / start_training, cleared by finish_training. Never saved.
const MODE_TRAINING := "training"
const TUTORIAL_MOVE := 1
const TUTORIAL_LEAP := 2
## Tutorial test bits (written only while Economy.tutorial_on(), so a save made with the gate off never
## holds them): the training maze was finished or skipped, and the hub tour was finished or skipped.
const TUTORIAL_TRAINING := 4
const TUTORIAL_HUB := 8
## 16, 32, 64, 128: the ability tutorial's lines were shown (AbilityCoach.BITS).

## Remappable actions and their default (primary) keys. Movement also keeps the arrow keys
## as fixed secondary keys, so the game stays playable whatever gets remapped.
const DEFAULT_KEYS := {
	move_up = KEY_W, move_down = KEY_S, move_left = KEY_A, move_right = KEY_D,
	jump = KEY_SPACE, restart = KEY_R, interact = KEY_F,
	ability_rifle = KEY_1, ability_splat = KEY_2, ability_kaze = KEY_3, ability_sense = KEY_M,
}
## Keys an ability action (Abilities v1) takes when a save from before them already uses its default
## for another action (first free one), so an older custom binding is never reset.
const ABILITY_SPARE_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0,
	KEY_Q, KEY_E, KEY_C, KEY_Z, KEY_X, KEY_V, KEY_G, KEY_T]
const SECONDARY_KEYS := {move_up = KEY_UP, move_down = KEY_DOWN, move_left = KEY_LEFT, move_right = KEY_RIGHT}
## Keys no remappable action can take, so one key never does two things: the arrows (movement's fixed
## SECONDARY_KEYS) and F11 (toggle_fullscreen). Esc and P (pause) are refused by the CONTROLS page.
const RESERVED_KEYS: Array[int] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_F11]
## Actions the CONTROLS page doesn't list (SLIME SENSE stays on M): their key is never swapped away,
## since the player couldn't see or undo the move.
const UNLISTED_ACTIONS: Array[String] = ["ability_sense"]

## The player's save. user:// is the RELEASE user data dir (project.godot application/config/
## custom_user_dir_name, e.g. ~/Library/Application Support/SlimeTime_R1 on macOS, /userfs/SlimeTime_R1
## in a browser), so saves from builds before the public release (in the old "Slime Time" app_userdata
## dir) are never read. See docs/itch-release.md "Fresh-start policy".
const REAL_SAVE_PATH := "user://save.cfg"
## Throwaway saves are this + the process id + ".cfg" (deleted on start and on quit).
const THROWAWAY_PREFIX := "user://test_save_run_"
## Where progress is saved. Only a normal launch uses the real save; tests, demo scenes, headless,
## movie/screenshot and dev runs get a per-process throwaway file (see _default_save_path), and
## `--save-path=user://x.cfg` picks one explicitly.
var save_path := _default_save_path()
## The release epoch: written to every save and code as [meta] epoch, and required when one is read.
## A save or code from another epoch (or with none: every build before the public release) is never
## loaded. Bump it together with custom_user_dir_name ("SlimeTime_R<epoch>") and SAVE_CODE_PREFIX
## ("SLIME<epoch + 1>-") to wipe everyone's progress again (docs/itch-release.md).
const RELEASE_EPOCH := 1
## Save codes start with this. "SLIME1-" codes come from builds before the public release and are
## refused with "FROM AN OLD VERSION" (is_old_code).
const SAVE_CODE_PREFIX := "SLIME2-"
## The allow-list checker every untrusted save text (save.cfg, pasted codes) goes through first.
const SaveText := preload("res://scripts/save_text.gd")
## The stopwatch skin's "notice seen" mark in skin_notices_seen (level numbers are 1-10).
const STOPWATCH_NOTICE := 200
## Highest level the player may start (1-10).
var highest_unlocked := 1
## Number of story levels beaten so far (0-10). Also decides which skins are unlocked.
var levels_cleared := 0
## Bit set of wordless hints already used (TUTORIAL_MOVE / TUTORIAL_LEAP, and with the tutorial test on
## TUTORIAL_TRAINING / TUTORIAL_HUB); saved, optional key.
var tutorial_seen := 0
## Tutorial test session state (never saved). `training_replay`: the current training run is the
## SETTINGS replay (writes nothing). `training_used`: TUTORIAL_MOVE / TUTORIAL_LEAP the player really used
## in this training run (note_training_input), merged into tutorial_seen by finish_training.
## `tour_replay`: the hub tour after a replayed training is due (hub_tour_due) until finish_hub_tour.
## `training_skipped`: the last training run ended through SKIP TRAINING. `training_coin`: that run had
## picked up the practice coin (game.gd leave_training; the hub tour's coin bag line). `tutorial_launch`: what
## `--tutorial[=maze|hub]` asked for ("intro", "maze", "hub"; "" = no flag), read once by the boot title
## (take_tutorial_launch).
var training_replay := false
var training_used := 0
var tour_replay := false
var training_skipped := false
var training_coin := false
var tutorial_launch := ""
## Story beats shown (bits STORY_INTRO / STORY_FINALE). Optional in saves; RESET PROGRESS clears it.
var story_seen := 0
const STORY_INTRO := 1
const STORY_FINALE := 2
## 4 is taken by the demo: its end screen was seen (Demo.END_SEEN_BIT; the full game ignores it).
const STORY_DEMO_END := 4
## 8 too: the demo's randomizer end screen was seen (Demo.RANDOM_END_SEEN_BIT).
const STORY_DEMO_RANDOM_END := 8
## 16 too: the demo's FULL GAME PREVIEW maze was started (Demo.PREVIEW_SEEN_BIT).
const STORY_DEMO_PREVIEW := 16
## 32: the preview's ability tutorial has played (AbilityCoach: later preview runs are just the maze).
const STORY_DEMO_PREVIEW_COACHED := 32
## Dry-ups per story level since it was last cleared (not saved); drives the mercy assist.
var dry_ups := {}
## Story level the game scene loads next.
var current_level := 1

## Save layout version, written to [meta]. 3 = ticket vouchers (under the old [wallet] globs keys) +
## medal tiers; 4 = the redesigned story layouts (docs/level-design.md); 5 = the bigger hard-mode mazes
## (HARD_SLIME_MULT rebalance, docs/level-design.md section 7). Every save of the public release
## (RELEASE_EPOCH 1) is version 5 or later and saves/codes without the epoch are never loaded, so the
## pre-v5 migrations were removed in spring cleaning (2026-10-15).
## 6 = the upgrades v2 coin tree (docs/design/upgrades-v2.md A2.4): [upgrades] tree = 2 marks levels of
## the new per-track tables; a save without it holds old 10-level tracks, remapped by coins invested
## (see _migrate_tree; keyed on the tree mark, not the version, so it is idempotent on its own);
## tree = 3 marks the repriced tree (MORE SLIME 80 / SPEED 46 / BRIGHTNESS 39): tree 2 levels are
## repriced on load (_migrate_prices), no save version bump needed. Both can still run for a real
## player: release-epoch saves were written by builds with tree 1 and tree 2.
const SAVE_VERSION := 6
## TICKET VOUCHERS: the renewable, cosmetic-and-utility currency (never converted to or from coins).
## The ONLY faucet is the randomizer, whose goal IS a ticket: a win pays by how many attempts that
## maze took (RANDOM_ATTEMPT_PAY: first try 10, then 8, 6, 4, 2, and 1 from the sixth on); only
## while Economy.RANDOM_DAILY_CAP is on, at most 5 paying wins per UTC day. A player with no MORE SLIME upgrade bought, and a
## typed or replayed seed, get at most 1 per win. Sinks (upgrades v2 batch 2): the hat wheel (free,
## then 12, +2 per spin taken, up to 40), hat DYES (10 each, RAINBOW 99; hats are never sold), the WORKSHOP
## (ticket utility upgrades) and cosmetics (trail styles, map papers). All numbers: Economy.
## (Saved under the old [wallet] keys "globs" and "globs_lifetime" so existing saves still load.)
const TICKETS_MAX := 99999
## Tickets a randomizer win pays on attempt 1, 2, 3 ... of that maze; later attempts pay the last.
const RANDOM_ATTEMPT_PAY: Array[int] = Economy.RANDOM_ATTEMPT_PAY
## Payout cap for a player who has bought no MORE SLIME upgrade ("excess slime"), and for a typed or
## replayed seed (a memorized seed can't be farmed).
const TICKETS_NO_SLIME_CAP := Economy.TICKETS_NO_SLIME_CAP
const TICKETS_REPLAY_CAP := Economy.TICKETS_REPLAY_CAP
## Randomizer wins that pay tickets per UTC day.
const RANDOM_PAID_PER_DAY := Economy.RANDOM_PAID_PER_DAY
const PAID_SEEDS_MAX := 10
## Hat wheel price: the first spin is free, the second costs SPIN_COST, each later one SPIN_STEP more
## (spins already taken beyond the second), never above SPIN_COST_MAX.
const SPIN_COST := Economy.SPIN_COST
const SPIN_STEP := Economy.SPIN_STEP
const SPIN_COST_MAX := Economy.SPIN_COST_MAX
const RAINBOW_PITY_MAX := 40
## Spins kept when a save is read (a hostile save can't push the price math anywhere odd).
const SPINS_MAX := 100000
## Level medals: the best clear-time tier per level and mode (a small int, saved under [medals]).
## Gold (3) = at or under the level's par time, silver (2) = within SILVER_FACTOR x par, bronze (1)
## = any unassisted clear. Hard mode keeps its own tiers (same thresholds) that don't count toward
## all_medals().
const TIER_NONE := 0
const TIER_BRONZE := 1
const TIER_SILVER := 2
const TIER_GOLD := 3
const GOLD_FACTOR := 1.0
const SILVER_FACTOR := 1.3
## Slime reserve (ASSIST): after this many dry-ups on one level in a session, the next attempt
## can be played with a bit more slime (never on hard mode; no medals, records or tickets).
const ASSIST_AFTER := 3
const ASSIST_BONUS := 0.10
var tickets := 0
var tickets_lifetime := 0
## Best medal tier per level (hard mode's under level + HARD_RECORDS): key -> 1..3.
var medals := {}
## Hat wheel: spins made in all, and spins since the rainbow hat was last rolled (pity).
var spins := 0
var rainbow_pity := 0
## The wheel's own seed: each spin's roll comes from it and `spins` (wheel_roll), so loading a save
## code from before a spin and spinning again lands the same hat; re-rolling is never free. 0 = not
## picked yet (SaveFile.write picks one).
var wheel_seed := 0
## UTC day number and how many randomizer wins were paid on it.
var random_pay_day := 0
var random_paid := 0
## Seeds that paid a randomizer win on random_pay_day (newest last, at most PAID_SEEDS_MAX): the
## same seed pays nothing again that day.
var random_paid_seeds: Array[int] = []
## Not saved: false once the current seed was typed in or already won (replayed), which pays at most
## TICKETS_REPLAY_CAP. NEW MAZE makes it true again.
var random_seed_fresh := true
## Not saved: attempts (starts, incl. dry-up retries and restarts) per randomizer maze this session,
## keyed by random_attempt_key (the seed code). NEW MAZE clears it.
var random_attempts := {}
## Not saved: the tickets the attempt pod last showed for each maze (same keys as random_attempts), so
## a restart that changes the number can make the pod pop. Cleared with random_attempts.
var random_offer_shown := {}
## Not saved: the ticket pickups (TicketPickup cells) taken in each randomizer maze (same keys as
## random_attempts), so its retries don't put them out again. Cleared with random_attempts.
var random_tickets_taken := {}
## Not saved: the level whose next attempt was chosen to be played with the slime reserve.
var assist_level := 0
## Tests set a day number here instead of reading the clock (-1 = use the clock).
var day_override := -1
## DESCENT (upgrades v2 batch 3, Descent): the run being played (Descent.new_run; in memory, with a copy
## at each floor start / cleared floor saved for a relaunch: descent_resume), the deepest floor ever reached and the run
## time it took (saved [descent] best_floor / best_time), runs banked in all, the UTC day and how many
## runs were paid on it (forward-only like the randomizer's), and the milestone floors already paid
## (bitmask, Descent.milestone_bit).
var descent_run := {}
## DESCENT resume (owner decision D6, docs/spring-cleaning/phase5-platform.md "Descent resume"): the run as it
## stood at the start of its current floor, or right after clearing it (on the boon card), saved as
## [descent_run] so a phone that kills the app (or a closed window) brings the run back on relaunch: the hub
## offers RESUME (that floor's start, or its boon card) or QUIT RUN (banked like quitting from the pause menu
## today: half the pot mid-floor, the whole pot on the boon card). {} = no run saved. Cleared when the run banks
## (CASH OUT, dry-up, quit), so a run can never bank twice; the maze and the boon offers come from the run seed,
## so resuming can never reroll them. Never in a save code (codes copy progress to other devices).
## One resume per floor (owner decision D9): RESUME of a mid-floor snapshot counts it (`resumes`, saved at once);
## once a floor has been resumed DESCENT_RESUMES_PER_FLOOR times, a further kill / closed window / reloaded tab on
## that floor leaves only QUIT RUN (banks half, as a dry-up does). Clearing the floor starts the count over.
var descent_resume := {}
const DESCENT_RESUMES_PER_FLOOR := 1
## The keys of a saved run ([descent_run]); `format` guards the layout (another format is dropped, not read).
const DESCENT_RUN_FORMAT := 1
const DESCENT_RESUME_KEYS := ["seed", "floor", "meter", "boons", "bladders", "pot", "time", "wind_used", "slot",
	"cleared", "bonuses", "new_best", "best_before", "resumes"]
var descent_best_floor := 0
var descent_best_time := 0.0
var descent_runs := 0
var descent_pay_day := 0
var descent_paid := 0
var descent_milestones := 0

var selected_skin := Skins.DEFAULT
## The hat the slime wears (Hats.NONE for none).
var selected_hat := Hats.NONE
## Hats won on the hat wheel (saved): they're off the wheel and can be worn.
var hats_owned: Array[String] = []
## Hats bought from the TAILOR ([hats] bought; stats only; the TAILOR is gone (hats are never sold),
## old saves keep their count).
var hats_bought := 0
## Hat dyes bought in the SHOP ([hats] dyes: "hat:dye" each, Hats.dyes_for), and the dye each hat
## is worn in ([hats] dyes_worn, the same form; a hat not in it wears its own color).
var hat_dyes_owned: Array[String] = []
var hat_dyes := {}
## Tickets spent in all ([wallet] tickets_spent; for stats and sanity checks).
var tickets_spent := 0
## The ticket WORKSHOP's levels by id (Workshop; [workshop], 0-3 each; off in hard mode).
var workshop := {}
## ABILITIES v1: the ticket abilities' levels by id (Abilities; [abilities], 0-3 each; off in hard mode).
var abilities := {}
## Cosmetics bought with tickets (Cosmetics ids; [cosmetics] owned) and the ones worn: a trail
## style and a map paper (Cosmetics.DEFAULT_TRAIL / DEFAULT_PAPER when none is).
var cosmetics_owned: Array[String] = []
## The prize wheel's look: "odds" (rarity and chance only, the prize shown once it stops; owner
## 2026-10-22), or with the debug flag --wheel-style=rewards each prize on its wedge (the comparison).
var wheel_style := "odds"
var trail_style := Cosmetics.DEFAULT_TRAIL
var map_paper := Cosmetics.DEFAULT_PAPER
## Coins picked up in the story levels: level -> Array of coin keys ("x,y" cells). Each coin can
## only be collected once; they're saved the moment they're grabbed.
var coins_found := {}
## Upgrade levels bought with coins: id -> level (see Upgrades).
var upgrades := {}
## Coins the upgrades v2 migration put back in hand (Upgrades.migrate_level), until the hub has shown
## its one-time UPGRADES REWORKED notice (take_tree_refund_notice). Saved as [upgrades] refund_notice.
var tree_refund_notice := 0
## Set when the upgrades screen was opened from a dry-up: its back button then says PLAY and
## returns to the level (not saved).
var return_to_game := false
## Jelly: every slime is see-through and collected coins sink in and dissolve. Off (the default) =
## the opaque normal-mode skins; the jelly versions are the hard-mode reward (saved; skins screen
## toggle; D14).
var jelly := false
## Pastel: the worn skin in its soft pastel version (Skins.pastel; unlocked by randomizer wins,
## Skins.pastel_wins). Only ever on with a skin that has one (Skins.has_pastel). Saved; skins screen toggle.
var pastel := false
## Dev mode (--unlock-all): dev-only upgrades (wall power) show up and there are plenty of coins.
var dev_tools := false
## Dev toggles (Game.set_dev_bright / set_dev_no_drain; F1 / F2 in a level): kept for the session so
## they survive restarts, never saved.
var dev_bright := false
var dev_no_drain := false
const DEV_COINS := 999
## Spending coins dev mode adds (0 when --coins sets an exact amount).
var dev_coins := DEV_COINS
## --all-coins: every coin counts as found, wherever it is.
var all_coins_debug := false
var custom_color := Color8(239, 125, 47)
## The hub's color ([skin] hub, owner 2026-10-21): "" = AUTO (the worn skin's), else a skin id whose
## look (opaque) the room and stations take; `hub_custom` = the custom color it was set to (the
## wardrobe gives the wheel a fresh color each visit). Only once normal mode is beaten (hub_color_open).
var hub_skin := ""
var hub_custom := Color8(239, 125, 47)
var sound_on := true
## Sound-effects volume, 0-1 (the SFX audio bus: Sfx and the level ambience; saved as `volume`, which
## was the master volume before music) and music volume, 0-1 (the Music bus: the Music autoload).
## Settings has a slider for each (UIKit.make_volume_slider); the Master bus stays at 0 dB.
var volume := 0.8
var music_volume := 0.8
const SFX_BUS := "SFX"  # i18n: ignore (an audio bus name)
const MUSIC_BUS := "Music"  # i18n: ignore (an audio bus name)
## Reduce motion: no screen shake, camera kick or hit-stop (see Game.motion_scale).
var reduce_motion := false
## Phones buzz on a splat (Slime._buzz); SETTINGS VIBRATION (Platform.has_vibration) turns it off.
var vibration := true
## Desktop: the window was fullscreen when last toggled (saved [settings] fullscreen, only written when on;
## applied at launch on a normal player launch, Platform.remembers_fullscreen). Kept by RESET PROGRESS.
var fullscreen := false
## The language the player picked in the LANGUAGE screen (a locale code, "" = never picked; i18n, D15).
## Read from [settings] language whatever the gate; written back only when not empty, so a save that never
## had one stays byte-identical. Never in save codes (a device preference): a loaded code keeps it. Set
## only by Language.pick; kept by RESET PROGRESS.
var language := ""
## Fog brightness: FOG_DARK, FOG_NORMAL (the default look) or FOG_BRIGHT (see Game.fog_look).
const FOG_DARK := 0
const FOG_NORMAL := 1
const FOG_BRIGHT := 2
var fog_brightness := FOG_NORMAL
## Hard mode: explored areas that fully dim are swallowed by fog again (no faint memory).
var hard_mode := false
## Record (fastest) clear time per story level, in seconds.
var best_times := {}
## Levels whose "first run: playing as ..." notice has already been shown.
var skin_notices_seen: Array[int] = []
## Levels beaten on hard mode (each unlocks the solid version of that level's skin).
var hard_cleared: Array[int] = []
## action -> physical keycode of its primary key.
var bindings := DEFAULT_KEYS.duplicate()

## Not saved: what "play" means right now.
var mode := MODE_STORY
var random_seed := 1
## Not saved: the MORE SLIME level the current seed's maze is built for (part of its seed code),
## or -1 until the maze is built, which then takes the player's own level.
var random_level := -1
var randoms_cleared := 0
## Randomizer mazes beaten in total (saved).
var randoms_won := 0
## Set by debug flags so a test session never overwrites the real save.
var saving_enabled := true
## The demo (Demo.on) was given a save it didn't write (no [meta] demo marker: a full-game save, or a full
## game's code): it plays it in memory and never writes it, so a player who owns both never loses
## full-game progress to the demo (docs/demo-plan.md "Save carry-over"). Not saved.
var demo_guard := false
## Debug (--touch): show the on-screen touch controls even without a touchscreen.
var force_touch := false
## Trail map surveys (see Survey; shown at the hub's MAP TABLE): story level key (level, + HARD_RECORDS
## on hard mode) -> survey. Recorded by real, unassisted, non-dev story runs (game.gd); saved under
## [maps] (optional: older saves have none); RESET PROGRESS clears them.
var maps := {}
## The map table's first-time hint was shown (saved as [maps] hint_seen).
var maps_hint_seen := false
## Debug flag: every story level (normal + hard) starts fully surveyed (Survey.full; not saved).
const MAPS_FULL_FLAG := "--maps=full"
## Not saved: a skin the current level forces (its first run is played in the newest skin earned).
## While set, it replaces the selected skin everywhere (slime, trail, HUD, menus).
var skin_override := ""


func _ready() -> void:
	# In a browser the save lives in the site's storage; asking for it to be kept as persistent
	# stops the browser from evicting it when space runs low (Chrome/Edge usually just agree).
	if Platform.has_js():
		JavaScriptBridge.eval("if (navigator.storage && navigator.storage.persist) { navigator.storage.persist(); }", true)
	# The hub's use key isn't in project.godot's input map; it's made here (F by default).
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	for id in Abilities.ids():  # the abilities' keys (1 / 2 / 3 by default), made here like interact
		if not InputMap.has_action(Abilities.action(id)):
			InputMap.add_action(Abilities.action(id))
	if save_path == _throwaway_save_path():
		_clear_throwaway_saves()  # fresh every run
	var args := user_args()
	if args.size() != OS.get_cmdline_user_args().size():
		print("Dry Trying: debug launch flags are ignored in release builds (kept: %s)" % ", ".join(args))
	var story_complete := STORY_COMPLETE_FLAG in args
	var autoplay := Autoplay.requested(args)
	var tutorial := tutorial_flag(args)
	# --demo (debug): the demo on a clean in-memory save, like --tutorial (the real save is never read);
	# with --save-path=user://x.cfg it plays and keeps that file instead, to try the carry-over.
	var demo_clean := "--demo" in args and save_path == _throwaway_save_path()
	if _is_test_or_tool_run():
		story_seen = STORY_INTRO | STORY_FINALE  # tests start levels directly; story tests reset this
	elif story_complete or autoplay or tutorial != "" or demo_clean:
		pass  # a clean in-memory state (set up below), never the player's save
	elif save_path == _throwaway_save_path():
		load_progress(REAL_SAVE_PATH)  # dev/headless/movie runs read the player's save, never write it
	else:
		load_progress()
	apply_bindings()
	apply_volume()
	if fullscreen and save_path == REAL_SAVE_PATH and Platform.remembers_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)  # the player's last choice (M4)
	if Platform.remembers_fullscreen() and DisplayServer.get_name() != "headless":
		_watch_window_mode()
	if story_complete:  # first, so the other debug flags can still adjust the state it sets
		enable_story_complete()
	if autoplay:
		enable_autoplay()
	if tutorial != "":
		enable_tutorial_test(tutorial)
	var coins_in_hand := -1  # --coins=N (-1: not given)
	for arg in args:
		if arg.begins_with("--level="):
			current_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levels.COUNT)
		elif arg == "--unlock-all":
			enable_dev_mode()
		elif arg == "--promo":  # promo captures: the RAINBOW / STOPWATCH skins stay locked silhouettes even with --unlock-all (not saved)
			saving_enabled = false
			promo_secrets_locked = true
		elif arg == "--touch":
			force_touch = true
		elif arg == "--hard":
			saving_enabled = false
			hard_mode = true
		elif arg == "--random":
			start_random()
		elif arg == "--demo-preview" and Demo.on():  # the demo's FULL GAME PREVIEW maze right away (with --demo; open scenes/main.tscn)
			saving_enabled = false
			levels_cleared = Demo.levels()
			highest_unlocked = Demo.levels()
			story_seen |= STORY_INTRO | STORY_DEMO_END
			tickets_lifetime = maxi(tickets_lifetime, 1)
			begin_demo_preview()
		elif arg == "--descent" or arg.begins_with("--descent="):  # a Descent run (--descent=SEED: that run seed)
			start_descent(arg.trim_prefix("--descent=").to_int() if arg.begins_with("--descent=") else 0)
		elif arg.begins_with("--skin="):
			saving_enabled = false
			selected_skin = arg.trim_prefix("--skin=")
		elif arg.begins_with("--upgrades="):  # e.g. --upgrades=4,2,1: MORE SLIME 0-7, SPEED 0-4, BRIGHTNESS 0-3 (the v2 tree; higher clamps)
			saving_enabled = false
			var levels := arg.trim_prefix("--upgrades=").split(",")
			for i in mini(levels.size(), 3):
				var id: String = Upgrades.LIST[i].id  # levels of the current tree (7 / 4 / 3)
				upgrades[id] = clampi(levels[i].to_int(), 0, Upgrades.max_level(id))
		elif arg.begins_with("--coins="):  # exactly this many coins in hand (no dev bonus; set after the loop)
			saving_enabled = false
			dev_coins = 0
			coins_in_hand = maxi(arg.trim_prefix("--coins=").to_int(), 0)
		elif arg == "--all-coins":  # every story coin found (for rainbow screenshots); not saved
			saving_enabled = false
			dev_coins = 0
			all_coins_debug = true
			coins_found = {}
			for level in range(1, Levels.COUNT + 1):
				coins_found[level] = []
				for i in Levels.COINS[level - 1]:
					coins_found[level].append("debug%d" % i)
		elif arg.begins_with("--medals="):  # medal tiers for levels 1, 2, ... e.g. 3,2,1 (not saved)
			saving_enabled = false
			var tiers := arg.trim_prefix("--medals=").split(",")
			for i in mini(tiers.size(), Levels.COUNT):
				medals[i + 1] = clampi(tiers[i].to_int(), 0, TIER_GOLD)
		elif arg.begins_with("--tickets="):  # this many tickets in hand (not saved)
			saving_enabled = false
			tickets = clampi(arg.trim_prefix("--tickets=").to_int(), 0, TICKETS_MAX)
		elif arg.begins_with("--hat="):
			saving_enabled = false
			selected_hat = arg.trim_prefix("--hat=")
		elif arg.begins_with("--dye="):  # every dyeable hat owns and wears this dye, e.g. --dye=rainbow (not saved)
			saving_enabled = false
			var dye := arg.trim_prefix("--dye=")
			for hat in Hats.ids():
				if dye in Hats.dyes_for(hat):
					if not "%s:%s" % [hat, dye] in hat_dyes_owned:
						hat_dyes_owned.append("%s:%s" % [hat, dye])
					hat_dyes[hat] = dye
		elif arg.begins_with("--workshop="):  # e.g. --workshop=1,0,3,2,0: SECOND WIND, QUICK CHARGE, STICKY, MAGNET, GOO NOSE (0-3)
			saving_enabled = false
			var levels := arg.trim_prefix("--workshop=").split(",")
			for i in mini(levels.size(), Workshop.LIST.size()):
				var id: String = Workshop.LIST[i].id
				workshop[id] = clampi(levels[i].to_int(), 0, Workshop.max_level(id))
		elif arg.begins_with("--abilities="):  # e.g. --abilities=3,1,2: SLIME RIFLE, SLIME SPLAT, SLIMAKAZE (0-3)
			saving_enabled = false
			var ability_levels := arg.trim_prefix("--abilities=").split(",")
			for i in mini(ability_levels.size(), Abilities.LIST.size()):
				var id: String = Abilities.LIST[i].id
				abilities[id] = clampi(ability_levels[i].to_int(), 0, Abilities.max_level(id))
		elif arg.begins_with("--wheel-style="):  # the prize wheel's look: odds (default) or rewards (HatWheel)
			wheel_style = arg.trim_prefix("--wheel-style=")
		elif arg.begins_with("--trail="):  # wear (and own) a trail style, e.g. --trail=candy
			saving_enabled = false
			var style := arg.trim_prefix("--trail=")
			if Cosmetics.kind_of(style) == Cosmetics.TRAIL:
				if style != Cosmetics.DEFAULT_TRAIL and not style in cosmetics_owned:
					cosmetics_owned.append(style)
				trail_style = style
		elif arg.begins_with("--paper="):  # use (and own) a map paper, e.g. --paper=blueprint
			saving_enabled = false
			var paper := arg.trim_prefix("--paper=")
			if Cosmetics.kind_of(paper) == Cosmetics.PAPER:
				if paper != Cosmetics.DEFAULT_PAPER and not paper in cosmetics_owned:
					cosmetics_owned.append(paper)
				map_paper = paper
		elif arg == "--softbounce":  # the soft bounce test (Economy.SOFT_BOUNCE_TEST, docs/spring-cleaning/soft-bounce-test.md)
			saving_enabled = false
			Economy.softbounce_force = 1
		elif arg == "--coincatch":  # the coin catch test (Economy.COIN_CATCH_TEST, docs/spring-cleaning/coin-catch-test.md)
			saving_enabled = false
			Economy.coincatch_force = 1
		elif arg == "--pastel":  # wear the PASTEL version of the skin (Progress.pastel, Skins.pastel)
			saving_enabled = false
			set_pastel(true)
		elif arg == "--nocoincatch":  # A/B: the old instant pickup (coin catch is on by default now)
			saving_enabled = false
			Economy.coincatch_force = 0
		elif arg == "--nocoinreveal":  # A/B: no revealed coins on the maps in dev (Economy.MAP_COIN_REVEAL_TEST)
			saving_enabled = false
			Economy.mapcoinreveal_force = 0
		elif arg == "--languages":  # the translations test (Economy.LANGUAGES_TEST, docs/i18n/plan.md)
			saving_enabled = false
			Economy.languages_force = 1
		elif arg.begins_with("--lang="):  # ... with this locale forced for this run (never saved)
			saving_enabled = false
			Economy.languages_force = 1
			Economy.forced_locale = arg.trim_prefix("--lang=")
		elif arg == "--quiet-window":
			_after_quiet_start.call_deferred()
	settle_debug_coins(coins_in_hand)  # after the loop, so the flag order doesn't matter
	if MAPS_FULL_FLAG in args:  # after the loop: --unlock-all clears the maps
		saving_enabled = false
		seed_full_surveys()


## The debug coin flags, after every other flag: `in_hand` >= 0 (--coins=N) leaves exactly N coins in
## hand on top of whatever --upgrades= bought; otherwise, if the flags left a negative balance (e.g.
## --upgrades= over the real save's coins, read-only: the '-4' of an old screenshot), debug coins
## (level 0 keys, never saved) pay for what the coins found don't cover, so it reads 0.
func settle_debug_coins(in_hand: int) -> void:
	if in_hand >= 0:
		coins_found = {0: []}
	if in_hand < 0 and _coins_balance() >= 0:  # (unclamped: the demo's coins() is floored at 0)
		return
	if not coins_found.has(0):
		coins_found[0] = []
	for i in maxi(maxi(in_hand, 0) - _coins_balance(), 0):
		coins_found[0].append("debug%d" % coins_found[0].size())


## Launch flags an exported RELEASE build still honors: they only preview the touch / web UI layout.
## Every other flag after `--` (--unlock-all, --story-complete, --autoplay*, --level=, --coins=,
## --tickets=, --medals=, --upgrades=, --skin=, --hat=, --maps=, --random, --hard, --jelly,
## --all-coins, --save-path=, --quiet-window...) is a debug / dev tool: a release export
## (OS.is_debug_build() false) ignores them and launches as a normal game. The editor binary that
## tools/play.sh, screenshot.sh and test_all.sh run is a debug build, so they keep working.
const RELEASE_FLAGS := ["--touch", "--web-ui"]


## The launch flags this build honors out of `args`: all of them in a debug build (editor binary,
## debug export), only RELEASE_FLAGS in a release export.
static func game_args(args: PackedStringArray, debug_build: bool) -> PackedStringArray:
	if debug_build:
		return args
	var out := PackedStringArray()
	for arg in args:
		if arg in RELEASE_FLAGS:
			out.append(arg)
	return out


## The flags after `--` that this launch honors (see game_args). Game code reads flags through this.
static func user_args() -> PackedStringArray:
	return game_args(OS.get_cmdline_user_args(), OS.is_debug_build())


## Debug (--quiet-window, used by tools/play.ps1 and screenshot.ps1): the window was opened
## without taking focus via a temporary override.cfg. Delete that file right away (so normal runs
## aren't affected) and make the window focusable again, so clicking it lets you play.
func _after_quiet_start() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://override.cfg"))
	get_window().set_flag(Window.FLAG_NO_FOCUS, false)


## F11 toggles fullscreen anywhere in the game (desktop and browser).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


## False where FULLSCREEN means nothing: a browser without the Fullscreen API for page elements (iPhone
## Safari; docs/qa-web-report.md O4) and native phones (always fullscreen). SETTINGS then disables its
## FULLSCREEN button and F11 does nothing. See Platform.has_window_fullscreen.
static func fullscreen_available() -> bool:
	return Platform.has_window_fullscreen()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## F11 / SETTINGS FULLSCREEN. On desktop the choice is saved ([settings] fullscreen) and applied at the next
## launch (Platform.remembers_fullscreen).
func toggle_fullscreen() -> void:
	if not fullscreen_available():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if Platform.remembers_fullscreen():
		fullscreen = is_fullscreen()
		save_progress()


## The window can leave or enter fullscreen without F11 (macOS: the green button, View > Exit Full Screen): on
## desktop every window resize re-reads the mode once the resizing has settled (WINDOW_SETTLE seconds, longer
## than macOS's animated fullscreen transition), so the remembered choice follows the window (QA phase 5 #4).
const WINDOW_SETTLE := 0.8
var _window_settle: Timer


func _watch_window_mode() -> void:
	_window_settle = Timer.new()
	_window_settle.one_shot = true
	_window_settle.wait_time = WINDOW_SETTLE
	_window_settle.ignore_time_scale = true
	_window_settle.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_window_settle)
	_window_settle.timeout.connect(func() -> void: window_mode_changed(DisplayServer.window_get_mode()))
	get_tree().root.size_changed.connect(_window_settle.start)


## The window is now in `mode` (DisplayServer.WINDOW_MODE_*): on desktop a fullscreen choice that differs from it
## is updated and saved. Returns true if it changed.
func window_mode_changed(mode: int) -> bool:
	if not Platform.remembers_fullscreen():
		return false
	var now := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if now == fullscreen:
		return false
	fullscreen = now
	save_progress()
	return true


## Removes this run's throwaway save when the game quits (only the autoload owns it).
func _exit_tree() -> void:
	if _owns_throwaway_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _owns_throwaway_save() -> bool:
	return save_path == _throwaway_save_path() and get_parent() != null and get_parent() == get_tree().root


## A per-process scratch save, so concurrent test runs never share (and corrupt) one file.
static func _throwaway_save_path() -> String:
	return "%s%d.cfg" % [THROWAWAY_PREFIX, OS.get_process_id()]


## Deletes this run's throwaway save (fresh, deterministic start) and any left behind by runs that
## crashed more than a few hours ago (another run's live file is never that old... and is not ours).
func _clear_throwaway_saves() -> void:
	var own := ProjectSettings.globalize_path(save_path)
	DirAccess.remove_absolute(own)
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var prefix := THROWAWAY_PREFIX.trim_prefix("user://")
	var now := Time.get_unix_time_from_system()
	for file in dir.get_files():
		if file.begins_with(prefix) and file.ends_with(".cfg"):
			var path := "user://" + file
			if now - FileAccess.get_modified_time(path) > 6 * 3600:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## True for anything that is not the player just playing: a script (tests), a scene under
## res://tests/ or res://tools/, headless, movie/screenshot capture, editor/CLI tool modes, and
## any debug flag after `--` (dev mode, --level=, --skin=...). Only `--quiet-window` (tools/play.ps1's
## normal launch) and `--save-path=` are allowed on a player launch.
static func _is_non_player_run() -> bool:
	const TOOL_FLAGS := ["-s", "--script", "--headless", "--write-movie", "--quit", "--quit-after",
		"--fixed-fps", "--import", "--check-only", "--doctor", "--dev", "--unlock-all", "--editor", "-e"]
	for arg: String in OS.get_cmdline_args() + user_args():
		if arg in TOOL_FLAGS or arg.begins_with("--write-movie=") or arg.begins_with("--script=") \
				or arg.begins_with("--export") or arg.begins_with("res://tests/") \
				or arg.begins_with("res://tools/") or arg.ends_with(".gd"):
			return true
	for arg: String in user_args():
		if arg.begins_with("-") and arg != "--quiet-window" and not arg.begins_with("--save-path=") \
				and not (arg in RELEASE_FLAGS and not OS.is_debug_build()):
			return true
	return DisplayServer.get_name() == "headless"


## The real save for a normal launch, otherwise a throwaway per process. `--save-path=user://x.cfg`
## (before or after `--`) picks a file explicitly; the real save is refused outside a normal launch.
static func _default_save_path() -> String:
	var explicit := ""
	for arg: String in (OS.get_cmdline_args() + user_args()) if OS.is_debug_build() else PackedStringArray():
		if arg.begins_with("--save-path="):
			explicit = arg.trim_prefix("--save-path=")
	var non_player := _is_non_player_run()
	if explicit != "" and not (non_player and _is_real_save(explicit)):
		return explicit
	return _throwaway_save_path() if non_player else REAL_SAVE_PATH


## True if `path` is the player's real save file (however it's spelled).
static func _is_real_save(path: String) -> bool:
	return ProjectSettings.globalize_path(path).simplify_path() == ProjectSettings.globalize_path(REAL_SAVE_PATH).simplify_path()


## Tests, screenshots and promo renders (scripts and scenes under res://tests/ or res://tools/)
## start from a fresh default state instead of the player's save, so whatever the player last
## did (hard mode on, jelly off...) can't change what they check or show.
static func _is_test_or_tool_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("res://tools/"):
			return true
	return false


## Loads `path` (default: save_path). Saving still only ever goes to save_path.
## The file's text is checked by SaveText's allow-list BEFORE it is parsed (a save.cfg can't run code
## or crash the parser). A save that exists but can't be read or doesn't pass is moved aside to
## `<name>.corrupt.cfg` (the newest CORRUPT_KEEP kept) before the game starts fresh, so the next save
## can't silently destroy it; that only happens for our own save file while saving is enabled (dev runs
## that just peek at the real save never touch it). A save from another release epoch is not corrupt:
## it starts fresh by policy (docs/itch-release.md) and is overwritten by the next save.
func load_progress(path := "") -> void:
	var file_path := save_path if path == "" else path
	var owned := file_path == save_path and saving_enabled
	if owned:
		_recover_temp_save(file_path)
	if not FileAccess.file_exists(file_path):
		return  # no save: a fresh start
	var file := _load_checked(file_path)
	if file == null:
		if Demo.on():
			demo_guard = true  # (maybe a newer full game's save the demo can't read: play fresh, never touch it)
		elif owned:
			_set_aside_corrupt(file_path)
		return
	if not _is_this_epoch(file):
		demo_guard = Demo.on()  # (the demo never overwrites another epoch's save; the full game starts fresh)
		return  # one from another release epoch: a fresh start (the file is overwritten on the next save)
	if Demo.on() and SaveFile.get_int(file, "meta", "version", 0) > SAVE_VERSION:
		demo_guard = true  # a newer full game's save: play fresh in memory, never write it
		return
	_read(file)
	_guard_full_save(file)
	# An older (version 5) save was migrated in memory (the coin tree); write it back once so the
	# migration doesn't rerun on each launch.
	if SaveFile.get_int(file, "meta", "version", 0) < SAVE_VERSION:
		save_progress()


## The save file at `path` as a ConfigFile, or null if it can't be opened, is too big, or fails the
## allow-list / parse. An empty (or whitespace-only) file parses as an empty save (no epoch: fresh).
static func _load_checked(path: String) -> ConfigFile:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	if f.get_length() > SaveText.MAX_BYTES:
		return null  # (never read a huge file into memory)
	var bytes := f.get_buffer(f.get_length())
	f.close()
	if SaveText.is_blank(bytes):
		return ConfigFile.new()
	return SaveText.parse(bytes)


## Backups of unreadable saves kept next to it: <name>.corrupt.cfg (newest), .corrupt.2.cfg, ...
const CORRUPT_KEEP := 3
## Set when this session's save was found unreadable: where it was moved ("" if it wasn't).
var corrupt_backup := ""


static func corrupt_backup_path(path: String, n := 1) -> String:
	return "%s.corrupt%s.cfg" % [path.get_basename(), "" if n <= 1 else ".%d" % n]


## Moves an unreadable save out of the way (rotating older backups), so starting fresh never overwrites
## it. If it can't be moved or copied, saving is turned off for this session to protect it.
func _set_aside_corrupt(path: String) -> void:
	var g := func(p: String) -> String: return ProjectSettings.globalize_path(p)
	DirAccess.remove_absolute(g.call(corrupt_backup_path(path, CORRUPT_KEEP)))
	for n in range(CORRUPT_KEEP - 1, 0, -1):
		if FileAccess.file_exists(corrupt_backup_path(path, n)):
			DirAccess.rename_absolute(g.call(corrupt_backup_path(path, n)), g.call(corrupt_backup_path(path, n + 1)))
	var backup := corrupt_backup_path(path)
	if DirAccess.rename_absolute(g.call(path), g.call(backup)) == OK or DirAccess.copy_absolute(g.call(path), g.call(backup)) == OK:
		corrupt_backup = backup
	else:
		saving_enabled = false


## Finishes or cleans up an interrupted atomic save (see _write_atomic): a leftover `<save>.tmp` next
## to an existing save is an unfinished write and is deleted; with no save at all (a crash between
## removing and renaming on platforms where rename can't replace) a temp that passes the checks is
## the newest save and becomes it.
func _recover_temp_save(path: String) -> void:
	var temp := path + TEMP_SUFFIX
	if not FileAccess.file_exists(temp):
		return
	var g_temp := ProjectSettings.globalize_path(temp)
	var file := _load_checked(temp) if not FileAccess.file_exists(path) else null
	if file != null and _is_this_epoch(file):
		DirAccess.rename_absolute(g_temp, ProjectSettings.globalize_path(path))
	else:
		DirAccess.remove_absolute(g_temp)


## Takes everything from a save (the save file or a loaded save code; `from_code`: a pasted save code,
## which never brings a saved Descent run with it). The reading itself is SaveFile.read.
func _read(file: ConfigFile, from_code := false) -> void:
	SaveFile.read(self, file, from_code)


## Upgrade levels from a save without [upgrades] tree = 2 are levels of the old 3 x 10 tree (level n
## cost n coins). Each track maps by coins invested onto TREE 2's prices, rounded down
## (Upgrades.migrate_level: SLIME 10 -> 7, SPEED 10 -> 3 with 19 coins back, BRIGHTNESS 10 -> 3 with 5
## back, SLIME 5 -> 3 with 3 back); _migrate_prices then reprices those tree 2 levels like any tree 2
## save. Coins in hand are derived (found - spent), so the remainder is back in hand by itself and
## nobody can go negative. A pure function of the stored levels; the next save writes the current
## tree, so it never runs twice. Runs before the "never spend more than found" check. Dev wall power
## is not counted in the notice (it was never real money). The coins returned are kept for the hub's
## one-time notice.
func _migrate_tree() -> void:
	var returned := 0
	for id: String in upgrades.keys():
		var level := Upgrades.migrate_level(id, upgrades[id])
		if id != "power":
			returned += Upgrades.old_total_cost(upgrades[id]) - Upgrades.tree2_total_cost(id, level)
		if level > 0:
			upgrades[id] = level
		else:
			upgrades.erase(id)
	tree_refund_notice = maxi(0, returned)


## Upgrade levels from a tree 2 save were bought at Economy.TREE2_COSTS (MORE SLIME 55, SPEED 60,
## BRIGHTNESS 50); coins in hand are derived from levels x the CURRENT prices, so without this a
## repricing would silently move every balance (and could make it negative). Each track first maps by
## the coins it held, rounded down onto the current prices (Upgrades.level_for_coins), then levels are
## bought back up to what the player had, MORE SLIME first, while the coins found still cover them:
## a player keeps every level they can afford (a maxed tree stays maxed; it costs 165 either way),
## and never ends with less in hand than 0. The coins this frees (old spent - new spent, if more)
## join the hub's one-time COINS RETURNED notice. A pure function of the stored levels and coins
## found (idempotent: the next save writes the current tree, so it never runs twice); runs before the
## "never spend more than found" check. Dev wall power is free in both trees and kept as it is.
func _migrate_prices() -> void:
	var had := upgrades.duplicate()
	var old_spent := 0
	for upgrade: Dictionary in Upgrades.LIST:
		var id: String = upgrade.id
		if upgrade.get("dev", false) or not had.has(id):
			continue
		var invested := Upgrades.tree2_total_cost(id, had[id])
		old_spent += invested
		var level := Upgrades.level_for_coins(id, invested)
		if level > 0:
			upgrades[id] = level
		else:
			upgrades.erase(id)
	for upgrade: Dictionary in Upgrades.LIST:
		var id: String = upgrade.id
		if upgrade.get("dev", false):
			continue
		while upgrade_level(id) < int(had.get(id, 0)) and coins_earned() - coins_spent() >= Upgrades.cost(id, upgrade_level(id)):
			upgrades[id] = upgrade_level(id) + 1
	tree_refund_notice = maxi(0, tree_refund_notice + old_spent - coins_spent())


## The coins the tree migration returned, once: the hub shows UPGRADES REWORKED / COINS RETURNED +N
## and calls this, which clears (and saves) the notice so it never shows again. 0 = nothing to show.
func take_tree_refund_notice() -> int:
	var n := tree_refund_notice
	if n > 0:
		tree_refund_notice = 0
		save_progress()
	return n


## The shortest best time kept (S4): a record of 0 s, a negative one or 1e-9 (hand-made saves) could
## never be beaten; anything a real frame-stepped run can set (1/60 s and up) is kept.
const MIN_RECORD := 0.001
## Largest physical keycode accepted from a save (Godot keycodes stay below KEY_SPECIAL | 0xFF...).
const KEY_MAX_CODE := (1 << 23) - 1


## A saved Descent run ([descent_run], D6) checked and clamped, or {} when there is none or it can't be one
## (another format, a seed / floor out of range, boons that can't go together or more boons than floors
## cleared): such a run is dropped, like any unreadable optional section.
static func read_descent_run(file: ConfigFile) -> Dictionary:
	const S := "descent_run"
	if not file.has_section(S) or SaveFile.get_int(file, S, "format", 0) != DESCENT_RUN_FORMAT:
		return {}
	var run_seed := SaveFile.get_int(file, S, "seed", 0)
	var floor_no := SaveFile.get_int(file, S, "floor", 0)
	if run_seed < 1 or run_seed > Economy.DESCENT_SEED_MAX or floor_no < 1 or floor_no > DESCENT_FLOOR_MAX:
		return {}
	var cleared := SaveFile.get_int(file, S, "cleared", floor_no - 1)
	if cleared != floor_no - 1 and cleared != floor_no:
		return {}
	var boons := {}
	var raw: Variant = file.get_value(S, "boons", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var picks := 0
	for id: Variant in raw:
		var n: Variant = raw[id]
		if typeof(id) != TYPE_STRING or not id in Descent.IDS or typeof(n) != TYPE_INT or n < 1:
			return {}
		var top := int(Descent.boon(id).get("max", 1))
		boons[id] = mini(n, top if top > 0 else DESCENT_FLOOR_MAX)
		picks += boons[id]
	if picks > floor_no - 1 or not Descent.boons_compatible(boons):
		return {}
	var bonuses: Array = []
	var raw_bonuses: Variant = file.get_value(S, "bonuses", [])
	if typeof(raw_bonuses) == TYPE_ARRAY:
		for pair: Variant in raw_bonuses:
			if typeof(pair) == TYPE_ARRAY and pair.size() == 2 and typeof(pair[0]) == TYPE_INT and typeof(pair[1]) == TYPE_INT:
				bonuses.append([clampi(pair[0], 1, DESCENT_FLOOR_MAX), clampi(pair[1], 0, 100)])
	return {
		seed = run_seed, floor = floor_no, cleared = cleared,
		meter = clampf(SaveFile.get_float(file, S, "meter", 100.0), 0.0, 100.0),
		boons = boons,
		bladders = clampi(SaveFile.get_int(file, S, "bladders", 0), 0, int(boons.get("bladder", 0))),
		pot = clampi(SaveFile.get_int(file, S, "pot", 0), 0, Economy.DESCENT_POT_MAX),
		time = clampf(SaveFile.get_float(file, S, "time", 0.0), 0.0, 1.0e7),
		wind_used = SaveFile.get_bool(file, S, "wind_used", false),
		slot = clampi(SaveFile.get_int(file, S, "slot", 0), 0, Economy.DESCENT_PAID_PER_DAY),
		bonuses = bonuses.slice(-8),
		new_best = SaveFile.get_bool(file, S, "new_best", false),
		best_before = clampi(SaveFile.get_int(file, S, "best_before", 0), 0, DESCENT_FLOOR_MAX),
		# (optional, D9: older saves have none = not resumed yet; a boon card is never limited)
		resumes = 0 if cleared == floor_no else clampi(SaveFile.get_int(file, S, "resumes", 0), 0, DESCENT_RESUMES_PER_FLOOR),
	}


## The ticket store's part of a save (SaveFile.read_store).
func _read_store(file: ConfigFile) -> void:
	SaveFile.read_store(self, file)


## Writes the save (if saving is on). Returns false if it couldn't be written: the old file is then
## left exactly as it was, the progress stays in memory and the write is retried later
## (SAVE_RETRY_FIRST seconds, doubling up to SAVE_RETRY_MAX) and on the next save.
func save_progress() -> bool:
	if not saving_enabled or demo_guard or _preview_save != null:
		return true  # (nothing is written during the demo's FULL GAME PREVIEW: end_demo_preview puts it all back)
	var ok := write_atomic(save_path, _write().encode_to_text())
	save_failed = not ok
	if not ok:
		_schedule_save_retry()
	else:
		_retry_delay = SAVE_RETRY_FIRST
	return ok


const TEMP_SUFFIX := ".tmp"
const SAVE_RETRY_FIRST := 5.0
const SAVE_RETRY_MAX := 60.0
## True while the last save attempt failed (disk full, read-only folder, storage blocked...).
var save_failed := false
var _retry_pending := false
var _retry_delay := SAVE_RETRY_FIRST


func _schedule_save_retry() -> void:
	if _retry_pending or not is_inside_tree():
		return
	_retry_pending = true
	get_tree().create_timer(_retry_delay, true).timeout.connect(_retry_save)
	_retry_delay = minf(_retry_delay * 2.0, SAVE_RETRY_MAX)


func _retry_save() -> void:
	_retry_pending = false
	if save_failed:
		save_progress()


## The Steam / store seam (docs/spring-cleaning/phase5-platform.md "Steam seam"): a progress milestone was just
## saved: `id` = "medal_normal" / "medal_hard" (medals won in that mode), "coins" (story coins found), "hats" (hats
## owned), "random_wins", "descent_floor" (deepest floor). PlatformEvents.progress_event
## carries it; nothing listens yet (a future Steam build's achievements backend will). Dev, story-complete and
## autoplay runs report nothing (their progress isn't real).
func report_progress(id: String, value: int) -> void:
	if dev_tools or not saving_enabled:
		return
	var events := get_node_or_null("/root/PlatformEvents")
	if events:
		events.progress_event.emit(id, value)


## The app is going to the background (PlatformEvents): every change is already saved the moment it happens
## (atomically), so only a save that failed earlier (disk full, storage blocked) is still waiting; it is
## retried now instead of on its timer, which a suspended app would never reach.
func flush_save() -> void:
	if save_failed:
		save_progress()


## Writes `text` to `path` so the file is always either the old save or the complete new one: the
## text goes to `path.tmp`, is read back and compared (a short write on a full disk / quota is caught
## even when the OS reported success), and only then renamed over `path` (atomic on macOS, Linux and
## the web's in-memory file system, which Godot syncs to IndexedDB on the next frame; on Windows Godot
## removes then renames, and _recover_temp_save handles a crash in between). A failed rename is retried
## once. On any failure false is returned and the temp file is removed while `path` is still there
## (untouched); if Windows already removed `path`, the verified temp file is kept for _recover_temp_save.
static func write_atomic(path: String, text: String) -> bool:
	var bytes := text.to_utf8_buffer()
	var temp := path + TEMP_SUFFIX
	var g_temp := ProjectSettings.globalize_path(temp)
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	var stored := f.store_buffer(bytes)
	f.close()
	if not stored or FileAccess.get_file_as_bytes(temp) != bytes:
		DirAccess.remove_absolute(g_temp)
		return false
	var g_path := ProjectSettings.globalize_path(path)
	if DirAccess.rename_absolute(g_temp, g_path) == OK or DirAccess.rename_absolute(g_temp, g_path) == OK:
		return true  # (one retry: on Windows a virus scanner / indexer can hold the file for a moment)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(g_temp)  # the old save is still there: as if nothing was written
	# else Windows removed the old save before its rename failed: the verified temp file is now the only copy
	# and stays (_recover_temp_save promotes it on the next launch; the next save retries the rename).
	return false


## Everything that's saved, as a ConfigFile, written to the save file or turned into a save code
## (`for_code`: without the saved Descent run, which a code copied to another device could bank on both).
## The writing itself is SaveFile.write.
func _write(for_code := false) -> ConfigFile:
	return SaveFile.write(self, for_code)


## The whole save as a code to copy somewhere safe: SAVE_CODE_PREFIX ("SLIME2-") and the save file, gzipped, in
## base64. Pasting it back with load_code restores the progress (in a browser whose storage was
## cleared, on another browser, or in the Windows version).
func save_code() -> String:
	var packed := _write(true).encode_to_text().to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return SAVE_CODE_PREFIX + Marshalls.raw_to_base64(packed)


## Longest save code read (base64 characters); real ones are a few KB.
const MAX_SAVE_CODE_LENGTH := 65536


## The save inside a code, or null if it isn't a working Dry Trying save code. Only codes made by this release epoch work: an old prefix, or a code without this [meta] epoch,
## gives null (is_old_code tells those apart from broken codes).
static func read_code(code: String) -> ConfigFile:
	code = _clean_code(code)
	if not code.begins_with(SAVE_CODE_PREFIX):
		return null
	var file := _decode_code(code.trim_prefix(SAVE_CODE_PREFIX))
	return file if file != null and _is_this_epoch(file) else null


## True for a code from an older build: another "SLIME<n>-" prefix (e.g. SLIME1- from before the
## public release), or a working save with this prefix but not this release epoch.
static func is_old_code(code: String) -> bool:
	code = _clean_code(code)
	if code.begins_with(SAVE_CODE_PREFIX):
		var file := _decode_code(code.trim_prefix(SAVE_CODE_PREFIX))
		return file != null and not _is_this_epoch(file)
	var dash := code.find("-")
	return code.begins_with("SLIME") and dash > 5 and code.substr(5, dash - 5).is_valid_int()


## True if a save (file or code) was written by this release epoch.
static func _is_this_epoch(file: ConfigFile) -> bool:
	if not file.has_section_key("meta", "epoch"):
		return false  # (get_value with a null default logs an engine error for a missing key, S8)
	var epoch: Variant = file.get_value("meta", "epoch")
	return typeof(epoch) == TYPE_INT and epoch == RELEASE_EPOCH


## A pasted code without the whitespace, invisible characters and wrapping a chat app or web page
## may add: spaces, tabs, line breaks, non-breaking / zero-width spaces, a BOM, quotes or backticks
## round it (a markdown code fence) and a trailing period. None of these can be part of a code.
static func _clean_code(code: String) -> String:
	for junk in [" ", "\n", "\r", "\t", "\u00a0", "\u200b", "\u200c", "\u200d", "\u2060", "\ufeff", "`", "\"", "\u201c", "\u201d", "'"]:
		code = code.replace(junk, "")
	return code.trim_suffix(".")


static var _BASE64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")


## The save inside a code's base64 (after the prefix), or null if it isn't one.
static func _decode_code(body: String) -> ConfigFile:
	if body.length() > MAX_SAVE_CODE_LENGTH or body.length() % 4 != 0 or not _BASE64.search(body):
		return null  # (not base64: refused before base64_to_raw, which would log engine errors)
	var packed := Marshalls.base64_to_raw(body)
	if packed.is_empty():
		return null
	var text := SaveText.gunzip(packed)  # bounded: never decompress_dynamic (it hangs on trailing bytes, S10)
	if text.is_empty():
		return null
	var file := SaveText.parse(text)  # allow-list first: a code is data, never code (S1, S11)
	if file == null or not file.has_section("progress"):
		return null
	return file


## Replaces the progress with the save in `code` (and saves it). False if the code doesn't work.
func load_code(code: String) -> bool:
	var file := read_code(code)
	if file == null:
		return false
	_read(file, true)
	_guard_full_save(file, true)
	apply_bindings()
	apply_volume()
	save_progress()
	return true


## The demo's carry-over guard (see demo_guard): a save or code without the demo's marker is the full
## game's, and the demo never writes over it. The full game (and a demo save in the demo) saves as ever.
## `from_code`: a pasted code can turn the guard on, never off: a demo code pasted into a guarded demo (the
## real file is still the full game's) must not let the next save overwrite it. Only loading a demo-marked
## save FILE clears it.
func _guard_full_save(file: ConfigFile, from_code := false) -> void:
	var full := Demo.on() and not is_demo_save(file)
	demo_guard = (demo_guard or full) if from_code else full


## True for a save / code the demo wrote ([meta] demo = true).
static func is_demo_save(file: ConfigFile) -> bool:
	return file.has_section_key("meta", "demo") and typeof(file.get_value("meta", "demo")) == TYPE_BOOL \
			and file.get_value("meta", "demo")


## Records a story win and picks the next level (back to 1 after beating the last one). On hard
## mode it also unlocks that level's solid skin.
func complete_level(level: int, save := true) -> void:
	if level < 1 or level > Levels.COUNT:
		return  # (not a story level: a randomizer maze or a Descent floor has level 0)
	if hard_mode and not level in hard_cleared:
		hard_cleared.append(level)
	levels_cleared = maxi(levels_cleared, level)
	dry_ups.erase(level)
	highest_unlocked = maxi(highest_unlocked, mini(level + 1, Levels.COUNT))
	current_level = level + 1 if level < Levels.COUNT else 1
	if save:
		save_progress()


## True until the first chalice: the title goes straight into level 1 and the hub waits. With the
## tutorial test on, the finished (or skipped) training also ends it: the tour opens the hub before level 1.
func is_fresh_save() -> bool:
	return levels_cleared == 0 and randoms_won == 0 and hard_cleared.is_empty() \
		and not (Economy.tutorial_on() and has_seen_tutorial(TUTORIAL_TRAINING))


func has_seen_tutorial(bit: int) -> bool:
	return tutorial_seen & bit != 0


func has_seen_story(bit: int) -> bool:
	return story_seen & bit != 0


func mark_story_seen(bit: int) -> void:
	if not has_seen_story(bit):
		story_seen |= bit
		save_progress()


func mark_tutorial_seen(bit: int) -> void:
	if not has_seen_tutorial(bit):
		tutorial_seen |= bit
		save_progress()


## ---------------------------------------------------------------- tutorial test (SPLASHDOWN)
## The first-session tutorial behind Economy.TUTORIAL_TEST (docs/tutorial/design.md, "API for chunks B-E").
## With the gate off every function here is inert: nothing is due, nothing is written.

## The training maze is the gameplay scene in MODE_TRAINING (chunk B's game.gd branch).
const TRAINING_SCENE := "res://scenes/main.tscn"
## The hub, where the tour runs (chunk D's hub_tour.gd) and where training ends.
const TOUR_SCENE := "res://scenes/hub.tscn"


## True when a fresh save should get the training maze: the gate is on, the save has no progress and
## no tutorial bit at all (an old save without the key reads TUTORIAL_MOVE | TUTORIAL_LEAP once it has
## progress; a save that moved in level 1 has bit 1), and it isn't dev mode.
func tutorial_due() -> bool:
	return Economy.tutorial_on() and not dev_tools and is_fresh_save() and tutorial_seen == 0


## True when the hub should run its tour: the gate is on and either the training was just replayed
## from SETTINGS, or the save finished / skipped the training and hasn't had the tour yet.
func hub_tour_due() -> bool:
	if not Economy.tutorial_on() or dev_tools:
		return false
	return tour_replay or (has_seen_tutorial(TUTORIAL_TRAINING) and not has_seen_tutorial(TUTORIAL_HUB))


## True while a training run is set up or under way (game.gd reads Progress.mode the same way).
func in_training() -> bool:
	return mode == MODE_TRAINING


## Sets up a training run (MODE_TRAINING; `replay` = the SETTINGS replay, which writes nothing) and
## returns the scene to open for it. Used where another screen opens the scene (the launch intro's
## Story.next_scene); everyone else calls start_training. (game.gd's MODE_TRAINING branch plays it.)
func prepare_training(replay := false) -> String:
	mode = MODE_TRAINING
	training_replay = replay
	training_used = 0
	training_skipped = false
	return TRAINING_SCENE


## Opens the training maze behind the goo wipe (the title's PLAY on a due save; chunk E's SETTINGS
## TRAINING button with `replay` = true).
func start_training(replay := false) -> void:
	UIKit.go(get_tree(), prepare_training(replay))


## The training cues (chunk C) report a real move / leap in the maze (TUTORIAL_MOVE / TUTORIAL_LEAP):
## remembered for this run only and saved by finish_training, so a SETTINGS replay writes nothing.
func note_training_input(bit: int) -> void:
	if in_training():
		training_used |= bit & (TUTORIAL_MOVE | TUTORIAL_LEAP)


## Ends the training run (the chalice: `skipped` false; SKIP TRAINING in the pause menu: true) and
## returns the scene to go to next (the hub, where the tour is now due). Outside a replay and with the
## gate on it saves TUTORIAL_TRAINING plus the MOVE / LEAP bits the player really used (so the level 1-2
## cues don't teach them again; a skip before moving keeps them as the safety net). Safe to call twice.
func finish_training(skipped: bool) -> String:
	if mode == MODE_TRAINING:
		mode = MODE_STORY
	training_skipped = skipped
	tour_replay = training_replay
	if Economy.tutorial_on() and not training_replay:
		var bits := tutorial_seen | TUTORIAL_TRAINING | training_used
		if bits != tutorial_seen:
			tutorial_seen = bits
			save_progress()
	training_replay = false
	training_used = 0
	return TOUR_SCENE


## Ends the hub tour (finished at the archway, skipped with Esc / B / SKIP, or ended by using a
## station): saves TUTORIAL_HUB (gate on, not a replay) so it never comes back.
func finish_hub_tour() -> void:
	var replay := tour_replay
	tour_replay = false
	if Economy.tutorial_on() and not replay:
		mark_tutorial_seen(TUTORIAL_HUB)


## Debug `--tutorial` / `--tutorial=maze` / `--tutorial=hub` (tools/play.sh --tutorial): "intro", "maze",
## "hub", or "" without the flag (an unknown value plays the whole thing).
static func tutorial_flag(args: PackedStringArray) -> String:
	for arg in args:
		if arg == "--tutorial":
			return "intro"
		if arg.begins_with("--tutorial="):
			var which := arg.trim_prefix("--tutorial=")
			return which if which in ["maze", "hub"] else "intro"
	return ""


## Debug `--tutorial[=maze|hub]`: the tutorial gate on, over a clean in-memory fresh save (the real save is
## never read, as with --story-complete, and nothing is saved). "intro": the launch intro is due, then the
## training maze and the tour; "maze": the intro counts as seen and the boot title opens the maze;
## "hub": training counts as done (with its MOVE / LEAP bits) and the boot title opens the hub's tour.
func enable_tutorial_test(which: String) -> void:
	saving_enabled = false
	reset_progress()  # (saves nothing: saving is off)
	dev_tools = false
	Economy.tutorial_force = 1
	tutorial_launch = which
	story_seen = 0 if which == "intro" else STORY_INTRO
	if which == "hub":
		tutorial_seen = TUTORIAL_MOVE | TUTORIAL_LEAP | TUTORIAL_TRAINING


## The boot title's `--tutorial=maze|hub` hand-off: the scene to open instead of the title ("" = none),
## once per run ("intro" is the launch intro's own hand-off, see Story.launch_next).
func take_tutorial_launch() -> String:
	var which := tutorial_launch
	if which == "intro" or which == "":
		return ""
	tutorial_launch = ""
	if which == "maze":
		return prepare_training(false) if tutorial_due() else ""
	return TOUR_SCENE if hub_tour_due() else ""


## Dev mode, exactly as `--unlock-all` (tools/play.sh --dev) sets it up: every level unlocked,
## dev tools on, nothing saved. Tests call this to play in the owner's dev launch configuration.
func enable_dev_mode() -> void:
	saving_enabled = false
	story_seen = STORY_INTRO | STORY_FINALE
	dev_tools = true
	levels_cleared = Levels.COUNT
	highest_unlocked = Levels.COUNT
	hard_cleared.assign(range(1, Levels.COUNT + 1))
	maps = {}  # dev launches read the player's save: its maps aren't shown (--maps=full seeds them)


## Debug `--story-complete` (tools/play.sh --story): a player who has beaten the whole story, on
## normal AND hard mode, and found every coin, for testing the postgame. Unlike dev mode it is a
## plain player state: no dev tools or dev coins (F1/F2 stay off), every level cleared on both modes
## (randomizer, level select, every opaque and jelly skin incl. rainbow), all Levels.total_coins()
## coins found and none spent (upgrades left to buy), story intro/finale and tutorial seen. Best
## times: normal levels 1-5 just under par, 6-10 at STORY_SILVER_PACE x par, hard all at that pace;
## medals are derived from them (tier_for: gold, silver), so 25/30 normal (the stopwatch skin stays
## locked) and 20/30 hard. Starts from a clean state (the real save is never read) and saves nothing.
const STORY_COMPLETE_FLAG := "--story-complete"
const STORY_GOLD_PACE := 0.95
const STORY_SILVER_PACE := 1.15


func enable_story_complete() -> void:
	saving_enabled = false
	dev_tools = false
	story_seen = STORY_INTRO | STORY_FINALE
	tutorial_seen = TUTORIAL_MOVE | TUTORIAL_LEAP
	levels_cleared = Levels.COUNT
	highest_unlocked = Levels.COUNT
	current_level = 1
	mode = MODE_STORY
	hard_mode = false
	hard_cleared.assign(range(1, Levels.COUNT + 1))
	skin_notices_seen.assign(range(1, Levels.COUNT + 1))
	selected_skin = Skins.skin_for_level(Levels.COUNT - 1)  # the last first-run skin (level 10's)
	set_jelly(false)  # the default (opaque) look
	set_pastel(false)
	upgrades = {}
	coins_found = {}
	best_times = {}
	medals = {}
	for level in range(1, Levels.COUNT + 1):
		var keys: Array = []
		keys.assign(Levels.coin_keys(level))
		coins_found[level] = keys
		for hard in [false, true]:
			var par := Levels.level_par(level, hard)
			var pace := STORY_GOLD_PACE if not hard and level <= Levels.COUNT / 2 else STORY_SILVER_PACE
			var key: int = level + (HARD_RECORDS if hard else 0)
			best_times[key] = snappedf(par * pace, 0.01)
			medals[key] = tier_for(best_times[key], par)
	seed_full_surveys()


## Debug `--autoplay` (tools/play.sh --autoplay, see scripts/autoplay/autoplay.gd): the game plays
## the story by itself from a brand-new player's state, in memory only (the real save is never read
## and nothing is saved). Story intro/finale count as seen unless `--autoplay-cinematics`; the
## tutorial counts as seen. Adds the Autoplay driver to the root (it survives scene changes).
func enable_autoplay() -> void:
	saving_enabled = false
	dev_tools = false
	tutorial_seen = TUTORIAL_MOVE | TUTORIAL_LEAP
	if not Autoplay.CINEMATICS_FLAG in user_args():
		story_seen = STORY_INTRO | STORY_FINALE
	get_tree().root.add_child.call_deferred(Autoplay.new())


func start_story(level: int) -> void:
	mode = MODE_STORY
	current_level = clampi(level, 1, highest_unlocked)


## Records a randomizer win (saved) and pays its tickets for winning on `attempt` (see
## random_payout: the attempt table, capped at 1 for a typed / replayed seed or no MORE SLIME bought;
## 0 once today's 5 paying wins are used, while assisted (or dev toggles), or for a seed that already
## paid today). Returns the tickets paid. The maze stays the same until the player picks NEW MAZE.
func complete_random(assisted := false, seed_value := 0, attempt := 1) -> int:
	randoms_cleared += 1
	randoms_won += 1
	var paid := 0
	if not assisted:
		_check_pay_day()
		if utc_day() > random_pay_day:  # a new day: the cap starts over (never when the clock went back)
			random_pay_day = utc_day()
			random_paid = 0
			random_paid_seeds.clear()
		paid = random_tickets_due(attempt, seed_value)
		if paid > 0:
			random_paid = mini(random_paid + 1, RANDOM_PAID_PER_DAY)  # counts up to the cap (when it's on)
			if seed_value != 0:
				random_paid_seeds.append(seed_value)
				while random_paid_seeds.size() > PAID_SEEDS_MAX:
					random_paid_seeds.remove_at(0)
		add_tickets(paid, false)
	if seed_value != 0:
		random_seed_fresh = false  # winning it again is a replay
	save_progress()
	report_progress("random_wins", randoms_won)
	return paid


## The key random_attempts counts a maze's starts under: its seed code (+ hard mode).
static func random_attempt_key(seed_value: int, seed_level: int, hard := false) -> String:
	return Levels.seed_code(seed_value, seed_level) + ("H" if hard else "")


## Counts one more start of the maze under `key` and returns which attempt this is (1 = first).
func begin_random_attempt(key: String) -> int:
	random_attempts[key] = int(random_attempts.get(key, 0)) + 1
	return random_attempts[key]


## True when the ticket pickup at `cell` of the maze under `key` was already taken (this session).
func random_ticket_taken(key: String, cell: Vector2i) -> bool:
	return cell in random_tickets_taken.get(key, [])


## Takes the ticket pickup at `cell` of the maze under `key` and pays it (unless `unpaid`: an assisted
## or dev-toggled run takes it for nothing). Returns the tickets paid. Saves.
func take_random_ticket(key: String, cell: Vector2i, unpaid := false) -> int:
	if random_ticket_taken(key, cell):
		return 0
	var taken: Array = random_tickets_taken.get(key, [])
	taken.append(cell)
	random_tickets_taken[key] = taken
	return 0 if unpaid else add_tickets(Economy.RANDOM_TICKET_PAY)


## Tickets a win pays on attempt `attempt` before any cap: 5, 4, 3, 2, then 1 from the fifth on.
static func tickets_for_attempt(attempt: int) -> int:
	return RANDOM_ATTEMPT_PAY[clampi(attempt, 1, RANDOM_ATTEMPT_PAY.size()) - 1]


# ---------------------------------------------------------------- tickets and medals

## Today as a UTC day number (days since 1970).
func utc_day() -> int:
	return day_override if day_override >= 0 else int(Time.get_unix_time_from_system() / 86400.0)


## How far after today a stored pay day may be before it counts as today (time zones, a clock
## that was a day off). The cap is forward-only (a clock moved back never resets it), but a day further
## ahead than this comes from a wrong (future) clock or a hand-made save and would lock the daily
## payouts until the real date caught up (years): it is treated as today, keeping today's count.
const PAY_DAY_AHEAD := 2


func _check_pay_day() -> void:
	if random_pay_day > utc_day() + PAY_DAY_AHEAD:
		random_pay_day = utc_day()


## What a randomizer win on `attempt` would pay right now (see random_payout).
func random_tickets_due(attempt := 1, seed_value := 0) -> int:
	return random_payout(attempt, seed_value).tickets


## What a randomizer win on `attempt` of the maze `seed_value` would pay right now, and why it is
## less than the table says: {tickets, table, cap} with cap "" (full), "daily" (today's paying wins
## are used up: 0), "paid" (this seed already paid today: 0), "replay" (a typed or replayed seed: 1)
## or "slime" (no MORE SLIME bought: 1; never in dev mode, where everything is unlocked). Assisted / dev-toggled runs are the caller's (they pay 0).
func random_payout(attempt := 1, seed_value := 0) -> Dictionary:
	_check_pay_day()
	var table := tickets_for_attempt(attempt)
	var open := not Economy.random_daily_cap_on() or utc_day() > random_pay_day or random_paid < RANDOM_PAID_PER_DAY
	if not open:
		return {tickets = 0, table = table, cap = "daily"}
	if seed_paid_today(seed_value):
		return {tickets = 0, table = table, cap = "paid"}
	if not random_seed_fresh and table > TICKETS_REPLAY_CAP:
		return {tickets = TICKETS_REPLAY_CAP, table = table, cap = "replay"}
	if int(upgrades.get("slime", 0)) <= 0 and not dev_tools and table > TICKETS_NO_SLIME_CAP:
		return {tickets = TICKETS_NO_SLIME_CAP, table = table, cap = "slime"}
	return {tickets = table, table = table, cap = ""}


## True when `seed_value` already paid a win on the current UTC day.
func seed_paid_today(seed_value: int) -> bool:
	_check_pay_day()
	return seed_value != 0 and utc_day() <= random_pay_day and seed_value in random_paid_seeds


## Adds tickets (kept within 0-99,999; the amount actually added is returned). Saves unless told not to.
func add_tickets(amount: int, save := true) -> int:
	var before := tickets
	tickets = clampi(tickets + amount, 0, TICKETS_MAX)
	var added := tickets - before
	if added > 0:
		tickets_lifetime += added
	if save and added != 0:
		save_progress()
	return added


func medal_key(level: int) -> int:
	return _record_key(level)


## The best medal tier (0-3) won on `level` in the current mode.
func medals_for(level: int) -> int:
	return clampi(int(medals.get(medal_key(level), 0)), 0, TIER_GOLD)


## The tier a clear in `run_time` seconds earns on a level with par time `par`: gold at or under
## par, silver within SILVER_FACTOR x par, bronze for any other clear.
static func tier_for(run_time: float, par: float) -> int:
	if run_time <= par * GOLD_FACTOR:
		return TIER_GOLD
	if run_time <= par * SILVER_FACTOR:
		return TIER_SILVER
	return TIER_BRONZE


## Records a cleared story level: its medal tier (kept when it is the best so far) and, with
## `finish`, the best time and the level's cleared mark (record_time + complete_level) in that same
## save. A clear played with the slime reserve earns nothing. Returns {tier (this run's), best
## (the saved tier now), new_best (this run raised it, first clear included), assisted}.
func record_clear(level: int, run_time: float, par: float, assisted := false, finish := false) -> Dictionary:
	var result := {tier = 0, best = medals_for(level), new_best = false, assisted = assisted}
	if assisted or level < 1 or level > Levels.COUNT:
		return result  # (level 0: not a story level, never a medal or record)
	var tier := tier_for(run_time, par)
	result.tier = tier
	if tier > result.best:
		medals[medal_key(level)] = tier
		result.best = tier
		result.new_best = true
	if finish:
		record_time(level, run_time, false)
		complete_level(level, false)
	save_progress()
	report_progress("medal_%s" % ("hard" if hard_mode else "normal"), medals_total())
	return result


## Medal tiers won across the story in one mode (the current one unless `hard` says otherwise), on
## levels 1..`up_to` (all of them by default; the demo's hub passes Demo.levels()).
func medals_total(hard: Variant = null, up_to := Levels.COUNT) -> int:
	var total := 0
	var offset := HARD_RECORDS if (hard_mode if hard == null else hard) else 0
	for level in range(1, mini(up_to, Levels.COUNT) + 1):
		total += clampi(int(medals.get(level + offset, 0)), 0, TIER_GOLD)
	return total


## The most medals there are to win in one mode (3 per level).
static func medals_max() -> int:
	return Levels.COUNT * TIER_GOLD


## True when every normal-mode level has a gold (tier 3). Hard-mode tiers don't count. (A future
## STOPWATCH skin unlocks on this.)
func all_medals() -> bool:
	return medals_total(false) == medals_max()


# ---------------------------------------------------------------- slime reserve (assist)

## Whether the dry-up screen should offer the slime reserve: 3+ dry-ups on this story level since
## it was last cleared (this session), and never on hard mode.
func assist_offered(for_level: int) -> bool:
	return not hard_mode and for_level >= 1 and for_level <= Levels.COUNT \
			and int(dry_ups.get(for_level, 0)) >= ASSIST_AFTER


## Chooses to play `for_level`'s next attempt with the reserve. False if it isn't on offer.
func accept_assist(for_level: int) -> bool:
	if not assist_offered(for_level):
		return false
	assist_level = for_level
	return true


## True (once) if the attempt now starting was chosen to be an assisted one.
func take_assist(for_level: int) -> bool:
	var on := assist_level == for_level and assist_offered(for_level)
	assist_level = 0
	return on


func start_random() -> void:
	if demo_preview_due() or demo_preview_replay():
		begin_demo_preview()  # (the demo's randomizer is the FULL GAME PREVIEW maze, from its first use on: owner 2026-10-23)
		return
	mode = MODE_RANDOM
	new_random_maze()


# ---------------------------------------------------------------- the demo's FULL GAME PREVIEW

## The state from before the preview (a save of it) while the preview runs, else null.
var _preview_save: ConfigFile = null
## What isn't in a save but the preview changes (the randomizer's current maze, the worn-skin override).
var _preview_live := {}
const _PREVIEW_LIVE_KEYS: Array[String] = ["mode", "random_seed", "random_level", "random_seed_fresh", "randoms_cleared",
	"random_attempts", "random_offer_shown", "random_tickets_taken", "skin_override", "hard_mode", "current_level", "return_to_game"]


## The preview's card was shown (once per preview; its restarts go straight in). Not saved.
var preview_card_shown := false


## Whether the randomizer portal plays the preview maze again: a demo whose preview was played (owner, 2026-10-22:
## after beating the demo the randomizer always takes them back into it, no new seeds).
func demo_preview_replay() -> bool:
	return Demo.on() and Demo.PREVIEW and Economy.abilities_on() and has_seen_story(STORY_DEMO_PREVIEW) and _preview_save == null


## Whether the preview's first run is next (a demo with it, not seen yet): the randomizer portal's first use after
## the demo's levels (owner, 2026-10-23; it used to follow the RANDOM_WINS-th randomizer win, still the fallback in
## game.gd play_next for a random maze started some other way).
func demo_preview_due() -> bool:
	return Demo.on() and Demo.PREVIEW and Economy.abilities_on() and not has_seen_story(STORY_DEMO_PREVIEW) and _preview_save == null


## Starts the demo's FULL GAME PREVIEW (Demo.PREVIEW): marks it seen (saved, so it plays once), keeps the whole
## state as it is now, then sets up the preview maze and its borrowed look and abilities, in memory only (no save
## is written until end_demo_preview). The game scene reloaded after this plays it (game.gd `preview`).
func begin_demo_preview() -> void:
	if _preview_save != null:
		return
	mark_story_seen(STORY_DEMO_PREVIEW)
	preview_card_shown = false
	_preview_save = _write()
	_preview_live = {}
	for key in _PREVIEW_LIVE_KEYS:
		var value: Variant = get(key)
		_preview_live[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	Demo.preview = true
	mode = MODE_RANDOM
	hard_mode = false
	random_seed = Demo.PREVIEW_SEED
	random_level = Demo.PREVIEW_LEVEL
	random_seed_fresh = false
	random_attempts.clear()
	random_offer_shown.clear()
	random_tickets_taken.clear()
	_borrow_preview_look()
	for id in Abilities.ids():
		abilities[id] = Abilities.max_level(id)


## A random look from the full game: a skin past the demo's (opaque, jelly or pastel), a hat (sometimes dyed),
## a goo trail and a map paper.
func _borrow_preview_look() -> void:
	var skins: Array[String] = []
	for preset: Dictionary in Skins.PRESETS:
		if int(preset.unlock) >= Demo.levels():
			skins.append(preset.id)
	skin_override = skins.pick_random()
	set_jelly(randi() % 2 == 0)
	set_pastel(not jelly and randi() % 2 == 0)
	var hat_ids := Hats.ids()
	selected_hat = hat_ids.pick_random()
	var dyes := Hats.dyes_for(selected_hat)
	hat_dyes = {}
	if not dyes.is_empty() and randi() % 2 == 0:
		var dye: String = dyes.pick_random()
		hat_dyes_owned.append("%s:%s" % [selected_hat, dye])
		hat_dyes[selected_hat] = dye
	var trails: Array[String] = []
	var papers: Array[String] = []
	for item: Dictionary in Cosmetics.LIST:
		if item.has("earned"):
			continue
		(trails if item.kind == Cosmetics.TRAIL else papers).append(item.id)
	trail_style = trails.pick_random()
	map_paper = papers.pick_random()


## Ends the preview (if one runs): everything goes back to how it was before it (the borrowed look, abilities,
## the maze's attempts and records alike), and saving is back on.
func end_demo_preview() -> void:
	if _preview_save == null:
		return
	var before := _preview_save
	_preview_save = null
	Demo.preview = false
	_read(before)
	for key: String in _preview_live:
		set(key, _preview_live[key])
	_preview_live = {}
	mark_story_seen(STORY_DEMO_PREVIEW_COACHED)  # (its ability tutorial has played: replays are just the maze)


## True while the demo's FULL GAME PREVIEW runs.
func in_demo_preview() -> bool:
	return _preview_save != null


# ---------------------------------------------------------------- DESCENT runs (batch 3)

## A saved best floor is never above this (a hand-made save can't claim more).
const DESCENT_FLOOR_MAX := 999


## Starts a new DESCENT run (seed 0 = a random run seed) on floor 1 with a full meter. Any run in
## progress is dropped (it never banked).
func start_descent(run_seed := 0) -> void:
	if not Economy.descent_on():
		return  # cut for now (Economy.DESCENT_ENABLED, D11)
	if descent_resume_pending():
		quit_saved_descent()  # (a saved run is banked as a quit, never silently dropped)
	mode = MODE_DESCENT
	descent_run = Descent.new_run(run_seed if run_seed > 0 else Descent.roll_seed())
	descent_run.best_before = descent_best_floor
	_reach_descent_floor()


## True while a DESCENT run is being played (started, not banked yet).
func descent_active() -> bool:
	return mode == MODE_DESCENT and not descent_run.is_empty() and not descent_run.ended


## The current floor was cleared with `left` percent of the meter after `seconds` (`tainted`: a dev
## toggle was on this floor). Adds the floor's tickets to the pot (Descent.clear_floor) and returns them.
func clear_descent_floor(left: float, seconds: float, tainted := false) -> int:
	if not descent_active() or int(descent_run.cleared) >= int(descent_run.floor):
		return 0
	descent_run.tainted = descent_run.tainted or tainted
	var gain := Descent.clear_floor(descent_run, left, seconds)
	descent_run.resumes = 0  # (D9: a cleared floor starts the resume count over)
	_take_descent_slot()
	_snapshot_descent()  # (resumes on the boon card: the floor stays cleared, its offers are the same)
	return gain


## The run's first cleared floor takes one of today's paid slots (if any are left and the run isn't
## dev-toggled) and saves at once, so closing the game mid-run can't keep the slot for a later run.
## The run then banks into that slot whenever it ends (Economy.DESCENT_PAID_PER_DAY).
func _take_descent_slot() -> void:
	if int(descent_run.get("slot", 0)) > 0 or descent_run.tainted or not descent_day_open():
		return
	descent_run.slot = _use_descent_slot()
	save_progress()


## Uses one of today's paid Descent slots (a new UTC day starts the count over; a clock moved back
## never does) and returns its number (1 = the day's first paid run).
func _use_descent_slot() -> int:
	_check_descent_day()
	if utc_day() > descent_pay_day:
		descent_pay_day = utc_day()
		descent_paid = 0
	descent_paid = mini(descent_paid + 1, Economy.DESCENT_PAID_PER_DAY)
	return descent_paid


## The boon offers after the current (cleared) floor (Descent.offers: seeded by run and floor).
func descent_offers() -> Array[String]:
	if descent_run.is_empty():
		return []
	return Descent.offers(descent_run.seed, descent_run.floor, descent_run.boons)


## Takes boon `id` (one of descent_offers) and goes down a floor (Descent.descend); reaching the new
## floor may pay a milestone (saved). False when the floor isn't cleared or `id` wasn't offered.
func descend(id: String) -> bool:
	if not descent_active() or int(descent_run.cleared) < int(descent_run.floor) or not id in descent_offers():
		return false
	Descent.descend(descent_run, id)
	_reach_descent_floor()
	return true


## The run reached its current floor: a deeper best floor (or the same, faster) is saved, and a
## milestone floor reached for the first time pays its bonus once ever (Economy.DESCENT_MILESTONES;
## floor 10 also unlocks the ABYSS trail). Dev-toggled runs set no record and earn no bonus.
func _reach_descent_floor() -> void:
	descent_run.bonus = 0
	descent_run.resumes = 0  # (D9: a new floor has not been resumed)
	if descent_run.tainted:
		_snapshot_descent()
		return
	var floor_no: int = descent_run.floor
	var t: float = descent_run.time
	var changed := false
	var before := int(descent_run.get("best_before", 0))
	if floor_no > before and before > 0:
		descent_run.new_best = true  # deeper than before this run (a first run sets the record without a fanfare)
	if floor_no > descent_best_floor or (floor_no == descent_best_floor and t < descent_best_time):
		descent_best_floor = mini(floor_no, DESCENT_FLOOR_MAX)
		descent_best_time = t
		changed = true
	var bit := Descent.milestone_bit(floor_no)
	if bit >= 0 and descent_milestones & (1 << bit) == 0:
		descent_milestones |= 1 << bit
		descent_run.bonus = add_tickets(Descent.milestone(floor_no), false)
		descent_run.bonuses.append([floor_no, descent_run.bonus])
		changed = true
	if floor_no >= Economy.DESCENT_ABYSS_FLOOR and not "abyss" in cosmetics_owned:
		cosmetics_owned.append("abyss")
		changed = true
	_snapshot_descent()  # saves (the records above with it)


## Keeps the run as it stands now (a floor start or a cleared floor) as `descent_resume` and saves it (D6). A
## run with a dev toggle (pays nothing) or already banked keeps none.
func _snapshot_descent() -> void:
	if descent_run.is_empty() or descent_run.get("ended", false) or descent_run.get("tainted", false):
		descent_resume = {}
	else:
		var snap := {}
		for key: String in DESCENT_RESUME_KEYS:
			snap[key] = descent_run.get(key, Descent.new_run(1).get(key, 0))
		descent_resume = snap.duplicate(true)
	save_progress()


## True when a saved run waits to be resumed (or quit): the hub asks on arrival and at the portal's DESCENT.
func descent_resume_pending() -> bool:
	return Economy.descent_on() and not descent_resume.is_empty() and not descent_active()


## True when the saved run is mid-floor and that floor was already resumed DESCENT_RESUMES_PER_FLOOR times (D9):
## the resume prompt then offers only QUIT RUN (banks half, as a dry-up does).
func descent_resume_spent() -> bool:
	return not descent_resume.is_empty() and int(descent_resume.cleared) < int(descent_resume.floor) \
		and int(descent_resume.get("resumes", 0)) >= DESCENT_RESUMES_PER_FLOOR


## Makes the saved run the run being played again (mode DESCENT), exactly as it was saved: the same floor (its
## maze from the run seed), meter, boons, pot, time, paid slot and milestone record. A cleared floor resumes on
## its boon card with the same offers. False when none is saved, or when its floor's one resume is spent (D9).
## Nothing is paid by resuming; a mid-floor resume is counted and saved at once (one per floor, D9).
func resume_descent() -> bool:
	if not Economy.descent_on():
		return false
	if descent_resume_spent() or not _load_saved_descent():
		return false
	if int(descent_run.cleared) < int(descent_run.floor):
		descent_run.resumes = int(descent_run.get("resumes", 0)) + 1
		descent_resume.resumes = descent_run.resumes
		save_progress()
	return true


## The saved run made the live run again, as saved (RESUME, QUIT RUN). False when none is saved.
func _load_saved_descent() -> bool:
	if descent_resume.is_empty():
		return false
	var run := Descent.new_run(int(descent_resume.seed))
	for key: String in descent_resume:
		run[key] = descent_resume[key]
	run.best_before = mini(int(run.best_before), descent_best_floor)
	descent_run = run.duplicate(true)
	mode = MODE_DESCENT
	return true


## QUIT RUN on the resume prompt: the saved run banks as quitting it from the pause menu would (half the pot
## mid-floor, the whole pot on the boon card) and is gone. Returns end_descent's result ({} if none was saved).
func quit_saved_descent() -> Dictionary:
	if not Economy.descent_on():
		return {}  # the saved run stays untouched while Descent is off
	if not _load_saved_descent():
		return {}
	var on_boon_card := int(descent_run.cleared) >= int(descent_run.floor)
	return end_descent(on_boon_card)


## False for a cosmetic the player should not see at all: ABYSS while Descent is off, unless already owned.
func cosmetic_visible(id: String) -> bool:
	return id != "abyss" or Economy.descent_on() or id in cosmetics_owned


## True once earned cosmetic `id` has been earned (ABYSS: Descent floor DESCENT_ABYSS_FLOOR reached).
func cosmetic_earned(id: String) -> bool:
	if id == "abyss":
		var bit := Descent.milestone_bit(Economy.DESCENT_ABYSS_FLOOR)
		return descent_best_floor >= Economy.DESCENT_ABYSS_FLOOR or (bit >= 0 and descent_milestones & (1 << bit) != 0)
	return false


## A stored Descent pay day far in the future counts as today (as the randomizer's, PAY_DAY_AHEAD).
func _check_descent_day() -> void:
	if descent_pay_day > utc_day() + PAY_DAY_AHEAD:
		descent_pay_day = utc_day()


## True while today still has a paid Descent slot left (the first DESCENT_PAID_PER_DAY runs that clear
## floor 1 take one; a clock moved back never opens a new day).
func descent_day_open() -> bool:
	_check_descent_day()
	return utc_day() > descent_pay_day or descent_paid < Economy.DESCENT_PAID_PER_DAY


## Paying runs left today.
func descent_paid_left() -> int:
	_check_descent_day()
	if utc_day() > descent_pay_day:
		return Economy.DESCENT_PAID_PER_DAY
	return maxi(Economy.DESCENT_PAID_PER_DAY - descent_paid, 0)


## What ending the current run now would bank: {tickets, base, cap, slot}; base = Descent.bank (whole
## pot on a cash out, half on a dry-up / quit, GLASS SLIME x1.5, at most the pot cap) and cap "" (paid in
## full), "practice" (no paid slot: today's are used up: 0), "dev" (a dev toggle was used: 0) or "slime"
## (no MORE SLIME bought: at most DESCENT_NO_SLIME_CAP; never in dev mode). `slot`: the day's paid run
## this is (the one it took on floor 1, else the one it would take; 0 when it pays nothing). `tainted`
## adds this floor's toggles.
func descent_payout(cashed: bool, tainted := false) -> Dictionary:
	if descent_run.is_empty():
		return {tickets = 0, base = 0, cap = "", slot = 0}
	var base := Descent.bank(descent_run.pot, cashed, descent_run.boons)
	if tainted or descent_run.tainted:
		return {tickets = 0, base = base, cap = "dev", slot = 0}
	var slot := int(descent_run.get("slot", 0))
	if slot <= 0:
		if not descent_day_open():
			return {tickets = 0, base = base, cap = "practice", slot = 0}
		slot = Economy.DESCENT_PAID_PER_DAY - descent_paid_left() + 1
	if int(upgrades.get("slime", 0)) <= 0 and not dev_tools and base > Economy.DESCENT_NO_SLIME_CAP:
		return {tickets = Economy.DESCENT_NO_SLIME_CAP, base = base, cap = "slime", slot = slot}
	return {tickets = base, base = base, cap = "", slot = slot}


## Ends the run and banks it (once): `cashed` = CASH OUT (the whole pot) else a dry-up / quit (half).
## It pays into the paid slot it took on floor 1 (_take_descent_slot); a run without one (started
## with none left) takes one now if a new day has begun and it pays anything. Saves. Returns the
## result (also kept in descent_run.result): {tickets, base, cap, slot, cashed, floor, cleared, pot,
## best_floor, new_best, time, bonuses}. {} when no run is going.
func end_descent(cashed: bool, tainted := false, seconds := 0.0) -> Dictionary:
	if not descent_active():
		return descent_run.get("result", {}) if not descent_run.is_empty() else {}
	descent_run.tainted = descent_run.tainted or tainted
	if not cashed:
		descent_run.time = float(descent_run.time) + maxf(seconds, 0.0)
	var due := descent_payout(cashed)
	var paid := 0
	if due.tickets > 0:
		if int(descent_run.get("slot", 0)) <= 0:
			descent_run.slot = _use_descent_slot()
		paid = add_tickets(due.tickets, false)
	descent_runs = mini(descent_runs + 1, 100 * TICKETS_MAX)
	descent_run.ended = true
	descent_resume = {}  # banked: nothing left to resume
	var result := {tickets = paid, base = due.base, cap = due.cap, slot = int(descent_run.get("slot", 0)) if due.cap in ["", "slime"] else 0, cashed = cashed, floor = int(descent_run.floor),
		cleared = int(descent_run.cleared), pot = int(descent_run.pot), best_floor = descent_best_floor,
		new_best = descent_run.get("new_best", false),
		time = float(descent_run.time), bonuses = descent_run.bonuses.duplicate(), boons = descent_run.boons.duplicate()}
	descent_run.result = result
	save_progress()
	report_progress("descent_floor", descent_best_floor)
	return result


## The current random maze's map (owner, 2026-10-21): every try at it so far, merged like a story
## survey (Survey: the tiles seen, the last try's route), for the MAP button after a dry-up
## (RandomMapView). In memory only: gone once the maze is cleared, a new one starts or the player
## goes back to the hub (discard_random_map). `random_map_key` = the maze's random_attempt_key.
var random_map := {}
var random_map_key := ""


## Adds a try at random maze `key` (its tiles seen and the cells walked) to its map; another maze's
## map is dropped first.
func record_random_map(key: String, maze: Dictionary, tiles: PackedByteArray, moves: PackedByteArray, goal_seen: bool,
		tickets: Array[Vector2i] = []) -> void:
	if key != random_map_key or not Survey.fits(random_map, maze):
		random_map = Survey.blank(maze)
		random_map_key = key
	Survey.merge_seen(random_map, tiles)
	if goal_seen:
		Survey.mark_seen(random_map, maze.goal * 2 + Vector2i.ONE)
	random_map.goal = random_map.goal or goal_seen
	random_map.tickets = tickets.duplicate()  # the maze's ticket pickups still out (the map shows the seen ones)
	if not moves.is_empty():
		random_map.moves = moves.slice(0, Survey.MAX_MOVES)
		random_map.start = maze.start


## The map of random maze `key` ({} = none yet, or another maze's).
func random_map_for(key: String) -> Dictionary:
	return random_map if key == random_map_key and not random_map.is_empty() else {}


func discard_random_map() -> void:
	random_map = {}
	random_map_key = ""


func new_random_maze() -> void:
	discard_random_map()
	random_seed = randi_range(1, 2_000_000_000)
	if Demo.gentle_maze(randoms_won):  # (the demo's first mazes: a seed that doesn't ask for most of the meter)
		for _i in 64:
			if Levels.random_usage_permille(random_seed) <= Demo.GENTLE_MAX_USAGE:
				break
			random_seed = randi_range(1, 2_000_000_000)
	random_level = -1
	random_seed_fresh = true  # (the demo too: a new random maze each time, its theme from Demo.themes())
	random_attempts.clear()  # a new maze starts counting at attempt 1
	random_offer_shown.clear()
	random_tickets_taken.clear()


# ---------------------------------------------------------------- skins

# ---------------------------------------------------------------- coins and upgrades

static func coin_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func has_coin(level: int, cell: Vector2i) -> bool:
	return all_coins_debug or coin_key(cell) in coins_found.get(level, [])


## Picks up a coin (once) and saves right away, so it counts even if the run ends in a dry-up.
## While `assisted` (the slime reserve is on) nothing is stored: those coins don't count later.
func collect_coin(level: int, cell: Vector2i, assisted := false) -> void:
	if assisted or has_coin(level, cell):
		return
	if not coins_found.has(level):
		coins_found[level] = []
	coins_found[level].append(coin_key(cell))
	save_progress()
	report_progress("coins", coins_earned())


func coins_found_in(level: int) -> int:
	var level_coins: Array = coins_found.get(level, [])
	if level >= 1 and level <= Levels.COINS.size():
		return mini(level_coins.size(), Levels.COINS[level - 1])
	return level_coins.size()


func coins_earned() -> int:
	var total := 0
	for level: int in coins_found:
		total += coins_found_in(level)
	return total


## Coins found in this build's story levels: every level in the full game; in the demo only levels
## 1..Demo.levels() (a guarded full save's later coins, or a desktop demo save's level 4 on the web, don't
## count there).
func coins_earned_here() -> int:
	if not Demo.on():
		return coins_earned()
	var total := 0
	for level in range(1, Demo.levels() + 1):
		total += coins_found_in(level)
	return total


## Coins in the upgrade tree at this build's prices. In the demo: Demo.prices, so only the levels up to each
## demo cap cost anything (a guarded full save's levels above the caps are kept but neither cost nor refund).
func coins_spent() -> int:
	var total := 0
	for id: String in upgrades:
		total += Upgrades.total_cost(id, upgrades[id])
	return total


## Found minus spent, unclamped (the load checks use it to refit a save that spent more than it found).
func _coins_balance() -> int:
	return coins_earned_here() - coins_spent() + (dev_coins if dev_tools else 0)


## Coins in hand (found minus what's in the upgrade tree). In the demo never below 0 (a guarded full save
## is left as it is) and never above Demo.coins_total() (only the demo's levels count).
func coins() -> int:
	return maxi(_coins_balance(), 0) if Demo.on() else _coins_balance()


## True if some coin upgrade can be bought now (under its cap, affordable): the R prompt's demo check.
func upgrade_buyable() -> bool:
	for upgrade: Dictionary in Upgrades.LIST:
		var id: String = upgrade.id
		if not upgrade.get("dev", false) and upgrade_level(id) < Demo.upgrade_cap(id) and coins() >= Upgrades.cost(id, upgrade_level(id)):
			return true
	return false


func upgrade_level(id: String) -> int:
	if Upgrades.get_upgrade(id).get("dev", false) and not dev_tools:
		return 0
	return int(upgrades.get(id, 0))


## Puts coins into an upgrade (one level). Returns false if it's maxed or too expensive.
func buy_upgrade(id: String) -> bool:
	var upgrade := Upgrades.get_upgrade(id)
	if upgrade.is_empty() or (upgrade.get("dev", false) and not dev_tools):
		return false  # unknown, or the dev-only wall power outside dev mode (E3)
	var level := upgrade_level(id)
	if level >= Demo.upgrade_cap(id) or coins() < Upgrades.cost(id, level):
		return false  # (maxed, or at the demo's cap: Demo.upgrade_cap is max_level in the full game)
	upgrades[id] = level + 1
	save_progress()
	return true


## Lowers by one level the upgrade whose top level costs the most at this build's prices (the first in
## Upgrades.LIST on a tie): a demo save's levels, bought at the demo's prices, refitted to the coins found.
## False if nothing is left to lower.
func _drop_priciest_level() -> bool:
	var pick := ""
	var most := -1
	for upgrade: Dictionary in Upgrades.LIST:
		var id: String = upgrade.id
		var level := int(upgrades.get(id, 0))
		if level > 0 and Upgrades.cost(id, level - 1) > most:
			most = Upgrades.cost(id, level - 1)
			pick = id
	if pick == "":
		return false
	if upgrades[pick] <= 1:
		upgrades.erase(pick)
	else:
		upgrades[pick] -= 1
	return true


## Takes one level's coins back out of an upgrade.
func refund_upgrade(id: String) -> bool:
	var level := upgrade_level(id)
	if level <= 0:
		return false
	if level == 1:
		upgrades.erase(id)
	else:
		upgrades[id] = level - 1
	save_progress()
	return true


func set_jelly(on: bool) -> void:
	jelly = on
	Skins.jelly = on


func set_pastel(on: bool) -> void:
	pastel = on
	Skins.pastel = on


## Randomizer mode opens once all the story levels are beaten.
func is_randomizer_unlocked() -> bool:
	if Demo.on():  # the demo's randomizer opens after its last level (and not at all where it is left out)
		return Demo.randomizer_open() and levels_cleared >= Demo.levels()
	return levels_cleared >= Levels.COUNT


func is_hat_unlocked(id: String) -> bool:
	if dev_tools and not Hats.get_hat(id).is_empty():
		return true  # dev mode can try on every hat, even before they're released
	return Hats.is_unlocked(id, hats_owned)


## The hats still on the hat wheel: the ones not won yet.
## Every prize still on the hat wheel: the hats you don't have, then the wheel trails
## (Cosmetics.wheel_ids, not in the demo) you haven't won (dev mode's free cosmetics don't count).
func hats_left() -> Array[String]:
	var left: Array[String] = []
	for id in Hats.ids():
		if not id in hats_owned:
			left.append(id)
	if not Platform.is_demo():
		for id in Cosmetics.wheel_ids():
			if not id in cosmetics_owned:
				left.append(id)
	return left


## Whether the hat wheel can be spun right now: dev mode always (free); otherwise once hats are out
## (Hats.available), with a hat left to win and the first spin (free) or its price in tickets. The
## demo: not before its end screen, nor past Demo.HATS_MAX hats (demo_wheel_block), dev mode included.
func can_spin_hats() -> bool:
	if hats_left().is_empty() or demo_wheel_block() != "":
		return false
	if dev_tools:
		return true
	return Hats.available and spin_cost() <= tickets


## Why the demo's hat wheel can't spin (Demo.wheel_block: "closed" until the demo is completed, i.e. its
## last level cleared (even if the game was closed on the win row, before the end screen) or the end
## screen seen; "full" at Demo.HATS_MAX hats owned), or "" (always in the full game).
func demo_wheel_block() -> String:
	return Demo.wheel_block(levels_cleared >= Demo.levels() or has_seen_story(STORY_DEMO_END), hats_owned.size())


## What the next spin costs: nothing in dev mode and for the very first spin, then SPIN_COST plus
## SPIN_STEP for every spin already taken after the second, up to SPIN_COST_MAX.
func spin_cost() -> int:
	return 0 if dev_tools or spins == 0 else spin_cost_after(spins)


## The price of the spin that follows `taken` spins (0 = the free first one).
static func spin_cost_after(taken: int) -> int:
	if taken <= 0:
		return 0
	# The step count is clamped first, so no input (not even one near 2^62) can overflow into a negative price.
	return clampi(SPIN_COST + SPIN_STEP * mini(taken - 1, 20), SPIN_COST, SPIN_COST_MAX)


## Whether hat `id` is one of the wheel's rare prizes (Economy.WHEEL_RARE).
static func is_rare_hat(id: String) -> bool:
	return id in Economy.WHEEL_RARE


## How likely the wheel is to land on hat `id` next to the others (its wedge's share): the odds
## table in Economy (WHEEL_WEIGHT / WHEEL_RARE_WEIGHT), plus Hats.PITY_STEP per missed spin
## (`pity`) for the flowing (rainbow) hat.
static func wheel_weight(id: String, pity := 0) -> float:
	var w := Economy.WHEEL_RARE_WEIGHT if is_rare_hat(id) else Economy.WHEEL_WEIGHT
	if Hats.get_hat(id).get("flows", false):
		w += maxi(pity, 0) * Hats.PITY_STEP
	return w


## The hat a spin lands on: `roll` (0-1) walked along the wheel weights of `ids`, in order.
static func wheel_pick(ids: Array, pity: int, roll: float) -> String:
	if ids.is_empty():
		return ""
	var total := 0.0
	for id: String in ids:
		total += wheel_weight(id, pity)
	var at := clampf(roll, 0.0, 0.999999) * total
	for id: String in ids:
		at -= wheel_weight(id, pity)
		if at < 0.0:
			return id
	return ids[-1]


## The hats the next spin can land on: every hat left, except on this save's first spin (spins == 0,
## which a fresh save, RESET PROGRESS, a new epoch and a code that never spun all start at), which
## leaves the rare ones out so wiping a save for another free spin can never win one. (Only if
## nothing but rare hats is left on a first spin, which no real play reaches, are they in.)
func wheel_pool() -> Array[String]:
	var left := hats_left()
	if spins > 0:
		return left
	var common: Array[String] = []
	for id in left:
		if not is_rare_hat(id):
			common.append(id)
	return common if not common.is_empty() else left


## One whole spin, done before the wheel starts turning: picks the hat (the rare rainbow hat gets
## more likely with every spin that misses it), takes the tickets, wins the hat and saves, all
## together, so closing the game mid-spin can't lose a payment or a prize. `roll` (0-1) picks
## the hat; leave it -1 for a random one. Returns the hat's id, or "" if it can't spin.
## The next spin's roll (0-1): fixed by wheel_seed and the spins made so far.
func wheel_roll() -> float:
	if wheel_seed == 0:
		wheel_seed = randi() | 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([wheel_seed, spins])
	return rng.randf()


func spin_hat(roll := -1.0) -> String:
	if not can_spin_hats():
		return ""
	var pick := wheel_pick(wheel_pool(), rainbow_pity, wheel_roll() if roll < 0.0 else roll)
	_pay(spin_cost())
	spins += 1
	rainbow_pity = 0 if Hats.get_hat(pick).get("flows", false) else mini(rainbow_pity + 1, RAINBOW_PITY_MAX)
	win_hat(pick)  # saves everything above too
	return pick


# ---------------------------------------------------------------- hat dyes (the SHOP's DYES)

## Whether "hat:dye" names a real dye of a real dyeable hat (Hats.dyes_for).
static func _dye_key_valid(key: String) -> bool:
	return key.get_slice_count(":") == 2 and key.get_slice(":", 1) in Hats.dyes_for(key.get_slice(":", 0))


## Whether dye `dye` of hat `hat` is yours (dev mode: every dye).
func owns_dye(hat: String, dye: String) -> bool:
	return dye in Hats.dyes_for(hat) and (dev_tools or "%s:%s" % [hat, dye] in hat_dyes_owned)


## The dye hat `hat` is worn in ("": its own color).
func hat_dye_of(hat: String) -> String:
	var dye: String = hat_dyes.get(hat, "")
	return dye if owns_dye(hat, dye) else ""


## What dye `dye` costs (0 in dev mode): the RAINBOW dye more than the others.
func dye_price(dye := "") -> int:
	if dev_tools:
		return 0
	if not Hats.dye_flows(dye):
		return Economy.DYE_PRICE
	return Economy.DYE_PRISM_PRICE if dye == "prism" else Economy.DYE_RAINBOW_PRICE


## A dye can be bought for a hat you have won, in a dye it comes in and you don't own yet.
func can_buy_dye(hat: String, dye: String) -> bool:
	return Demo.shop_open() and is_hat_unlocked(hat) and dye in Hats.dyes_for(hat) and not owns_dye(hat, dye) \
		and dye_price(dye) <= tickets


## Buys dye `dye` for hat `hat` and puts the hat on in it (pay + own + wear + save at once).
## False if it can't be bought.
func buy_dye(hat: String, dye: String) -> bool:
	if not can_buy_dye(hat, dye):
		return false
	_pay(dye_price(dye))
	hat_dyes_owned.append("%s:%s" % [hat, dye])
	wear_dye(hat, dye)  # saves
	return true


## Wears hat `hat` (if unlocked) in dye `dye` ("": its own color; only a dye you own). Saves.
## False if it can't.
func wear_dye(hat: String, dye: String) -> bool:
	if not is_hat_unlocked(hat) or (dye != "" and not owns_dye(hat, dye)):
		return false
	if dye == "":
		hat_dyes.erase(hat)
	else:
		hat_dyes[hat] = dye
	selected_hat = hat
	save_progress()
	return true


## Takes `amount` tickets (never below 0) and counts them as spent. Doesn't save.
func _pay(amount: int) -> void:
	var paid := clampi(amount, 0, tickets)
	tickets -= paid
	tickets_spent = mini(tickets_spent + paid, 100 * TICKETS_MAX)


# ---------------------------------------------------------------- the ticket workshop and cosmetics

## The level in effect: 0 while the workshop is switched off (Economy.WORKSHOP_ENABLED); the saved
## level stays in `workshop` (see workshop_saved_level).
func workshop_level(id: String) -> int:
	return int(workshop.get(id, 0)) if Economy.workshop_on() else 0


## The level held in the save, whether or not the workshop is on.
func workshop_saved_level(id: String) -> int:
	return int(workshop.get(id, 0))


## What the next level of workshop track `id` costs (0 when maxed, and in dev mode).
func workshop_cost(id: String) -> int:
	return 0 if dev_tools else Workshop.cost(id, workshop_level(id))


## The TICKETS tab opens once the player has ever had a ticket (dev mode always).
func workshop_open() -> bool:
	return Economy.workshop_on() and (dev_tools or tickets_lifetime > 0)


func can_buy_workshop(id: String) -> bool:
	return workshop_open() and workshop_level(id) < Workshop.max_level(id) and workshop_cost(id) <= tickets


## Buys the next level of workshop track `id` (pay + level + save at once). Not refundable.
func buy_workshop(id: String) -> bool:
	if not can_buy_workshop(id):
		return false
	_pay(workshop_cost(id))
	workshop[id] = workshop_level(id) + 1
	save_progress()
	return true


# ---------------------------------------------------------------- ABILITIES v1

## The level in effect: 0 while the abilities are switched off (Economy.ABILITIES_ENABLED); the saved
## level stays in `abilities`.
func ability_level(id: String) -> int:
	return int(abilities.get(id, 0)) if Economy.abilities_on() else 0


## What the next level of ability `id` costs (0 when maxed, and in dev mode).
func ability_cost(id: String) -> int:
	return 0 if dev_tools else Abilities.cost(id, ability_level(id))


## The TICKETS tab's abilities open once the player has ever had a ticket (dev mode always).
func abilities_open() -> bool:
	return Economy.abilities_on() and (dev_tools or tickets_lifetime > 0)


func can_buy_ability(id: String) -> bool:
	return abilities_open() and Demo.ability_open(id) and Abilities.max_level(id) > 0 and ability_level(id) < Abilities.max_level(id) \
		and ability_cost(id) <= tickets


## Buys the next level of ability `id` (pay + level + save at once). Not refundable.
func buy_ability(id: String) -> bool:
	if not can_buy_ability(id):
		return false
	_pay(ability_cost(id))
	abilities[id] = ability_level(id) + 1
	save_progress()
	return true


## Defaults are always owned; dev mode owns everything.
func owns_cosmetic(id: String) -> bool:
	if id == Cosmetics.DEFAULT_TRAIL or id == Cosmetics.DEFAULT_PAPER:
		return true
	return id in cosmetics_owned or (dev_tools and not Cosmetics.get_item(id).is_empty())


func cosmetic_price(id: String) -> int:
	return 0 if dev_tools else Cosmetics.price(id)


func can_buy_cosmetic(id: String) -> bool:
	return Demo.shop_open() and not Cosmetics.get_item(id).is_empty() and not Cosmetics.is_earned(id) and not Cosmetics.is_wheel(id) and not owns_cosmetic(id) and cosmetic_price(id) <= tickets


## Buys cosmetic `id` and puts it on (pay + own + wear + save at once). False if it can't.
func buy_cosmetic(id: String) -> bool:
	if not can_buy_cosmetic(id):
		return false
	_pay(cosmetic_price(id))
	cosmetics_owned.append(id)
	_wear(id)
	save_progress()
	return true


## Wears an owned cosmetic (or a default), replacing the one of its kind. Saves. False if not owned.
func equip_cosmetic(id: String) -> bool:
	if not owns_cosmetic(id) or Cosmetics.kind_of(id) == "":
		return false
	_wear(id)
	save_progress()
	return true


## Takes off cosmetic `id` if it is worn (back to its kind's default). Saves.
func unequip_cosmetic(id: String) -> void:
	if trail_style == id:
		trail_style = Cosmetics.DEFAULT_TRAIL
	elif map_paper == id:
		map_paper = Cosmetics.DEFAULT_PAPER
	save_progress()


## Wears an owned cosmetic; a paper is worn whole (its sheet, walls and route together).
func _wear(id: String) -> void:
	if Cosmetics.kind_of(id) == Cosmetics.TRAIL:
		trail_style = id
	else:
		map_paper = id


## The cheapest thing in the store not owned yet (hat spin, hat dye, workshop level, cosmetic)
## is affordable: the hub prompts show a "!" (spec C.3).
func store_affordable(where: String) -> bool:
	if dev_tools:
		return false
	var cheapest := TICKETS_MAX + 1
	if where == "upgrades":
		if not workshop_open() and not abilities_open():
			return false
		if workshop_open():
			for id in Workshop.ids():
				if workshop_level(id) < Workshop.max_level(id):
					cheapest = mini(cheapest, workshop_cost(id))
		if abilities_open():
			for id in Abilities.ids():
				if ability_level(id) < Abilities.max_level(id) and Demo.ability_open(id):
					cheapest = mini(cheapest, ability_cost(id))
	else:
		if Hats.available and not hats_left().is_empty() and Demo.hat_wheel_open() and demo_wheel_block() == "":
			cheapest = mini(cheapest, spin_cost())
		if not Demo.shop_open():
			return cheapest <= tickets  # (the demo: the SHOP is in the full game)
		for id in Cosmetics.ids():
			if not owns_cosmetic(id):
				cheapest = mini(cheapest, cosmetic_price(id))
		for hat in hats_owned:
			for dye in Hats.dyes_for(hat):
				if not owns_dye(hat, dye):
					cheapest = mini(cheapest, dye_price(dye))
	return cheapest <= tickets


## A hat won on the wheel: it's yours (off the wheel), and the slime puts it on. Saved.
func win_hat(id: String) -> void:
	if Cosmetics.is_wheel(id):  # a wheel trail: yours for good, and worn
		if not id in cosmetics_owned:
			cosmetics_owned.append(id)
			trail_style = id
			save_progress()
		return
	if id in hats_owned or Hats.get_hat(id).is_empty():
		return
	hats_owned.append(id)
	selected_hat = id
	save_progress()
	report_progress("hats", hats_owned.size())


## Wears hat `id` (if unlocked) and saves.
func select_hat(id: String) -> void:
	if is_hat_unlocked(id):
		selected_hat = id
		save_progress()


## Whether skin `id` can be worn: opaque (`jelly_version` false, normal-mode unlock) or as jelly
## (true, its hard-mode unlock), and in its pastel version (`pastel_version` true: also its randomizer
## wins, Skins.pastel_wins; never in the demo); null = in the version worn now (pastel only where the
## skin has one).
## Debug flag --promo (promo captures): RAINBOW and STOPWATCH read as locked whatever else is unlocked.
var promo_secrets_locked := false


func is_skin_unlocked(id: String, jelly_version: Variant = null, pastel_version: Variant = null) -> bool:
	var as_pastel: bool = (pastel and Skins.has_pastel(id)) if pastel_version == null else pastel_version
	if not Demo.skin_open(id, jelly if jelly_version == null else jelly_version) or (as_pastel and Demo.on()):
		return false  # (a full-game skin: a FULL GAME silhouette in the demo, even with a full save)
	if promo_secrets_locked and id in [Skins.RAINBOW, Skins.STOPWATCH]:
		return false  # (promo rule, owner 2026-10-20: the secret skins only ever as locked silhouettes)
	if dev_tools:
		return not as_pastel or Skins.has_pastel(id)
	return Skins.is_unlocked(id, levels_cleared, hard_cleared, jelly if jelly_version == null else jelly_version, coins_earned(), all_medals(), as_pastel, randoms_won)


## The skin in use right now: a level's forced first-run skin, else the selected one.
func active_skin() -> String:
	return skin_override if skin_override != "" else selected_skin


## Hard mode keeps its own records: saved under the level number + this.
const HARD_RECORDS := 100


func _record_key(level: int) -> int:
	return level + HARD_RECORDS if hard_mode else level


## Record time for a level (on the current mode) in seconds, or -1 if never cleared with a time.
func best_time(level: int) -> float:
	return best_times.get(_record_key(level), -1.0)


## Saves `seconds` as the level's record if it's the first time or faster. Returns true only when
## an existing record was beaten (a first clear just sets the record).
func record_time(level: int, seconds: float, save := true) -> bool:
	if not is_finite(seconds) or seconds < MIN_RECORD:
		return false  # no real clear is that fast (and a save could never read it back: _read drops it)
	var previous := best_time(level)
	if previous >= 0.0 and seconds >= previous:
		return false
	best_times[_record_key(level)] = seconds
	if save:
		save_progress()
	return previous >= 0.0


## True (once per level, saved) when the level's forced-skin notice should be shown.
func take_skin_notice(level: int) -> bool:
	if level in skin_notices_seen:
		return false
	skin_notices_seen.append(level)
	save_progress()
	return true


func set_hard_mode(on: bool) -> void:
	hard_mode = on
	save_progress()


## The skin earned by the level before `level` (Lime for level 1): the one a new level's very
## first attempt is played in, if the level hasn't been cleared yet.
func forced_skin_for(level: int) -> String:
	return Skins.skin_for_level(level - 1) if level > levels_cleared else ""


## The very first attempt at a new level equips the skin just earned, opaque (it stays equipped, so
## the menus match it; the player can change it any time after). Returns it, or "" if nothing changed.
## Each level does this once (saved).
func equip_first_run_skin(level: int) -> String:
	var skin := forced_skin_for(level)
	if skin == "" or level in skin_notices_seen or not is_skin_unlocked(skin, false):  # (its opaque version)
		return ""
	skin_notices_seen.append(level)
	var changed := selected_skin != skin or jelly or pastel
	selected_skin = skin
	set_jelly(false)
	set_pastel(false)
	save_progress()
	return skin if changed else ""


## Wipes all progress: levels, records, coins, upgrades, skins, hats and randomizer wins. Sound,
## volume, reduce motion, fog brightness, the language and key bindings are kept (they are preferences).
func reset_progress() -> void:
	levels_cleared = 0
	highest_unlocked = 1
	current_level = 1
	mode = MODE_STORY
	randoms_cleared = 0
	randoms_won = 0
	selected_skin = Skins.DEFAULT
	hub_skin = ""
	set_jelly(false)
	set_pastel(false)
	selected_hat = Hats.NONE
	hats_owned.clear()
	custom_color = Color8(239, 125, 47)
	hard_mode = false
	best_times = {}
	skin_notices_seen.clear()
	hard_cleared.clear()
	coins_found = {}
	upgrades = {}
	tree_refund_notice = 0
	skin_override = ""
	tutorial_seen = 0
	training_replay = false
	training_used = 0
	tour_replay = false
	training_skipped = false
	story_seen = 0
	dry_ups = {}
	tickets = 0
	tickets_lifetime = 0
	medals = {}
	spins = 0
	rainbow_pity = 0
	wheel_seed = 0
	hats_bought = 0
	hat_dyes_owned.clear()
	hat_dyes = {}
	tickets_spent = 0
	workshop = {}
	abilities = {}
	cosmetics_owned.clear()
	trail_style = Cosmetics.DEFAULT_TRAIL
	map_paper = Cosmetics.DEFAULT_PAPER
	random_pay_day = 0
	random_paid = 0
	random_paid_seeds.clear()
	random_seed_fresh = true
	random_attempts.clear()
	random_offer_shown.clear()
	random_tickets_taken.clear()
	assist_level = 0
	maps = {}
	maps_hint_seen = false
	descent_run = {}
	descent_resume = {}
	descent_best_floor = 0
	descent_best_time = 0.0
	descent_runs = 0
	descent_pay_day = 0
	descent_paid = 0
	descent_milestones = 0
	save_progress()


## Whether the hub's color can be chosen: normal mode beaten (all story levels cleared), or dev mode.
func hub_color_open() -> bool:
	return dev_tools or levels_cleared >= Levels.COUNT


## The skin the hub wears: "" = AUTO (the worn skin's), or the chosen one while it's allowed.
func hub_skin_in_use() -> String:
	if hub_skin == "" or not hub_color_open() or not (is_skin_unlocked(hub_skin, false) or is_skin_unlocked(hub_skin, true)):
		return ""
	return hub_skin


## The hub's color (the room and the stations): the chosen skin's, else the worn skin's.
func hub_color() -> Color:
	match hub_skin_in_use():
		"":
			return skin_color()
		Skins.STOPWATCH:
			return Skins.STOPWATCH_BASE
		Skins.RAINBOW:
			return Skins.RAINBOW_BASE
		Skins.CUSTOM:
			return hub_custom
	return Skins.get_preset(hub_skin_in_use()).color


## Whether the hub flows in rainbow colors (the chosen skin, else the worn one).
func hub_rainbow() -> bool:
	return is_rainbow() if hub_skin_in_use() == "" else hub_skin_in_use() == Skins.RAINBOW


## Sets the hub's color to skin `id` ("" = AUTO); false if that can't be chosen. Saves.
func set_hub_skin(id: String) -> bool:
	if id != "" and (not hub_color_open() or not (is_skin_unlocked(id, false) or is_skin_unlocked(id, true))):
		return false
	hub_skin = id
	if id == Skins.CUSTOM:
		hub_custom = custom_color
	save_progress()
	return true


## True when the rainbow skin is in use (and unlocked).
func is_rainbow() -> bool:
	return active_skin() == Skins.RAINBOW and is_skin_unlocked(Skins.RAINBOW)


## True when the stopwatch skin is in use (and unlocked).
func is_stopwatch() -> bool:
	return active_skin() == Skins.STOPWATCH and is_skin_unlocked(Skins.STOPWATCH)


func skin_color() -> Color:
	var id := active_skin()
	if skin_override == "" and not is_skin_unlocked(id):
		return Skins.get_preset(Skins.DEFAULT).color
	if id == Skins.STOPWATCH:
		return Skins.STOPWATCH_BASE
	if id == Skins.RAINBOW:
		return Skins.RAINBOW_BASE
	if id == Skins.CUSTOM:
		return custom_color
	if pastel and (skin_override == "" or Demo.preview):  # (the pastel version's color: its trail, meter and menu text match)
		return Skins.PASTEL.get(id, Skins.get_preset(id).color)
	return Skins.get_preset(id).color


## Wears skin `id` opaque (`jelly_version` false) or as jelly (true), and pastel or not
## (`pastel_version`; null = as now, where the skin has one), if that version is unlocked.
func select_skin(id: String, jelly_version: Variant = null, pastel_version: Variant = null) -> void:
	var as_jelly: bool = jelly if jelly_version == null else jelly_version
	var as_pastel: bool = (pastel if pastel_version == null else pastel_version) and Skins.has_pastel(id)
	if is_skin_unlocked(id, as_jelly, as_pastel):
		selected_skin = id
		set_jelly(as_jelly)
		set_pastel(as_pastel)
		save_progress()


# ---------------------------------------------------------------- sound

func set_volume(value: float, save := true) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()
	if save:
		save_progress()


func set_music_volume(value: float, save := true) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply_volume()
	if save:
		save_progress()


## The SFX and Music buses (made here, under Master, the first time) at their volumes.
func apply_volume() -> void:
	for pair in [[SFX_BUS, volume], [MUSIC_BUS, music_volume]]:
		var index := ensure_bus(pair[0])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(pair[1], 0.0001)))
		AudioServer.set_bus_mute(index, pair[1] <= 0.0)


## The index of audio bus `bus_name`. The buses are in res://default_bus_layout.tres (Master, SFX, Music),
## loaded at startup: they must exist from the start, since the web build's sample playback routes sounds
## through browser copies of the buses made then (a bus added at run time left the web silent). Adding one
## here is only a fallback. Players pick their bus by name (Sfx, Game's ambience: SFX_BUS; Music: MUSIC_BUS).
static func ensure_bus(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	return index


# ---------------------------------------------------------------- controls

## Whether `keycode` can become `action`'s key: a real key, not RESERVED_KEYS, and not the key of
## an action the CONTROLS page doesn't list (UNLISTED_ACTIONS).
func can_bind(action: String, keycode: int) -> bool:
	if keycode <= 0 or keycode > KEY_MAX_CODE or not action in DEFAULT_KEYS or keycode in RESERVED_KEYS:
		return false  # (not a key, which a save could never read back, or a key with a fixed job)
	for other: String in UNLISTED_ACTIONS:
		if other != action and bindings.get(other, 0) == keycode:
			return false
	return true


## Binds `keycode` as the primary key for `action`. If another action used that key, the two
## swap keys so no key is ever bound twice. A key can_bind refuses changes nothing.
func set_binding(action: String, keycode: int) -> void:
	if not can_bind(action, keycode):
		return
	for other: String in bindings:
		if other != action and bindings[other] == keycode:
			bindings[other] = bindings[action]
	bindings[action] = keycode
	apply_bindings()
	save_progress()


func reset_bindings() -> void:
	bindings = DEFAULT_KEYS.duplicate()
	apply_bindings()
	save_progress()


## Puts the key bindings into the input map (every event of a remappable action is replaced), then the fixed
## gamepad layout on top (Platform.PAD_BUTTONS; the left stick is PlatformEvents').
func apply_bindings() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _key_event(bindings[action]))
		var secondary: int = SECONDARY_KEYS.get(action, 0)
		if secondary != 0 and secondary != bindings[action]:
			InputMap.action_add_event(action, _key_event(secondary))
	Platform.apply_pad_layout()  # the fixed gamepad layer (D4), never wiped by a key change


## The name of a bound key (bindings are physical keys): the letter the player's keyboard layout prints
## on it (Z for the W key on AZERTY: Platform.key_label, desktop windows only).
static func key_name(keycode: int) -> String:
	if keycode == 0:
		return ""
	return OS.get_keycode_string(Platform.key_label(keycode as Key)).to_upper()


static func _key_event(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


# ---------------------------------------------------------------- trail map surveys

func survey_key(level: int, hard: bool) -> int:
	return clampi(level, 1, Levels.COUNT) + (HARD_RECORDS if hard else 0)


## The survey of a story level ({} = never recorded). A survey of another layout (an update re-laid
## the maze: its size or fingerprint no longer fits, Survey.fits) is stale: it is dropped here, so the
## level shows no survey and its next run starts a fresh one (and can set any route time).
func survey_for(level: int, hard: bool) -> Dictionary:
	var key := survey_key(level, hard)
	var survey: Dictionary = maps.get(key, {})
	if not survey.is_empty() and not Levels.has_data(level, hard):
		return {}  # (a demo export lacks this level: its survey is kept as it is, unread)
	if not survey.is_empty() and not Survey.fits(survey, Levels.story_maze(level, hard)):
		maps.erase(key)
		return {}
	return survey


## Merges one recorded attempt at a story level into its survey and saves (game.gd calls this once
## per real, unassisted, non-dev run, when it ends). `tiles`: one byte per maze tile, non-zero = seen
## this attempt; `moves`: the cells walked (Survey move codes) from the maze's start. The tiles seen
## are added to the ones seen before. The route is replaced by a clear only when it is faster than
## the stored clear (or there is none); without any clear yet, each attempt that moved replaces the
## faint last-attempt route. `goal_seen`: the goal came into view (a win counts). `coins_seen`: the
## coins this attempt's light revealed (merged into the survey's `seen_coins` while
## Economy.map_coin_reveal_on, saved beside it as [maps] coins_N).
func record_survey(level: int, hard: bool, maze: Dictionary, tiles: PackedByteArray, moves: PackedByteArray,
		won: bool, run_time: float, goal_seen: bool, coins_seen: Array[Vector2i] = []) -> void:
	if level < 1 or level > Levels.COUNT:
		return  # (not a story level: survey_key would clamp a Descent floor's 0 onto level 1)
	var key := survey_key(level, hard)
	var survey: Dictionary = maps.get(key, {})
	if not Survey.fits(survey, maze):  # never recorded, or stale (another layout): start afresh
		survey = Survey.blank(maze)
	Survey.merge_seen(survey, tiles)
	if goal_seen or won:  # the chalice was in sight: its tile counts as seen (the map only marks seen tiles)
		Survey.mark_seen(survey, maze.goal * 2 + Vector2i.ONE)
	survey.goal = survey.goal or goal_seen or won
	if not coins_seen.is_empty() and Economy.map_coin_reveal_on(dev_tools):
		var known: Array = survey.get("seen_coins", [])
		for cell in coins_seen:
			if not cell in known:
				known.append(cell)
		survey.seen_coins = known
	var route := moves.slice(0, Survey.MAX_MOVES)
	if won and is_finite(run_time) and run_time > 0.0:
		var ms := clampi(roundi(run_time * 1000.0), 1, Survey.MAX_MS)
		if not survey.clear or ms < survey.best_ms:
			survey.clear = true
			survey.best_ms = ms
			survey.moves = route
			survey.start = maze.start
	elif not survey.clear and not route.is_empty():
		survey.moves = route
		survey.start = maze.start
	maps[key] = survey
	save_progress()


## The coins the MAP TABLE draws on a level's map: never a collected one; with the map coin reveal on
## (Economy.map_coin_reveal_on: everyone, unless --nocoinreveal) the uncollected coins its survey's
## runs revealed (`seen_coins`). Hard maps have no coins.
func map_coins(level: int, hard: bool) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if hard or not Economy.map_coin_reveal_on(dev_tools):
		return cells
	var seen: Array = survey_for(level, hard).get("seen_coins", [])
	for cell in Levels.story_coin_cells(level):
		if cell in seen and not has_coin(level, cell):
			cells.append(cell)
	return cells


## Every story level, normal and hard, fully surveyed (Survey.full): its best route = the shortest
## route, in the level's record time if it has one (else par). For --story-complete / --maps=full.
func seed_full_surveys() -> void:
	for level in range(1, Levels.COUNT + 1):
		for hard in [false, true]:
			var key := survey_key(level, hard)
			maps[key] = Survey.full(Levels.story_maze(level, hard), best_times.get(key, Levels.level_par(level, hard)))
