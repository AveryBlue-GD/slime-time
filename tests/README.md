# tests/

Everything under `tests/` is one of four kinds. Only the first kind is run by `./tools/test_all.sh`.

## 1. Suites: `test_*.gd` (76) run by `./tools/test_all.sh`

- `./tools/test_all.sh` runs every suite headless, in parallel (`-j N`, default 3/4 of the cores; `-j 1` = one at a time),
  prints `suites: N failed: 0`. `./tools/test_all.sh test_coins test_hats` runs just those; `TIMES=1` lists the slowest jobs;
  `KEEP_LOGS=dir` keeps every job's output. Long suites are split into shards (`SHARDS` in the script): `test_nav_fuzz`
  (scripted, web ring, walks 0-8, and walks 9-end: open-ended `--nav-walk=9-`, so a new walk always runs) and `test_maze_golden` (4 shards, `-- --shard=K`).
- One suite: `./tools/godot.sh --path . --headless --fixed-fps 60 --quit-after 300000 -s res://tests/test_X.gd`; it must print `RESULT: PASS`.
- Suites `extends "res://tests/suite_base.gd"`: `failures`, `_check(ok, label)`, `_result()`, `throwaway_save()` (a save file unique to the
  process, never a fixed name: suites run side by side), `_spawn_game({level = 3})`, `_physics_frames(n)`, `_wait_seconds(s)`, `_tap_key(code)`,
  `_check_budget(...)` (wall-clock budgets, see below). `nav_fuzz_lib.gd` is the shared driver of
  the navigation fuzzer; `start_dirs.gd`, `err_log.gd` (collects engine errors during a test) and `autopilot.gd` are helpers.
- Added in the spring cleaning: `test_platform` (Platform seam: Android back, background pause, safe areas, fullscreen sync, mobile
  home icon; `Platform.override` / `safe_area_override` simulate phones), `test_gamepad` (the fixed pad layout with real joypad events),
  `test_interpolation` (physics interpolation changes no run result), `test_ui_layout` / `test_ui_touch` (the rules of
  [docs/ui-rules.md](../docs/ui-rules.md) on every screen), `test_descent_resume` (Descent run saved / resumed, one resume per floor).
- `JOB_TIMEOUT=sec` (default 600) kills a hung job (and only its own process group, `tools/job_timeout.pl`) and reports `<label> TIMEOUT`; Ctrl-C keeps
  the logs and prints where. A suite name that matches no suite fails the run. Each job removes its own `dev_attempts_<pid>.log` and throwaway saves,
  and `test_all.sh` sweeps those of dead pids at the start (it prints how many); only those name patterns, never `save.cfg` / `dev_attempts.log`.
- `_check_budget` guarantee: each try runs a fixed CPU probe before and after the measurement, divides the time by the smaller probe slowdown (clamped to
  1 .. 2.0), and passes on the best of 5 tries. Budgets are the idle time x ~1.6 (floor build 12 ms, hard maze 15 ms, par for 20 levels 100 ms; idle 7.5 / 9.5 /
  ~65). So on a quiet machine (probe < 1.25x idle: a suite alone, `-j 1`) a code slowdown of 2x FAILS (proven with a scratch-copy mutation that does each
  build twice). Under heavy parallel load the probe cannot tell code from load, so there only slowdowns beyond about 3x idle fail. 1.5x regressions are not caught.
- Tests and tools never write the real save (`~/Library/Application Support/SlimeTime_R1/save.cfg`).

## 2. Demo and capture scenes: `demo*.tscn` (marketing and screenshot tools, not tests)

Watchable or screenshot scenarios, kept working on purpose (screenshots for itch, docs and the owner's checks, movies, promo shots).
Run one with the screenshot tool or watch it live (dev mode, nothing saved):

```
./tools/screenshot.sh --frames 120 --scene res://tests/demo_dry.tscn --unlock-all        # -> .screens/latest.png
./tools/play.sh --dev --scene res://tests/demo_record_run.tscn                            # watch it
./tools/godot.sh --path . --write-movie /tmp/story.avi --fixed-fps 30 --quit-after 800 res://tests/demo_story.tscn -- --story=intro
```

Each script's header comment lists its options (`--shot=`, `--skin=`, `--attempt=N`, ...). What they are for:

| Scene | What it shows |
|---|---|
| `demo` | the autopilot playing the main scene (generic screenshot / movie base) |
| `demo_story` | the story intro and finale cutscenes (`--story=intro`, `--story=finale`, `intro:3` starts at shot 3; `--calm`); screenshots and movies |
| `demo_launch` | a fresh save's first launch: the trailer, skipped, wiping into the title |
| `demo_unlock_all` | a brand-new save played through the real flow by the autopilot, hub to victory (watchable) |
| `demo_record_run`, `demo_record`, `demo_rewards` | a win with NEW RECORD / medal / ticket rewards and the REPLAY / NEXT buttons |
| `demo_dry`, `demo_pause`, `demo_prompt`, `demo_quitmenu`, `demo_reset`, `demo_wipe` | single menu / HUD states (dry-up buttons, pause menu, R prompt, trapdoor confirm, reset confirm, goo wipe) |
| `demo_level_select`, `demo_maps`, `demo_hats`, `demo_wheel`, `demo_store`, `demo_hubskin`, `demo_stopwatch`, `demo_medal_skins`, `demo_hat_audit`, `demo_hat_hops` | level select, map table, hats page, hat wheel, ticket store / trails, skins, stopwatch skin, the hat contact sheets and hat hops |
| `demo_abilities`, `demo_descent`, `demo_heat`, `demo_attempts`, `demo_random_ticket`, `demo_brightness`, `demo_cues`, `demo_edge`, `demo_jump`, `demo_jelly`, `demo_touch_hint` | feature scenarios (abilities, Descent, HEAT, attempt pod, randomizer ticket, light radius, level 1 cues, maze edge, charged leap, jelly coins, touch hint) |
| `demo_overview` | level-design top-down view of a whole maze (needs a window: `-- --level=5 [--hard] [--out=PATH]`) |

## 3. Tools that are not suites

- `audit_ui` (UI symmetry audit), `bench_heat` (HEAT winnability sweep, ~480 runs), `bench_random_size` (randomizer size benchmark).
- `qa_poc_*.gd`, `qa_soak.gd`: QA proofs of concept and the long soak / leak driver; `qa_poc_disk_full` is also run by `test_save_robust`.
- Promo renders live in `tools/promo/` (`cover.tscn`, `jump_shot.tscn`, `make_promo.sh/.ps1`); re-render only when asked.

## 4. Data

- `tests/data/maze_golden.txt`: golden digests of every maze (see `test_maze_golden.gd` for how to rewrite it on purpose).
