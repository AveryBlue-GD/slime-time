# Spring cleaning phase 1: code (code-janitor, 2026-10-15)

Branch `spring-cleaning`, compared against tag `spring-cleaning-baseline` (dfbfccb). Area: `scripts/**`,
`scenes/**`, `tests/**` (kept in step with removals), `project.godot`, `tools/*.gd` (none exist).
Net change in that area: 18 files, +188 / -374 lines. Game code alone (`scripts/`): +116 / -228 lines.

The codebase was already lean. A reference scan found no unused scripts, scenes, signals,
input actions or autoloads. It found no commented-out code blocks and no TODO/FIXME/HACK
markers. It found no stray debug prints: the three `print` calls left are the release-flag notice
in `Progress._ready` and the autoplay log/summary, both deliberate.

## Commits

| Commit | What | Lines |
|---|---|---|
| 55e212a | Code comments point at the moved docs (`docs/archive/advisor/graphics-shading.md`, `docs/archive/qa-nav-report.md`, Descent -> `docs/level-design.md` section 9) | +4 / -4 |
| 234a0c8 | Pre-v5 save migrations and legacy par tables removed (with their tests) | +88 / -244 |
| e936d08 | Unused constants and `Progress.record_for` removed | -14 |
| 8c3e0de | `UIKit.add_ticket_confirm`: one BUY? confirm for the hat wheel SHOP and the upgrades TICKETS tab | +52 / -62 |
| 6f9ffed | Small duplicates merged (fog colour packing, slime sheet loader, spawn shuffle, 8x8 icon painting) | +44 / -50 |

## Removed, by category

### Save migrations that can no longer run (234a0c8; scripts -90 / +19)
Under the fresh-start policy (`docs/itch-release.md`), every release-epoch save is version 5 or later.
Saves and codes without the epoch are never loaded.
- `Progress._migrate_coins` (version < 4: re-mapped old-layout coin keys by count), plus `LAYOUT_VERSION`.
- `Progress._migrate_hard_times` (version < 5: dropped hard best times), plus `HARD_LAYOUT_VERSION`.
- The version < 3 medal bitmask conversion in `_read_wallet`, and the per-version par choice in
  `_migrate_medals`. This is now `_tier_from_record(key)`, which always uses the current par.
  The in-epoch case it still covers is a save with best times but no `[medals]` section.
- `Levels.legacy_par`, `Levels.v4_hard_par`, `LEGACY_STEPS`, `LEGACY_HARD_STEPS`.
- Tests: `test_layout_migration.gd` lost its v2/v3 migration sections. It keeps the v5 coin keys,
  the SLIME1- refusal, hostile values and deep dead ends. `test_hard_rebalance.gd`'s migration
  section now checks that a v5 save keeps its hard times and tiers, and that a save with no
  `[medals]` gets tiers from its times. In `test_tickets.gd`, the v2 "veteran" save became a v5
  save with the old `[wallet]` keys; its records are on 1/8 s steps so they survive a save code's
  text exactly (a save code prints floats with fewer digits).
- Behavior for real saves is unchanged. For a hand-made save that claims the epoch with version
  < 5, junk coin keys are no longer re-mapped; they are kept and capped by count, like any v5/v6
  save. Hostile-save tests still pass.

**Kept on purpose (in-epoch, real players can hit them):** `_migrate_tree` (tree 1 -> 2) and
`_migrate_prices` (tree 2 -> 3), and `Economy.TREE2_COSTS` / `OLD_TREE_LEVELS`, `Upgrades.migrate_level` /
`old_total_cost` / `tree2_total_cost` / `level_for_coins`. The tag `v2-release-candidate` (066fc01) already
has the epoch but no tree mark (tree 1). `v2-upgrades-b2` and `v2-upgrades-v2` have the epoch and tree 2. So
epoch-1 saves with tree 1 or tree 2 exist, at least the owner's. Also kept: the ability spare-key
fallback in `_read_bindings` (abilities came after the epoch), the `tutorial_seen` / `story_seen`
defaults (story flags: owner instruction), `Levels.SEED_CODE_LEGACY_MAX` (typed seed codes, not
saves), the SLIME1- "FROM AN OLD VERSION" refusal, and `Survey` version checks (validation).

### Unused declarations (e936d08, -14)
Unreferenced in scripts, scenes, tests, tools, project.godot, export presets and shaders:
`HUD.ABILITY_PIP`, `ABILITY_PIP_OFF`, `MEDAL_GOLD`; `Skins.SOURCE_LIGHT/MID/DARK`; `MazeTiles.BORDER_VARIANTS`;
`UIKit.BUTTON_HOVER`, `BUTTON_DISABLED`; `Progress.record_for`.

## Duplicates consolidated
- **Ticket BUY? confirm** (8c3e0de). `hat_wheel.gd` and `upgrades_screen.gd` built the same
  blocker, panel, label, price row, BUY and BACK line for line. Only the price tint differed. They
  now share `UIKit.add_ticket_confirm(parent, on_buy, on_back, price_tint)`, which creates the
  same nodes in the same order.
- **Fog packing**: `Game._fog_color` now calls `_fog_color_ticks`, with the same clamps.
- **Slime sheet pixels**: `Slime._load_sheet_image()` replaces two copies of the lazy load.
- **Spawn shuffle**: `SpawnPicker._shuffle()` replaces two copies of the seeded Fisher-Yates
  shuffle. It makes the same RNG draws, and the golden maze digests are unchanged.
- **8x8 icons**: `BoonIcons.paint(rows)` and `BoonIcons.icon_rect(tex, scale)` now serve both
  the Descent boons and `Abilities.icon` / `make_icon`.
- Looked at and left alone:
  - `cost` / `total_cost` / `ids` in `Upgrades`, `Abilities` and `Workshop`: 4-6 line functions
    over different tables; merging them would only add coupling.
  - `clampi(_int(...))` in `Progress._read`, 21 times: a helper was tried and reverted (no
    clearer, no shorter).
  - `MazeGenerator.generate` vs `_grow_level`: they differ in RNG draw order, so merging would
    change the menu backdrop maze.
  - The pause/restart overlay setup: too small to be worth it.
  - `UIKit.lock_focus` is already the single focus-lock implementation.

## Needs an owner decision (left intact)
- **Ticket WORKSHOP** (`Economy.WORKSHOP_ENABLED := false`: SECOND WIND, QUICK CHARGE, STICKY,
  MAGNET, GOO NOSE) is untouched behind its flag. This covers `scripts/workshop.gd`, its
  upgrades-screen tab, its `Progress` reads, writes and buys, the `--workshop=` flag, and the
  tests and demos (`demo_store.tscn --shot=confirm/wind/nose` only work with it on).
- **`Game._finish(did_win, text, delay)` ignores `delay`.** The win flow computes
  `delay = WIN_FINAL_DELAY` (5 s) for the level-10 win, but `_finish` always waits
  `CHOICE_DELAY` (0.6 s). This looks like an old intent that never took effect, or a bug. It is
  left as it is because removing or fixing it changes behavior. `test_nav_fuzz.gd` uses
  `WIN_FINAL_DELAY` as a wait.
- The migration paths above (`_migrate_tree` / `_migrate_prices`) can go only after a future epoch bump.

## Archived
Nothing. Every removal was provably dead for real players, so `_archive/` was not created.

## Not touched (owner instruction: keep all cutscenes)
Nothing story-related was changed: `story.gd`, `story_screen.gd`, `story.tscn`, the title's
first-launch trailer and STORY button, the story sounds, `test_story.gd`, `demo_story.*` and
`story_seen`. The intro frames 60/300/600/900 are in the pixel set: 0 px changed.

## Stale doc references (for docs-keeper)
- `docs/level-design.md` lines 5, 97, 102-103, 301, 304, 354, 358-359: `_migrate_coins`,
  `_migrate_medals`, `_migrate_hard_times`, `legacy_par`, `v4_hard_par`, `LEGACY_STEPS` /
  `LEGACY_HARD_STEPS` no longer exist. Medals from times now use `Progress._tier_from_record`
  against the current par.
- `docs/itch-release.md` line 40: "the pre-v5 save migrations (`_migrate_*`) are still in the
  code". They were removed. The ones left (`_migrate_tree`, `_migrate_prices`) are in-epoch.
- `docs/architecture.md` line 30 (`_migrate_*`) and line 40 ("layout migration" in the suites
  list). `test_layout_migration.gd` now covers v5 coin keys, SLIME1- refusal, hostile values and
  deep coins.
- `docs/advisor/maps.md:448` and `docs/perf/cpu.md:201` mention `_migrate_coins` /
  `_migrate_medals` (historic notes; fine if archived).
- New API worth a line in architecture.md: `UIKit.add_ticket_confirm`, `BoonIcons.paint` /
  `icon_rect`.

## Evidence

**Tests.**
- Every commit group: all 70 suites passed with a parallel runner (6 at a time, the same command
  line as `tools/test_all.sh`, fake `HOME`) every time.
  - The golden maze test (`test_maze_golden`) is in that set.
  - So are the save round-trip and robustness suites: `test_save_code`, `test_save_robust`,
    `test_save_isolation`, `test_fresh_start`, `test_extremes`, `test_tickets`,
    `test_layout_migration`, `test_hard_rebalance`.
- Final sequential `./tools/test_all.sh`: see the summary line at the end of this file.

**Pixel diff.** Harness in `/private/tmp/claude-501/sc_pix/` (outside the repo).
- Method:
  - A baseline worktree of `spring-cleaning-baseline` and a worktree of HEAD plus the change
    under test.
  - Both run with `--fixed-fps 60` and a seeded global RNG.
  - The menu backdrop's and the flowing hat's wall-clock drift are pinned to the frame count.
    The GooBox layout seed is pinned to `hash([w, h])` (its canvas-item RID varies run to run).
  - The 320x180 root viewport is saved at fixed frames.
- 41 frames:
  - title (2) and rainbow title (2); hub (3) and rainbow hub
  - skins screen with rainbow (3), Stopwatch and Chameleon
  - settings, CONTROLS, level select (normal, hard), upgrades (2), MAP TABLE
  - level 1 (2), level 5, level 10 rainbow
  - randomizer, randomizer with abilities, hard level 3, Descent (2)
  - `--autoplay` (frames 40/200/400/800), story intro (60/300/600/900)
  - pause menu, victory
  - the upgrades abilities BUY? confirm and the hat wheel SHOP BUY? confirm
- Results:
  - Baseline vs baseline: 0 px (after pinning).
  - After each group: **0 differing pixels in all frames** (38 frames for group 1; 40-41 frames
    after the confirm and abilities shots were added).
- Worktrees were removed afterwards.

**Import and boot warnings.**
- `--headless --import` on an already-imported tree: 0 ERROR/WARNING lines before and after. A
  fresh worktree's first import shows four `pixel.fnt` "cannot open imported fontdata" errors
  before the font is imported, the same at baseline.
- Headless boot (`--quit-after 120`, fake HOME):
  - title: clean before and after.
  - hub: clean before and after.
  - main: `1 resources still in use at exit` and `2 ObjectDB instances were leaked at exit` at
    baseline, and exactly the same after. No new lines.

**Final sequential `./tools/test_all.sh`** (HEAD 6f9ffed, fake HOME): `suites: 70 failed: 0`, 5 min 46 s.
