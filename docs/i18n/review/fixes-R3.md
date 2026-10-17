# Fix pass R3: hub notice, upgrades COINS hint, wardrobe try-on stage (Arabic)

Scope: `scripts/hub.gd` (the one-time notice), `scripts/ui/upgrades_screen.gd` (COINS hint),
`scripts/ui/skin_showcase.gd` (try-on stage); new test `tests/test_i18n_r3_layout.gd`;
`tests/test_i18n_f3a_layout.gd`'s notice check now measures the stations' ink (as the code does).
`skins_screen.gd`, `hat_wheel.gd`: no change needed.
Measured with `./tools/i18n_capture.sh` (19 locales, every state): before = HEAD 68d775d's versions of these three
scripts, after = this pass, both on the same working tree (the other R3 agents' files as they were), compared
pixel by pixel. Shots: `docs/i18n/shots/fixes-R3/<state>_before.png` / `_after.png` (the locales that change, 2x).

## English
Pixel-identical in every state (hub-notice, upgrades-coins / -abilities, wardrobe-*: byte-identical captures).
The only other states that differ between the two runs are the rainbow / trail tiles' animation phase (ko
wardrobe-skins x 216-230) and states owned by the other agents (story / pause / HUD / result).

## Per-row results

| Locale(s) | State | Row | Result | Measured before -> after |
|---|---|---|---|---|
| ar (A5, low) | wardrobe-skins | try-on slime not mirrored (leftovers accepted it as "game art", contradicting ui-rules 10.2) | fixed | the routine mirrors: x' = 220 - x about the stage, each `_e` / `_w` step plays the sheet's `_w` / `_e` animation (the art is never flipped: no `flip_h`, scale > 0). Slime ink x 56-87 -> 232-263 on the stage x 50-269 (6 columns from the left end -> 6 from the right). It now starts at the right end and splats into the right edge. The slime is `keep_ltr` so UIKit's one-off Node2D mirror does not fight the per-frame placement (no 1-frame jump on a relayout). leftovers.md's A5 "not an error" line removed; ui-rules 10.2 says how. |
| es, pt_BR, fr, it, de (low); also ru, tr, id | hub-notice | notice on 3 lines since F3a (2 x min(left, right) room ~124 px measured on the stations' sprite frames) | fixed | 2 lines everywhere. The room is now measured on the stations' resting-frame ink (cabinet ink to x 87, chair from 230; the frames' transparent margins counted before), then the side padding narrows 8 -> 5 and the box may sit off the centre, then the same 2 (not 3) columns from the props. Box (outline x) / lines: es 102-217, 3 -> 90-227, 2 (pad 5, centre 159, 2 clear columns to the cabinet and to the chair); pt_BR 101-218, 3 -> 91-226, 2 (pad 5); fr / it 98-221 / 106-213, 3 -> 95-224, 2 (pad 8, centred); de 100-219, 3 -> 91-226, 2 (pad 7); ru 100-219, 3 -> 93-226, 2 (pad 8); tr 102-217, 3 -> 90-227, 2 (pad 5); id 105-214, 3 -> 91-226, 2. Text ink 1+ clear column off the side lumps (pad 4 had es's last `8` on the right lump: rejected). The wardrobe's door swing (frames 3-4 reach x 93) waits until the notice has faded when it would come within 2 columns of it (es / pt_BR / de / tr / id / ru / fr / it; never in English, 4 columns clear). Top 24, bottom 57: 11 rows over the wheel. en / pl / CJK / th / vi / hi / ar / pseudo unchanged. |
| hi (low) | upgrades-coins | hint 1 clear row under the bottom row's drips (was 2); with fix pass R2's 22 px hi buttons it had become 0 (drips row 118, hint ink from 118) | fixed | the hint (taller script) moves down until its first ink is GAP_XS clear rows under the drips, by its shaped ink per line: drips end 118, clear 119-120, ink 121-150, then 4 clear rows over BACK (155). th / ar / ja / ko / zh_* / vi already had 2+: unchanged. |
| pseudo (low) | upgrades-coins | footer note broke `...IN THE STORY` / `MAZES____]` (one-word line) | fixed | a note wider than the 312 px column breaks at the balanced space (`UIKit.break_line`), autowrap kept only where no such space exists (CJK, Thai): `[______COINS HIDE AT DEAD ENDS` / `IN THE STORY MAZES________]` / second note; 3 lines as before, ink rows 120-144 (2 clear rows under the drips). No other locale wraps this hint. |
| ja, zh_CN (low; ko too) | upgrades-abilities | hint on the bottom row beside BACK | accepted (documented) | the F3a taller rows leave no GAP_M + hint line under the list, so the plan's documented fallback (ui-rules 10.1 "Two-line rows in goo panels": the hint on the bottom row) applies, as already accepted for vi / zh_TW. Centred (ink centre ja 159, ko / zh_CN 159.5), 26 / 30 / 61 clear columns from BACK, on BACK's text rows (165-173). Added to leftovers.md's line. |

## Rules settled (docs/ui-rules.md 10.1 "Fix pass R3 rules", 10.2)
- A one-off panel between props is measured on their ink in the resting frame; padding narrows to
  `NOTICE_MIN_PAD` (5: 1 clear column off the goo's side lumps) and the panel may sit off centre before a line
  breaks; props' idle animations that would reach under it wait.
- A hint under goo rows keeps GAP_XS clear rows under their drips by its ink, not its line box.
- A note too wide for its column breaks at the balanced space where the language spaces its words.
- RTL: the try-on stage mirrors its routine (positions, E / W animation choice), never the art.

## Tests
- `tests/test_i18n_r3_layout.gd` (every locale, Arabic included): notice 2 lines in en / es / pt_BR / fr / it / de,
  clear of the side stations' resting ink (GAP_S at full padding, else GAP_XS), padding >= NOTICE_MIN_PAD, idle
  animations held when they would reach it, GAP_S over the wheel, inside the screen, English box (98, 24) 124x30;
  COINS hint first ink GAP_XS under the drips (taller scripts) / line box under them, last ink over the bottom row,
  lines inside the column, no one-word line; try-on slime at the mirrored x with the swapped animation in Arabic, at
  the English x / animation elsewhere, art never flipped.
- `tests/test_i18n_f3a_layout.gd`: the notice-vs-stations check measures their resting ink (sprite frames before).
- `./tools/i18n_capture.sh --gate` (all 19 locales, every state): PASS, goo-ink 0 in every locale, 0 missing glyphs,
  real save unchanged.
- `./tools/test_all.sh`: every suite touching these screens passes (test_i18n_r3_layout, test_i18n_f3a_layout,
  test_upgrades_v2, test_phase5; test_i18n_screens' open rows are all settings). At the time of this pass the
  suite was red only in files the parallel R3 agents had in progress (hi button_h 22 vs test_ui_kit_locale /
  test_language_screen, ar HEAT icons, zh_TW result panel, the .po check) and in load-sensitive perf budgets.
