# Spring cleaning, phase 1: docs (docs-keeper)

Branch `spring-cleaning`. Scope: `docs/**` (not `polish-shots/`), `CLAUDE.md`, `README.md`.

## Classification

| Doc | Purpose | Status | Action |
|---|---|---|---|
| CLAUDE.md | rules, commands | living | shortened 73 -> 51 lines |
| README.md | player overview | living | facts fixed |
| docs/README-docs.md | index | living | rewritten (living vs archive) |
| docs/handoff.md | current state | living | rewritten lean (99 lines, was 880) |
| docs/architecture.md | code layout detail | living, NEW | CLAUDE.md layout text moved here verbatim |
| docs/level-design.md | levels, randomizer, Descent, Heat rules | living | kept (history refs repointed) |
| docs/design/upgrades-v2.md | implemented economy spec | living | kept (history refs repointed) |
| docs/story.md | plot, cinematics | living | kept |
| docs/playtime-estimate.md | playtime priors | living (priors) | kept |
| docs/itch-release.md, itch-update-guide.md | release policy, publishing steps (tool docs; no outdated store copy file exists) | living | kept |
| docs/qa-web-report.md | web QA + phone checklist | living | kept |
| docs/qa-release-report.md | save/export QA status table | living reference | kept |
| docs/advisor/maps.md | open map unlock proposal | living (open task) | kept |
| docs/perf/{measurements,cpu,rendering,startup-memory-web}.md | perf audits, useful for the ports | living reference | kept |
| docs/game-design.md | original 6-phase brief | superseded | archived |
| docs/hats-audit.md | hat scale audit | historical | archived |
| docs/polish-research.md | early polish diagnosis (implemented) | historical | archived |
| docs/qa-nav-report.md | nav fuzzer findings (fixed) | historical | archived |
| docs/review-abilities.md, review-maps.md, review-upgrades-b1..b4.md | code reviews, all fixed | historical | archived |
| docs/advisor/{comparables-presentation,flow-level-design,graphics-shading,juice-audio-ui,roguelike-progression}.md | advisor research 2026-10-12 | historical | archived to archive/advisor/ |
| docs/perf/results-batch-a.md, results-batch-b.md | applied optimizations | historical | archived to archive/perf/ |
| old handoff history | per-feature log | historical | docs/archive/handoff-history.md |

## Moved / merged / removed

- All moves used `git mv` (history kept), each archived file got a one-line `>` header saying what superseded it.
- Merged: handoff's duplicate "Current state"/"Original handoff" content collapsed into the new lean handoff (full text kept in archive/handoff-history.md); CLAUDE.md's long layout section moved to architecture.md.
- Removed: nothing deleted. No outdated marketing-copy file exists in docs/ (only the itch tagline/description steps inside itch-update-guide.md, which is a tool doc and still current: tagline ESCAPE THE FOG / OR DRY TRYING).

## CLAUDE.md: 73 -> 51 lines (41 KB -> 10 KB)

Changed (facts and structure only): the 25-line Pixel-art/Layout dump moved to docs/architecture.md and replaced by a short map; intro now says Godot 4.7.2, lists the current modes, save version 6; removed "all 6 build phases" blow-by-blow; autoloads verified (`Progress`, `Sfx`, `RotateHint`, `Transition`); input-actions line kept but shortened (abilities only in randomizer + Descent); agent list updated (12 agents, previously 6) without model names; the test-suite description (70 suites, verified) shortened; performance paragraph shortened with a pointer. Kept verbatim: both command sections, Workflow rules (launch via play.ps1, screenshots with level skins, no promo/zip rebuilds, UTF-8 no BOM, commit working states, editor rewriting project.godot), save safety paragraph, Obsidian decisions log.

Verified against code: 320x180 / 1280x720 / viewport+integer stretch, main scene, `custom_user_dir_name=SlimeTime_R1`, `RELEASE_EPOCH = 1`, `SAVE_VERSION = 6`, 165 coins (sum of `Levels.COINS`), 70 test files, presets (Windows, Web, macOS), `Hats.available = true`, `WORKSHOP_ENABLED = false`, `ABILITIES_ENABLED = true`, `Abilities.allowed_in`.

## Rules left alone that may be outdated (for the owner)

- Workflow: "Launching for the user: always use `.\tools\play.ps1`" is Windows-only; the Mac section says the right-monitor trick does not exist there. Probably worth a "Windows only" tag.
- Workflow: release zips "live on the user's Desktop (`SlimeTime-vX.Y`)" and the Windows zip/promo images are stuck at v2.2; unclear if still how releases are made (Steam/mobile builds will need their own notes).
- "Commit working states with git" and the handoff preference "Commits end with Co-Authored-By: Claude Opus 5.5" (still in the archived/handoff preferences) differ from the current attribution reminder (a different model name); left as is.
- Decisions-log rule points at an Obsidian vault path (Mac only); fine, just confirm it still exists.
- Handoff preference "Words: glide / leap stay" and "Sound: low, dark" kept verbatim in handoff.md.

## Links fixed

- Every `](...md)` link and every plain `docs/...md` path in docs/, CLAUDE.md, README.md was rewritten for the moves by script and then checked: no broken relative links remain and no `docs/*.md` path in text is missing.
- Docs that cited handoff per-batch history (design/upgrades-v2.md, level-design.md) now point to archive/handoff-history.md.
- Not edited (not my area), for code-janitor / agents owners:
  - `scripts/game.gd:47` comment: `docs/advisor/graphics-shading.md` -> `docs/archive/advisor/graphics-shading.md`
  - `tests/test_nav_fuzz.gd:13` and `:28`: `docs/qa-nav-report.md` -> `docs/archive/qa-nav-report.md`
  - `tests/demo_descent.gd:15`: "docs/handoff.md, Descent" -> `docs/archive/handoff-history.md`
  - `.claude/agents/game-advisor.md` mentions `docs/game-design.md` (now `docs/archive/game-design.md`); `.claude/agents/code-janitor.md` mentions `results-batch` (now `docs/archive/perf/`).

## Images referenced by living docs (please keep in docs/polish-shots/)

`abilities2_before.png`, `abilities_*.png`, `finale2_*.png`, `hard_before_l1*`, `size_u100_ms0*`, `spawn_level01..10.png`, `story3_*.png`, `ticketgoal_goal.png` (from level-design.md, design/upgrades-v2.md, story.md). The docs only name them in backticks (no embedded markdown images), so a missing file breaks nothing technically. Archived docs (handoff-history, hats-audit, ...) name many more shots; those are historical and may lose their pictures.

## Phase 1 follow-up (docs-keeper, 2026-10-15)
Stale facts fixed after code-janitor and asset-auditor removals (verified against the code):
- `docs/level-design.md`: header and section 4 note the pre-v5 migrations, `legacy_par`, `v4_hard_par`, `_migrate_coins` and `_migrate_hard_times` are removed (kept as history); `_migrate_medals` is now `_tier_from_record`.
- `docs/itch-release.md`: migrations are gone from the code; only `_migrate_tree` / `_migrate_prices` remain.
- `docs/architecture.md`: save-format line (in-epoch migrations only); `walls.png` / `fillets.png` dropped from the sprites list.
- `docs/advisor/maps.md`, `docs/perf/cpu.md`, `docs/perf/startup-memory-web.md`: notes that the referenced migration / unused assets are removed.
- Left as dated reports: `docs/qa-release-report.md` (exclude_filter line), `docs/design/upgrades-v2.md` (refers to the kept `_migrate_tree` / `_migrate_prices`).
