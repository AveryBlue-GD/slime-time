# Re-check: Thai (th), Hindi (hi), Arabic (ar)

Re-review 2026-10-17 after fix passes F1-F4 and the leftover pass, from fresh `tools/i18n_capture.sh` frames of all 56
states (map-table and map-view included) per locale, each compared with English and with the previous captures
(the frames the original th / hi / ar reviews used) at 2x-8x nearest upscale. Pixel positions are 320x180 frame
coordinates (x, y); "clear rows / columns" count background pixels between ink and the nearest border / goo pixel.
No missing glyphs, no dotted circles, Arabic joined everywhere (lam-alef, init / medi / fina), no untranslated
English apart from the deliberate key names and the save code.

Severity as in the original reviews: high = wrong / clipped / unreadable or a rule broken on many screens; med =
clearly worse than English; low = polish.

## Thai (th)

| # | Original row | Status | Evidence (new capture) |
|---|---|---|---|
| T1 | hud-randomizer level name on the slime | fixed | name `- ศาลเจ้าจมน้ำ -` on the line under the pods (y ~30-36), slime from y 64 |
| T2 | hud-descent-pot `ชั้น 1` pushed down | still there (partly fixed, low) | slime clear now, but `ชั้น 1` (x ~150-172, y ~83-93) is still drawn on the top of the dithered maze wall around the slime (wall from y ~80); identical to the previous capture. F2 says "no longer touches anything": it touches the maze art. Not in leftovers.md |
| T3 | wardrobe titles at body size | fixed | 16 px titles สกิน / หมวก / รอย on all three pages |
| T4 | upgrades-abilities `พุ่งชนกำแพง` ุ on the bottom border | fixed | ุ ends on row 150, row 151 clear in its columns, lumps / border from 151 / 152 |
| T5 | language `हिन्दी` ि on the goo in Thai | fixed | T3 B4 (F3b), no ink on the lump row |
| T6 | 11 px 1-bit stacks (เนื้อเรื่อง, ม reading as บ) | still there (low) | title STORY `เนื้อเรื่อง` still a 4-row blob over เ / ื / ้; font limitation for a native reader, not listed in leftovers.md |
| T7 | result-win-l3 compact NEW RECORD | fixed | big `สถิติใหม่!` banner between the chalices, as English and result-win-l10 |

New findings (Thai):

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| hud-l10 | story line `ร้อน ทางออกคือปากปล่องภูเขาไฟ วิ่ง!` | Regression: previously above the slime (ink y 49-61, slime top y 64, clear, the original review called it clean); now moved under the slime (ink y 84-96). English keeps the line above the slime (y 35-41). The F2 fix for ar A4 / hi H7 (line >= 2 px from the slime or else below it) also took Thai, which already fitted above. Readable, but worse than English and than before. | low | `scripts/hud.gd` (story line placement vs the slime, `_story_gap()` / F2 slime-clear rule) |

Thai counts: still open low 2 (T2, T6); new low 1.

## Hindi (hi)

| # | Original row | Status | Evidence (new capture) |
|---|---|---|---|
| H1 | upper matras on the lump row (25 states) | fixed | e.g. upgrades COINS tab `सिक्के`: lump row 6, first ink row 7; goo-ink 0 in every state (leftover gate). But see new finding N1: the 1-row shift put lower matras on the bottom border in the settings grid |
| H2 | VOLUME `वॉल्यूम` 1 px high, ॉ on the lump row | fixed | settings: VOLUME headline row 87 = box top 81 + 6, SOUND headline 62 = box top 56 + 6; ॉ under the lump row. (Its ू now ends on the bottom border: N1) |
| H3 | level-select info panel line 1 on the top drips | fixed | first ink 1 clear row under the lumps (F3b), both -normal and -hard |
| H4 | hud-l8-assisted story line on the slime | accepted (leftovers.md "Story line continued under the slime") - agree | line now under the slime (y ~102-112), readable, the ASSIST pod takes the rows above |
| H5 | hud-randomizer name on the slime | fixed | `- डूबा देवस्थान -` at y ~32-42, slime from y 64 |
| H6 | hud-descent-pot floor line touching the slime | fixed | `मंज़िल 1` at y ~50-60, slime / maze from y ~80 |
| H7 | hud-l10 ु of मुँह on the slime | fixed | line under the slime (y ~84-96), >= 2 px clear |
| H8 | heat panel FOG BITES name 1 px from the frame | fixed | `कटखना कोहरा` 2 clear columns to the frame (F3a) |
| H9 | REPLAY / COINS 2 px padding | accepted (leftovers.md) - agree | COINS tab ink x 10-39 in a 4-43 tab: 5 / 4 columns from the outer edge, English's own minimum |
| H10 | Latin ESC / P / F11 dropped in Hindi lines | accepted (leftovers.md) - agree, low | still sits 2-3 px under the shirorekha (key-controls note y ~130-147); a shared-baseline design choice, readable |

New findings (Hindi):

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| settings, pause-story, pause-random, pause-descent | settings-grid buttons and the VOLUME box with a lower matra: `आवाज़: चालू`, `फुलस्क्रीन: बंद`, `हलचल: पूरी`, `वॉल्यूम` | Regression of the H1 fix: the ु / ू now end on the row directly above the box's dark bottom border, 0 clear rows (text shadow drawn on the border). Measured: settings SOUND ू ends y 74, border 75 (old capture: ends 75, border 77, 1 clear row); FULLSCREEN ु ends 74, border 75; MOTION ू ends 124, border 125; VOLUME ू ends 99, border 100 (pause-descent: 122 / 123). Other Hindi buttons keep 1 clear row (pause RESTART `फिर शुरू` ू ends 88, border 90; result-dry-up 163 / 165), as English drips do (BACK: drips 174, border 176). | med | `scripts/ui/ui_kit.gd` `button_v_margins()` (3 / 1 for hi) + the settings grid / volume box height (21 px with `Language.LINE_TRIM` hi 2 in `scripts/language.gd`) |
| upgrades-coins | hint line 1 `सिक्के कहानी की भूलभुलैयों के बंद सिरों पर छिपे हैं` | 1 clear row between the bottom upgrade row's drips (y 115) and the hint's top ink (y 117); the old capture had 2 (ink from 118); th / ar keep 3 (ink from 119), English 20+. Crowded against the goo. | low | `scripts/ui/upgrades_screen.gd` (coins page hint top vs the last row) |

Hindi counts: still open 0; new med 1, low 1.

## Arabic (ar)

| # | Original row | Status | Evidence (new capture) |
|---|---|---|---|
| A1 | boon signs on the wrong side (`1+`, `%10-`) | fixed (reworded, F4) | GREEDY GOO card: `تذكرة/طابق`, `خزان أقل 10%`; every signed number left on screen reads correctly (`+60%`, `(+0)`, `+4`, `+10%`, `+888`, `+1`). The dropped "+1" is a wording loss F4 documents (80 px line) |
| A2 | wardrobe-skins hint on the stage border | fixed | hint ink y ~113-124, 4+ clear rows over the stage (F3a) |
| A3 | hud-randomizer / hud-descent-pot intro on the slime | fixed | name y ~33-42, `الطابق 1` y ~52-60; slime / maze from y ~64 / ~80 |
| A4 | hud-l10 story line on the slime top | fixed | line under the slime (y ~84-96), clear |
| A5 | try-on slime not mirrored | accepted in leftovers.md - **disagree**, still open (low) | slime still at the stage's left end (x ~60-90, as English). leftovers.md cites ui-rules 10.2 "What does not mirror", but 10.2 "How" says UIKit "mirrors Node2D sprites under a mirrored control (slime previews, the try-on slimes; art is never flipped)": the position should mirror, only the art not. Either the code or the rule is wrong |
| A6 | VOLUME = الصوت twice | fixed | `علو الصوت` |
| A7 | QUIT TO HUB = الساحة | fixed | `عودة للساحة` |
| A8 | wardrobe-trails `مظاهر` tail touching | fixed | ink x 9-40 in a 6-44 inner box: 3 / 4 clear columns |
| A9 | heat-panel icons at 1x / GROUNDED name near its icon | fixed as stated, but **regressed** (new high below) | five icons at 2x now, ملتصق بالأرض 1x with 3 clear columns |
| A10 | hat-wheel-shop names 2 px from the border | fixed | name ink R 5 (F3a) |
| A11 | story pips / skip mark not mirrored | accepted (custom `_draw`, ui-rules 10.2 "text drawn with draw_string... custom drawing") - agree | unchanged |

New findings (Arabic):

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| level-select-heat-panel | the five 2x icons (DIM moon, BRITTLE crack, FOG BITES cloud, THIRSTY drop, RACE hourglass) | **Icons overflow their toggles.** Mirrored at their 1x width while drawn at 2x, so each sits ~9 px too far right: DIM's moon x 297-308 covers its toggle's right border (x 306-308, the focused toggle's frame); FOG BITES's cloud x 97-114 spans its toggle's right border (107-108), the 2 px gap and the next toggle's left border (111-113); BRITTLE / THIRSTY / RACE likewise straddle the border between two toggles. Old capture (1x icons) and th / hi / en are inside the tile. | high | `scripts/ui/heat_panel.gd` 241-245 (icon `position` with `icon.scale = 2`; the RTL mirror x' = parent_w - x - w uses the unscaled TextureRect width) / `UIKit.relayout` mirroring in `scripts/ui/ui_kit.gd`; set the icon's size (or `custom_minimum_size`) to the scaled size instead of `scale` |

Arabic counts: still open low 1 (A5); new high 1.

## Checked, no new error

All three: title, language, settings-save-code, settings-reset-confirm (ar CONFIRM on the right, CANCEL focused on
the left), key-controls (ar note `الأسهم للحركة - ESC/P إيقاف - F11 ملء الشاشة` in reading order), level-select
normal / hard (ar number lists read 2 4 7 10 right to left, each number LTR), upgrades-abilities, wardrobe-hats /
-trails, hat-wheel wheel / shop (ar `(0/3)` at the line's end), hub, hub-coin-board, hub-notice (ar `+888` sign
correct), hub-portal, hub-quit, hub-resume, all 10 hub prompts (ar `!` at the left end), pause menus (layout),
restart-prompt, hud-l1, hud-l1-all-found, hud-l7-hard-heat-63 (ar heat pod fully mirrored), hud-l8-assisted,
result-dry-up / -randomizer-win / -win-l3 / -win-l10 (ar `محاولة 2 = +4`, `+10%` in order), victory, descent
boon card / summary, story-intro-card-0..4, map-table (ar tiles mirrored, `صعب` checkbox on the right of its text,
6 tiles a page centred) and map-view (map art unmirrored as the rule says).
