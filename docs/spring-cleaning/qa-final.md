# QA final: spring cleaning verification against the baseline

Reviewer: final QA lead (qa-tester + code-reviewer + perf-profiler standards), 2026-10-16. Code verified: `4451271` (the
later `7b7a384` touches only docs). Baseline: tag `spring-cleaning-baseline` (`dfbfccb`) and [baseline.md](baseline.md).

## Method

- Both trees were scratch git worktrees, each with its own fake `HOME`:
  - final: `/private/tmp/claude-501/final_wt` at `4451271`;
  - baseline: `/private/tmp/claude-501/final_base` at `dfbfccb`.
- Probes ran from scratch files only (none committed):
  - `qa_final_play.gd`: 20 randomizer seeds and abilities;
  - `qa_final_soak.gd`: a soak through every mode;
  - `qa_final_inputs.gd`: a pad-only and touch-only copy of the nav fuzzer;
  - `qa_final_kill.gd`: a Descent kill and resume across real `kill -9`;
  - the phase 4 perf drivers (`p4.gd`, `trans.gd`, `qa4_pace.gd`);
  - movie-writer captures with a pixel differ.
- Wherever a probe runs on both trees, it ran on both on the same machine (Apple M3, Godot 4.7.2) in the same session, so
  the before/after numbers compare like with like.
- **Real save.** `~/Library/Application Support/SlimeTime_R1/save.cfg` did not exist before or after the run. The md5 of
  every other file in that folder (`dev_attempts.log`, `logs/*`) was identical before and after.
- **Godot processes.** None that I had not started was touched.

## INCIDENT (must fix first): the Godot editor binary was overwritten

- **What happened.** While re-running the kill probe I used `tools/job_timeout.pl` with the wrong argument order. Its
  usage is `job_timeout.pl SECONDS PIDFILE COMMAND...`, and I left out PIDFILE. The script therefore took
  `/Applications/Godot.app/Contents/MacOS/Godot` as its PID file and **wrote a 5-byte PID into it**.
- **Current state.** The Godot 4.7.2 editor binary on this Mac is destroyed:
  - `/Applications/Godot.app/Contents/MacOS/Godot` is now the text `41123`;
  - every `./tools/godot.sh`, `test_all.sh`, `screenshot.sh`, `play.sh` and export now fails with "command not found".
- **Why it can't be restored locally.** There is no local copy of 4.7.2 (`~/Downloads/Godot.app` is 4.3). Time Machine is
  not mounted, and the APFS snapshots are system-update snapshots only.
- **Fix (owner).** Re-download Godot **4.7.2-stable** (macOS universal, the official build `ed1daf0bf`) from
  godotengine.org and replace `/Applications/Godot.app`.
  - I did not download it myself: a download needs the owner's go-ahead.
  - The export templates (`~/Library/Application Support/Godot/export_templates/4.7.2.stable`) are intact.
- **Effect on the results.** Every result below was measured before this happened. The only check it cut short is the
  real-process Descent kill test (see edge cases).
- **Lesson.** `job_timeout.pl` should refuse a PIDFILE that already exists and is not a pid file (a one-line guard). See
  known issue 3.

## 1. Test suites

| | Baseline | Final |
|---|---|---|
| Suites | 70, all passing | **76, 0 failed** (two runs) |
| `./tools/test_all.sh` wall time (default jobs) | 5 min 58 s (serial runner) | **1 min 51 s** (run 1, 6 jobs) and **2 min 08 s** (run 2): 2.8-3.2x faster |
| Serial (`-j 1`) | 5:58 (doc). Re-measured today under load: 8:47 | 6:59 under the same kind of background load (76 suites, against 70) |

The speed-up comes from the parallel runner and sharding (phase 2). Per job, the slowest are the nav-fuzz walks 9-end
(59 s), `test_descent_runs` (58 s) and the nav-fuzz walks 0-8 (48 s).

## 2. Full playthroughs (final and baseline give the same simulation)

- **Autoplay campaign**, `--autoplay --speed=8 --autoplay-cinematics --autoplay-quit`, normal then hard, headless at
  `--fixed-fps 60`:
  - **165/165 coins, 60/60 gold medals (30 normal + 30 hard), 10/10 hard cleared, 0 dry-ups**, upgrades 7/4/3, game time
    1803.18 s.
  - The final summary is **field-for-field identical to the baseline**: the same best times and the same 42 runs.
  - A windowed real-time speed-8 run was not repeated (cut off by the incident). The headless run plays the same ticks.
- **Randomizer, 20 seeds** (MORE SLIME 0-7, autopilot):
  - **20/20 won**, including the largest maze (36x20, seed 1, MORE SLIME 7) and 9 more 36x20 mazes.
  - Every line (cells, route, slime left, time) is **identical to the baseline**.
- **Abilities in the randomizer** (3/3/3, rifle, splat and kaze fired during the run, 4 seeds):
  - 3 won, 0 engine errors, identical to the baseline.
  - The 4th (seed 17485866) stalls the same way in both trees: the test autopilot does not re-plan after a SLIMAKAZE
    dash. This is a harness limit, not a regression.
- **HEAT combos** (`tests/bench_heat.gd`, every pickable mask on every hard level):
  - **480 runs, 0 lost**, identical to the baseline. Tightest: 7.4 % slime left (L1, THIRSTY); 58 % of the RACE
    countdown.
  - The bench's own exit leak halved (34 to 17 objects).
- **Descent** (`test_descent_runs -- --runs=20 --deep=6`):
  - 20/20 runs reach floor 4.
  - Deep runs reach floors **14, 14, 9, 14, 11, 11**: 5 of 6 reach floor 10 or more, and 14 is the suite's cap.
  - The output is identical to the baseline.
- **Story-complete launch**: every scene boots with `--story-complete` (section 5), and the soak runs from that state.
- **Cutscenes** (movie writer at 60 fps, every 10th frame compared pixel by pixel, final against baseline):
  - Story intro (1428 frames), finale (771) and the Reduce Motion intro (1494): **the cutscene art is pixel-identical**.
    The only difference is 4 px per frame in row 159, x 146-173: the current story pip.
  - That pip change is phase 3's documented fix **Y1** (the pip is centred on its row, rows 159-163 instead of
    160-163). It belongs to the UI overlay, not the art.
  - First-launch trailer from a fresh save (3600 frames): every trailer frame matches except that pip row.
  - From the wipe into the title (frame 1450) on, frames differ **run to run in the same tree**: baseline against
    baseline differ from frame 1460, and final against final do too. The cause is the title's per-scene random text
    drips and wall-clock backdrop drift, already noted in qa-phase4-review's harness notes. So this is not a change.
  - `demo_launch` (trailer skipped) behaves the same way.
  - D1 holds: every cutscene, banner and the STORY button are intact.

## 3. Edge cases

- **Nav fuzz, beyond the suite's own seeds** (all strict, 0 violations): default seeds 9001 and 9002, the touch variant
  9004, the web ring 9003 and 9005. These cover:
  - rapid input spam: double and burst presses, presses in the wipe and on the scene-change frame;
  - pause and resume spam;
  - background on and off at random moments (BG-PAUSE, BG-CLOCK, BG-HELD);
  - Android back.
- **Gamepad only** (a fuzzer copy whose only inputs are A, B, X, Y, D-pad, START, VIEW, LB/RB, the stick, waits and
  background), 6 seeds, up to 3000 steps per walk: **PASS, 0 violations**. It reached title, hub (coin board, portal,
  quit, wheel, shop), level select and HEAT panel, upgrades (both tabs), skins (skins, hats, trails), maps and map view,
  controls, key controls, the code panel, reset, a story level (pause, R prompt, dry-up, win), victory, story, and
  Descent floors, boon cards and the run summary.
  - Not reached at random: the seed box (it needs typing; a pad uses COPY / PASTE), HEAT in play, the wheel's buy
    confirm, a key rebind wait. `test_gamepad` covers all four.
- **Touch only** (taps on buttons and at random, the touch pause / home button, the JUMP circle, the joystick, waits,
  background), 6 seeds x 2000 steps: **PASS, 0 violations**. Coverage was the pad list plus HEAT, the seed box,
  `keys:rebinding` and `settings:codepanel`.
- **Save and load.** Every soak cycle saves, exports a save code, imports it and reloads (188 round trips in all), with 0
  errors. `test_save_robust` (corrupt and truncated files, gzip bombs, disk full) and `test_save_code`
  pass in both runs.
- **Descent kill and resume, one-resume cap (D9).**
  - `test_descent_resume` passes: hostile data and the cap.
  - My real-process probe got through the first kill: floor 2 start, pot 1, `resumes` 0, then the process was killed.
    Its relaunch found no run, because a `-s` tool run does not load its save at boot (a harness detail: `load_progress`
    only runs for player launches).
  - The fixed rerun is the one that hit the incident above, so the real-kill relaunch with the cap is **not
    re-verified here**.
  - The code review (section 7) found the cap logic correct.
- **Soak**, 65 simulated minutes per tree, headless at `--fixed-fps 60`. Each cycle visits title, hub and hat wheel; a
  story level (every 3rd hard, every 15th with HEAT) and an R restart; a randomizer at MORE SLIME 0-7 with abilities
  fired; ESC spam; a Descent run of 2 floors; a story cutscene; skins, maps, level select, upgrades and controls; a
  save / code / load; and random background toggles.

  | | Baseline | Final |
  |---|---|---|
  | Length | 65.9 sim min, 215 level starts | 65.4 sim min, 200 level starts |
  | Nodes / orphans / resources (from cycle 1) | +0 / +0 / +0 | **+0 / +0 / +0** |
  | Objects | +26 | +60 (levels off at about 5,690; a 240 sim min run: +63, flat from cycle 30 to 148) |
  | Static memory per level start | 10.1 KB | 10.9 KB (240 min: 10.9; engine-internal per the phase 4 audit) |
  | RSS | +16 MB | +18 MB (240 min: +30 MB) |
  | Script / engine errors | 0 | **0** |

## 4. Performance against the baseline

Per scene (`p4.gd`, windowed, vsync off, `--fixed-fps 60`, 120 warm-up + 600 measured frames, median of 2 runs per tree,
interleaved):

| Scene | Frame avg / p99 ms, baseline | final | Draw calls | Render CPU ms | Load ms |
|---|---|---|---|---|---|
| title | 0.89 / 2.08 | 0.89 / 1.98 | 14 -> 14 | 0.13 -> 0.13 | 155 -> **560** (boot preload, by design) |
| hub | 0.91 / 2.06 | 0.92 / 2.16 | 27 -> 27 | 0.14 -> 0.15 | 174 -> 177 |
| level select | 1.28 / 2.64 | 1.25 / 2.37 | 52 -> 52 | 0.32 -> 0.31 | 115 -> 105 |
| upgrades / maps / skins / controls | 1.00-1.29 | 0.99-1.31 | same | same | 3-10 ms faster |
| hat wheel | 1.21 / 2.45 | 1.21 / 2.44 | 78 -> 78 | 0.32 | 174 -> 179 |
| L1 | 1.45 / 2.80 | **1.23 / 2.53** | **116 -> 33** | 0.39 -> 0.21 | 312 -> 315 |
| L5 | 1.45 / 2.70 | **1.22 / 2.44** | **116 -> 33** | 0.39 -> 0.21 | 316 -> 315 |
| L10 | 1.46 / 2.71 | **1.20 / 2.37** | **116 -> 33** | 0.39 -> 0.21 | 310 -> 317 |
| hard 10 + all HEAT | 1.38 / 2.63 | **1.18 / 2.37** | **102 -> 34** | 0.35 -> 0.20 | 314 -> 318 |
| randomizer max (36x20) | 1.49 / 2.68 | **1.31 / 2.40** | **75 -> 28** | 0.31 -> 0.21 | 330 -> 340 |
| randomizer + abilities | 1.64 / 3.02 | **1.38 / 2.66** | **75 -> 28** | 0.33 -> 0.21 | 368 -> 355 |
| Descent floor 1 | 1.50 / 2.75 | 1.44 / 2.76 | 33 -> 28 | 0.26 -> 0.24 | 356 -> 358 |
| Descent floor 10 | 1.92 / 3.22 | **1.56 / 2.91** | **121 -> 38** | 0.44 -> 0.25 | 361 -> 362 |
| story intro / finale | 2.24 / 3.47 | 2.18 / 3.32 | 57 -> 57 | 0.42 -> 0.41 | 138 -> 142 |

**Gameplay frames are 12-19 % faster, with 65-72 % fewer draw calls.** Menus and cutscenes are unchanged, within noise.

Transitions through the real goo wipe (`trans.gd`; the worst frame inside the wipe; both runs per tree):

| First use in the session | Baseline | Final |
|---|---|---|
| title -> hub | 96.7 / 105.4 ms | **29.4 / 32.1 ms** |
| -> L1 (first level) | 182.0 / 184.7 ms (the wipe overran to 716-726 ms) | **37.4 / 38.1 ms** (541-544 ms, on time) |
| -> story | 85.8 / 95.0 ms | **8.9 / 10.3 ms** |
| -> menus / L10 / randomizer / Descent | 24-51 ms | 27-53 ms (unchanged) |

- **Warm (second pass):** unchanged for levels. Menus are 1-5 ms worse in the worst frame (hub 10 -> 12-16 ms,
  level select 18 -> 21 ms). That is small and under one 60 Hz frame. Noted, not a finding.
- **Cost of the preload:** the title's first load is 155 -> 560 ms, under the boot screen.

High refresh (`qa4_pace.gd`, L1 autopilot with a top hat, 5 s per rate):

| Rate | twitches/s (1 px back-and-forth) before -> after | on the ideal pixel | interpolation switches | hat reversals | light off the slime |
|---|---|---|---|---|---|
| 60 Hz | 6.0 -> 6.0 (identical frames, interpolation off) | n/a | 0 -> 0 | 0 -> 0 | 0 -> 0 |
| 144 Hz | 24.8 -> **0.0** | 40.1 % -> **96.2 %** | 0 -> 1 (the start-up switch on, after the 0.5 s hold) | 2 -> 0 | 2 -> 0 |
| 240 Hz | 17.4 -> **0.0** | 32.9 % -> **94.8 %** | 0 -> 1 (the same) | 0 -> 0 | 1 -> 0 |

"On the ideal pixel" includes the first 0.5 s, which is drawn before interpolation turns on (about 5 % of frames). The
renderer and the script mirror agree in 100 % of frames.

Web export (release, both trees exported today; my scratch `perf/` folder was moved out first):

| | Baseline doc | Baseline re-export | Final |
|---|---|---|---|
| `index.pck` | 5,293,612 | 5,293,580 | **5,232,424 (-61,188 bytes, -1.2 %)** |
| `index.wasm` | 39,514,754 | 39,514,754 | **39,514,754 (same engine)** |

Desktop exports (final): Windows 114,560,408 bytes; macOS zip 64,386,310; Linux 78,751,848. The pck has no `tests/`,
`tools/`, `docs/`, `.claude` or `_archive` paths.

Repo:

| | Baseline | Final |
|---|---|---|
| GDScript lines (scripts + tests + tools) | 42,859 | **46,497** (+3,638: scripts 21,817 -> 23,572 (platform seam, pad, Descent resume, interpolation); tests 20,925 -> 22,808; tools 117) |
| Scripts | 64 | **67** (+`platform.gd`, `platform_events.gd`, +1) |
| Test files | 116 | **124** (suites 70 -> 76) |
| Tracked files | 1,216 | 1,200 |
| `assets/` | 20 MB (20,976 KB) | **20 MB (20,908 KB)** |
| `docs/` tracked | 22 MB | **13.3 MB** |
| `docs/` on disk | 58 MB (22 tracked + 36 git-ignored polish mp4s) | 116 MB: 13.3 tracked + 36 polish mp4s + **68 MB new git-ignored `spring-cleaning/perf/*.mp4`** (phase 4 D5 captures; local only, delete when the owner has seen them) |
| Git pack | 25.2 MiB (the one on-disk pack file) | The pack file is still 25.20 MiB, plus 3,272 loose objects (59 MiB). Fully packed (a fresh `--no-local` bare clone): baseline only 46.96 MiB -> spring-cleaning **52.38 MiB** (+5.4 MiB over 67 commits; no history rewrite, D7) |

## 5. Clean logs

- **Headless boot of all 13 scenes**, plain and with `--story-complete` (26 boots): 0 errors and 0 warnings, except the
  known engine exit-leak pair.
  - **Where it shows:** only in `main.tscn`, as "2 ObjectDB instances leaked / 1 resource still in use". The baseline
    showed it in `main` and in `hub --story-complete`, so there is one fewer now.
  - **Cause** (`--verbose`): an `AudioStreamWAV` and its `AudioStreamPlaybackWAV`, `res://assets/sounds/ambient_dungeon.wav`,
    still playing when `--quit-after` ends the run. The level's ambience is not stopped before the tree is torn down.
    This is an engine-side exit artifact, harmless.
- **Exports:** Web, Windows, macOS and Linux release exports have **0 errors and 0 warnings**. The exported macOS app
  boots, headless and windowed (fake HOME), with no errors.
- **Not clean:** every *windowed* quit of the debug build prints PlatformEvents errors. See known issue 1.

## 6. Marketing and capture tools

- **`tools/promo/make_promo.sh --out-dir <temp>`:** all 9 images in 1 min 19 s (`cover.png` and `screenshot-1` to `-8`).
  - `screenshot-6-new-record` (frame 1150) shows the result panel, the NEW RECORD banner and REPLAY / NEXT LEVEL / HUB.
  - The run's stderr shows the issue-1 exit errors.
- **`tools/screenshot.sh`:** exercised 9 times by the promo run.
- **`--write-movie`:** the PNG captures of `demo_story` (intro, finale, `--calm`), `demo_launch` and the fresh-save boot
  all work.
- **Demo scenes:** `demo`, `demo_record_run` and `tools/promo/jump_shot` / `cover` were rendered by the promo run.
- **Autoplay:** `--autoplay` (with cinematics) ran in section 2.
- **Not run separately:** the windowed `play.sh --dev` / `--story` launches. `play.sh` only maps them to `--unlock-all`
  and `--story-complete`, and both flags boot cleanly in section 5.
- **Story demo:** `demo_story` was captured in full (section 2).

## 7. Code review of `44ba3a8..4451271`

The review covered:
- `44ba3a8` rainbow gold counts;
- `8108557` the interpolation switch hold and hitch rule, and the camera carry-over;
- `36d780b` the first-launch preload;
- `ddccdb2` `shortest_path` with no route;
- `0b4a702` the promo frame;
- `4451271` the D9 resume cap, the D10 home icon, the wipe pause, the fullscreen sync and the boon excludes.

What holds:
- **D9 cap.**
  - `resumes` is written with every snapshot and reset by `_reach_descent_floor` (the only new-floor path) and by
    `clear_descent_floor`.
  - The read is clamped to 0..1 and forced to 0 on a boon card.
  - RESUME counts the resume and saves before the scene loads. QUIT RUN goes through `_load_saved_descent`, so a spent
    floor can still bank.
  - I found no path that resets the count without a clear.
- **Wipe pause.** `_pause_if_backgrounded` waits until the wipe is over, then pauses once, and only if the app is still in
  the background and the platform wants it paused.
- **Interpolation switch and camera.** A hitch is skipped without breaking the hold, a run of 3 hitches counts, and the
  hold resets on every flip. The camera seed only applies mid-level.
- **No new web or Android shader risk.**

Findings:

1. `scripts/platform_events.gd:84` (`_notification`) - the macOS window sends `NOTIFICATION_APPLICATION_FOCUS_OUT` while
   the app quits, after the autoload has left the tree. `enter_background` then calls `get_tree()` on null:
   - `ERROR: Parameter "data.tree" is null`;
   - `SCRIPT ERROR: Cannot call method 'call_group' on a null value` at :137;
   - at :114 / :117, `get_node()` from outside the tree, and `'root' on a null instance`.

   This happens on every windowed debug quit (game, captures, promo, tests). It is new since phase 5 and the headless gates
   could not see it. The fix is `if not is_inside_tree(): return` at the top of `_notification`; I verified in scratch
   that it removes every one of these lines.
2. `scripts/progress.gd:505` (`window_mode_changed`) - MINIMIZED is treated as "not fullscreen".
   - **Failure:** on Windows, minimizing a fullscreen window (Win+D or the taskbar) saves `fullscreen=false` after
     0.8 s. Restoring the window saves `true` again, but quitting while minimized makes the next launch windowed.
   - **Status:** found by reading the code, not verified on Windows.
   - **Fix:** `if mode == DisplayServer.WINDOW_MODE_MINIMIZED: return false`.

No other issues.

## Known issues, ranked

| # | Severity | Issue | Repro |
|---|---|---|---|
| 0 | **Blocker (environment, caused by this QA run)** | The Godot 4.7.2 editor binary was overwritten with a PID (see INCIDENT) | `cat /Applications/Godot.app/Contents/MacOS/Godot` prints `41123`. Fix: reinstall 4.7.2-stable |
| 1 | Low (log noise; can hide real errors in captures and logs) | PlatformEvents script errors on every windowed quit | `./tools/godot.sh --path . --quit-after 200 res://scenes/hub.tscn -- --story-complete`, then read the last lines |
| 2 | Low (Windows only, unverified) | A fullscreen choice is lost if the game quits while minimized | Windows: F11, Win+D, close from the taskbar, relaunch: the game opens windowed |
| 3 | Low (tooling) | `tools/job_timeout.pl` writes the pid into whatever file is its 2nd argument, with no check | `perl tools/job_timeout.pl 60 <some file> cmd` overwrites `<some file>`. Fix: refuse an existing non-empty PIDFILE, or one that is not in a temp dir |
| 4 | Info | The test autopilot cannot finish some randomizer runs after a SLIMAKAZE dash (same in the baseline) | `qa_final_play.gd`, seed 17485866, MORE SLIME 1, all abilities |
| 5 | Info | Warm menu transitions are 1-5 ms worse in the worst frame (still under 16.7 ms) | `trans.gd`, pass 2 |
| - | Open from earlier phases | M5 rainbow cost on phones, M3 pad on the color wheel, the port-time items, D7 (local mp4s) | see [phase5-platform.md](phase5-platform.md) |

## Verdict

**Ship-ready on code**, with one caveat: the Godot binary must be reinstalled before any further work on this Mac.
- Every suite passes, and the suite run is about 3x faster.
- The campaign, randomizer, HEAT and Descent simulations are tick-identical to the baseline.
- The cutscenes are pixel-identical apart from the documented pip fix.
- Gameplay frames are 12-19 % cheaper, with 65-72 % fewer draw calls.
- The first-use stalls are cut 3-10x.
- At high refresh rates, twitching drops from 17-25 per second to 0.
- The web pck is smaller and the wasm is the same.
- Issue 1 is a one-line fix worth doing before release.

## Housekeeping

- Removed afterwards: the scratch worktrees (`final_wt`, `final_base`), the fake HOMEs, the captures and the bare-clone
  pack measurements.
- The real save folder was verified unchanged (see Method).
