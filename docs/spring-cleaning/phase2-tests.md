# Phase 2: test suite health (test-curator, 2026-10-16)

Branch `spring-cleaning`, from tag `spring-cleaning-phase1`. Machine: Apple M3 (8 cores), Godot 4.7.2. No gameplay, visual or save
change; the only game-code edit is the dead `Game._finish` parameter (below). Scratch evidence is in `/private/tmp/claude-501/p2/`.

## Result in one table

| | Before | After |
|---|---|---|
| `./tools/test_all.sh`, wall clock | 6:00 (360 s serial; QA measured 5:58 and 6:24) | **about 1:55 (102-119 s)** with the default 6 jobs; `-j 1` still works (about 5:50, the sum of the single runs below) |
| Two `test_all.sh` at the same time | unsafe (shared save files) | passes, 215 s for both |
| Suites | 70 | 70 (`suites: 70 failed: 0`) |
| Assertions (`ok` lines printed, summed) | 2,491 | 2,502: +9 new checks (coins, medals, next_steps), +9 from the 3 checks each maze_golden shard repeats, -6 always-true `or true` lines removed from test_extremes, -1 for nav_fuzz's wrapper of the web-ring child (the ring itself is now a job of its own) |

Wall clock fell by 68 %. The CPU work did not shrink much (350 s vs 360 s of single-suite time; the machine was a little warmer for the "after"
column), the win comes from running suites in parallel and splitting the two long suites so that none is the critical path. Nothing was
dropped to get there.

## 1. Suite runtimes

Every suite run alone, `--headless --fixed-fps 60`, one after the other (idle machine, nothing else running):

| Suite | Before (s) | After, run alone (s) |
|---|---:|---:|
| test_nav_fuzz | 115.5 | 87.9 |
| test_maze_golden | 49.1 | 53.0 |
| test_attempt_restarts | 24.5 | 24.7 |
| test_descent_runs | 22.6 | 24.0 |
| test_save_robust | 17.7 | 19.6 |
| test_autoplay | 14.8 | 15.7 |
| test_spawn_picker | 11.9 | 12.8 |
| test_random_usage | 7.7 | 8.2 |
| test_fog_bytes | 7.6 | 8.1 |
| test_border | 7.0 | 7.3 |
| test_phase3 | 6.7 | 6.9 |
| test_extremes | 5.8 | 6.2 |
| test_heat | 4.7 | 5.3 |
| test_slime_pricing | 3.4 | 3.8 |
| test_maps | 3.1 | 3.4 |
| test_phase5 | 2.9 | 3.0 |
| test_abilities | 2.3 | 2.3 |
| test_descent | 2.3 | 2.5 |
| test_story | 2.2 | 2.3 |
| test_random_tickets | 2.1 | 2.2 |
| test_autoplay_planner | 1.8 | 1.7 |
| test_trails | 1.8 | 2.1 |
| test_hub_skin_flow | 1.7 | 1.8 |
| test_hub_skins | 1.6 | 1.9 |
| test_medals | 1.5 | 1.6 |
| test_tickets | 1.5 | 1.6 |
| test_workshop | 1.5 | 1.6 |
| test_fresh_start | 1.2 | 1.4 |
| test_hub_maps | 1.2 | 1.6 |
| test_coins | 1.1 | 1.2 |
| test_next_steps | 1.1 | 1.1 |
| test_hub | 1.0 | 1.2 |
| test_rainbow | 1.0 | 1.0 |
| test_stopwatch | 1.0 | 1.1 |
| test_upgrades_v2 | 1.0 | 1.1 |
| test_dev_toggles | 0.9 | 0.9 |
| test_feedback | 0.9 | 0.9 |
| test_flow | 0.9 | 0.9 |
| test_hard_mode | 0.9 | 0.9 |
| test_hat_fit | 0.9 | 1.1 |
| test_mercy | 0.9 | 0.9 |
| test_pause_restart | 0.9 | 0.9 |
| test_seed | 0.9 | 1.0 |
| test_store | 0.9 | 1.2 |
| test_themes | 0.9 | 1.0 |
| test_bounce | 0.8 | 0.7 |
| test_dev_log | 0.8 | 1.0 |
| test_hard_rebalance | 0.8 | 1.0 |
| test_phase1 | 0.8 | 0.8 |
| test_phase1b | 0.8 | 0.8 |
| test_polish | 0.8 | 0.8 |
| test_records | 0.8 | 0.9 |
| test_skin_rules | 0.8 | 0.9 |
| test_story_complete | 0.8 | 1.0 |
| test_touch_cues | 0.8 | 0.9 |
| test_workshop_off | 0.8 | 0.9 |
| test_hats | 0.7 | 0.7 |
| test_level_tiles | 0.7 | 0.8 |
| test_phase2 | 0.7 | 0.7 |
| test_phase4 | 0.7 | 0.8 |
| test_phase6 | 0.7 | 0.7 |
| test_touch | 0.7 | 0.7 |
| test_jelly_swap | 0.6 | 0.8 |
| test_settings_layout | 0.6 | 0.6 |
| test_settings_nav | 0.6 | 0.7 |
| test_atmosphere | 0.5 | 0.5 |
| test_layout_migration | 0.5 | 0.7 |
| test_release_flags | 0.5 | 0.7 |
| test_save_code | 0.5 | 0.7 |
| test_save_isolation | 0.5 | 0.7 |
| **Total (sum of the 70 runs)** | **360** | **350** |

Top 10 slowest and what was done:

1. `test_nav_fuzz` 115 -> 88 s alone. It started a **child process of the full walk set** for the web ring (`--web-ui`, 7 plain walks of 600 steps
   **and** 11 area walks of 2,000 steps, about 50 s, run blocking inside the parent). The child's area walks now take 500 steps (the same
   eleven areas, the same web UI). Coverage of the normal ring is unchanged (18 walks x their full step counts, all scripted checks). In
   `test_all.sh` it is four parallel jobs (scripted 9 s, web ring 25 s, walks 0-8, walks 9-17); new `--nav-walk=A-B` and `--nav-no-web-child`.
2. `test_maze_golden` 49 s: pure CPU (8,000 generator runs at 5 ms; the generator keeps a static BFS buffer, so threads would be unsafe). Four
   shards (`-- --shard=K`, one per MORE SLIME group; shard 0 also checks the 20 story digests) compared against their slice of the golden file.
   Run without `--shard` it does everything as before.
3. `test_attempt_restarts` 24.5 s, 4. `test_descent_runs` 22.6 s, 5. `test_save_robust` 17.7 s, 6. `test_autoplay` 14.8 s, 7. `test_spawn_picker` 11.9 s,
   8. `test_random_usage` 7.7 s, 9. `test_fog_bytes` 7.6 s, 10. `test_border` 7.0 s: all real work (played floors/campaigns, 10,000 spawn picks
   and 20,000 hostile codes, per-step fog byte comparisons, a Python regeneration of 40 theme atlases). I looked for waste and found no frame
   count that a check does not need, so they are unchanged; they run in parallel with the others and start first (the `SLOW` list in the script).
   The one waste found elsewhere: about 60 places waited `END_DELAY` = 2 s (130 frames) after a win for buttons that appear after 0.6 s;
   they now wait `CHOICE_DELAY` + margin (see section 5).
- `test_autoplay` now cuts a stuck bot off at 120,000 frames instead of 400,000 (the campaign needs 14,198). A game bug that stops the bot
  (found by a mutation, below) used to hang the suite for 10+ minutes.

`test_all.sh` itself: `-j N`, `suite names`, `TIMES=1` (slowest jobs), `KEEP_LOGS=dir`; each job's output goes to a temp file and only
failures are printed; it re-execs under `caffeinate -i` (see the fuzz diagnosis).

## 2. Flakiness

I could not make `test_nav_fuzz` or `test_maze_golden` fail on the current code in any configuration (4 and 8 concurrent copies of the **old**
suites, 6-way and 12-way parallel `test_all`, 3 + 3 sequential runs, 3 pairs of simultaneous `test_all` runs, the first of which found the hard-maze budget problem), so the original one-off failures
have no proven cause. What I did find and fix, all of which break under concurrency:

1. **Fixed throwaway save names.** About 25 suites wrote `user://test_save.cfg` (the rest `test_save_heat/swap/story/1b`, `test_border`, `test_maps`,
   `test_dev_toggles`, `test_workshop_off`, `test_dev_log.log`): in the same user dir, one suite's write, load or end-of-run delete lands in
   another's save when two run at once (a parallel test_all, a QA fuzz next to a test_all, two agents). A stale `test_save_story.cfg` was lying in
   the dir. Now `throwaway_save()` gives `user://<suite>_<pid>.cfg` and `_result()` deletes it. (None of these were the real `save.cfg`.)
2. **Wall-clock budget asserts**: `test_tickets` (par for 20 levels < 100 ms; failed at 148-152 ms with 6-8 jobs), `test_descent` (floor build
   < 40 ms), `test_hard_rebalance` (worst hard build < 30 ms; failed at 39.5 and 43 ms with two test_all side by side, even as a best of 5).
   `_check_budget` takes the best of up to 5 runs and divides each by how much slower than idle a fixed workload just ran. A real slowdown of the
   code on an idle machine still fails; a busy machine does not.
3. **Real UTC day.** Suites that touch the daily pay caps (random tickets, Descent, abilities, mercy, ...) and the nav fuzz used the real
   date, so a UTC midnight (07:00 here) in the middle of a run reset the caps and changed behavior. `Progress.day_override` is pinned to a
   fixed day in the 13 affected suites and in `nav_fuzz_lib`.
4. `test_nav_fuzz` ran a blocking child process of 50 s inside itself (no timeout). It is now its own parallel job.
5. Left alone, noted for Phase 4: the game reads wall-clock time in three places (`UpgradesScreen` 300 ms double-buy guard, `Hats` rainbow flow,
   `MenuBackdrop` drift). Only the guard changes behavior (a buy within 300 ms of the last one is ignored), so a fuzz walk that buys things plays out
   slightly differently on a loaded machine. The invariants hold either way.
6. `test_maze_golden`: nothing in it depends on time, saves, order or other suites (seeded RNG, pure functions); 8 concurrent copies of the old
   suite all pass with identical digests. The most likely cause of the one failure is that code or `tests/data/maze_golden.txt` was being edited
   by another agent during the run (Phase 1 had several agents on the working tree).

Stability runs on the final commit: 3 sequential `./tools/test_all.sh`: `suites: 70 failed: 0` three times (113, 119, 114 s); one run of two
`test_all.sh` at the same time (12 jobs on 8 cores): both `70 failed: 0` (215 s). The parallel pair found a real problem earlier in the phase (the budgets in item 2, fixed). Real save (`SlimeTime_R1/save.cfg`) did not exist before and does not exist after; the
pre-release save (`Godot/app_userdata/Slime Time/save.cfg`) still has its mtime of Oct 13.

### Why QA's web / touch fuzz runs looked like 27 minutes

It is neither the harness nor the game: **the Mac was asleep.** QA's logs show `elapsed 73.4 s` (web 7002) and `77.7 s` (touch 7003) from the
test's own clock while the log files were opened at 20:41 and closed at 21:08. `pmset -g log` shows the laptop on battery in 15-minute
Maintenance Sleep cycles with 24-second dark wakes from 20:10 to 21:07 (lid/HID wake at 21:07), and the engine's tick clock does not count
sleep. The same pattern explains the 33 min for the default 7002 run at 18:25 (sleep at 18:27). Measured now on an idle machine:
`--nav-seed=7002 --nav-variant=web` takes **53 s** (`elapsed 52.8s`), the same as the harness-only cost. Game performance is not involved either: one walk
costs 2.3 ms per input and is linear (1,200 steps 3 s, 2,400 steps 5 s, 4,800 steps 11 s), the object count stays flat (5,374-5,654 objects, 0 orphans)
and the "50 enter/exit cycles" growth check passes. Fix: `test_all.sh` runs under `caffeinate -i`; for hand-run fuzz seeds use
`caffeinate -i ./tools/godot.sh ...`. Nothing for Phase 4 here.

## 3. Assertion-light tests

I found them in two ways: a scan of all 1,824 `_check(` calls for constant/tautological conditions, and **mutation checks**: 16 one-line breaks of game code
made in a scratch copy of the project (`/private/tmp/claude-501/p2/mut*`, never in the repo), each followed by the full parallel suite, plus the targeted mutations below.

Mutation sweep (caught = at least one suite failed):

| Mutation | Result |
|---|---|
| `tier_for`: silver boundary `<=` -> `<` | **survived** -> test_medals now pins the exact boundaries |
| `coins()` without the dev coins | **survived** -> test_coins pins it |
| `JUMP_COST_FACTOR` 0.5 -> 0.45 | survived on purpose (feel tuning, not pinned; unpinned constants are tuned by the owner) |
| `ASSIST_AFTER` `>=` -> `>`; `RANDOM_PAID_PER_DAY` `<` -> `<=`; reveal distance 24 -> 12; wall grip 0.85 -> 0.7; wall fog alpha 0.3 -> 0.45 | caught (test_bounce, test_maps, test_attempt_restarts, test_save_robust, test_medals...) |
| Price boundaries `<=` -> `<`: upgrades (coins), spin, TAILOR hat, ability, cosmetic; max level; buy counts as a spin; spin price ramp | all caught |
| (not in a table, but also tried) `test_extremes` smoke checks | **survived** (Reduce Motion, jelly and fog ignored by the level) -> rewritten |

Strengthened, each with a mutation proving it can fail (the old version passed with the same mutation):

| Test | Was | Now | Mutation that now fails it |
|---|---|---|---|
| `test_extremes` settings combos | `_check(true, "32 combinations rendered a level")` | 32 of 32 levels run and each wears its settings: `motion_scale()`, `fog_look()`, jelly translucency, level, hard mode | `motion_scale()` always 1.0; `set_translucency(0.0)`; `fog_look()` fixed at index 1 (old test passed the first one, checked) |
| `test_extremes` skins x hats | `_check(true, ...)` | the count must be skins x 2 + hats x 2 and every level wears the chosen skin | `skin_color = Color.WHITE` -> "26 of them without the chosen skin" |
| `test_extremes` menus | `_check(true, "menus survive...")` | each of 8 scenes loads (`scene_file_path`) and is still the same scene after the window storm | (scene load only; a missing scene is also caught by the error log) |
| `test_extremes` | `... or true` (twice: records, story-complete) | records line deleted (the next line is the real check); story-complete asserts 25/30 medals and the stopwatch still locked | n/a |
| `test_medals` | boundary 15.6 vs 1.3 x 12 (equal only by float luck) | exact gold/silver products pass, one hair slower drops a tier | `<=` -> `<` in `tier_for` |
| `test_coins` | dev coins untested | dev mode adds them, normal mode does not | `coins()` without dev coins |
| `test_next_steps` | wins waited, never checked the delay | no buttons at 0.5 s, the 3 buttons at 0.7 s, on level 1 and level 10 | `CHOICE_DELAY` 1.0 and 0.3 |

Not assertion-light after review: the `CONST: false` hits are failure branches, and `test_level_tiles` already counts the flames (`flames == 5`)
and rejects a tile whose flame is not the heat-10 one (the "flame-tile" check found earlier).

## 4. Shared helpers (tests/)

- `tests/suite_base.gd` (`extends "res://tests/suite_base.gd"` instead of `SceneTree`; 64 suites): `failures`, `_check`, `_result` (prints
  `RESULT:` and deletes the suite's throwaway files), `throwaway_save(tag)`, `_spawn_game(settings)`, `_physics_frames`, `_wait_seconds`,
  `_tap_key`, `_check_budget`, `_to_window`/`_send_touch`/`_send_drag`. About 500 duplicated lines removed (58 copies of `_check`, 14 of
  `_frames`, 8 of `_spawn`, ...).
- `tests/err_log.gd`: the engine-error collector (4 copies). `tests/nav_fuzz_lib.gd` was already shared.
- Left as they are (genuinely different, or one-off): `_press`/`_click` variants, `_state` builders, `test_save_robust`'s own error filter.
- Demo scenes (`tests/demo_*`, `autopilot.gd`, `qa_*`, `bench_*`, `audit_ui`) stay out of test_all (it only globs `test_*.gd`) and are listed with how to run
  them in **`tests/README.md`**. All of them, `tools/promo/`, `--story-complete`, autoplay and the dev toggles are untouched.

## 5. Phase 1 QA leftovers

- `tests/test_trails.gd` comment now says the batch 2 shots are only in `git show spring-cleaning-baseline:docs/polish-shots/batch2_trail_<style>.png`.
- `Game._finish(did_win, text)` lost its dead `delay` parameter, and `END_DELAY` / `WIN_FINAL_DELAY` are gone (nothing in the game used them). Behavior
  unchanged: the win shows its buttons after `CHOICE_DELAY` (0.6 s), a dry-up after `DRY_CHOICE_DELAY` (0.25 s) or `DESCENT_SUMMARY_DELAY`. Proof: the new
  `test_next_steps` timing check (above); all suites; and the pixel harness (`/private/tmp/claude-501/sc_pix/harness`, the same one as Phase 1: title, hub,
  skins, controls, level select, maps, levels 1/5/10 incl. rainbow, randomizer, hard, Descent, autoplay frames, story intro, pause, victory, the two BUY? confirms),
  phase-1 tag vs this branch: **41 frames, 0 differing pixels**. Tests that waited `END_DELAY` wait `CHOICE_DELAY` now.
- `docs/playtime-estimate.md` retry overhead no longer counts a 2 s wait.

## 6. The story intro "leak" (9/4 vs 3/1 ObjectDB instances / resources at exit)

**Noise, not a leak, and not from Phase 1.** `--verbose` shows what is left at exit: `AudioStreamWAV whoosh.wav` and two `AudioStreamPlaybackWAV`
(the sound that is still playing when the demo quits on its `done` signal); the count is the number of sounds still ringing at that moment, so it
depends on timing. Runs of `demo_story.tscn -- --story=intro --fixed-fps 60 --quit-after 6000`:

| Tree | idle machine | machine under load |
|---|---|---|
| `spring-cleaning-baseline` | 3 obj / 1 res (4 of 4) | **9 obj / 4 res (8 of 8)** |
| this branch | 3 / 1 (10 of 12; 2 of 12 exit with nothing) | 9 / 4 (3 of 6), 5 / 2 (2 of 6), clean (1 of 6) |

So the baseline shows QA's 9/4 too. Stopping every `Sfx` player before `quit()` does not remove them (the playbacks live in the AudioServer's mixer
until the process ends); every test suite prints the same "N resources still in use" because the autoloaded `Sfx` keeps its streams. Nothing to fix in
test/demo code. For Phase 4: optional, free the `Sfx` players and `AudioServer` playbacks in an exit hook for a quiet exit; no runtime effect.

## For Phase 4 (perf) and later

- The wall-clock reads listed in section 2, item 5.
- Maze generation is 5 ms mean / 19 ms worst per randomizer maze natively (8,000 builds); `MazeGenerator._order/_visited` are static scratch buffers, which
  would make building mazes on worker threads unsafe without changes.
- `Progress`'s per-process `dev_attempts_<pid>.log` files pile up in the user dir (45 left over from test runs); `DevLog._remove_stale` only deletes those older
  than 6 h. Harmless, a nicety to clean up on start.
