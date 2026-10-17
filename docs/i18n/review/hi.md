# UI review: Hindi (hi)

Reviewed 2026-10-17 from the `tools/i18n_capture.sh` frames (320x180, seeded) for all 54 states except map-table and
map-view (owned by another review), each compared side by side with English at 3x-8x nearest upscale; pixel positions
are in 320x180 frame coordinates (x, y). A scan for text pixels (248,212,188 / 184,153,132) touching a goo or border
pixel found **0 hits in English** and 30 states with hits in Hindi. Glyph check: 0 missing glyphs; no dotted-circle
placeholders; conjuncts (क्र, स्क्री, ट्र, ज़्या, ग्रे, न्द) shape correctly and ि reorders before its consonant everywhere.

Severity: high = wrong / clipped / unreadable or a rule broken on many screens; med = clearly worse than English;
low = polish.

| # | State | Element / text | Problem | Severity | Suspected file |
|---|---|---|---|---|---|
| H1 | (systemic, 25 states) | every button / tab whose text has an upper matra (ि ी े ै ो ौ ं ँ ॉ, reph) | The marks are drawn **on the goo lump row** (row 2 of the 21 px button, the row right under the light border); ui-rules section 10 says the highest mark starts on row 3, under the lump row. English has 0 such pixels. Measured examples: upgrades COINS tab सिक्के box rows 4-24, ि hook / े ink at (10-11, 6) and (31, 6), lump row = 6; settings FULLSCREEN फुलस्क्रीन: बंद box rows 57-77, ी hook ink at (220-221, 59), lump row 59. Other hits (x, y): title ENTER हब में चलो (154-160, 86), (190-194, 86-87), STORY कहानी (36-37, 158); settings हलचल: पूरी (119-121, 107), कोहरा (68-70, 131), प्रगति मिटाओ (255-256, 158), (268-271, 158), (299-301, 158); settings-save-code कॉपी (265-272, 61); level-select-hard हीट 0 (280-283, 158); heat panel ठीक (152-154, 148); key-controls कीज़ रीसेट (139-142, 158), (165-175, 158); upgrades tabs (11-12, 6), (31, 6), (58-63, 6); upgrades-abilities स्लाइमाकाज़े row (88-90, 113); wardrobe JELLY जेली (26-57, 6-7), page buttons टोपियाँ / लकीरें / स्किन्स (282-306, 158-159); hat wheel tabs पहिया (31-33, 11), sub-tabs टोपी / लकीरें / कागज़ (99-169, 36-37); hub-portal रैंडम भूलभुलैया (123, 56), (182, 56), गहराई (173-175, 80); hub-quit छोड़ो (119-131, 104); hub-resume जारी रखो / रन छोड़ो (116-215, 114); pause-story / pause-random / pause-descent (99-198, 72-84), (177-181, 96-108), (187-189, 120), (133, 131); restart-prompt फिर शुरू (139-144, 69), (165, 93); result-* buttons (43-212, 147-148); descent-boon-card भुनाओ / नीचे चलो (62-64, 147), (245-280, 147); victory रैंडमाइज़र (192-193, 109), हब (137-141, 133). | high | `scripts/language.gd` line 97 (`hi` metrics: `ink_above = 0`, `ink_nudge = 1`), `UIKit.button_v_margins()` (top 2 / bottom 0) in `scripts/ui/ui_kit.gd` ~211-225 |
| H2 | settings, pause-story, pause-random, pause-descent | VOLUME label वॉल्यूम in the volume box | The label sits 1 px higher than every other button text (headline on box row +5, SOUND's on +6: box 81-101, headline row 86 vs SOUND box 57-77, headline 63) and its chandra ॉ is drawn on the lump row 83 (49, 83), (53, 83); the ू reaches row 99 (1 row above the bottom inner edge). | med | `scripts/ui/ui_kit.gd` ~1341-1363 (volume box label, `make_label(... FONT, TEXT_DIM)` not offset by `ink_nudge`) |
| H3 | level-select-hard (also -normal) | info panel line 1 हार्ड पर जीते लेवलों की हीट बढ़ाओ / अगला खोलने को यह लेवल पार करो | Top marks (ो ी ें) touch the panel's top goo drips at (130, 83) and (241, 83); no room above the first line. English line 1 has 2+ px. | med | `scripts/ui/level_select.gd` (panel text top; `accent_room()` is 0 for hi) |
| H4 | hud-l8-assisted | story line भूले-बिसरों की कोठरी। तुम्हें कोई नहीं भूलेगा। | With the ASSIST pod on its own row the story line drops to y 77-89 and is drawn over the player slime (x 180-192, y 84-96; तुम्हें sits on it). English: line at y 50-58, clear of the slime. | med | `scripts/hud.gd` 269-275 (`story_label.offset_top = _area_base + _story_gap()`) |
| H5 | hud-randomizer | level name - डूबा देवस्थान - | Drawn at y 70-82, over the player slime (x 153-167, y 64-75); English name at y 44-50, above it. | med | `scripts/hud.gd` (intro under the taller second pod row, `_area_base`) |
| H6 | hud-descent-pot | floor line मंज़िल 1 under - काल कोठरी - | Pushed to y 92-102 (English FLOOR 1 at y 56-63) and touches the slime's top (slime y 102-114). | med | `scripts/hud.gd` (same as H5) |
| H7 | hud-l10 | story line गरमी। रास्ता ज्वालामुखी के मुँह से है। भागो। | Line at y 53-66; the ु of मुँह reaches the slime's top (slime y 66-77, x 153-165). | low | `scripts/hud.gd` |
| H8 | level-select-heat-panel | FOG BITES tile कटखना कोहरा | Name fills the tile: right ink x 303-304 vs the tile's inner border at x 305 (1 px), 2 px from the icon on the left. English FOG BITES has 6 px. | low | `scripts/ui/heat_panel.gd` (tile name fit; `heatmod` name msgstr) |
| H9 | result-randomizer-win, upgrades-coins | REPLAY MAZE वही भूलभुलैया; COINS tab सिक्के | Text padding 2 px each side (button x 26-109, ink x 31-104; tab x 4-43, ink x 9-38) vs `BUTTON_TEXT_PAD` 4 in English. | low | `scripts/hud.gd` result buttons / `UIKit.tab_widths` (width from measured text) |
| H10 | key-controls (also settings hint, level-select SEED lines) | Latin runs inside Hindi lines: ESC, P, F11 | Latin caps start 2-3 px below the shirorekha and their drips end 1 px under the Devanagari baseline, so ESC / P look dropped in the line (key-controls hint at y 130-147). | low | slimy font fallback order in `scripts/language.gd` (mixed-script line metrics) |

Clean (no Hindi-specific error found): language, hub, hub-coin-board, hub-notice, hub-prompt-* (all 10), wardrobe-hats /
-trails layout (apart from H1), descent-summary, settings-reset-confirm, hud-l1, hud-l1-all-found, hud-l7-hard-heat-63,
story-intro-card-0..4 (no text). Numbers keep the slimy digits with `digit_top()`; no untranslated English; no bad
line breaks.

Counts: high 1 (systemic, 25 states), med 5, low 4.
