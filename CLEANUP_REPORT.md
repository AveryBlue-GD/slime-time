# Cleanup report: audit of 2026-11-02

Branch `cleanup/audit-2026-11-02`, based on `claude/mobile-sync-polish` (PR #5, which already holds PR #3 and #4), as
Conner chose. The full working notes are in [AUDIT.md](AUDIT.md): the file map, the baseline, every finding with its
status, and a change log with a test or a measurement for each change. The six review reports are in
[docs/audit/2026-11-02/](docs/audit/2026-11-02/).

**In one paragraph:** 28 changes. Fifteen fix real bugs, each with a test that fails without the fix. One of them was a
softlock players on phones could reach. Seven make the game cheaper to run, each measured before and after. The rest
delete dead code or fix build and tooling problems. Every test suite still passes, apart from one that only fails because
the cloud machine runs as root; it passes as a normal user, the same result as before the cleanup. The hub's frame cost
dropped by about 70 %, and launch got 5-10 % faster. Five findings need your decision because fixing them would change
how the game looks or feels, and they are listed below. Nothing was merged.

## 1. Baseline vs final

Same cloud machine (Linux, 4 cores, the official Godot 4.7.2 binary CI uses), headless, so this is CPU cost only, not the
GPU. "Gate" = the full check every batch went through: all suites, asset import, export pack sizes, and the 8-scenario
bench (`bench/run.sh`, 7 runs, median).

| Metric | Baseline (4826fd0) | Final (c75be70) | Change |
|---|---|---|---|
| Test suites | 137 run, 136 pass (+1 root-only) | 138 run, 137 pass (+1 root-only; passes as a normal user) | +1 suite, +16 checks in 11 suites |
| Asset import | 0 warnings | 0 warnings | = |
| GDScript warnings | 0 | 0 | = |
| Engine warnings in test logs | 134 (131-134 between runs) | 127 | -7 |
| Export pack, macOS | 12,317,692 B | 12,312,292 B | -5,400 B (the unused sound) |
| Export pack, iOS | 12,216,780 B | 12,211,380 B | -5,400 B |
| Export pack, Web | 11,627,664 B | 11,622,264 B | -5,400 B |
| Nodes in every scene | e.g. title 120 | 117 | -3 (the unused sound's 3 players) |
| Orphan nodes | 0 | 0 | = |

**Head-to-head bench** (base and final checked out side by side, run in alternating rounds right after the final gate,
9 runs each, medians; headless). Startup: **2130 ms -> 2018 ms (-5.3 %)**.

| scenario | frame avg ms | p95 ms | script ms | load ms |
|---|---|---|---|---|
| title | 0.978 -> 0.905 (-7.5 %) | 2.842 -> 2.79 (-1.8 %) | 0.114 -> 0.109 (-4.4 %) | 334.4 -> 327.1 (-2.2 %) |
| hub | 1.362 -> 0.432 (-68.3 %) | 2.035 -> 1.254 (-38.4 %) | 1.21 -> 0.293 (-75.8 %) | 322.3 -> 332.9 (+3.3 %) |
| level1 | 0.422 -> 0.405 (-4.0 %) | 0.667 -> 0.613 (-8.1 %) | 0.258 -> 0.246 (-4.7 %) | 61.9 -> 60.2 (-2.7 %) |
| level10 | 0.445 -> 0.442 (-0.7 %) | 0.706 -> 0.645 (-8.6 %) | 0.28 -> 0.274 (-2.1 %) | 120 -> 116.1 (-3.3 %) |
| random | 0.412 -> 0.404 (-1.9 %) | 0.624 -> 0.62 (-0.6 %) | 0.252 -> 0.249 (-1.2 %) | 213.9 -> 209.9 (-1.9 %) |
| story | 0.931 -> 0.896 (-3.8 %) | 2.851 -> 2.668 (-6.4 %) | 0.106 -> 0.107 (+0.9 %) | 222.5 -> 228 (+2.5 %) |
| skins | 0.387 -> 0.36 (-7.0 %) | 0.572 -> 0.553 (-3.3 %) | 0.246 -> 0.231 (-6.1 %) | 237.6 -> 251.6 (+5.9 %) |

The hub is the big win (frame cost -68 %, script time -76 %). Everything else is equal or a little better. The few
small "+" values (story p99 +7.8 %, skins load +5.9 %, hub load +3.3 %) are well inside this machine's run-to-run noise
(7-80 % on p99 and load times; see AUDIT.md section 2). The final gate's own 7-run bench showed startup 2,113 -> 1,909 ms, so
launch is 5-10 % faster depending on the run.

**Memory peak (+0.2 MB, explained, not a leak).** The headless peak went from 109.15 MB to 109.35 MB. A probe showed why:
the peak grows with the size of the script *source text* the engine parses (adding 130 KB of comment lines to one script
raised it by 3.4 MB). The cleanup added about 8 KB of comments and code, mostly comments explaining each fix. Exported
games ship scripts as compressed binary tokens without comments (`script_export_mode=2` in every preset), so the shipped
game does not pay this cost the same way. The real memory fix in this cleanup is D1-03 (section 2).

**Measurement honesty.** Run-to-run noise on this shared machine is 7-23 % on frame averages, so a 1 % change cannot be
seen here. A speed change was only accepted when it beat that noise, measured with `bench/micro.gd` (one function, many
calls, before and after in the same session) and the scene bench. One candidate (D2-06) gained too little and was
rejected. AUDIT.md section 2 has the full rule.

## 2. Changes by category

Numbers in brackets are the AUDIT.md change-log entries.

### Bugs players could hit (15)

- **Phone softlock (D2-02) [1].** With the pause menu open, turn the phone upright (the "rotate" cover appears), close the
  menu with back, then turn the phone sideways again: the game stayed paused with no menu and no way out. *Check:* that
  sequence now resumes play.
- **Touch controls on the result screen (D2-01) [2].** After a level ended, the first tap on the result screen brought the
  joystick and JUMP back on top of the result panel. *Check:* tap the result screen on a phone; nothing appears. One side
  effect: the touch pause button is not shown on result screens either; their own buttons and back still work.
- **Goo wipe glitch (D2-03) [3].** Leaving a screen within a third of a second of arriving let the old wipe hide the new
  one halfway, so the old screen flashed through.
- **Double tap starts the wrong thing (D2-04) [10].** A quick second tap during the wipe (level select, title, victory,
  boards, demo end, language) changed what the first tap had started, e.g. level 2 instead of level 1.
- **Cancelled touches (D2-05) [11].** When iOS takes a touch back (a system swipe, palm rejection), the game still leaped
  or fired an ability. Now nothing fires.
- **SLIMAKAZE wipes the slime's colours (A-02) [12].** After the first SLIMAKAZE dash, the slime lost its skin colours.
  Copying a material in Godot 4.7.2 blanks the colours of both the copy and the original. *Check:* dash in a random maze;
  the slime keeps its skin.
- **Demo's gold FULL label (D1-01) [4]**, **RESET PROGRESS kept a randomizer penalty (B-02) [5]**, **a rare save-loss
  path on Windows when a rename fails (B-01) [6]**, **a won goal shown locked after a save-code import (B-03) [7]**.
- **Hub tour leftovers (C-02, C-03) [8]:** a "!" showed on the prize wheel during the guided tour, and after a replayed
  tour R stopped turning the room. **Hub return (C-04) [9]:** back from BOARDS via the DAILY sign now faces the sign.
- **Pause bugs (A-03, C-08, A-06) [23, 24]:** pausing during the 0.9 s dry-up hold, the win staging, or a lurker
  near-miss slow-mo let them finish behind the pause menu (and the menu's accept key skipped them). They now wait.
- **DAILY badge clock (C-09) [28]:** "NEW IN 5H" never counted down during a visit, and the next daily's "!" didn't come
  back at midnight UTC until you left the hub. *Visible change:* the badge now updates live.

### Performance (7 accepted, 1 rejected)

- **Hub [14]:** the station-name placer ran every frame, although the names hide for good after 3 seconds. Now it stops
  then: about 1 ms down to 0.03 ms per frame. This is most of the hub's 70 % drop in the table.
- **Wardrobe PAPERS page [15]:** every arrow-key move re-drew all 12 map previews. Now only a changed one: 6.5 ms down to
  0.8 ms per move.
- **Rainbow skin [18]:** about 35-40 % less work per frame on the hub and the skins screen.
- **Launch [19]:** all 17 translation files (2 MB) were loaded at every launch, even in English. Now only the chosen
  language loads, and only when it is picked: about 0.2 s less at startup.
- **Map frames [16]** 37 % faster with identical pixels, and the **story intro [20]** slightly cheaper.
- **Memory (D1-03) [13]:** the goo frames kept a record of every screen ever opened, which grew for the whole session
  (+19 entries per wardrobe visit). Now it only keeps what is on screen.
- Rejected: redrawing the wardrobe trail less often (D2-06) [17]. It saved 12 % of the draws, which was not worth the extra
  check it needed.

### Dead code and hygiene

- Deleted unused functions, constants, a field and two branches that did nothing (-36 lines) [22]. Removed a sound that
  was loaded at every launch but never played [25].
- Exports: the macOS icon is now scaled pixel-sharp for Retina (it was blurred) [21], and the new `bench/` folder stays out
  of every build [21].
- Tooling: `tools/test_all.sh` now cleans up leftover test files on Linux and in CI. The path was wrong, and 21 stale files
  had piled up [26]. CI now uses a read-only token [27].
- New: `bench/bench.gd` and `bench/run.sh` (the scene bench), `bench/micro.gd` (per-function timings), and
  `tests/test_transition.gd`.

## 3. Left alone, and why

**Needs your decision (it would change look or feel):**

| id | What | Why it's yours |
|---|---|---|
| A-01 | Lurker stealth ("stand still") never works with RELAXED or NO DRAIN, because stillness is only counted while idle drain is on | Fixing it makes lurkers easier to avoid in those modes: a feel change |
| D1-04 | Goo-frame lumps: every box of the same size gets the same lumps (the layout key loses the box's id). Confirmed by probe | Fixing it changes how many menus look |
| A-04 | The ghost racer is drawn over the fog, so it shows the best route through unexplored maze | It could be a bug or a deliberate hint |
| C-07 | The rainbow meter's outline never recolours | A look change |
| E-01, E-04, E-13 | macOS bundle id differs from iOS; ad-hoc signing (fine for itch, not for a notarized or App Store release); iOS app on Apple Silicon Macs | Release decisions |

**Left on purpose:**

- **Large refactors:** split `progress.gd` (3,683 lines) and move the fog engine out of `game.gd` (A-21, B-19). These are
  worth doing, but each is a big move with risk and no player-visible gain. Doing them in a cleanup loop would break the
  "smallest change" rule. AUDIT.md has a concrete plan for each.
- **T-03** (48 layout warnings in non-English tests): the obvious fix moves the upgrades title, so it needs a visual check
  in each language.
- **E-10:** playing a misspelled sound name logs an error. That error is useful, so it was kept.
- **D1-08** could not be reproduced: Godot 4.7.2 drops that coroutine silently.
- About 40 more low items: duplication, magic numbers, stale comments, small hot paths in rarely used screens. Each is
  listed in AUDIT.md section 3 with a one-line plan. The last pass found nothing more that was both safe and worth the
  churn.
- **Test-only noise:** the nav fuzz walk now happens to reach PASTE CODE, which logs "Clipboard is not supported" under
  the headless test display. This doesn't happen on a real Mac or phone.

## 4. What needs your Mac

This machine has no GPU, no macOS and no export templates. Please run:

1. `./bench/run.sh --display` on the M3 (opens a window), once on this branch and once on `claude/mobile-sync-polish`.
   This gives real frame times with the GPU.
2. Export the macOS app and time a cold launch to the title; this branch should be about 0.2 s faster (language files).
3. Check the signed bundle size and the new crisp Dock icon.
4. On an iPhone: the rotate softlock sequence from section 2, and a SLIMAKAZE dash in a random maze.

## 5. Next steps

1. Decide on the owner items in section 3 (A-01 and D1-04 first; both are small code changes once decided).
2. Merge this branch into the PR #5 line after review.
3. Then, as separate PRs: the `progress.gd` split and the fog-engine extraction, using the bench in this branch to show
   they don't slow anything down.
