# QA review: Spring cleaning phase 2 (test suite health)

Reviewer: code-reviewer (QA gate). Range: `spring-cleaning-phase1..9a117db`, limited to `tests/`, `tools/test_all.sh`,
`scripts/game.gd` and `docs/spring-cleaning/phase2-tests.md`. Read-only review. The only file written is this one.

## Runs

- `./tools/test_all.sh` (default 6 jobs, macOS `/bin/bash` 3.2.57): `suites: 70 failed: 0 (6 jobs, 95 s)`, exit 0.
- `./tools/test_all.sh -j 1 test_save_robust test_fresh_start`: `suites: 2 failed: 0 (1 jobs, 19 s)`, exit 0.
- `-j 1 test_tickets test_descent test_hard_rebalance` on an idle machine (timing headroom, see finding 3).
- Fake-Godot harness (`GODOT=<script>`) for failure paths. A suite that prints `RESULT: FAIL`, a suite that segfaults and a
  failing `test_maze_golden#2` shard each show up as `<label> FAILED:` with their FAIL/SCRIPT ERROR lines, and the run exits 1.
  With only an unknown suite name it prints `no such suite` and exits 1.
- Real save `~/Library/Application Support/SlimeTime_R1/save.cfg` did not exist before these runs and does not exist after them.
  No `test_*_<pid>.cfg` files were left behind.

## Findings (most severe first)

1. **tools/test_all.sh:80-94 - no per-job wall-clock timeout.** Each job is `godot ... > log` under `xargs -P` with only
   `--quit-after 300000` (a frame count). A blocking hang never reaches that frame limit. Examples: a hung `OS.execute`
   child (test_border, test_autoplay, test_hat_fit, test_hub_maps, test_maps and test_save_robust all start child processes),
   or an engine-level hang like the one in `tests/qa_poc_gzip_hang.gd`. In that case `test_all.sh` never ends and `caffeinate -i`
   keeps the Mac awake indefinitely. Nothing says which job is stuck, and on Ctrl-C the `trap` on line 48 deletes every log
   (`KEEP_LOGS` only copies them at the end). **Fix:** wrap the Godot call in a watchdog. macOS has no `timeout` but does have
   perl: `perl -e 'alarm shift; exec @ARGV' "${JOB_TIMEOUT:-600}" "$root/tools/godot.sh" ...`. Write `TIMEOUT` into the
   `.result` file when the job exits by signal. Also count the `.result` files against the jobs in `jobs.txt`, and on INT print
   the labels that have no result yet and keep `$work`.

2. **tests/test_save_robust.gd:63-67 - the start-up sweep deletes other live runs' files.** It removes every
   `user://qa_robust_*` file, which includes the pid-tagged scratch saves of another `test_save_robust` running at the same time.
   That breaks the promise in `tools/test_all.sh:9-10` that two `test_all.sh` runs side by side "cannot disturb each other". Two
   agents running tests a few seconds apart is the normal case on this branch, and the suite runs for about 29 s. If run B
   starts during run A, run A's write-then-reload cases find their file gone and fail at random. The phase-2 pair test started
   both runs together, so both swept before either had written anything. **Fix:** only delete files whose embedded pid is not a
   running process (`OS.is_process_running(pid)`), or only files older than about 10 minutes.

3. **tests/suite_base.gd:78-107 (`_check_budget`) - cannot catch a 2x slowdown, and the load adjustment can over-correct.**
   Idle measurements versus budgets: descent floor 7.5 / 40 ms (5.3x headroom), hard maze 9.5 / 30 ms (3.2x), par for 20 levels
   48.7 / 100 ms (2.05x). So a 2x regression passes all three even on an idle machine. Under the 6-job run, par was "load-adjusted"
   to 39.0 ms, *below* its idle 48.7 ms. Dividing by a 4.75 ms probe and then keeping the best of 5 quotients picks the try where
   the short probe was preempted or ran on an efficiency core while the long measurement was not, which hides about 20% more.
   The comment and `phase2-tests.md` item 2 ("a real slowdown ... on an idle machine still fails") overstate what the check
   does. **Fix:** probe before and after the measurement and use the smaller value, cap `slowdown` (for example at 2.0), and set
   budgets near 2x the idle value (about 15 / 20 / 100 ms) if 2x is meant to be caught. Otherwise reword the comment and docs to
   say these budgets only catch gross (3x and up) regressions.

4. **tools/test_all.sh:37-38 - nav_fuzz walk shards are hard-coded to `0-8` and `9-17`.** Today's walks are 7 plain plus 11 area
   walks, indices 0-17, and the logs confirm 9 + 9 walks ran. If a 12th `AREAS` entry or another start is added (index 18),
   `test_all.sh` silently never runs it, while a standalone `test_nav_fuzz` still would. **Fix:** make the last shard open-ended
   (accept `--nav-walk=9-` or `9-999` in `test_nav_fuzz.gd`), or have the suite fail when a `--nav-walk=A-B` range ends before
   the last index while `B` is the declared end.

5. **tools/test_all.sh:62-78 - a mistyped suite name next to a valid one is silently ignored.**
   `./tools/test_all.sh test_phase1 test_typo` prints `suites: 1 failed: 0` and exits 0 (checked with the fake-Godot harness).
   A caller who means to run two suites gets a green result for one. **Fix:** after building the job list, check each name in
   `wanted` against `suites` and exit 1 with `no such suite: <name>` for any that does not match.

6. **scripts/dev_log.gd:44 (exercised by tests) - per-process files pile up in the release user dir.** Each full
   `test_all.sh` leaves about 18 `dev_attempts_<pid>.log` files in `~/Library/Application Support/SlimeTime_R1/` (169 files and
   9.2 MB there now, next to where the player's `save.cfg` goes). Throwaway saves of a suite that crashes or hits `--quit-after`
   are also never removed, because only `_result()` deletes them. PIDs get reused, so an old file can be appended to later.
   **Fix:** have `suite_base._result()` (and `nav_fuzz_lib`) also delete `DevLog`'s per-pid log, and add one stale sweep (gated
   by `OS.is_process_running` as in finding 2) for `test_*_<pid>*.cfg` and `dev_attempts_<pid>.log`.

## Checked and fine

- **Parallel runner.** Works on macOS bash 3.2 (`export -f`, `<<<`, `${x//#/_}`, empty arrays). `caffeinate -i` re-execs once
  and the exit code passes through. A failing suite, a crashed suite or a failing shard makes the run fail and is named.
  `failed` counts suites with any failed shard only once. Logs are per job, and `KEEP_LOGS` / `TIMES` work. There is no
  `test_all.ps1`. CLAUDE.md:32 documents Windows as running each suite on its own (serial), and the sharded suites still run in
  full without arguments (`test_maze_golden` without `--shard`, `test_nav_fuzz` with its in-process web child).
- **suite_base / err_log consolidation.** Every one of the 58 removed `_check` bodies was the same as the shared one (print
  `ok`/`FAIL`, `failures += 1`). Every one of the 64 removed `RESULT` lines was the same condition as `_result()`. The removed
  `_frames`, `_wait`, `_spawn`, `_key`, `_touch` and `_drag` helpers all awaited `physics_frame` / set the same fields, the same
  as their base versions. Per-suite `_check(` counts drop by exactly the one removed definition. The exceptions are test_coins
  (+1), test_next_steps (+2) and test_extremes, where the tautologies `_check(true, ...)` and `... or true` were replaced by real
  conditions. ErrLog filters the same warnings and "Clipboard" messages (only the stored-line cap differs). `test_all` still
  matches `RESULT: PASS`.
- **throwaway_save.** `user://<suite>_<pid><tag>.cfg` can never equal `user://save.cfg`, and `Progress._is_real_save` guards
  the path as well. The file is deleted when created and again in `_result()`. Base members are initialized before suite
  members, so the `var test_save := throwaway_save()` member initializers register correctly.
- **Pinned UTC day.** `Progress.day_override` is a plain in-memory variable (progress.gd:142, read only at :1332), never saved.
  It is set only in tests and `nav_fuzz_lib`, so it cannot leak into a normal launch.
- **game.gd dead delay.** The old `_finish` never read `delay`. Both branches wait `DRY_CHOICE_DELAY` / `DESCENT_SUMMARY_DELAY`
  / `CHOICE_DELAY`, the same as before. No callers with 3 arguments remain anywhere in the repo. test_next_steps shows no
  buttons at 0.5 s and buttons at 0.7 s on levels 1 and 10, and nav_fuzz shows CONTINUE after level 10 -> finale -> Esc ->
  victory (both pass). None of the waits changed from `END_DELAY` to `CHOICE_DELAY` is waiting on a descent dry-up (1.0 s).
- **nav_fuzz reduction.** The normal ring keeps all 18 walks at full step counts plus every scripted check. Only the `--web-ui`
  ring's 11 area walks dropped from 2,000 to 500 steps (same seed 1239 = 1234 + 5, same 7 x 600 plain walks). It now runs as its
  own job, gated on its own `RESULT` line. That is still meaningful coverage of the web-only UI (hub without QUIT).
- **maze_golden shards.** The slices `[0, 40 + 2000)` and `[40 + K*2000, 40 + (K+1)*2000)` match the order the file is written
  in, and a truncated golden file fails the size check. An out-of-range `--shard` crashes, which counts as a FAIL.
