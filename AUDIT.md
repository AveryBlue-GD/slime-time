# Code audit and cleanup log (2026-11-02)

Branch `cleanup/audit-2026-11-02`, cut from `claude/mobile-sync-polish` (PR #5, which already contains PR #3 and PR #4) at
`d089ce5`. The owner chose this base over `main` because `main` stopped on 2026-10-22, 194 commits (300 files) behind the
demo work, and PRs #3-#5 all target `demo-mustfix-2`.

How to read this file: **section 1** maps the code, **section 2** is the measured baseline, **section 3** is the prioritized
findings list (the work queue for the cleanup loop), **section 4** logs each accepted change with before / after numbers.
The full evidence for every finding (quoted code, callers checked) is in [docs/audit/2026-11-02/](docs/audit/2026-11-02/), one
file per area (A gameplay, B state / save, C hub / HUD, D1 + D2 UI, E platform / build). Those area reports were written by
six parallel read-only auditors; line numbers in them are as reported and are re-checked when a finding is worked on.

---

## 1. Map

**Stack.** Godot 4.7.2, GDScript only, renderer `gl_compatibility` (desktop and mobile), base resolution 320x180 scaled by
integer steps (`stretch/mode="viewport"`, `scale_mode="integer"`). 84 game scripts (~42,700 lines in `scripts/`), 17 scenes,
200 test scripts (~40,600 lines), generated assets (`tools/make_*.py`). Targets: macOS (universal, ad-hoc signed), iOS
(iPhone + iPad, built on the owner's Mac by `tools/ios_build.sh`), plus Windows / Linux / Web / Steam presets.

**Entry points.**
- `run/main_scene` = `scenes/title.tscn` (`scripts/ui/title.gd`). First launch hands off to the story intro, then the
  SPLASHDOWN training maze, then the hub tour.
- Seven autoloads, created in this order: `Progress` (all state + saves, launch flags), `Language` (locales, `.po` catalogs,
  fallback fonts), `Sfx` (32 sounds x 3 voices), `Music` (hub loops, title, level bed / 3-layer orchestra), `RotateHint`
  (portrait cover, pauses the tree), `Transition` (goo wipe for every scene change, physics-interpolation switch, toasts),
  `PlatformEvents` (back button, focus loss -> pause + save flush, 60 fps cap on web / phones, pad stick).
- Debug flags (`--dev`, `--unlock-all`, `--demo`, `--tutorial`, ...) are parsed in `Progress._ready` and ignored by release
  builds (except `--touch`, `--web-ui`).

**Scene flow.** title -> (story intro -> training) -> hub. The hub (`scripts/hub.gd`) is a round room of stations; each
station `UIKit.go`es to a screen (level select, maps, skins, upgrades, settings, boards) or opens an in-place overlay (hat
wheel / shop, coin board, quit, portal). Level select / the randomizer portal / daily sign load `scenes/main.tscn` (the
game). Every BACK and QUIT TO HUB returns to the hub. All scene changes go through `Transition.go` (cover 0.22 s, swap,
uncover 0.32 s); restart / retry use `reload_current_scene`.

**Game loop** (`scripts/game.gd`, 3,539 lines; area report A has the full walk-through).
- Physics at 60 Hz. `Main._physics_process` runs before the slime's, so it reads last tick's position: relight the fog
  around the slime, run clock, ghost, meter drain (distance x cost; airborne and knockback free), paint goo + reveal,
  lurkers, pickups (coins, tickets, goo drops by distance), goal reveal, HUD meter, low-slime heartbeat, orchestra, dry-up.
- `_process` (render rate): HUD pod updates, fog shader uniforms, ambient motes, LIGHT & LIFE frame, pixel-locked camera
  lead, shake, then `_flush_textures` (uploads the fog / trail images when dirty).
- Physics interpolation switches on only above ~72 fps (`Transition.follow_frame_rate`), so 60 fps output is unchanged.

**Rendering.** Tile layers (Floor, Walls, Border, Bedrock) -> trail sprite (z1, `trail.gdshader` + glow child) -> fillets
(z2) -> pickups / lurker bodies (z6) -> ambient motes (z9) -> fog (z10, `fog.gdshader` decoding an RGBA8 image, one texel per
2 px cell) -> slime / chalice / lights (z11) -> hat, lurker eyes, particles (z12) -> HUD CanvasLayer. The CPU keeps the fog /
trail as `PackedByteArray`s and writes exact disc spans; the whole image is re-uploaded when dirty. Menus share one UI kit
(`scripts/ui/ui_kit.gd`): every screen root gets a Theme of `GooBox` styleboxes (procedural slime frames, layout cached per
canvas item) and a `SkinText` node that recolours labels and theme colours to the skin (every frame only for the rainbow
skin).

**Input.** Actions in `project.godot` (WASD / arrows, Space, R, Esc) plus `interact` and the ability keys added at runtime by
Progress; `Progress.apply_bindings()` applies the CONTROLS page and the fixed pad layer. The slime polls `Input.get_vector`
and `jump` each physics tick (charge on press, launch on release). Touch: `scripts/ui/touch_controls.gd` (floating joystick
on the left half, JUMP on the right, pause, ability buttons) presses the same actions, tracking each finger by index.

**Physics / collision.** Walls are TileSet physics squares (16x16) on wall and border tiles. Gliding uses `move_and_slide`
with lane centring; leaps step `move_and_collide` with a corner slip of up to 3 px; splat knockback ricochets. Goal =
Area2D `body_entered` (chalice or randomizer ticket voucher, radius 6). Coins / tickets / drops / lurkers = distance checks
in game.gd / lurkers.gd (coin reach 10 px, MAGNET upgrade with a tile line-of-sight check).

**Assets.** `preload` for shaders, the slime sheet + json, coins, lurkers. `load` by constructed path for theme atlases
(`Themes.atlas_path`), level recipes (`scripts/level_data/level_NN.gd`, so a demo export can leave them out), ambience
WAVs (`ambient_<theme>_<k>.wav` while the file exists), `.po` catalogs, music.

**State and saves** (`scripts/progress.gd`, 3,683 lines, plus `save_file.gd` / `save_text.gd`; area report B).
`user://save.cfg` under the custom user dir `SlimeTime_R1`; `[meta] version` 7, `epoch` 1. Every change saves at once
(`save_progress`, ~55 call sites) through `write_atomic` (write temp, read back and compare, rename, retry with back-off).
Untrusted text (save, ghosts file, pasted codes) passes an allow-list scanner before `ConfigFile.parse`. Corrupt / newer /
other-epoch saves are set aside with backups. Tests, tools, headless and dev runs never write the real save.

**Build / run / test commands** (bash, project root; Windows twins are `.ps1`).
- Godot: `./tools/godot.sh` (or `GODOT=/path`). Import: `./tools/godot.sh --path . --headless --import`.
- Play: `./tools/play.sh [--dev] [--story] [--demo] [--scene ...]`. Screenshot: `./tools/screenshot.sh`.
- Tests: `./tools/test_all.sh [-j N] [suite ...]` (every `tests/test_*.gd`, headless, parallel; prints `suites: N failed: M`).
- Bench (new): `./bench/run.sh [--display] [--runs N] [scenario ...]` (section 2).
- Exports: `./tools/godot.sh --path . --headless --export-release "<preset>" <out>` (needs the 4.7.2 export templates);
  demo builds `./tools/build_demo.sh`; iOS `./tools/ios_build.sh` on the Mac. CI: `.github/workflows/tests.yml` runs every
  suite on Linux on each push / PR.

---

## 2. Baseline (2026-11-02, before any change)

Machine: cloud Linux container, 4 cores, 15 GB RAM, official Godot 4.7.2 Linux editor binary (the same one CI uses).
**Not** the owner's MacBook: numbers below are for comparing before / after on the same machine, not absolute Mac numbers.

### Build and tests

| Metric | Value | How |
|---|---|---|
| Test suites | **137 run, 136 pass, 1 fail** | `./tools/test_all.sh` (3 jobs), 427 s wall |
| The 1 failure | `test_save_robust`: "a read-only save dir" (2 checks) | The container runs as root, and root can write to a read-only folder. Run as a normal user it **passes** (`RESULT: PASS`). Environmental, not a code bug; PR #5 reported the same. |
| Import (asset re-import) | 12.1 s, 0 warnings, 0 errors | `godot --headless --import` |
| Export pack size (game data, no engine) | macOS 12,317,692 B; iOS 12,216,780 B; Web 11,627,664 B | `godot --headless --export-pack "<preset>" out.pck` (8.4 s / 6.0 s / 5.6 s). The full app adds the 4.7.2 engine template, which the cleanup cannot change and which this container does not have. |
| Engine warnings in test logs | 134 lines | grep `WARNING` over every suite log (breakdown below) |
| Engine errors in test logs (non-fatal) | 80 "resources still in use at exit" + 7 others | see T-01..T-04 in section 3 |

Warnings breakdown: 80 x "ObjectDB instances were leaked at exit" (suites quit with nodes alive; test teardown, not the
game), 48 x "Nodes with non-equal opposite anchors will have their size overridden" (all from
`scripts/ui/upgrades_screen.gd:325` `_fit_title` under non-English locales; finding T-03), 4 x "Loaded resource as image
file" (font tests reading PNGs directly), 1 Steam init (fake), 1 CanvasItem RID leak. **GDScript parser warnings: 0.**

### Performance harness (`bench/`)

There was no checked-in harness (the 2026-10-13 profiling used a scratch copy), so one was added:
`bench/bench.gd` (scenarios) and `bench/run.sh` (runs each scenario N times in its own process and prints the median).
Fixed seeds, `--fixed-fps 60` (every run simulates the same frames), vsync off (wall time = real cost), 120 warm-up frames,
600 measured frames. Gameplay scenarios drive the slime with the game's own `RoutePilot` along a fixed back-and-forth route
that never reaches the goal, with the meter frozen, so the level never ends mid-measurement.

Scenarios: `startup` (process start -> title's first frame), `title`, `hub` (all 8 stations), `level1`, `level10`, `random`
(randomizer seed 5, MORE SLIME at max), `story` (intro), `skins` (wardrobe). Metrics: frame avg / p95 / p99 / max (ms),
`script_ms` (time inside node `_process` + `_physics_process`), load ms, static memory high-water mark (MB), node count,
orphan nodes; under `--display` also draw calls and render objects.

**Baseline, headless (CPU cost only), median of 5 runs:**

| scenario | avg ms | p95 ms | p99 ms | script ms | load ms | mem peak MB | nodes | orphans |
|---|---|---|---|---|---|---|---|---|
| startup | 2,072 ms to first title frame | | | | | 109.15 | | |
| title | 0.883 | 2.693 | 3.940 | 0.103 | 319.0 | 109.15 | 120 | 0 |
| hub | 1.310 | 1.960 | 2.189 | 1.173 | 305.9 | 109.15 | 317 | 0 |
| level1 | 0.405 | 0.665 | 0.898 | 0.245 | 60.1 | 109.15 | 271 | 0 |
| level10 | 0.452 | 0.739 | 0.946 | 0.278 | 117.2 | 109.15 | 320 | 0 |
| random | 0.429 | 0.633 | 0.728 | 0.269 | 205.4 | 109.15 | 268 | 0 |
| story | 0.902 | 2.717 | 3.856 | 0.104 | 220.9 | 109.15 | 120 | 0 |
| skins | 0.426 | 0.661 | 0.760 | 0.272 | 250.7 | 109.15 | 354 | 0 |

**Noise.** Run-to-run spread on this shared container is large: 7-23 % on frame averages, up to 75 % on p99 (and 260 % on
one skins run). Memory high-water marks and node counts are exact (0 % spread). A 1 % wall-clock difference is therefore
**not measurable here**; I tried instruction counting with callgrind for a deterministic number, but one scenario took
521 s and the slime's path still depended on wall time, so it is not practical per iteration. The acceptance rule used in
section 4 is therefore:
1. exact metrics (memory peak, nodes, orphans, pack size, warnings) must not get worse at all;
2. a change aimed at speed must show a gain larger than the run-to-run spread, measured on the scenario it targets with a
   targeted micro-measurement where needed, else it is not claimed;
3. for every other change, the 7-run median of every timing metric must stay within the baseline's min-max range; if it
   falls outside, the run is repeated, and a confirmed regression means revert.

**Still needed on the owner's Mac** (cannot be measured here): real-GPU frame time on the M3 (`./bench/run.sh --display`
opens a window on macOS), macOS memory, startup of the exported `.app`, the signed bundle size. Commands are in
CLEANUP_REPORT.md.

### Test coverage before changing anything

The 137 suites already lock in the rules the brief names: gameplay rules and scoring (`test_economy_integrity`,
`test_random_tickets`, `test_tickets`, `test_medals`, `test_records`, `test_coins`, `test_upgrades_v2`, `test_slime_pricing`,
`test_hard_mode`), hit detection (`test_coins`, `test_coin_catch`, `test_workshop` magnet reach, `test_bounce`,
`test_lurkers`), save / load (`test_save_robust` incl. a hostile value in every key, `test_fresh_start`, `test_save_code`,
`test_save_isolation`, `test_layout_migration`, `test_trust_fixes`), maze generation (`test_maze_golden`, 4 shards of golden
mazes; `test_spawn_picker`, `test_seed`), the full story played by the autopilot (`test_phase3`), navigation fuzzing
(`test_nav_fuzz`), and UI layout rules per locale (`test_ui_layout`, `test_i18n_*`). Coverage is not thin, so no broad characterization pass was added.
Instead, **each change in section 4 adds or names the test that pins the behaviour it touches** (a regression test that
fails before the change when the change is a bug fix).

---

## 3. Findings (prioritized)

Severity: **critical** = crash / save loss / softlock players can reach; **high** = player-visible bug; **medium** = latent
bug, measurable waste or meaningful dead code; **low** = cleanup. Status: `open`, `fixed (#n)` = section 4 entry n,
`owner` = needs the owner's decision, `left` = deliberately left (reason in CLEANUP_REPORT.md).
"Feel" marks a fix that changes gameplay feel or look and must be flagged.

No critical findings. Order below = the order the loop works them.

### High

| id | category | where | finding | fix plan | status |
|---|---|---|---|---|---|
| D2-02 | bug (softlock) | scripts/ui/rotate_hint.gd `_process` / `set_shown` | Pause menu open, phone turned upright, menu closed by back / Esc / pad while the cover is up, phone turned sideways: the tree stays paused with no menu, nothing can unpause | clear `_was_paused` where `_process` re-pauses under the cover | open |
| D2-01 | bug | scripts/ui/touch_controls.gd `hide_controls` / `_input` | After a level ends the touch controls hide, but the first tap on the result screen shows them again on top of the result panel and presses jump / move | a `suppressed` flag set by `hide_controls`, cleared only by an explicit show | open |
| D2-03 | bug | scripts/ui/transition.gd `go` | `go()` doesn't kill the previous uncover tween; leaving a screen within 0.32 s of arriving lets the old tween hide the goo sheet mid-wipe | kill `_tween` at the start of `go()` | open |
| D1-01 | bug | scripts/ui/upgrades_screen.gd `_refresh` | Demo build: the gold "FULL" cost label is repainted dim by SkinText before the first frame | take the capped label out of the skin-text group (as hub.gd does) | open |

### Medium

| id | category | where | finding | fix plan | status |
|---|---|---|---|---|---|
| B-01 | bug (save loss, rare) | scripts/progress.gd `write_atomic` | When the rename fails after Windows removed the old save, the next write truncates and deletes the temp file that is then the only copy | promote an orphaned temp first; never delete the temp while the save is missing | open |
| B-02 | bug (economy) | scripts/progress.gd `reset_progress` | RESET PROGRESS keeps the parked randomizer abandon penalty, which is saved; first random maze after re-beating the story pays 1 instead of 10 | reset the runtime randomizer fields in `reset_progress` | open |
| B-03 | bug | scripts/ui/achievements_screen.gd, achievements.gd | WIN A WEEKLY MAZE shows locked after a save-code import (boards aren't in codes) though its reward stays owned | count a goal unlocked if it is in `ach_known` or met | open |
| C-03 | bug | scripts/hub.gd tour gates | After a replayed tour is skipped / finished, the hub stays in tour mode: R doesn't turn the room, the DAILY sign never offers WEEKLY / BOARDS | gate on "tour active" (`tour != null and not tour.over`) | open |
| C-02 | bug | scripts/hub.gd `_ready` | "!" badges are built before the tour exists, so a "!" shows on the prize wheel during the guided first tour | refresh badges after the tour is set up and when it ends | open |
| C-04 | bug | scripts/hub.gd daily -> boards | Coming back from BOARDS (opened from the DAILY sign) resets the room instead of facing the sign | leave with the portal station, as the daily start does | open |
| D2-04 | bug | level_select / title / victory / boards / demo_end / language screens | Handlers change Progress before `UIKit.go`, which silently refuses during a wipe: a quick double tap starts the second level / maze | check `Transition.busy` first (or make `go` return bool) | open |
| D2-05 | bug | scripts/ui/touch_controls.gd | OS-cancelled touches (`canceled` flag) still leap / fire abilities / tap | on `canceled`, release without acting | open |
| A-01 | bug, **feel** | scripts/game.gd `_idle_drain`, lurkers.gd | Lurker stealth ("stand still") reads `_still_time`, which only grows when idle drain is on, so stealth never works with RELAXED / NO DRAIN | count stillness on its own, independent of the drain gates | open (flag) |
| A-02 | bug? | scripts/slime.gd `_afterimage` | SLIMAKAZE afterimage `mat.duplicate()`; game.gd notes duplicate() drops colour params in this Godot | headless check first; build the material like `_build_outer_fog` if real | open (verify) |
| D1-04 | bug? | scripts/ui/goo_box.gd `_draw` | Layout cache key truncates the 64-bit RID to int32, so a rebuilt tile in a reused slot may get the old tile's lumps | headless check; key by the full id | open (verify) |
| D1-03 | leak | scripts/ui/goo_box.gd `_drawn` | Grows for the whole session unless rainbow is on | record only while tinting / clear on recolor | open |
| C-01 | hot-path | scripts/hub.gd `_process` -> `_place_hints` | Label solver runs every frame although names hide for good after 3 s | solve only while names are visible | open |
| D1-02 | hot-path | scripts/ui/skins_screen.gd `_refresh_papers` | Every focus move on PAPERS re-renders all 12 paper maps (new textures + materials) | render on page show / look change only | open |
| D1-05 | hot-path | goo_box.gd `tint`, skin_text.gd `_flow` | Rainbow skin: up to 7 full tree walks per frame | cache control lists per SkinText | open |
| D1-07 | hot-path | scripts/ui/story_screen.gd | Array literals per brick, lambdas per hero, Dictionary particles (cpu.md #7 remainder) | const arrays, keep RNG order | open |
| D2-06 | hot-path | scripts/ui/skin_showcase.gd `_age_trail` | Trail redrawn every frame even when unchanged | redraw on cell or alpha-step change | open |
| D2-07 | hot-path | scripts/ui/map_view.gd `_draw_frame` | Per-pixel loop over the whole map to paint a 4 px frame | iterate the four bands only | open |
| E-03 | hot-path | scripts/language.gd `enable` | All 17 `.po` catalogs (~2 MB) loaded at every launch, even for English | load the current locale only | open |
| A-21 | architecture | scripts/game.gd 1105-1664 | 560-line fog / trail engine mixed into game.gd | extract a `RevealMap` class | left (large refactor; see report) |
| E-01 | mac-ios | export_presets.cfg | macOS bundle id `com.slimetime.game` vs iOS `com.averyblue.drytrying` | owner picks one | owner |
| E-02 | mac-ios | export_presets.cfg macOS presets | Icon is the 256 px icon.png upscaled with filtering (`icon_interpolation=4`) for Retina sizes | use `assets/ios/icon_1024.png`, interpolation 0 | open |
| E-04 | mac-ios | export_presets.cfg | Ad-hoc signing, no notarization / sandbox: fine for itch, blocks a notarized or Mac App Store release | owner, at release time | owner |

### Low

| id | category | where | finding / fix plan | status |
|---|---|---|---|---|
| T-01 | test hygiene | tests/test_coins.gd:60, test_workshop.gd:121 | `obj in typed_array` on a freed coin logs engine errors; check `is_instance_valid` first | open |
| T-02 | test hygiene | tests/test_fresh_start.gd:187 | `raw_to_base64` of an empty buffer logs an engine error | open |
| T-03 | bug (warning) | scripts/ui/upgrades_screen.gd:325 | `_fit_title` sets `size` on an anchored label (48 warnings under non-English locales) | open |
| T-04 | test hygiene | 80 suites | "ObjectDB instances leaked at exit": suites quit with live nodes | left (test teardown only) |
| A-03 | bug | game.gd `_dry_hold` | The dry-up hold keeps counting under the pause menu | open |
| A-04 | bug? | ghost_racer.gd | Ghost racer drawn over the fog (same z, added later): shows the best route through fog | owner |
| A-05 | hygiene | ambient.gd, game.gd | Motes z 9 draw over pickups (z 6), comments say under | open (comments) |
| A-06 | bug | lurkers.gd | Near-miss slow-mo ends on the wall clock (a pause ends it) | open |
| A-07..A-11 | hot-path | game.gd, fx.gd, lurkers.gd | Per-row array literals in `_disc_runs`, Image round-trip in `_rgba8`, new gradients per burst, material per glimmer, eye layer redraw every frame | open |
| A-12, A-13 | dead-code | fx.gd, slime.gd | `Fx.crust_flakes`, `afterimage_colors`, `DUST_BRIGHT`, `Slime.is_hurt`: no references | open |
| A-14 | dead-code | game.gd | `_fog_packed`, `_fog_lit_ticks`, `_cell_pos` used only by tests | left (test API) |
| A-15..A-17 | duplication | game.gd, shaders | MAGNET pickup rule copied; slime screen rect twice; `bayer4` / noise copied across shaders | open |
| A-18..A-19 | magic-number | levels.gd, ticket_goal.gd, fog.gdshader | Copies of slime speed / grab radius; vignette 176x100 | open |
| A-20 | unchecked-error | game.gd ambience | `load(...) as AudioStreamWAV` dereferenced without null check | open |
| A-22 | architecture | lurkers.gd | Reaches into game privates | left (with A-21) |
| B-04 | architecture | progress.gd | Migrations overwrite the only pre-migration copy | open |
| B-05 | unchecked-error | progress.gd | Other-epoch backup copy result unchecked | open |
| B-06, B-07 | bug | progress.gd demo preview | Snapshot misses some runtime fields; restore applies demo fix-ups to a guarded full save (memory only) | open |
| B-08, B-09 | hot-path | achievements.gd, hat.gd | Achievement list rebuilt 2-3x per save; hat catalog lookups per frame | open |
| B-10..B-13, B-16 | duplication | progress.gd, boards.gd, dev_log.gd, survey.gd, demo.gd | Random-maze reset block x5; daily hash x2; tool-flag lists drifted; base64 check x2 and missing in ghost decoder; story bits x2 | open |
| B-14 | unchecked-error | boards.gd | Ghost file read fully before its size check | open |
| B-15 | dead-code | achievements.gd, progress.gd, descent.gd | `milestones_reached`, unused `silent` param, unreachable fallback dicts | open |
| B-17, B-18 | hygiene / magic | progress.gd, hats.gd, demo.gd | Stale prices in comments; repeated default colour literal | open |
| B-19 | architecture | progress.gd | God object (3,683 lines); concrete 6-way split in report B | left (large refactor) |
| C-05, C-06 | hot-path | hub.gd, hud.gd | Deep Dictionary `==` per frame (cpu.md #10); training line re-laid out per frame | open |
| C-07 | bug, **look** | hud.gd | Rainbow meter outlines never recolour | owner |
| C-08 | bug | hud.gd `_stage_wait` | Result staging runs on under the pause menu | open |
| C-09 | bug | hub.gd | DAILY badge hours never refresh during a visit | open |
| C-10, C-11 | duplication | hub_tour.gd, ability_coach.gd, hub.gd | SKIP pod copied; overlay-open list x5 (already drifted) | open |
| C-12, C-13 | dead-code | hud.gd, ability_runner.gd, autoplay_planner.gd | Unused / duplicate constants; two no-op branches | open |
| C-14..C-16 | hygiene / magic | abilities.gd, hub.gd, hud.gd | Stale comments; lines with lost continuations (tabs mid-line); screen-size literals | open |
| C-17, C-19 | autoplay (debug) | autoplay*.gd | Banner rebuilt per frame; finds a button by English text | open |
| C-18 | architecture | game.gd | Training cues loaded as an optional "chunk" with guards that can't fail | open |
| D1-06 | hot-path | ui_kit.gd `set_selected` | Not idempotent: every wardrobe focus move re-themes the whole grid | open |
| D1-08 | bug | skins_screen.gd `_hold_look_note` | Resumes after an await on a freed screen | open |
| D1-09, D1-10 | dead-code | story_screen.gd, hat_wheel.gd | Unread `name` key; unreachable "trails" shop section | open |
| D1-11..D1-14 | hot-path | controls.gd, story_screen.gd, ui_kit.gd | FULLSCREEN text per frame; story cover redraw under Reduce Motion; 8 check-box textures per theme; outline label re-applies 16 overrides per draw | open |
| D1-15..D1-18 | duplication / hygiene | upgrades_screen.gd, skins_screen.gd, hat_wheel.gd | Ticket-confirm copied x3; repeated code; BACK rewired by "last connection"; workshop rows ignore locale metrics | open |
| D2-08 | hot-path | title.gd LogoDrip | Redraw every frame while idle | open |
| D2-09 | unchecked-error | transition.gd | `change_scene_to_file` result ignored | open |
| D2-10, D2-11 | dead-code | intro_card.gd, map_view.gd | `was_skipped()` unused; `route_width` test-only | open |
| D2-12..D2-14 | duplication / hygiene | several screens, touch_controls.gd, transition.gd | Scene paths re-declared; tabs mid-line; duplicate assignment | open |
| E-05 | mac-ios | project.godot | Fullscreen only on F11, which macOS takes for Show Desktop; add Ctrl+Cmd+F | open |
| E-06 | bug (tooling) | tools/test_all.sh | Linux user-dir path wrong, so the stale test-file sweep never runs on Linux | open |
| E-07 | hygiene | tools/ios_build.sh | Edits tracked files in place (a killed build can leave the real Team ID in the tree) | left (owner's Mac-only tool; flagged) |
| E-08 | hygiene | .github/workflows/tests.yml | `--import \|\| true` hides import failures; no `permissions:` block | open |
| E-09 | dead asset | sfx.gd, assets/sounds/jingle.wav | Loaded with 3 players at boot, never played | open |
| E-10 | unchecked-error | sfx.gd | `play` / `stop` index without `has()` | open |
| E-11, E-12 | hygiene | language.gd, docs | Stale comments (languages "off"), icon size in docs | open |
| E-13 | mac-ios | App Store Connect | iOS app offered on Apple Silicon Macs would act as iOS | owner (release checklist) |

---

## 4. Change log (cleanup loop)

Each entry: finding id(s), what changed, the test that pins it, and before / after numbers. Commit per entry.

_(entries added as the loop runs)_
