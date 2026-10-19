# Demo build plan (owner request 2026-10-19)

A free demo that shows everything the game has, but leaves the player wanting the full game. Same codebase as
the full game: one switch, a handful of gates, no copied scenes or scripts. Advisor input:
[advisor/demo.md](advisor/demo.md) (end screen as the pitch, web variant, honest carry-over, 3 levels).

## 1. The switch

- `Platform.is_demo()` (`scripts/platform.gd`, the platform seam) is true when the export preset has the custom
  feature **`demo`** (step 2 adds the demo presets), or on the debug launch flag **`--demo`**
  (`./tools/play.sh --demo`, `.\tools\play.ps1 -Demo`; a release export ignores debug flags as usual).
  Tests force it with `Platform.demo_override` (1 on, 0 off, -1 real; `Platform.reset_overrides()`).
- Every gate asks the **`Demo`** class (`scripts/demo.gd`). With the switch off every `Demo` query answers
  "full game" (`Demo.levels() == 10`, no cap, everything open), so the full game is unchanged
  (`tests/test_demo.gd` section 2 checks it; the story mazes are byte-identical, see section 6).
- `--demo` runs on a **clean in-memory save** like `--tutorial` (the real save is never read or written: a debug
  flag means a throwaway save path). To try the carry-over, add `--save-path=user://demo_try.cfg`: that file is
  then loaded and kept between launches (never the real save; `--save-path=` refuses it for debug runs).

## 2. Config knobs (all in `scripts/demo.gd`)

| knob | default | meaning |
|---|---|---|
| `LEVELS` / `WEB_LEVELS` | 3 / 3 | story levels in the demo (desktop / web build) |
| `HARD_LEVELS` | 1 | hard levels (hard 1 unlocks jelly Lime and jelly Mint, the existing rule: both have hard level 1) |
| `UPGRADE_CAP` | 2 | each coin upgrade can be bought up to this level; the rest of the bar is darker, its cost says FULL |
| `RANDOMIZER` / `WEB_RANDOMIZER` | true / false | randomizer on desktop / web (the web demo leaves it out by default) |
| `HAT_WHEEL` / `WEB_HAT_WHEEL` | true / false | hat wheel on desktop / web |
| `RANDOM_SEEDS` | 1016, 1063, 1015 | the demo's randomizer mazes in order (usage 50 / 57 / 62 %, themes dungeon / mossy / sandstone); then they replay (replay pay) |
| `ABILITIES` | `["rifle"]` | abilities that can be bought and that work in a maze (a full save's others are switched off) |
| `WISHLIST_URL` | `""` | store page for every WISHLIST button; **empty = every WISHLIST button is hidden** (no Steam page yet) |
| `TEASER_LEVELS` | 4, 6, 7, 9, 10 | the end screen's teaser cards |
| `END_SEEN_BIT` | 4 | `Progress.story_seen` bit: the end screen was seen (the full game ignores it) |

## 3. What the demo has and how each lock looks

- **Story:** levels 1-3 (Dark Dungeon, Mossy Mines, Sandstone Sanctum) with their coins. The level select shows all
  10 tiles; 4-10 carry a gold lock and FULL, stay pressable and open the end screen. The info lines say
  LEVELS 4-10 ARE IN THE FULL GAME (hard: HARD 2-10 AND HEAT: FULL GAME). The hub archway's prompt adds FULL GAME
  once the next level is a full-game one. The HUD still says LEVEL n/10 (the full game's size, on purpose).
- **End screen** (`scenes/demo_end.tscn`, `scripts/ui/demo_end.gd`): after the level-3 chalice the win row is
  CONTINUE only the first time (every finisher sees the pitch before the hub and the randomizer), later
  REPLAY / CONTINUE / HUB. Also after the third demo maze is first won (top line: the full game's endless mazes
  and 3 abilities), and from any FULL GAME level tile. Layout: END OF THE DEMO, a story-voice line (THE WAY OUT
  IS STILL UP THERE), WISHLIST (hidden while the URL is empty; focused first when shown), five teaser cards that
  flip by themselves every 3.2 s (< > or LB / RB flip them: area name, LEVEL n - FULL GAME, what's new there, and
  a made-up map in that area's colours), the carry-over line, KEEP PLAYING (back to the hub; Esc too).
  **Teaser = title cards, not stills (my call):** the cards are built from names (strings the demo has anyway)
  and the map table's example maze in each theme's palette (`MapView.preview`: hashed from the level number,
  not the real maze). No later-level art, data or text ships, so nothing to strip or leak. Real screenshots
  of later areas belong on the store page.
- **Carry-over line (only where true):** desktop: YOUR PROGRESS CARRIES OVER TO THE FULL GAME (same save folder).
  Web: COPY YOUR SAVE CODE TO KEEP YOUR PROGRESS plus a SAVE CODE button (opens SETTINGS on the save-code panel):
  a browser save can never reach a desktop install. A Steam demo has its own app id and no shared Steam Cloud,
  so a Steam demo build should get the web wording too (or point at the save code) unless both read the same
  local folder (they do when `custom_user_dir_name` stays `SlimeTime_R1`).
- **WISHLIST** also as a quiet pause-menu button and a small hub sign under the ticket pod (after the end screen
  was seen); all hidden while `WISHLIST_URL` is empty. `Demo.open_wishlist()` uses `OS.shell_open` (a new tab
  on the web); a Steam build should route it to the overlay through `Platform` later.
- **Upgrades:** the cauldron works; each coin upgrade stops at level 2 (cost column FULL in gold, darker pips past
  the cap, hint line UPGRADES PAST LEVEL 2: FULL GAME). TICKETS tab: only SLIME RIFLE can be bought (the others
  show FULL); in a maze only RIFLE works (`AbilityRunner.create`).
- **Hard mode:** level 1 only; HEAT hidden (button and panel) and `heat_unlocked` false.
- **Randomizer:** opens after level 3 (`Progress.is_randomizer_unlocked`), plays `RANDOM_SEEDS` in turn (they pay
  tickets as usual), only the demo's themes (`Themes.for_seed` picks from `Demo.themes()`), no typed seeds (the
  pause menu's seed button is hidden). Locked portal prompt: CLEAR LEVEL 3; on the web (left out): FULL GAME.
- **Hat wheel:** works (free first spin + tickets from the mazes); on the web left out (station dimmed, FULL GAME).
  **SHOP:** on show, nothing for sale (status line THE SHOP OPENS IN THE FULL GAME, prices dimmed;
  `can_buy_cosmetic` / `can_buy_hat` false; the hub's "!" ignores it).
- **Skins:** Lime, Mint, Lemon, Ocean (opaque) and jelly Lime / Mint; every other skin is a silhouette whose
  status line says NAME - IN THE FULL GAME (`Progress.is_skin_unlocked` asks `Demo.skin_open`, so a full save
  shows the demo's skins only).
- **Maps / medals / records:** for the demo's levels; the map table keeps 4-10 sealed (even with a full save's surveys).
- Workshop and Descent stay off as in the full game. Intro + SPLASHDOWN tutorial are unchanged.

## 4. Full-game-only content (for step 2: the export exclude list)

**Single source of truth: `Demo.full_only_paths(web := false)`.** Print it with
`godot --path . --headless -s res://tools/demo_paths.gd [-- --web]`: one path per line, then a line
`EXCLUDE: a, b, c` ready for the demo preset's `exclude_filter` (add it to the usual `tests/*, tools/*, ...`).
It is computed from `Demo.LEVELS` / `WEB_LEVELS` / `HARD_LEVELS`, `Levels.data_path` and `Themes`, so changing a
knob changes the list. Today (desktop; web the same while `WEB_LEVELS` is 3):

| what | paths |
|---|---|
| story level data + banner line, levels 4-10 | `res://scripts/level_data/level_04.gd` .. `level_10.gd` |
| hard level tables, hard 2-10 | `res://scripts/level_data/hard_02.gd` .. `hard_10.gd` |
| tile art of the 7 later themes | `res://assets/sprites/themes/{sunken,sewers,catacombs,frozen,obsidian,crystal,volcanic}_{walls,floors,fillets,border}.png` (+ `.import`) |
| ambience of the 7 later themes | `res://assets/sounds/ambient_{theme}.wav` and `ambient_{theme}_N.wav` (+ `.import`) |

How the code keeps this possible:
- `Levels` reads each level from its own file (`scripts/level_data/level_NN.gd`: `NORMAL` recipe + `line()`;
  `hard_NN.gd`: `HARD` tables) by `load()` on first use, never at startup and never `preload`. `Levels.has_data`
  says whether a level is in this build; `Demo.can_load(path)` is the one check (`ResourceLoader.exists`, plus the
  tests' strip simulation). A missing level borrows level 1's data with a warning instead of crashing, and callers
  check first: the game falls back to the demo's last level, `Story.level_line` is empty, `Progress` keeps a full
  save's surveys and medals of missing levels untouched (`survey_for`, `_tier_from_record`).
- Theme art and ambience were already loaded by path for the current theme only (`MazeTiles`, `game.gd`); the demo
  only ever plays the demo's themes (story levels 1-3 and `Themes.for_seed` in the demo).
- The data files have no `class_name` (nothing in the global class cache points at them).
- `tests/test_demo.gd` plays levels 1-3 to the chalice and the first demo maze with `Demo.strip_test` on (every
  full-only path treated as absent) and checks that nothing asked for one (`Demo.denied`) and that none is in the
  resource cache (`ResourceLoader.has_cached`) afterwards.

Step 2 checklist: add `custom_features="demo"` presets (Windows, macOS, Linux, Web) with the exclude list; export;
open the export and play it through once (a missing file shows up as a load error in the log); keep
`custom_user_dir_name` = `SlimeTime_R1` so desktop carry-over works.

**What can't be protected:**
- The **code** ships in the demo: `game.gd`, the maze generator, the finale cutscene (`story_screen.gd` draws it
  in code), the HEAT / SHOP / Descent / workshop logic, `Themes` (names, fog colours), `MapView.THEMED` (palettes),
  `Skins.PRESETS`, `Levels.COINS` (coin counts per level, kept in code: `Levels.total_coins()` and the rainbow skin
  need them). Without the level files someone could still invent their own seeds.
- `assets/sprites/coins.png` holds all 10 coin metals in one sheet (a small leak; split it per theme if it matters).
- The translation catalogs (`locale/*.po`) hold every string, including the later levels' banner lines. They are
  English-only fallbacks today; step 2 can drop the `story.level_4` .. `story.level_10` entries from a demo copy of
  the catalogs, or ship the demo with languages off.
- **Optional deterrent later:** PCK encryption (`encrypt_pck` / `encrypt_directory` with a script encryption key)
  needs export templates compiled with that key (a custom template build). It slows casual extraction, it doesn't
  stop a determined one (the key is in the binary).

## 5. Save carry-over

- The demo writes the **same save** (same dir `SlimeTime_R1`, same format and version) with `[meta] demo = true`.
- **Full game loading a demo save:** reads everything (nothing is demo-only or dropped), and its next save simply
  doesn't write the marker. Same for a demo save code pasted into the full game.
- **Demo loading a full-game save** (no marker; someone who owns both, or a full code pasted into the demo): the
  demo plays it **in memory only** and never writes it (`Progress.demo_guard`: `save_progress` is a no-op, even
  RESET PROGRESS), so the full save stays byte-identical. It shows only the demo's content (levels, skins, maps,
  abilities are gated by `Demo`, not by clamping the loaded values). Open question for the owner: show a small note
  ("FULL GAME SAVE: THE DEMO WON'T CHANGE IT") somewhere, e.g. on the title?
- Demo progress then carries over by itself on the same machine (desktop). Web: by save code only (end screen).
- A demo save that already has more than the demo allows (hand-made, or the --save-path test file) is just loaded.

## 6. Mazes unchanged

Moving the level tables into `scripts/level_data/` kept every value: all 20 story digests (`test_maze_golden`'s
`story N normal|hard` lines: walls, start, goal, coins, route, par) were rebuilt and compared equal to
`tests/data/maze_golden.txt` (on Windows the golden file's CRLF line ends make that suite fail as before; the
digests themselves match). `test_hard_rebalance` reads the tables through `Levels.hard_data`.

## 7. Text

English only (owner rule), every string through `Loc.t` with `# i18n:` hints; catalogs merged
(`python tools/i18n_extract.py --merge`), row in `docs/i18n/pending.md`; the capture gate has four demo states
(`demo level select`, `demo upgrades capped`, `demo skin locked`, `demo end screen`). Screenshots: `docs/demo/`.
