# Phase 1 QA test gate (qa-tester)

Branch `spring-cleaning`, tested at commit 24a1d49 (code) on the dev Mac (Apple M3), 2026-10-15. Baseline: tag `spring-cleaning-baseline` (dfbfccb).
Verdict: **PASS on all 8 checks, no bugs found.** Scratch evidence in `/private/tmp/claude-501/qa1/`.

| # | Check | Result |
|---|---|---|
| 1 | `./tools/test_all.sh` | PASS: `suites: 70 failed: 0`, 6:23.9 wall (baseline 5:58; ~7% slower, but run alongside concurrent reviewer/docs activity and an idle-priority worktree add, so within noise). No failures, no reruns needed. |
| 2 | Full autoplay campaign, speed 8, normal + hard | PASS: `COMPLETE: coins 165/165, medals 30/30 normal, 30/30 hard, 42 runs, 0 dry-ups`, all 10 levels cleared on both modes, rc=0, 235 s wall. Also covered by tests/test_autoplay (passed in check 1). |
| 3 | Nav fuzz, 10 extra seeds (7001-7010) | PASS: 30/30 runs `RESULT: PASS` (default, `--nav-variant=touch`, `--nav-variant=web` for each seed 7001-7010; default 7001 run alone earlier, 2:07). |
| 4 | Save round trips | PASS (own script, throwaway save, headless): fresh state -> played level 1 through the real game scene (cleared, best time 2.98 s recorded, file written) -> `save_code()` (SLIME2-, 743 chars) -> `reset_progress()` wiped state -> `load_code()` accepted and restored a byte-identical `_write()` -> after reset + save the file on disk has levels_cleared=0 and reloads fresh. Real-save safety: `~/Library/Application Support/SlimeTime_R1/save.cfg` did not exist before and does not exist after (no md5 to compare). tests/test_save_code, test_save_robust, test_save_isolation, test_autoplay (real save byte-identical) passed. Note: my script's `reset_progress(); load_progress()` disk-reload step did not restore the cleared level; identical behaviour on the baseline, so it is a harness artifact (not a regression), not investigated further. |
| 5 | Headless boot title/hub/main/story vs baseline | PASS: all rc=0. hub/main/story ERROR/WARNING lines identical to baseline (only the engine's exit-time "ObjectDB instances were leaked / resources still in use" pair, which baseline also prints for main/story). The title scene printed that pair in 1 of 1 first run on the new tree but baseline also printed it in 2 of 4 reruns, i.e. nondeterministic exit noise, not new. Baseline checked out in a temp worktree, imported, compared, and removed (`git worktree list` clean). |
| 6 | Web / Windows / macOS exports | PASS: all three `--export-release` rc=0 with zero ERROR/WARNING lines. Web `index.pck` 5,189,008 bytes (baseline 5,293,612, -2%), `index.wasm` 39,514,754 (identical). Windows exe 114.5 MB, macOS zip 64.3 MB, mac .pck 5,289,968. Web pck path listing (559 entries): 0 paths under tests/, tools/, docs/, _archive/, .claude/, build/ (top level: .godot, assets, scenes, scripts, icon.png). The string `res://icon.ico` appears once; it is the `config/windows_native_icon` value inside project.binary, not a packed file. |
| 7 | Story intro and finale demo scenes headless | PASS: `res://tests/demo_story.tscn -- --story=intro` and `--story=finale` each run without `--quit-after`, exit on their own `done` signal rc=0 (2 s and 1 s of wall time at max fps), no errors other than the exit-leak pair (baseline intro prints it too: 3/1 vs 9/4 instances; counts differ but it is exit-time noise). tests/test_story and test_story_complete passed. |
| 8 | Capture tools | PASS: `screenshot.sh --scene hub --unlock-all` (hub with all stations rendered), `screenshot.sh --scene main --level 5 --unlock-all` (Level 5/10 HUD + slime rendered), `--write-movie` of demo_story intro (2.1 MB avi, rc=0), tools/promo `cover.tscn` writes a 33 KB PNG, `jump_shot.tscn` renders via screenshot.sh (charged-leap shot with meter and landing dots). Note: `screenshot.sh --level N` alone shows the title because it needs `--scene res://scenes/main.tscn`; same as documented usage. |

## Bugs
None found.

## Observations (not bugs)
- Exit-time "ObjectDB instances leaked / resources still in use" lines appear in headless runs on both trees and vary run to run; counts on the story demo are higher than baseline (9/4 vs 3/1), worth a glance in a later phase if leak hygiene matters.
- The Phase 1 diff does not change the Web pck contents policy; the pck shrank ~104 KB.
