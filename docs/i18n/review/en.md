# Visual review: en (English, baseline)

Reviewer pass of the 54 non-map states (map-table / map-view owned by another reviewer) from
`./tools/i18n_capture.sh` (seeded, 320x180). English is the reference the other locale reviews are measured
against; this file lists what is already off in English itself (each also appears as "also en" in
es / pt_BR / fr / it / de). Coordinates are 320x180 frame pixels (x, y). Missing-glyph check: 0 findings.

Summary: high 0, med 1, low 4.

| state | element / text | problem | severity | suspected file / key |
|---|---|---|---|---|
| hub-coin-board | HUD pill (tickets 60, chalices 25/30) over the COIN BAG board | the hub HUD pill (x 4-77, y 3-15) is drawn over the board's top-left frame (board left edge x ~53): `25/30` sits on top of the orange frame and the board corner is hidden. Every locale (board x ~50 there). | med | `scripts/hub.gd` (coin board z-order / HUD pill not hidden while the board is open) |
| upgrades-abilities | ability descriptions `SHOOTS GOO`, `BOMB 3X3`, `WALL DASH` | the dim second line's drips reach row 49, the row's bottom goo band starts at row 50: drips touch the goo on all three rows (same in every locale). | low | `scripts/ui/upgrades_screen.gd` (ability row text placement) |
| result-dry-up | third line `ASSIST: +10% SLIME, NO MEDALS/TICKETS` | the line's drips sit on the panel's bottom goo band (0 px clear); the first two lines have room. Same in every locale. | low | `scripts/game.gd` (result panel lines, `result.assist_note`) |
| language | `PORTUGUÊS (BR)`, `TIẾNG VIỆT` buttons | the Ê circumflex and the Ế / Ệ marks sit 0-1 px under the button's top frame row; the native names are the same in every locale, so this shows everywhere. | low | `scripts/ui/language_screen.gd` (`fit_styles`, accent top margin) |
| wardrobe-hats / -trails | empty band between the status lines (y ~125) and BACK (y ~165) | ~40 px of empty screen under two short lines while the grid above is cramped; not a defect, but the layout looks unfinished. | low | `scripts/ui/skins_screen.gd` |

Not reviewable from these captures: story-intro-card-0..4 show no caption text in any locale (the frame is
taken before the caption types in), so story captions were not checked here.

Checked and clean: title, level select (normal / hard / HEAT panel), upgrades coins, wardrobe skins, settings
(+ reset confirm, save code), key controls, hub and all prompts / overlays, HUD states, pause (3), restart,
results (win L3 / L10, randomizer), Descent boon card + summary, victory, hat wheel (wheel / shop).
