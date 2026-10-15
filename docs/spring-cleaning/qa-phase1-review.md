# QA review: spring cleaning phase 1 (code-reviewer, 2026-10-15)

Diff: `spring-cleaning-baseline..HEAD` on `spring-cleaning` (reviewed at 24a1d49, then re-checked at
5d44274, which adds docs-keeper's docs-only commit). Read-only review. I checked every claim myself
and did not rely on the phase 1 reports.

## Verdict
**No blocking issues.** The game-code changes do not change behavior for any real save.
There are 3 minor findings (2 stale references after the moves, and 1 old dead parameter).

## Findings (most severe first)

1. `.claude/agents/code-janitor.md:10`, `.claude/agents/game-advisor.md:7`
   - **Problem:** Both agent prompts still point at docs that were moved to the archive:
     - `docs/perf/results-batch-a.md` is now `docs/archive/perf/results-batch-a.md`.
     - `docs/game-design.md` is now `docs/archive/game-design.md`.
   - **Failure scenario:** Phase 2 code-janitor is told to look up its pixel-diff harness in a file that no longer exists. Each game-advisor run is pointed at a missing design spec. Both waste effort or skip a step.
   - **Fix:** Update both paths to the `docs/archive/...` ones. My link check found no other broken living links: markdown links plus `docs/...` mentions across scripts, tests, tools and agents.

2. `tests/test_trails.gd:8`
   - **Problem:** The comment points at `docs/polish-shots/batch2_trail_*.png`. asset-auditor deleted all 5 of those files.
   - **Failure scenario:** Anyone checking the trail look against the reference shots finds nothing.
   - **Fix:** Point the comment at `git show spring-cleaning-baseline:docs/polish-shots/batch2_trail_<n>.png`, or remove the reference.

3. `scripts/game.gd:2026` (and `:31`, `:1973-1976`)
   - **Problem:** `Game._finish(did_win, text, delay)` ignores `delay`, as reported. This is **not a regression from this diff**; the parameter has been dead for a while:
     - Up to `456d63e` (2026-10-10), `delay` was the auto-advance wait: 2 s, or `WIN_FINAL_DELAY` = 5 s on the level-10 win before the victory screen.
     - `456d63e` replaced the auto-advance after a win with REPLAY/NEXT buttons after `CHOICE_DELAY` (0.6 s).
     - `1903fb5` (2026-10-11) did the same for dry-ups (now `DRY_CHOICE_DELAY`, or `DESCENT_SUMMARY_DELAY`).
     - Since then, `END_DELAY` and `WIN_FINAL_DELAY` are only passed around and used as generous waits in tests: `test_nav_fuzz.gd:1072` and about 10 suites that wait `END_DELAY * 60` frames.
   - **Intended behavior today:** Buttons come up after `CHOICE_DELAY`. On level 10 the CONTINUE button plays the story finale. The 5 s linger was the old auto-advance and has no role with buttons.
   - **Failure scenario:** None at runtime. However:
     - Readers assume the final win lingers for 5 s.
     - `docs/playtime-estimate.md:87` counts a 2.0 s `END_DELAY` in the retry overhead, which does not happen. Real retry overhead is `DRY_CHOICE_DELAY` 0.25 s plus the wipe.
   - **Fix:** In phase 2:
     - Remove the `delay` parameter and `WIN_FINAL_DELAY`.
     - Keep `END_DELAY` only if tests still use it as a wait, or switch those tests to `CHOICE_DELAY`.
     - Correct `playtime-estimate.md:87`.
   - **Owner decision:** If the owner *wants* the "YOU ESCAPED ALL 10 MAZES!" message to stay up longer before the buttons, use `delay` in the win-branch await instead. That is a behavior change for the owner to decide, not a cleanup.

## Verified clean (no finding)

**(1) Removals are unreferenced.**
- I ran `git grep` over the whole repo (scripts, scenes, `.tres`/`.tscn`, `project.godot`, `export_presets.cfg`, tools, tests and shaders) for every removed name:
  - `_migrate_coins`, `_migrate_hard_times`, `_migrate_medals`, `legacy_par`, `v4_hard_par`
  - `LEGACY_*STEPS`, `LAYOUT_VERSION`, `HARD_LAYOUT_VERSION`, `record_for`
  - `ABILITY_PIP*`, `MEDAL_GOLD`, `SOURCE_LIGHT/MID/DARK`, `BORDER_VARIANTS`, `BUTTON_HOVER/DISABLED`
  - the removed PNGs and their `uid://` values
- Only docs and historical notes mention them.
- String-built paths cannot reach the deleted files:
  - `Themes.atlas_path`: `themes/%s_%s.png`
  - `hub.gd`: `ART + name`, with `ART` = `assets/sprites/hub/`
  - `UIKit`: `UI_DIR + "icon_%s.png"`
- The generators still import the kept wall/fillet functions from `make_placeholder_art.py`.

**(2) Migrations cannot be reached by a real save.**
- `RELEASE_EPOCH` was introduced in `d8f0468` (2026-10-14, "Fresh start for the public release"), with `SAVE_VERSION := 5` already in place.
- Every later commit has epoch 1 and `SAVE_VERSION` 5 (`v2-release-candidate`) or 6 (`v2-upgrades-b2`, `v2-upgrades-v2`, baseline).
- `_write` always writes `[meta] version` and `epoch`, for both the save file and SLIME2- codes.
- `load_progress`, `read_code` and `load_code` reject anything without the epoch.
- So no public or owner build ever wrote an in-epoch save with version < 5:
  - `_migrate_coins` (< 4), `_migrate_hard_times` (< 5) and the < 3 medal-bitmask path were unreachable.
  - For version >= 5, the old `_migrate_medals` par choice already gave `Levels.level_par`, so `_tier_from_record` is identical.
  - The "no `[medals]` section" path is kept.
- `_migrate_tree` and `_migrate_prices` are correctly kept.
- **No regression.**

**(3) The consolidations are identical to the old code.** I compared each line by line:
- `add_ticket_confirm`: same nodes, order, rects and callbacks. Price tint is `TICKET_TINT` for the hat wheel and `UIKit.TEXT` for upgrades, as before.
- `_fog_color` → `_fog_color_ticks`: same clamps and bytes.
- `_load_sheet_image`: same lazy load and decompress.
- `SpawnPicker._shuffle`: same draws. `cells_of` returns `Array[Vector2i]`, so the typed parameter is safe.
- `BoonIcons.paint` / `icon_rect`: same palette, size, flags, mouse filter and size flags as the Abilities copies.

**(4) Story and cutscenes are untouched.** No changes to `story*.gd`, `story.tscn`, `demo_story*`, `test_story`, story sounds or `story_seen`. The `docs/story.md` key frames (`story3_*`, `finale2_*`) are kept. The deleted `story_intro_*`, `story2_*` and similar shots are old doc screenshots, not game content.

**(5) Marketing and capture tools are intact.**
- The only `tools/` changes are the two art generators, which only drop outputs of removed assets.
- Unchanged: `tools/promo/*`, the screenshot/movie/play scripts, `scripts/autoplay/`, every `tests/demo_*` (`demo_descent.gd` changed only a doc path in a comment), and the dev toggles and `--story-complete` in `game.gd`/`progress.gd`.

**(6) `export_presets.cfg` is correct.**
- All three presets have the same exclude set plus `_archive/*`.
- Web also excludes `icon.ico`. That file is used only by `config/windows_native_icon`, at Windows export, and the Windows preset still ships it.
- `panel.png`, which used to ship, is gone.

**(7) Docs links are fine except finding 1.** No broken relative links in living docs, `CLAUDE.md` or `README.md`. The shortened `CLAUDE.md` keeps all rules: pixel art, save safety, launch, skins in screenshots, promo, shaders and agents.

**Tests not re-run by me** (the QA tester owns that). The test edits match the code changes. The removed checks covered only the removed pre-v5 paths.
