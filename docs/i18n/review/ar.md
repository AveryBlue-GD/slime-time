# UI review: Arabic (ar)

Reviewed 2026-10-17 from the `tools/i18n_capture.sh` frames (320x180, seeded) for all 54 states except map-table and
map-view (owned by another review), each compared side by side with English at 3x-8x nearest upscale; pixel positions
are in 320x180 frame coordinates (x, y). Glyph check: 0 missing glyphs. Letters are joined everywhere (Noto Kufi GSUB:
init / medi / fina forms and lam-alef in every string checked). Mirroring is right on every menu: BACK bottom right,
tab rows reversed (العجلة / المتجر, نقود / تذاكر, قبعات first on the right), level tiles 5..1, skin / hat / trail grids
from the top right, HUD pods (meter right, level left, coin / ticket icons on the outer side), dialogs' button pairs,
page arrows (NEXT `<` on the left), ؟ and ! at the left end. Not mirrored, correctly: the hub room, the game world, the
logo, the hat wheel's wheel, the code field's content (SLIME2-...), times / percentages / seeds. Placeholder numbers
(`+{n}`, `{a}/{b}`, `(+0)`, `+60%`) read right thanks to `Loc.fill`'s isolates.

| # | State | Element / text | Problem | Severity | Suspected file |
|---|---|---|---|---|---|
| A1 | descent-boon-card | GREEDY GOO card: `+1 تذكرة/طابق`, `الخزان -10%` | **Signs on the wrong side.** These signed numbers are literal text in the msgstr (no placeholder), so `Loc.isolate_ltr` never wraps them and the bidi algorithm moves the sign: drawn as `1+` (x 87-90, y 89-95) and `%10-` (x 32-42, y 108-113). Every other signed number on the card (`+60%`, `(+0)`, `+0`) is a placeholder and correct. The same literal pattern is in `boon.gulp.desc_1` (`+30% سلايم`), `boon.tank.desc_1` (`الخزان +15%`), `boon.slick.desc_1` (`انزلاق +15%`), `boon.blaze.desc_2` (`+1 سطوع`), `boon.thrift.desc_2` (`+15%`): expected to break the same way (not in the captured card). | high | `locale/ar.po` 221-316 (`boon.*.desc_*`) and `scripts/descent.gd` (boon lines bypass `Loc.fill`); fix in `Loc` (isolate signed numbers in any Arabic line) rather than per string |
| A2 | wardrobe-skins | hint كل مستوى جديد يلبسك أحدث مظهر لديك | The hint's ink (rows 117-127) sits **on the try-on stage's top border** (row 128): 23 text pixels touch it along x 60-261, and the descenders of ى / ي (مستوى, لديك) are covered by the stage. Thai / Hindi keep 11+ px here; English 13 px. | high | `scripts/ui/skins_screen.gd` 112-174 (`_plan`: status / rule tops vs `stage_top` for line_h 19) |
| A3 | hud-randomizer, hud-descent-pot | level name - المعبد الغارق -; floor line الطابق 1 | The intro is drawn below the taller second pod row: name at y 70-82 over the player slime (x 153-167, y 64-75); in Descent الطابق 1 at y 92-102 touches the slime top (y 102-114). English intro at y 44-63, clear. | med | `scripts/hud.gd` 269-275 (`story_label.offset_top = _area_base + _story_gap()`) |
| A4 | hud-l10 | story line حر شديد. المخرج هو الفوهة. اركض. | Line at y 53-66 ends on the slime's top (y 66). | low | `scripts/hud.gd` |
| A5 | wardrobe-skins | try-on slime in the stage | Not mirrored: the slime is at x 57-87 in both English and Arabic, although section 10.2 lists the try-on slimes among the mirrored Node2D sprites (it should start at the stage's right end). Re-check on a second frame (it walks). | low | `scripts/ui/skin_showcase.gd` / `UIKit` Node2D mirroring under the stage |
| A6 | settings, pause-story, pause-random, pause-descent | VOLUME = الصوت | Same word as the SOUND toggle (الصوت: مفعل), so two rows read "sound"; English distinguishes SOUND / VOLUME. Suggest مستوى الصوت (fits: the label has room left of the slider). | low | `locale/ar.po` 2394 (`settings.volume`) |
| A7 | pause-story, pause-random, pause-descent | QUIT TO HUB = الساحة | Only the noun ("the hub"), identical to the result screens' HUB button; the pause menu loses the "quit to" action. Suggest العودة إلى الساحة (fits the 98 px button). | low | `locale/ar.po` 2143 |
| A8 | wardrobe-trails | page button مظاهر (SKINS) | The ه tail's ink reaches x 7-8, the button's inner border is x 6 (0 px gap) while the right side has 2 px: text 1 px off centre and touching. | low | `scripts/ui/skins_screen.gd` (page button width from `tab_widths`; Kufi's side bearing) |
| A9 | level-select-heat-panel | all six HEAT toggles | Every icon is drawn at 1x (crescent, cloud, drop 6-8 px) even where the name fits (خافت, هش), so the panel looks unlike English's 2x icons; GROUNDED's name ملتصق بالأرض ends 2 px from its icon (x 293 vs 295). | low | `scripts/ui/heat_panel.gd` (1x icon fallback applied to all toggles, section 10.2) |
| A10 | hat-wheel-shop | item names (قبعة عالية, طاقية صوف ...) | Right-aligned names end 2 px from the row's inner border (ink x 293, border x 296) vs 3-4 px of left padding in English. | low | `scripts/ui/hat_wheel.gd` (shop row label margin under RTL) |
| A11 | story-intro-card-1..4 | shot pips and the fast-forward mark | Pips fill left to right and the skip mark stays bottom right (custom drawing, deliberately not mirrored by section 10.2); every other progress / page indicator in Arabic reads right to left. Decide once; not a defect under the current rule. | low | `scripts/ui/story_screen.gd` ~150 (pips drawn in `_draw`) |

Not errors (checked): Arabic hamza / dots on row 3 of a few buttons right under a goo lump (hat-wheel-shop أوراق at
(115, 37), result-randomizer-win (151, 148), settings-reset-confirm (206, 120), upgrades-coins (264, 38)) follow the
row-3 rule; the hub counter pod covering the coin board's top corner (x 243-315, y 4-23) also happens in English
(top left there). Word gaps in Kufi titles (إيقاف مؤقت) are one space, as written.

Clean: title, language, settings, settings-save-code, settings-reset-confirm, key-controls, level-select-normal /
-hard, upgrades-coins / -abilities (2 rows a page, `1/2` mirrors BACK), wardrobe-hats, hub and its overlays / prompts,
coin board, notice, pause menus (layout), restart-prompt, hud-l1, hud-l1-all-found, hud-l7-hard-heat-63,
hud-l8-assisted, results (dry-up, randomizer-win, win-l3, win-l10), victory, descent-summary, hat-wheel-wheel. No
untranslated English apart from the deliberate key names (ESC, P, F11, F) and the save code.

Counts: high 2, med 1, low 8.
