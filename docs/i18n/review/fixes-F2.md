# Fix pass F2: HUD, results, Descent, tutorial keys

Scope: `scripts/hud.gd`, `scripts/game.gd`, `scripts/tutorial_cues.gd`, `scripts/ui/descent_card.gd` (the shared
accent headroom / CJK digit spacing in `ui_kit.gd` / `language.gd` / `loc.gd` / `hub.gd` and the `.po` texts are other
passes). Verified with `./tools/i18n_capture.sh` (all 19 locales x 56 states, before and after) and measured;
`tests/test_i18n_f2_layout.gd` (new) checks every fixed row in every locale (Arabic included).
Before / after contact sheets (one state, all 19 locales, order en es pt_BR fr de it ru pl tr ja ko zh_CN zh_TW th vi
id ar hi pseudo): `docs/i18n/shots/fixes-F2/<state>_{before,after}.png`; the tutorial key: `tutorial-space_en_*`.

English pixels changed only where the owner asked: the dry-up result (its last line), the tutorial SPACE key and the
randomizer level pod with CODE LVx (YOU y). Every other English HUD / result / Descent rect is the same as at HEAD
(control-rect dump of the 13 states, diffed; pinned in the new test).

## Rules these fixes settle (for docs/ui-rules.md 10.1, owned elsewhere)

- **Intro texts keep clear of the player**: the game passes the slime's screen rect at spawn (`hud.set_player_rect`,
  from the camera's limits; hat included). When the pods push the area name / story line onto it, the texts go back
  up under the timer (the story levels' place), and a text still on the slime goes on under it.
- **Beside a pod**: a HUD text on a pod's rows keeps `TEXT_SIDE_CLEARANCE` = `GAP_XL` 12 px from it (2 px under it, as
  before); closer, it reads as part of the pod.
- **Level pod**: `GAP_L` clear of the timer pod in every language (English too); a longer name wraps at its own double
  space, else at the space that balances the lines, never leaving a lone `#n`.
- **Goo panels**: a first line with marks starts `accent_room()` lower (never on top of what `panel_style` already
  keeps); a last row whose slimy-font text is taller than its icons keeps 3 rows under its line box (2 clear rows over the lumps).
- **Result fitting order** (taller scripts): pack the panel's rows, pair its lines, and only then the compact banner.
- **Descent card**: a title with marks moves down by them (ink from row 4, as English) and the rows under it move with
  it; a tile face's side room is `GAP_L` (wider lines wrap); a face that fills its tile still starts its marks on row 3+.
- **Tutorial keys**: a key name wider than its key widens it (centred on the same pixel), W A S D keep 9 px.

## Rows handled

| Locale / row | State | Fixed? | How / measured before -> after |
|---|---|---|---|
| zh_TW (high) | hud-randomizer | fixed | name over the slime (y 60-73 on slime 63-80) -> under the timer, line top 25 (ink 25-41), slime rect (151, 64) 18x16 clear. |
| vi | hud-randomizer | fixed | name y ~62-66 on the slime top 65 -> line top 30 (marks from 25). |
| th T1 | hud-randomizer | fixed | name y 64-75 on the slime -> line top 26. |
| hi H5, ar A3 | hud-randomizer | fixed | name y 70-82 on the slime -> line top 29 (hi) / 28 (ar). |
| ja, ko, zh_CN | hud-randomizer | fixed | name touching the slime top (y 66) -> line top 23. |
| hi H6, ar A3 | hud-descent-pot | fixed | floor line y 92-102 touching the slime (102) -> name 29 / floor line 49 (hi), 28 / 48 (ar). |
| th T2 | hud-descent-pot | fixed (partly) | slime clear (line tops 62 / 80, slime from 100); the pot pod still pushes the name under it, which no longer touches anything. |
| hi H4 | hud-l8-assisted | fixed | story line y 77-89 over the slime (84-96) -> under the slime (the line can't sit higher: the ASSIST pod is on its rows). |
| zh_CN | hud-l8-assisted | fixed | story on the ASSIST pod's row 8 px from it -> line top 60, under the pod (41-58); side clearance 12. |
| pseudo | hud-l8-assisted, hud-l10 | fixed | story across the slime -> clear (test). |
| ar A4, hi H7 | hud-l10 | fixed | story line reaching the slime top (66) -> clear by >= 2 px (test). |
| pseudo | hud-l1, hud-l1-all-found | fixed | name 2 px from the ALL FOUND pod on its row -> below the pod (line top 44). |
| pl | hud-l7-hard-heat-63 | fixed | name in the HEAT pod's row 4 px from it -> under the pod (line top 44). |
| it | hud-l7-hard-heat-63 | fixed | level pod 5 px from the timer -> wraps `LIVELLO 7/10` / `DIFFICILE`, gap >= 8. |
| en (owner) | randomizer level pod | fixed | `RANDOM MAZE #n  CODE LVx (YOU y)` ran over the timer -> two lines at the double space, >= 8 px clear (pt_BR / ru / vi / pseudo long names: balanced break). |
| vi (high) | result-win-l3, -l10 | fixed | marks on the band's lump row (mark (119,44) under band 41-43) -> the first line 4 rows lower: marks start 1 row under the lumps. |
| zh_TW | result-win-l3 | fixed | compact `新紀錄！` line -> the big banner, as in the other locales (the panel pairs `第3關過關   時間 0:00.0` first). |
| th T7 | result-win-l3 | fixed | compact banner -> big banner, same way. |
| en, es, pt_BR, fr, de, it | result-dry-up | fixed | last line's drips on the bottom goo (0 px) -> 2 clear rows (en: drips end row 96, lumps 99); panel 41 -> 44 tall, still centred. |
| fr, pt_BR (high), ru | descent-boon-card title | fixed | ink from row 0 (accents cut) -> row 4, as English; meter line, PICK ONE, tiles and status move down with it (tiles keep 78 px in the accented locales, vi 71). |
| de, it, pl | descent-boon-card faces | fixed | names / lines 0-3 px from the tile stripes -> side room 8 px (wider lines wrap): every line >= 4 px inside the tile (test). |
| pseudo | descent-boon-card | partly | the right stripe touch is fixed (as above) and the marks no longer reach the tiles' goo rows; all tiles still start on one row by design, so shorter faces leave room at the bottom. |
| vi | descent-summary | fixed | Ầ's top on the band's lump (177,47 under 177,46) -> the lines 4 rows lower (panel 4 taller). |
| pseudo (high) | descent-summary rewards line | fixed | line past both panel borders -> the panel widens to the line + 8 px each side (centred, up to 312), a still wider line breaks onto two. |
| en (owner) | tutorial leap key | fixed | `SPAC` in a 29 px key -> `SPACE`, key 35 px (ink 2 / 3 px from the edge). W A S D keep 9 px. |
| ar A1 | descent-boon-card signs | not mine | literal signed numbers in the msgstr: `.po` pass. |
| ja / ko / zh_CN / zh_TW digit rows | HUD / results / Descent | not mine | CJK digit spacing: the ui_kit / language pass. |
| hi H9, id | result buttons padding, `REKOR BARU!` 3 px from the stripe | not changed | within the rules (BUTTON_TEXT_PAD 4 per side, >= 2 px clear); widths come from `UIKit.tab_widths` (ui_kit pass). |
| fr | dry-up line spans x 37-301 | not changed | inside REWARDS_W 296 with 6 px each side; the drip part is fixed. |
| de, es, fr, it | pause-descent note | not mine | `scripts/ui/pause_menu.gd`. |

## Left as is (seen while verifying)

- ar / hi result-win-l3 keep the compact banner: their 4-line panel does not fit with the big one even with paired
  lines (allowed in the test as COMPACT_OK).
- When the pods push only the story line onto the slime (L7 hard in it / vi, L8 in hi / ar / zh_TW), it continues under
  the slime, away from the name: readable, and the only free place.
- pseudo result-win-l3: the `_` brackets' drips on the medal row touch the bottom goo (pseudo glyphs only).
