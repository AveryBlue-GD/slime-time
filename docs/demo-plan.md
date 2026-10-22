# Demo build plan (owner request 2026-10-19)

A free demo that shows everything the game has, but leaves the player wanting the full game. Same codebase as
the full game: one switch, a handful of gates, no copied scenes or scripts. Advisor input:
[advisor/demo.md](advisor/demo.md) (end screen as the pitch, web variant, honest carry-over, 3 levels).

## 1. The switch

- `Platform.is_demo()` (`scripts/platform.gd`, the platform seam) is true when the export preset has the custom
  feature **`demo`** (the "... Demo" export presets, section 8), or on the debug launch flag **`--demo`**
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
| `LEVELS` / `WEB_LEVELS` | 4 / 4 | story levels in the demo (desktop / web build; owner 2026-10-19: the desktop demo has Sunken Shrine too; owner 2026-10-21: the web demo has the same 4 levels) |
| `HARD_LEVELS` | 1 | hard levels (hard 1 unlocks jelly Lime and jelly Mint, the existing rule: both have hard level 1) |
| `UPGRADE_CAPS` / `WEB_UPGRADE_CAPS` | `{"slime": 3, "speed": 2, "brightness": 1}` / the same (`= UPGRADE_CAPS`) | how far each coin upgrade can be bought (an upgrade not listed: 0); the rest of the bar is darker, its cost says FULL. Coin math below |
| `PRICES` / `WEB_PRICES` | slime 1, 4, 6; speed 6, 8; brightness 9 (= 34) / the same (`= PRICES`) | the demo's own coin prices, one per capped level (`Upgrades.cost` / `total_cost` use them while the demo is on); they add up to exactly the coins of the demo's levels |
| `HATS_MAX` | 2 | hats the demo's wheel gives at most; with that many owned it doesn't spin (a guarded full save that owns more: no spins either) |
| `RANDOMIZER` / `WEB_RANDOMIZER` | true / true | randomizer on desktop / web (owner 2026-10-21: the web demo has it too, no FULL GAME lock) |
| `HAT_WHEEL` / `WEB_HAT_WHEEL` | true / true | hat wheel on desktop / web (web too since 2026-10-21) |
| `RANDOM_WINS` | 3 | randomizer wins before the end screen's pitch (shown once, after that win); every maze is a new random one, as in the full game |
| `GENTLE_MAZES`, `GENTLE_MAX_USAGE` | 3, 750 | the first 3 randomizer mazes (by wins) are drawn from seeds whose perfect route uses at most 75% of the meter (no 90%+ marathon first); later ones any seed |
| `ABILITIES` | `["rifle"]` | abilities that can be bought and that work in a maze (a full save's others are switched off) |
| `ABILITY_PRICES` | `{"rifle": [5]}` | the demo's ticket prices for an ability's first levels (full game: SLIME RIFLE 15), so it is in reach before the randomizer's end screen (a win pays at most 5) |
| `WISHLIST_URL` | `""` | store page for every WISHLIST button; empty = the Steam page of `STEAM_APP_ID`; **with neither, every WISHLIST button is hidden** (no Steam page yet) |
| `STEAM_APP_ID` | `0` | the FULL game's Steam app id: the Steam build opens its page in the Steam overlay ([steam-setup.md](steam-setup.md)) |
| `TEASER_LEVELS` | 6, 7, 9, 10 | the end screen's teaser cards after the first one, which is always the area right after the demo (`Demo.teasers()`: 5, 6, 7, 9, 10); the first card says {count} MORE AREAS (6) |
| `END_SEEN_BIT` | 4 | `Progress.story_seen` bit: the end screen was seen (the full game ignores it); also opens the demo's hat wheel |

**Coin math (owner 2026-10-20).** The demo has its own prices (`PRICES`, not `Economy.COIN_TRACKS`), and they add up
to **exactly** the coins its levels hide (`Demo.coins_total()`, from `Levels.COINS`): desktop MORE SLIME 1 + 4 + 6,
SPEED 6 + 8, BRIGHTNESS 9 = **34** = 6 + 9 + 7 + 12 (levels 1-4), on desktop and web (`WEB_UPGRADE_CAPS` / `WEB_PRICES`
are the desktop's since the web demo got level 4, 2026-10-21; a 3-level web demo would be MORE SLIME 1 + 5, SPEED 7,
BRIGHTNESS 9 = 22). Every coin found has a use and finding them all buys
every demo level with 0 left. `tests/test_demo.gd` checks per platform: prices == coins, one price per capped level,
buying everything with all coins leaves 0, refunds give the demo prices back.
**Saves:** coins in hand are derived (found minus `Upgrades.total_cost` at this build's prices), so a demo save simply
re-prices. On load, a demo save in the demo is clamped to this platform's caps; a demo-marked save whose levels cost
more than the coins found at this build's prices (the full game's are higher: slime 3 + speed 2 + brightness 1 =
36 > 34) loses one level at a time from the track with the priciest top step (`Progress._drop_priciest_level`), so
the full game keeps as much as fits (34 coins: slime 3, speed 1, brightness 1, 7 in hand) and coins in hand never go
negative. Other saves keep the old rule.
**Coins in hand in the demo** (`Progress.coins()`): max(0, coins found in levels 1..`Demo.levels()`
(`coins_earned_here()`) − the demo-priced cost of the levels within the demo caps). A guarded full save (a full
save opened in the demo, in memory only) keeps its upgrades as they are; its levels above the caps neither cost nor
refund anything there, so the hand is never above `Demo.coins_total()` (a maxed full save: 0) and never below 0
(nothing is erased). The R key's "spend coins first?" prompt opens in the demo only if some upgrade is buyable
(`Progress.upgrade_buyable()`). The full game's math is unchanged.

## 3. What the demo has and how each lock looks

- **Title:** a DEMO sticker (demo builds only, `Platform.is_demo()`; owner-approved mockup C, 2026-10-19): a cream
  paper sticker with a dark outline, rounded corners, its top-right corner peeled back (the grey underside folded
  over the cut) and a soft drop shadow, tilted 12 degrees clockwise, DEMO in the game's 5x7 font at 2x. Generated
  by `tools/make_demo_sticker.py` -> `assets/sprites/title/demo_sticker.png` (65x40): built flat, turned by three
  integer shears (whole-pixel row / column shifts, nothing blended), then outlined and shaded, so every edge is a
  clean 1 px line. The letters are in the slime sheet's goo shades (the logo's skin shader gives them the equipped
  skin; rainbow isn't a demo skin, but works too), the paper in fixed colors the shader leaves alone. Drips under
  D, E, M; none under the O (it read DEMP). Placed at `title.gd` `DEMO_STICKER_POS` (4, 60): under the logo's
  letters (`LOGO_LETTER_ROWS`: only drips run under it), by the left slime and over its hat (owner: fine), clear
  of ENTER THE HUB (x 72); `tests/test_demo.gd` checks all of it and that the full game has no sticker. **The PNG
  ships in the full exports too** (633 bytes, never loaded there; not worth a cut-list entry).
- **Story:** levels 1-4 (Dark Dungeon, Mossy Mines, Sandstone Sanctum, Sunken Shrine; the web demo too since 2026-10-21) with their
  coins. The level select shows all 10 tiles; 5-10 (hard: 2-10) are **plain locks** (owner, 2026-10-19): the same dim lock as a level not unlocked
  yet in the full game, no FULL text, disabled, pressing one does nothing. The info lines are the full game's
  (CLEAR A LEVEL TO UNLOCK THE NEXT / EACH CLEAR ALSO UNLOCKS A NEW SKIN); hard: one line, BEAT A LEVEL ON HARD
  FOR ITS JELLY SKIN (the full game's hard line too). The hub archway says LOCKED once the next level is a full-game one.
  The map table keeps the later levels sealed. The HUD still says LEVEL n/10 (the full game's size, on purpose).
- **End screen** (`scenes/demo_end.tscn`, `scripts/ui/demo_end.gd`): after the last demo level's chalice (level 4) the win row is
  CONTINUE only the first time (every finisher sees the pitch before the hub and the randomizer), later
  REPLAY / CONTINUE / HUB. Also after the third demo maze is first won (top line: the full game's endless mazes
  and 3 abilities). Not from a level tile any more (locked tiles do nothing). Layout: END OF THE DEMO, a story-voice line (THE WAY OUT
  IS STILL UP THERE), WISHLIST (hidden while the URL is empty; focused first when shown), five teaser cards that
  flip by themselves every 3.2 s (< > or LB / RB flip them: area name, LEVEL n - FULL GAME, what's new there, and
  a made-up map in that area's colours), KEEP PLAYING (back to the hub; Esc too).
  **Teaser = title cards, not stills (my call):** the cards are built from names (strings the demo has anyway)
  and the map table's example maze in each theme's palette (`MapView.preview`: hashed from the level number,
  not the real maze). No later-level art, data or text ships, so nothing to strip or leak. Real screenshots
  of later areas belong on the store page.
- **No word about carry-over (owner, 2026-10-19):** nothing the player sees says or implies that demo progress
  carries over to (or is kept from) the full game: the end screen's carry-over line, the web end screen's
  save-code pitch and SAVE CODE button, the SETTINGS note FULL GAME SAVE: THE DEMO WON'T CHANGE IT and the RESET
  confirm's demo lines are gone (keys removed: `demo.end.carry`, `demo.end.carry_web`, `demo.save_code`,
  `settings.demo_guard`, `reset.demo_guard.2`; with them `levels.demo_full`, `levels.demo_normal.2`,
  `levels.demo_hard.2`). The save behaviour itself is unchanged (section 5): the demo marks its saves, never
  writes over a full-game save, and on the same desktop the full game still reads a demo save. The SETTINGS page's
  own SAVE CODE panel is untouched (it's the full game's backup feature).
- **WISHLIST** also as a quiet pause-menu button and a small hub sign under the ticket pod (after the end screen
  was seen); all hidden while there is no store page (`Demo.store_url()` empty) and always in a phone app.
  `Demo.open_wishlist()` goes through `Platform.open_store_page`: the Steam overlay on the store page in the Steam
  build (GodotSteam `activateGameOverlayToStore`), else `OS.shell_open` (a new tab on the web). [steam-setup.md](steam-setup.md).
- **Coin bag (hub):** the demo's levels show found / total as usual; later levels show `?/?` (dim) and the
  STORY line counts only the demo's levels (`STORY n/34`; `Demo.coins_total()`), so the full game's 165 is
  never told (a guarded full save too).
- **Upgrades:** the cauldron works at the demo's `PRICES`; each coin upgrade stops at its `UPGRADE_CAPS` level (MORE
  SLIME 3, SPEED 2, BRIGHTNESS 1 (web too): cost column FULL in gold, darker pips past the cap, hint line MORE UPGRADE LEVELS IN THE FULL GAME). TICKETS tab: only SLIME RIFLE can be bought (the others
  show FULL); in a maze only RIFLE works (`AbilityRunner.create`).
- **Hard mode:** level 1 only.
- **Randomizer:** opens after the last demo level (`Progress.is_randomizer_unlocked`). As in the full game, every
  maze is a new random one (`Progress.new_random_maze`: a random seed, so a new layout and start; entering the portal,
  NEW MAZE after a dry-up and after a win; RESTART replays the same maze), paying tickets as usual. The end screen's
  pitch follows the `RANDOM_WINS`-th win. (Until 2026-10-20 the demo replayed three fixed seeds picked by
  `randoms_won`: a dry-up or a fresh portal visit gave the same Dark Dungeon maze and start again, owner bug report.)
  Only the demo's themes (`Themes.for_seed` picks from `Demo.themes()`), no typed seeds (the
  pause menu's seed button is hidden). Locked portal prompt: CLEAR LEVEL 4; on the web (left out): FULL GAME.
- **FULL GAME PREVIEW** (owner, 2026-10-22; `Demo.PREVIEW`): the `RANDOM_WINS`-th win's NEW MAZE leads first into
  one hand-picked maze (`PREVIEW_SEED` 1854 at MORE SLIME `PREVIEW_LEVEL` 3: Sunken Shrine, 33 x 20 cells, a perfect
  route uses ~64% of the meter) with every ability at its top level and a random full-game look (a skin past the
  demo's, opaque / jelly / pastel, a hat, sometimes dyed, a trail, a map paper). A card (FULL GAME PREVIEW / PLAY)
  comes first (once; RESTART goes straight in); no ticket pickups, attempts, pod, pay or records; its win or dry-up
  offers only CONTINUE and the pause menu's QUIT also goes on to the randomizer's end screen. Nothing borrowed
  reaches the save: `Progress.begin_demo_preview` saves the seen bit (`PREVIEW_SEEN_BIT` 16: once per save), keeps a
  `_write()` of the whole state and writes nothing until `end_demo_preview` (DemoEnd, the hub and the title call it)
  reads that back. Debug: `--demo --demo-preview` with `scenes/main.tscn` starts it. Tests: `tests/test_demo_preview.gd`.
- **Hat wheel:** shut until the end screen was seen (`Progress.demo_wheel_block()` = `Demo.wheel_block`: "closed";
  station dimmed, prompt LOCKED, using it says CLEAR LEVEL 4, tour line SPIN FOR HATS AFTER LEVEL 4, so no free-spin
  promise before it opens). Then as in the full game: the first spin free, later ones cost tickets from the mazes,
  up to `HATS_MAX` hats ("full": prompt LOCKED, the wheel still opens with SPIN disabled and the line NO MORE HATS
  IN THE DEMO, also the tour line; no "!"). Counted as hats owned in the save, so a guarded full save with more
  hats just can't spin. Dev mode doesn't lift either block in the demo. On the web left out (station dimmed, FULL GAME).
  **SHOP:** on show, nothing for sale (status line THE SHOP OPENS IN THE FULL GAME, prices dimmed;
  `can_buy_cosmetic` / `can_buy_hat` false; the hub's "!" ignores it).
- **Skins:** Lime, Mint, Lemon, Ocean, Grape (opaque) and jelly Lime / Mint; every other skin is a silhouette whose
  status line says NAME - IN THE FULL GAME (`Progress.is_skin_unlocked` asks `Demo.skin_open`, so a full save
  shows the demo's skins only).
- **Maps / medals / records:** for the demo's levels; the map table keeps the later ones sealed (even with a full save's surveys).
- Workshop and Descent stay off as in the full game. Intro + SPLASHDOWN tutorial are unchanged.

## 4. Full-game-only content (the export cut list)

**Single source of truth: `Demo.full_only_paths(web := false)`**, and `Demo.export_cut(web)` = that list plus the
translation catalogs while the languages gate is off (section 9). Print them with
`godot --path . --headless -s res://tools/demo_paths.gd [-- --web]`: one full-only path per line, then a line
`EXCLUDE: a, b, c` (the whole cut). Nobody copies that line by hand: `--write-presets` writes it into the demo
presets (section 8). It is computed from `Demo.LEVELS` / `WEB_LEVELS` / `HARD_LEVELS`, `Levels.data_path`, `Themes`
and `Demo.FULL_ONLY_FILES`, so changing a knob, or adding a level or theme past the demo, changes the list.
Today (desktop, `LEVELS` 4; the web demo, `WEB_LEVELS` 4 since 2026-10-21, cuts the same files as the desktop: the "Web Demo"
preset gets `export_cut(true)`, the desktop ones `export_cut(false)`):

| what | paths |
|---|---|
| story level data + banner line, levels 5-10 | `res://scripts/level_data/level_05.gd` .. `level_10.gd` |
| hard level tables, hard 2-10 | `res://scripts/level_data/hard_02.gd` .. `hard_10.gd` |
| tile art of the 6 later themes | `res://assets/sprites/themes/{sewers,catacombs,frozen,obsidian,crystal,volcanic}_{walls,floors,fillets,border}.png` (+ `.import`) |
| ambience of the 6 later themes | `res://assets/sounds/ambient_{theme}.wav` and `ambient_{theme}_N.wav` (+ `.import`) |
| the victory screen (after the level-10 chalice only) | `res://scenes/victory.tscn`, `res://scripts/ui/victory.gd` (`Demo.FULL_ONLY_FILES`) |
| the 17 translation catalogs, while `Economy.LANGUAGES_TEST` is false | `res://locale/*.po` (`Language.CATALOGS`; never loaded with the gate off) |

(Counts: see `build/demo/reports/` after a build.)

How the code keeps this possible:
- `Levels` reads each level from its own file (`scripts/level_data/level_NN.gd`: `NORMAL` recipe + `line()`;
  `hard_NN.gd`: `HARD` tables) by `load()` on first use, never at startup and never `preload`. `Levels.has_data`
  says whether a level is in this build; `Demo.can_load(path)` is the one check (`ResourceLoader.exists`, plus the
  tests' strip simulation). A missing level borrows level 1's data with a warning instead of crashing, and callers
  check first: the game falls back to the demo's last level, `Story.level_line` is empty, `Progress` keeps a full
  save's surveys and medals of missing levels untouched (`survey_for`, `_tier_from_record`).
- Theme art and ambience were already loaded by path for the current theme only (`MazeTiles`, `game.gd`); the demo
  only ever plays the demo's themes (its story levels and `Themes.for_seed` in the demo).
- The data files have no `class_name` (nothing in the global class cache points at them).
- `tests/test_demo.gd` plays levels 1-4 to the chalice and the first demo maze with `Demo.strip_test` on (every
  full-only path treated as absent) and checks that nothing asked for one (`Demo.denied`) and that none is in the
  resource cache (`ResourceLoader.has_cached`) afterwards.

Step 2 (done, sections 8-10): the demo presets, the generator, the one-command build + verify, the CI test.
`custom_user_dir_name` stays `SlimeTime_R1` (project.godot, shared by every preset) so desktop carry-over works.
What still ships with the demo: section 9.

## 5. Save carry-over

- The demo writes the **same save** (same dir `SlimeTime_R1`, same format and version) with `[meta] demo = true`.
- **Full game loading a demo save:** reads everything (nothing is demo-only or dropped), and its next save simply
  doesn't write the marker. Same for a demo save code pasted into the full game.
- **Demo loading a full-game save** (no marker; someone who owns both, or a full code pasted into the demo): the
  demo plays it **in memory only** and never writes it (`Progress.demo_guard`: `save_progress` is a no-op, even
  RESET PROGRESS), so the full save stays byte-identical. It shows only the demo's content (levels, skins, maps,
  abilities are gated by `Demo`, not by clamping the loaded values). No note says so on screen (owner, 2026-10-19:
  the SETTINGS / RESET note was removed with the carry-over lines, section 3).
- Demo progress then carries over by itself on the same machine (desktop); web: by save code only. Neither is
  advertised in the game (section 3).
- A demo save that already has more than the demo allows (hand-made, or the --save-path test file) is just loaded.

## 6. Mazes unchanged

Moving the level tables into `scripts/level_data/` kept every value: all 20 story digests (`test_maze_golden`'s
`story N normal|hard` lines: walls, start, goal, coins, route, par) were rebuilt and compared equal to
`tests/data/maze_golden.txt` (on Windows the golden file's CRLF line ends make that suite fail as before; the
digests themselves match). `test_hard_rebalance` reads the tables through `Levels.hard_data`.

## 7. Text

English only (owner rule), every string through `Loc.t` with `# i18n:` hints; catalogs merged
(`python tools/i18n_extract.py --merge`), row in `docs/i18n/pending.md`; the capture gate has four demo states
(`demo level select`, `demo upgrades capped`, `demo skin locked`, `demo end screen`). Screenshots: `docs/demo/`
(`title_sticker_lime.png`, `title_sticker_ocean.png`, `level_select_locks.png` for the 2026-10-19 changes).

## 8. Shipping the demo (step 2, 2026-10-19)

**Presets.** `export_presets.cfg` has four demo presets, each GENERATED from its full twin (`tools/demo_export.gd`):
"Windows Demo" (`build/demo/windows/DryTryingDemo.exe`), "Web Demo" (`build/demo/web/index.html`: zip that folder's
files for itch, as with the full web build), "macOS Demo" (`build/demo/macos/DryTryingDemo.zip`, bundle id
`com.slimetime.game.demo`) and "Linux Demo" (`build/demo/linux/DryTryingDemo.x86_64`). Generated = the twin's
section and options copied, then the name, `custom_features="demo"`, the output path, the Windows product name
(Dry Trying Demo) and `exclude_filter` = the twin's excludes + `Demo.export_cut()`. **Edit the full presets
(editor or file), never the demo ones**: the next write replaces them. The full presets stay byte-identical (the
file is read and written with ConfigFile, exactly as the editor saves it).

**Commands** (from the project root; Godot 4.7.2 + its export templates, python 3):
- Rewrite the demo presets after a change (a knob, a new level / theme, an edited full preset):
  `./tools/godot.sh --path . --headless -s res://tools/demo_paths.gd -- --write-presets`
  (`-- --check-presets` only checks: exit 1 if out of date). `tests/test_demo_export.gd` (in `test_all`) fails
  while the file is out of date, so a forgotten regeneration can't ship.
- **Build + verify in one go:** `./tools/build_demo.sh [--all] [--no-smoke]` (macOS / Linux / Git Bash: `tools/godot.sh`
  finds `$GODOT`, the Mac app, `godot` on PATH or the winget console binary) or `.\tools\build_demo.ps1 [-All] [-NoSmoke]`
  (Windows PowerShell). It self-tests the pack reader (`python tools/test_pck_check.py`: synthetic packs of formats
  2-4, standalone and embedded, every leak form and near miss; run it by hand after touching `pck_check.py`; it is
  not in `test_all`, which runs only Godot suites), writes the presets and a fresh cut list (a failed write fails
  the build, never a stale list), exports Windows Demo + Web Demo (`--all`: + Linux Demo, + macOS Demo on a Mac
  only: the macOS presets' ad-hoc signing needs Xcode's tools, so neither the full nor the demo macOS preset
  exports on Windows), then:
  1. **pack check** (`tools/pck_check.py`, a Godot 4 PCK reader for formats 2-4; reads an `.exe` / `.x86_64` with
     the pack embedded, a `.pck`, and the `.pck` inside the macOS zip): lists every packed file and FAILS if a cut
     path is inside in any form: the file, its `.import` / `.remap` / `.uid`, a `.gdc`, the imported copy
     (`.godot/imported/<file>-<md5>.ctex|.sample`) or a converted scene (`.godot/exported/.../export-<md5>-<name>.scn`),
     or if its `res://` path is written in the pack's `.godot/uid_cache.bin` or `global_script_class_cache.cfg`.
     Excluding the source path keeps the imported data and the index entries out (verified, not assumed: the full
     pack fails the same check on every one of these, the demo pack passes);
  2. **smoke run** of the exported Windows and Web packs: the editor binary with `--main-pack <pack>` runs
     `tools/demo_smoke.gd` from outside the pack (tools/ is never exported) with
     `--save-path=<abs>/build/demo/reports/demo_smoke_selftest.cfg`: a debug binary honors it, so the throwaway save
     is outside the game's user folder (`SlimeTime_R1`); the script stops at once unless the file has that name and
     isn't the real save; the script and then the build script delete it (a crashed run's leftover is reported).
     The web pack runs with `--platform=web --expect=web` (a debug binary then answers `Platform.is_web()` true), so
     the web knobs are what is checked. Checks: the `demo` feature comes from the export (not a flag), the platform
     is the expected one, `Demo.levels()` / randomizer / hat wheel match that platform's knobs, every cut path of
     that platform is absent, levels 1..`Demo.levels()` (1-4, desktop and web) are played to the chalice by the route pilot and the end screen opens, the
     first demo maze is played to its ticket (web: the randomizer stays shut, `WEB_RANDOMIZER` false), every menu
     scene opens, a full-game level falls back. Fails on a failed check or any `ERROR` / `SCRIPT ERROR` line (the
     engine's "resources still in use at exit" line is ignored). The exported exe itself is never run (it would use
     the real save); the real save's md5 is compared before / after too.
  Reports: `build/demo/reports/` (cut list, pack listings, export and smoke logs; not inside `build/demo/web`,
  whose files are the itch upload). Last run (2026-10-21, Windows, 4 levels on both, with the music): 105 files cut from each demo;
  Web Demo pack 5.2 MB (45.1 MB in all, 14.8 MB gzipped: [web-size.md](web-size.md)); smoke: 32 / 32 checks
  (Windows), 29 / 29 (web). (2026-10-20, before the music: Windows Demo exe 112.3 MB with a 3.1 MB pack.)

## 9. What the demo still contains (accepted leaks)

- **The code** (compiled `.gdc`; a decompiler reads it): `game.gd`, the maze generator, the finale cutscene
  (`story_screen.gd` draws it in code and shares the file with the intro), SHOP / Descent / workshop logic,
  `Themes` (all 10 area names and fog colours), `MapView.THEMED` (palettes), `Skins.PRESETS`, the abilities, `Levels`
  (coins per level, `COUNT`). The level RECIPES (seeds, sizes, hard tables) are cut, so the story mazes 4-10 can't
  be rebuilt from the demo; someone could still invent seeds and play randomizer-style mazes in the demo's themes.
- **`assets/sprites/coins.png`**: one sheet with all 10 coin metals (a few pixels per later area). Accepted: tiny;
  a demo crop would need a second asset or an export-time image step.
- **Hats** (`hats.png`, the TAILOR's whole catalogue) and **every skin** (built from `Skins.PRESETS` in code): the
  demo shows them anyway (wheel prizes, FULL GAME silhouettes).
- **Sounds of the locked abilities** (`goo_lob`, `goo_burst`, `kaze`, ...) and every shared UI / slime sound:
  loaded by name, a few KB, no story content.
- **Fonts** for other scripts (`assets/fonts/{arabic,cjk,devanagari,thai}`, ~0.3 MB): not later content, only
  unused while languages are off (a possible size cut, left in).
- **The translation catalogs** are cut while `Economy.LANGUAGES_TEST` is false (they hold every string, the later
  levels' banner lines too, and are never loaded with the gate off). **If the demo ships with languages ON** they
  ship whole (the cut follows the gate): the 7 later banner jokes x 17 languages and the victory text leak as
  strings. If that matters then, add an export-time demo copy of the catalogs without `story.level_4` .. `_10` and
  `victory.*` (not done).
- **Path names**: none. The pack's `uid_cache.bin` and script class cache list only exported files; every build checks it (`pck_check.py` fails if a cut path is named in either).
- A harmless engine WARNING in every export (full too): `title.tscn`'s binary copy carries a stale UID for
  `title.gd` and falls back to the path (a stale editor cache entry; nothing to do with the demo).

## 10. PCK encryption (not done: a deterrent only)

Godot can encrypt the pack (`encrypt_pck=true`, `encrypt_directory=true`, `encryption_include_filters="*"`) with a
256-bit key from the `GODOT_SCRIPT_ENCRYPTION_KEY` environment variable at export time. The game can only read such
a pack when the **export templates were compiled with that same key** set: the official 4.7.2 templates can't, so
it needs a custom template build per platform (Windows, macOS universal + re-signing, Linux, Web). It stops casual
extraction (gdsdecomp and friends can't open the pack without the key), but the key sits inside the shipped binary
and is routinely pulled out with a debugger, so it stops nobody determined. Cutting the content (sections 4 and 8)
is the real protection; encryption would only add a hurdle for the code. `tools/pck_check.py` can't list an
encrypted directory (it says so), so the build's check would have to run before encryption or with the key.
