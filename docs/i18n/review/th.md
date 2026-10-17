# UI review: Thai (th)

Reviewed 2026-10-17 from the `tools/i18n_capture.sh` frames (320x180, seeded) for all 54 states except map-table and
map-view (owned by another review), each compared side by side with English at 3x-16x nearest upscale; pixel positions
are in 320x180 frame coordinates (x, y). Glyph check: 0 missing glyphs. A scan for text pixels touching a goo / border
pixel found hits in 6 states; all but the ones listed below are marks on **row 3** of a button (directly under a goo
lump), which is what ui-rules section 10 prescribes (English accents do the same), so they are not errors. Upper /
lower marks never clip; stacked marks (ั้ ี่ ื้ ิ์) stay inside every box; no line breaks mid-word (U+200B breaks only);
no mirroring (LTR locale). Overall Thai is in good shape.

| # | State | Element / text | Problem | Severity | Suspected file |
|---|---|---|---|---|---|
| T1 | hud-randomizer | level name - ศาลเจ้าจมน้ำ - | The intro line sits at y 64-75 (English: y 44-50), directly over the player slime (x 153-167, y 64-75): the name is unreadable on spawn. | med | `scripts/hud.gd` 269-275 (`story_label.offset_top = _area_base + _story_gap()`, below the taller second pod row) |
| T2 | hud-descent-pot | - คุกมืดมิด - / ชั้น 1 | Same cause: pushed to y 64-92 (English 44-63); ชั้น 1 is drawn over the maze walls just above the slime (slime y 100-114). Not on the slime, but worse than English. | low | `scripts/hud.gd` |
| T3 | wardrobe-skins, wardrobe-hats, wardrobe-trails | screen title สกิน / หมวก / รอย | Drawn at the 11 px body size (หมวก ink x 148-171, y 12-17: 6 rows) instead of the 16 px title font every other Thai screen uses (ตั้งค่า, เลือกด่าน: 10-row bodies). Deliberate fit step in the wardrobe plan, but the three pages look title-less next to the rest. | low | `scripts/ui/skins_screen.gd` 112-174 (plan step 1: title in the 8 px font) |
| T4 | upgrades-abilities | row 3 subtitle พุ่งชนกำแพง | The ุ under พ ends on row 148, right on the row's bottom goo border (row 149, 0 px gap); English sub-lines keep 2 px. | low | `scripts/ui/upgrades_screen.gd` (ability row height, `UIKit.pod_h2()` 35 for th) |
| T5 | language | native name हिन्दी (Hindi button) | In the Thai locale the ि hook of हिन्दी touches the button's goo row at (254, 135) and (272-273, 135); in English it has 1 px. (Hindi's own font in a Thai-sized button.) | low | `scripts/ui/language_screen.gd` (row heights from the current locale's metrics) |
| T6 | title, wardrobe, upgrades (font) | เนื้อเรื่อง, เรื่อง, สไลมาคาเซะ | At 11 px 1-bit the sara uee + tone stacks collapse into one 4-row blob (STORY button x 13-16 / 27-31, y 161-164: ื's two ticks lost), and ม reads as บ (สไลมาคาเซะ looks like สไลบาคาเซะ). Font limitation (fonts.md open item 4), needs a native reader. | low | `assets/fonts/thai` (Noto Sans Thai 11 drawn 1-bit) |
| T7 | result-win-l3 | NEW RECORD | Shown as a small one-line สถิติใหม่! 0:13.6 (y 128-138) instead of the big gold banner (English, and Thai result-win-l10, show the big one). Inconsistent between the two win screens. | low | `scripts/hud.gd` 812+ (`_build_record_banner`, fit fallback) |

Clean (no Thai-specific error found): settings, settings-save-code, settings-reset-confirm, key-controls (2 pages, 3 + 3
rows), level-select-normal / -hard / heat panel, upgrades-coins, hub and all hub overlays / prompts, coin board, notice,
pause-story / -random / -descent, restart-prompt, hud-l1, hud-l1-all-found, hud-l7-hard-heat-63, hud-l8-assisted,
hud-l10, result-dry-up, result-randomizer-win, result-win-l10, victory, descent-boon-card, descent-summary, hat-wheel
wheel / shop, story-intro-card-0..4 (no text). Slimy digits share the Thai baseline (`digit_top()` 5) everywhere; no
untranslated English.

Counts: high 0, med 1, low 6.
