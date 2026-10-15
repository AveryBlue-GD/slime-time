# QA review: Phase 3 (UI polish)

Date: 2026-10-16. Reviewer: code-reviewer + visual QA gate. Scope: commits `6686065`, `dbd62b2`, `56cbb5d`, `edeb5d8`
on `spring-cleaning`. Inputs: [phase3-ui-audit.md](phase3-ui-audit.md), [phase3-ui.md](phase3-ui.md),
[../ui-rules.md](../ui-rules.md), [decisions.md](decisions.md).

**Verdict: pass, with one behaviour regression to fix (finding 1).** Nothing in the polish changes gameplay, the
cutscene art, or keyboard/controller navigation. TouchButton never takes a click from a neighbouring control. Every
fix I re-measured matches the report's "after" numbers.

## How it was checked

- The review used scratch worktrees: `edeb5d8` (after) and `d0e0c77` (before Phase 3; see finding 2 for why not the
  `spring-cleaning-phase2` tag). Both were imported and run windowed with `--fixed-fps 60` and `--write-movie`, on
  throwaway saves only. Nothing ran in the repo's own tree, and both worktrees were removed afterwards.
- A capture driver produced 37 identical states in both trees: title, level select (normal / hard / HEAT panel),
  map table (select and view), upgrades (both tabs), skins, settings and SAVE CODE, controls, hub (room, quit, portal,
  coin board, hat wheel WHEEL / SHOP), and the HUD (L1, L3, L3 at 3.5 s, L8, L8 dev, L8 assist, L7 hard with six HEAT
  modifiers, L5 HEAT 1, randomizer, Descent, touch). It also captured pause (story, randomizer with seed 4294967295-7,
  Descent), the restart prompt, the state after the restart prompt closes, dry-up, win, the Descent card and the
  Descent summary. Each state was saved three ways: the frame, the frame with the world hidden, and the frame with all
  text transparent. The control rects were saved too. Measurements are in 320x180 base pixels.
- Suites run from the worktree: `test_ui_layout`, `test_ui_touch`, `test_nav_fuzz` (all 4 shards) and
  `test_level_tiles`. Result: 4 suites, 0 failed.
- Touch probe: for 22 screen states, every one of the 57,600 pixels was hit-tested through the real GUI picking
  (`push_input` of a mouse motion, then `gui_get_hovered_control`), once with touch on and once with it off.
- Cutscenes: `demo_story` intro (716 frames) and finale (386 frames) were recorded with `--write-movie` in both
  trees and compared frame by frame.
- Aspect ratios: level select was launched at 1280x720, 1280x800, 2560x1080, 1024x768, 2340x1080, 2048x1536 and
  1080x2340. I read the root's final transform each time.

## Re-measured fixes (rendered pixels unless noted)

| ID | Report "after" | Measured | |
|---|---|---|---|
| H1 timer pod | 136..183 (48 w), pads 4 / 4, 14 tall | outline 136..183, y 3..16; clock ink starts at 140 and bright digit ink ends at 179, so 4 / 4 from the outline. Width stays 48 at 0:00.3 and 0:03.7 | ok |
| H5 story line vs pods (L8) | rows 35..41, 2 px clear | line at row 35; the coins-left pod ends at row 32 | ok |
| H5 L7 hard + 6 modifiers | area name and line under the HEAT pod (line 50..56) | both are under the HEAT pod (19..32) and clear of it (visual + rects) | ok |
| P1 restart prompt | insets 8 / 8, panel 61 | panel 52..112, buttons 60..104 | ok |
| P4 SEED, 10-digit seed | "4294967295-7", pads 16 / 15 | button 110..209, text ink 126..194: 16 / 15, centre 160.5 | ok |
| L1 level grid | L34 / R34 | tiles 34..285 | ok |
| U2 quit confirm note | +0.5 | ink centre 160.5 (before: 166.5) | ok |
| R1 Descent card | HUD hidden | no HUD pixels under the card | ok |
| H2 / H3 pod heights, rows | 14 / 14 / 14, both second rows at 19 | all one-line pods 14 tall, rows at y 3 and 19 | ok |
| H4 HEAT pod | 14 tall at y 19 | 14 tall at y 19 | ok |
| H7 area texts under PAUSED / RESTART? | hidden | hidden (but see finding 1) | ok |
| M1 HARD checkbox | ends y 179, R4 | rect 272..315, y 163..178 | ok |
| M2 map hint | centred, bottom 177 | rect 48..271, y 167..176 | ok |
| U3 hub quit / portal buttons | 13 | all 13; quit panel 63..116, title at +8, buttons end 8 above the bottom | ok |
| C1 save code boxes | 13 | both LineEdits 13 tall | ok |
| C2 / X1 bottom row | BACK (4,164) 40x13, RESET (224,164) 92x13 | same on settings, controls, map view, title (STORY) and level select (HEAT mirrors) | ok |
| R2 / R4 Descent summary and card buttons | 84x13 gap 8 @153; card 96x13 @153 | NEW RUN 72..155, HUB 164..247 @153; CASH OUT 10..105, DESCEND 214..309 @153 | ok |
| G1 upgrades balance pod | 14 tall, sized to text | pod 281..315 at y 4, 14 tall | ok |
| Y1 story pip | rows 159..163 | the only change in either cutscene is row 159 (4 px per frame) | ok |
| TC1 JUMP | (280,140) | drawn at (280,140); the joystick home is (40,140) | ok |

## Findings (most severe first)

1. **`scripts/hud.gd:858` `hide_area_texts()`, called from `scripts/ui/pause_menu.gd` `open()` and
   `scripts/ui/restart_prompt.gd` `open()`: the area name and story line are lost for good if the player pauses or
   presses R early.** Opening either menu during the first ~3 s of a level kills the fade tween and hides both labels.
   Nothing shows them again on RESUME or CANCEL. Evidence: a capture after the restart prompt opens and closes has
   757 text-ink pixels in rows 20..39 before Phase 3 and 0 after. The story line is narrative content: it is shown
   once per level start. Fix: on open, only hide the labels and leave the tween alone (it pauses with the tree). On
   `resume()` / `close()`, re-show them if the tween is still running. Or let the menus restore what they hid. Keep
   the kill only for the results (`show_rewards` / `show_choices`). Add a check to `test_ui_layout`: open, then
   resume, and the texts must be back.
2. **The `spring-cleaning-phase2` tag (`8010964`) comes after the main Phase 3 code commit `6686065`, which sits in
   the history before it.** So `git diff spring-cleaning-phase2..edeb5d8 -- scripts` (the scope given to this gate)
   shows 4 of the 21 script files Phase 3 touched (only `hud.gd`, `level_select.gd`, `map_select.gd` and
   `upgrades_screen.gd`). It hides `touch_button.gd`, `ui_kit.gd`, the pause and restart menus, the hub, the Descent
   card and the rest. The same applies to any "before" capture, revert or comparison taken from that tag (for
   example "cutscenes identical vs the phase2 tag": the tag already has the pip change). Fix: name the Phase 3 base as
   `d0e0c77` in phase3-ui.md, or add a `spring-cleaning-phase3-base` tag at `d0e0c77`. This review used `d0e0c77..edeb5d8`.
3. **`scripts/ui/level_select.gd:18-21` (comment) and `docs/ui-rules.md` §3 (exception text): the level-tile number
   touches the record time.** The rules say "0 clear rows, no overlap". In the rendered frames, the number's drips and
   shadow run without a gap into the time's first row on tile 5 (rows 13..41 continuous) and tile 9: at 6x the "9"
   drip joins the "0" of 1:03.6. The drips are random per letter, so which tiles touch varies. Also, on 12 of 20
   tiles (normal + hard) text ink reaches tile row 41, the frame's bottom row. The comment says the time's drips end
   on rows 39-40, clear of it: it is the 1 px shadow under the row-40 drips. Fix: see owner item A below. Until then,
   change the comment and the rules text to "touching, by design".
4. **`docs/ui-rules.md` (header, "screens use them, not literals") does not match the code.** `TITLE_Y`, `FONT_BIG`,
   `DENSE_PITCH`, `GAP_XS`, `GAP_L`, `GAP_XL`, `TAB_H`, `POD_H2` and `TOUCH_MIN` have 0 uses in `scripts/`
   (`TOUCH_MIN` and `POD_H2` are used only by tests). 31 `Vector2(n, 13)` button sizes are still literals, for example
   `hat_wheel.gd` tabs, `restart_prompt.gd:26` (100 / 60 / 120) and the pause DEV column (`Vector2(6, 5)`, separation
   3). The values themselves match the screens (titles all at y 2 / 20 tall; rows 3/19/35/51; BACK 4,164). Fix: either
   write "new and changed code uses them" in the rules, or migrate the remaining literals in a later pass.
5. **`scripts/ui/touch_button.gd:17-22` / `UIKit.touch_active()`: mouse hit areas also change on desktops with
   touchscreen hardware.** That includes Windows touch laptops and web browsers that report touch. "Desktop is exactly
   as before" holds only without such hardware. There, a mouse hovers or clicks the nearest button from up to 5 px
   outside its art. No steals: the probe found none with touch on. Low impact. Fix: accept and state it in ui-rules
   §7. Or grow the area only for touch-emulated mouse events (track the last `InputEventScreenTouch` in an autoload).

No other issues:
- **TouchButton**: across all 22 states, comparing touch on and off, no pixel moved from one control to a different
  control. The grown hit areas cover only empty space and never take another target's drawn rect, a slider, the
  LineEdits or the HARD checkboxes. No hit lands on a focus-locked control behind an open panel (hub quit / portal,
  hat wheel, HEAT panel, SAVE CODE, pause, restart).
- **JUMP / joystick**: their touches are handled in `_input` and never overlap a grown button (the result row's hit
  area ends at x 253; JUMP starts at 261). The Descent card's DESCEND hit area (209..315 x 148..171) overlaps the JUMP
  disc, but the touch controls are hidden and the slime is frozen once the floor ends. No touch input is swallowed:
  `TouchButton` only overrides `_has_point`. Focus and keyboard navigation are untouched (nav fuzz passes).
- **Gameplay**: world pixels are identical apart from 1-3 particle-noise pixels. HUD changes are limited to the top
  rows (y 3..56: timer pod, pods, area name / story line) and the touch JUMP button, as listed.
- **Cutscenes** (D1): intro and finale are pixel-identical before and after, except row 159: the current pip grew 1 px
  up (the Y1 overlay). The cutscene art is untouched.
- **Aspect ratios**: integer scale at every size (4x, 4x + 40 px bars, 6x + 320 px pillars, 3x, 6x + 210, 6x, and 3x in
  portrait at 1080x1606). The root viewport is always 320x180, so the layout is the same everywhere.
- **Other regression sweep**: nothing clipped. No new overlaps on the screens I did not touch: hub room, map view,
  victory and the area-name banner (the hub room differs by 18 px of animation). Selected and hover states are
  distinct. Every transition is a pure fade (no positional tweens added). The pause DEV panel and the dialogs keep
  their z-order.

## Owner decisions from phase3-ui.md (with recommendation)

- **A. L2: centred tile number vs one clear row above the record time.** Recommend **moving the number up 2 px**
  (`NUMBER_Y` 13 -> 11). The number + time group (rows 13..40) currently sits about 5 px below the tile's centre, so
  moving it up centres the group better. It also removes the visible drip-into-digit joins (finding 3). The 2 px offset
  of the number alone is not noticeable at 1x.
- **B. Touch pitch of the dense stacks** (pause / restart 16, key rows 17, shop rows 15 -> 32-40 pt hit areas).
  Recommend **keeping the layout** for now. A 22 px pitch does not fit pause with the randomizer (6 rows + title > 180
  px). These are slow, deliberate menus, and every tap goes to the nearest button with no dead zones. Re-test on real
  phones in Phase 5. If misses show up, merge VOLUME into the SOUND row on touch rather than re-pitching every stack.
- **C. L3: 16 px glyphs "4" / "6" are 1 px left in their cell (font regeneration).** Recommend **doing it, as its own
  commit** with a before/after capture of every 16 px title and tile number. It is a data-only change via
  `tools/make_font.py`, but it touches every big text, so it should not be bundled with other work. It is low priority
  next to finding 1.
