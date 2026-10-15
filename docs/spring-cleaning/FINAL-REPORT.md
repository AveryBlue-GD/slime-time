# Spring cleaning: final report

Branch `spring-cleaning` (from `v2` at `dfbfccb`, tag `spring-cleaning-baseline`). Phases were done by separate agents
(code-janitor, asset-auditor, docs-keeper, test-curator, ui-polisher, perf-profiler, platform-porter) and each phase was
signed off by an independent QA/review agent (`qa-phase*.md`, `qa-final.md`); nobody verified their own work.
Owner decisions are in [decisions.md](decisions.md) (D1-D10). Detail for every item is in the phase reports linked below.

## 1. Removed

**Code** ([phase1-code.md](phase1-code.md))
- Pre-release save migrations that no real save can reach under the fresh-start epoch policy: `_migrate_coins`,
  `_migrate_hard_times`, the version<3 medal conversion, `Levels.legacy_par`, `v4_hard_par`, legacy step tables
  (scripts -90/+19 lines; their tests reworked). In-epoch coin-tree migrations (`_migrate_tree`, `_migrate_prices`) kept.
- Unused: 8 constants (hud, skins, maze_tiles, ui_kit) and `Progress.record_for`; the dead `delay` parameter of
  `Game._finish` with `END_DELAY` / `WIN_FINAL_DELAY` (behaviour unchanged since the buttons replaced auto-advance).
- Duplicates merged: one ticket BUY? confirm (`UIKit.add_ticket_confirm`), one 8x8 icon painter (boons + abilities),
  fog colour packing, slime sheet loader, spawn shuffle; ~500 duplicated test lines into `tests/suite_base.gd`.
- Scan found no unused scripts/scenes/signals/input actions/autoloads, no TODO/FIXME, no commented-out code, no stray
  debug prints.

**Assets and old material** ([phase1-assets.md](phase1-assets.md))
- `assets/sprites/walls.png`, `fillets.png`, `assets/ui/button_{normal,hover,pressed,disabled}.png`, `panel.png`
  (+ .import; generators no longer write them).
- 256 superseded development screenshots from `docs/polish-shots/` (15.8 MB; 80 kept). Recoverable from git history
  (added between 6c94f32 and b4bf685).
- No outdated store art or promo images were committed (`/itch-images/` is git-ignored and absent).
- No dependencies/plugins exist beyond Godot itself.

**Docs** ([phase1-docs.md](phase1-docs.md)): superseded reports moved to `docs/archive/` (not deleted): old reviews,
perf batch results, five advisor reports, hats audit, polish research, the original game design and the 880-line
handoff history. `CLAUDE.md` 73 -> 51 lines (41 KB -> 10 KB), detail moved to `docs/architecture.md`.

## 2. Moved to `_archive/`
Nothing. Every removal was proven unreferenced, so no `_archive/` folder was needed. Items that need a human decision
were kept in place instead:
- The disabled ticket **workshop** (`Economy.WORKSHOP_ENABLED = false`): switched off "for now" by the owner (D2).
- The git-ignored local videos (`docs/polish-shots/*.mp4`, `docs/spring-cleaning/perf/*.mp4`, ~105 MB) and whether to
  purge old screenshots from git history (D7, pending).

## 3. Optimizations (before -> after, Apple M3)
| Measure | Before | After |
|---|---|---|
| Gameplay draw calls | 102-121 | 28-38 |
| Level frame time (L10 / Descent floor 10) | 1.46 / 1.92 ms | 1.20 / 1.56 ms |
| Rainbow skin hub frame | 2.32 ms | 0.94 ms |
| First visit: hub / first level / story | 97-105 / 182 / 86-95 ms | 29-32 / 37 / 9-10 ms |
| First goo-wipe frame (shader stall) | 7.7 ms | 0.9 ms |
| Same-maze retry tile fill (L1 / L10 / 36x20) | 2.7 / 11.6 / 20.8 ms | 0.09 / 0.31 / 0.66 ms |
| Descent goo-drop placement per floor | 7-8.6 ms | 1.3-1.5 ms |
| 144 / 240 Hz: frames on the ideal pixel | 40 / 33 % | 96 / 95 % |
| 144 / 240 Hz: 1 px twitches per second | 24.8 / 17.4 | 0 / 0 |
| Web `index.pck` | 5,293,612 B | 5,232,424 B |
| Full test run | 5:58 (70 suites, serial) | ~1:51-2:08 (76 suites, parallel) |

Trade-off: the title's own load is 155 -> 560 ms because it preloads hub, level and story on the boot screen.
High-refresh smoothing uses physics interpolation that switches on only above ~72 fps, so 60 Hz is byte-identical with
no added input lag (D5). Side-by-side captures: `docs/spring-cleaning/perf/` (local mp4s + a committed frame strip).
No leaks: 65-240 simulated-minute soaks with flat nodes/orphans/resources and no script errors. Details:
[phase4-perf.md](phase4-perf.md), [phase4-perf-audit.md](phase4-perf-audit.md), [qa-final.md](qa-final.md).

## 4. UI polish ([phase3-ui-audit.md](phase3-ui-audit.md), [phase3-ui.md](phase3-ui.md))
- Every screen, menu, HUD element, popup and dialog audited from rendered pixels: 63 issues (7 high, 24 medium,
  32 low). Fixed: all 7 high, all 24 medium, 17 low; 5 low documented as rule exceptions; QA re-measured them.
- Highlights: HUD timer pod pads 4/15 -> 4/4; level-select grid 30/38 -> 34/34 px; quit-confirm note centred;
  10-digit SEED button no longer overflows; restart prompt padding 23 -> 8 px; story line never overlaps HUD pods;
  Descent card/summary no longer over the HUD; one-line pods all 14 px; buttons 13 px; BACK at (4,164) 40x13
  everywhere; selected vs hover states distinct; level-tile numbers clear the record time.
- Touch: `TouchButton` enlarges hit areas to ~46 pt only while touch is the active input, never overlapping.
- Rules: [docs/ui-rules.md](../ui-rules.md), implemented as named constants/helpers in `scripts/ui/ui_kit.gd`.
- Aspect ratios 16:9, 16:10, 21:9, 4:3, phones and tablets: whole-number scaling, nothing clipped.
- Before/after screenshots: `docs/spring-cleaning/ui-before/` and `ui-after/`.
- Needs a design decision: dense button stacks (pause, restart, key rows, shop) reach only 32-40 pt touch targets
  without a looser touch layout; the 16 px "4"/"6" glyphs look slightly unbalanced (measured centred - art call).

## 5. Bugs and crashes found and fixed
- Area name/story line lost after pausing in the first 3 s; rainbow skin turned gold coin counts pale;
  one slow frame on a 75-240 Hz screen toggled smoothing and snapped the camera 9-15 px; hat flicker above 60 Hz;
  `shortest_path` hung on an unreachable cell; first-launch preload ran during the wipe; hat-wheel taps could spend
  tickets on touch; Android back quit the app; menus ignored gamepads; a level kept running when backgrounded during
  a wipe; Descent resume could be retried without limit (now one resume per floor, D9); fullscreen not remembered;
  quit-time script errors from PlatformEvents; the promo "NEW RECORD" shot missed the banner; flaky tests (shared
  throwaway save, load-sensitive timing, midnight rollover) and a test runner with no timeout.
- Tooling incident: the final QA run invoked `tools/job_timeout.pl` with a missing argument and overwrote the Godot
  editor binary; restored from the official 4.7.2 download (verified identical) and the helper now refuses bad paths.

## 6. Remaining known issues (most severe first)
1. **Medium (design):** dense touch button stacks below 44 pt (see 4).
2. **Low:** Windows only, unverified: quitting while minimized may relaunch windowed (`progress.gd:505`).
3. **Low:** engine exit-time leak warning pair in `main.tscn` (level ambience still playing at quit; harmless).
4. **Low:** the real `kill -9` Descent relaunch with the one-resume cap was not re-run end to end after the final
   follow-up (unit/integration tests and code review cover it).
5. **Manual checks for the owner:** Mac fullscreen (green button / F11, quit, relaunch); judge the high-refresh clips.

## 7. Mobile and Steam readiness ([phase5-platform-audit.md](phase5-platform-audit.md), [phase5-platform.md](phase5-platform.md))
- Fixed: Android back (no quit; back/pause), full gamepad layout + menu navigation (D4), auto-pause and input release on
  focus loss/background, QUIT hidden and FULLSCREEN disabled on phones, device-appropriate hints, safe areas (home
  indicator, rounded corners), both iOS landscape sides, mobile renderer pinned to `gl_compatibility`, Linux preset,
  Descent run saved and resumed across app kills (D6, D9), mobile hub home icon back to the title (D10), a
  `Platform` seam + `PlatformEvents.progress_event` for future Steam achievements.
- Port-time setup still needed: Java + Android SDK + keystore, full Xcode + Apple team, Android/iOS presets (settings
  written in phase5-platform.md), app icons at store sizes, GodotSteam in a Steam-only preset, Steam Auto-Cloud on
  `save.cfg`, Steam Deck on-screen keyboard for the save-code box, pad button glyphs and remapping, rainbow-skin
  performance on real phones, real-device touch/safe-area checks.

## 8. Marketing and capture tools
All intact and verified on the final code: `tools/screenshot.sh`, `tools/play.sh` (`--dev`, `--story`, `--autoplay`),
`--write-movie` captures, the story demo, demo scenes in `tests/` (documented in `tests/README.md`), and
`tools/promo/make_promo.sh` (new Mac twin of the Windows script) rendered all 9 promo images to a temp folder, with
the NEW RECORD shot fixed. All cutscenes are intact and pixel-identical to the baseline (D1).
