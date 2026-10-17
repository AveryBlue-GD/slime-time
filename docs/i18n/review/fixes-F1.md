# Fix pass F1: shared causes (UIKit, Language, Loc, hub)

Scope: the review rows whose cause is shared (UIKit styles / sizes, Language metrics and fonts, Loc) or in
`scripts/hub.gd`. Screen scripts (title, settings, level select, upgrades, wardrobe, key controls, hat wheel,
LANGUAGE, map screens) are F3's; HUD / results / Descent were F2's (`fixes-F2.md`); translations F4's.
Rules: `docs/ui-rules.md` 10.1 "No ink on the goo", "Script gap (CJK)", 10.2 signed numbers; Panels / Pods.
Shots: `docs/i18n/shots/fixes-F1/<state>_before.png` / `_after.png` (all 19 locales per sheet, 2x).

Measured with `tools/i18n_capture.sh --measure-boxes` (box-relative ink: T = first ink row, B = clear rows
under the last; L / R = clear columns incl. shadow). Before = HEAD 53caa8f, after = this commit; same harness.

## Rendered check (new): goo-ink
`tools/i18n_capture.sh` now renders each state twice more (texts hidden, shadows hidden) and counts glyph ink
inside every visible goo box's band / lump rows (`OUT/json/goo_ink_<locale>.json`; README "Goo-ink check").
Capture is now deterministic (state frozen, fixed drip seed; hub physics held so the station prompts are
really shown: before, the prompt states were measured with the prompt already hidden by the hub's physics).
Glyph ink px in band rows, before -> after: en 153 -> 113 (coin board fixed; the rest is the LANGUAGE screen and
the upgrades ability rows, F3), es 42 -> 27, pt_BR 62 -> 32, fr 52 -> 24, de 37 -> 16, it 39 -> 22, ru 79 -> 47,
pl 46 -> 23, tr 54 -> 22, vi 172 -> 40, hi 169 -> 29, th 75 -> 16, zh_TW 45 -> 18, pseudo 356 -> 154, ja / ko /
zh_CN 16 -> 16, ar 16 -> 16. What is left is in screens: LANGUAGE native names (every locale, 16 px rows with
1 / 1 margins), title ENTER (own styles), settings language button label, level-select info panel, map-table
tiles, upgrades ability rows, vi key-controls, pseudo result / boon cards: all F3 (or F2) files.
`tests/test_i18n_f1_marks.gd` (headless) checks the rules below in every locale, including every glyph of every
translation against the metrics.

## Rows

| review row | status | how / measured |
|---|---|---|
| vi hub-prompt-* (all 9) marks in the pill band (high) | fixed | `panel_style()` margins from the script's ink (`panel_v_margins`): marks start on row 6 like English capitals. Random pill T1 -> T6 (99x18 -> 99x23), wheel T1 -> T6, story T3 -> T8; 0 band px in every prompt |
| ru / pl / tr / de / pt_BR / fr / it / pseudo hub pills (med) | fixed | same; the prompt's top room is only its own line's marks (`panel_v_margins(text)`): fr random T3 -> T6, pt story T3 -> T6, de coins T4 -> T7, pl quit T3 -> T6, tr coins T4 -> T7, pseudo T3 -> T6; unmarked lines keep English 18 px, T6 (es MODO ALEATORIO, ru МЕШОК МОНЕТ: `has_mark` no longer treats every Cyrillic letter as marked). tr cedillas: B3 (English drips B3) |
| ja / ko hub-prompt-coins pod covers the coin bag | fixed | CJK pill 25 -> 19 tall (ink T9 B7 -> T6 B4, as English T6 B3), and a taller pill grows down first (bottom edge to row 177, drops on screen): CJK top row 149 -> 156 = English |
| hi H1: upper matras on every button's lump row (25 states) (high) | fixed | Devanagari's 8 px line box trimmed to its ink (19 -> 17, `Language.LINE_TRIM`: no hi msgstr inks the last 2 descent rows), buttons stay 21 with margins 2 / 0 -> 3 / 1: COINS tab T2 -> T3, FULLSCREEN T2 -> T3, every hi button 0 band px except the title's own ENTER |
| hi H2: VOLUME label 1 px high, ॉ on the lump row | fixed | volume box takes the button margins in a taller script: label on the same row as the buttons' (T3), box 21 |
| es/pt/de/ru/pl MONEDAS, MOEDAS, MÜNZEN, МОНЕТЫ, MONETY tabs touch the frame | fixed | `BUTTON_TEXT_PAD` 4 -> 5 (`button_w`, `tab_widths`, `back_size`): es tab 50 -> 52 wide, L5 R4 -> L6 R5 (3 clear columns left, 2 right of the shadow); English widths unchanged (every English text fits its min width) |
| fr BOUTIQUE, TOURNER  GRATUIT; it NEGOZIO; tr DÜKKAN; ru КОЛЕСО tabs | fixed (shared part) | same pad: BOUTIQUE 54 -> 56 L5 R4 -> L6 R5, TOURNER GRATUIT 98 -> 100 L6 R5, NEGOZIO 48 -> 50. hat_wheel.gd's own centring (title at x 204) is F3 |
| BACK VOLTAR / ZURÜCK / RETOUR / ATRÁS interior 2/2 | fixed | `back_size` through `button_w`: +2, L6 R5 |
| hub-resume CONTINUAR / ABANDONAR, descent-summary OTRO DESCENSO, NOUVELLE PARTIE fill their buttons | fixed (pad) | +2 px each (resume 62 -> 64, L6 R5) |
| hi H9 REPLAY / COINS 2 px padding | partly | text-sized buttons get 5 per side; buttons at their English width keep it (COINS 40 -> 41, L4 -> L5) |
| tr HİKAYE, id CERITA title corner button 2/1 | fixed (pad) | 42 -> 44, L5 R4 -> L6 R5 |
| ko pause-random seed button fills | fixed if sized by button_w | pause_menu.gd sizing is F3's to confirm |
| CJK digits / key letters glued to the next kana / hanzi / hangul (ja, ko, zh_CN, zh_TW med) | fixed | `Loc.t` / `Loc.n` insert U+2007 (`Loc.SCRIPT_GAP`, no break) after a slimy digit / Latin letter / `% ) ] ! ?` before a CJK letter, ja / ko / zh only; the slimy fonts get a 1 px (2 px at 16) glyph for it. zh_CN 第1关: `1` ink x 175-176 touching 关 at 177 -> 1 clear column (1 at 174-176, 关 from 178). The other direction already had 1-2 px |
| en hub-coin-board: HUD pill over the board frame (med, all locales) | fixed | the ticket pod fades (alpha 0) while the board is open, back on close; English changes only in this state (and, in a capture run, the RID-seeded goo lumps of the states captured after it: same layout and text, different lump pattern; with the fade disabled every other English state is byte-identical) |
| vi hub-coin-board `1NGỤC` 3 px gap | fixed | two-column rows: number box to name `BOARD_NAME_GAP` 6 (English's one-column gap), was GAP_S 3; boards still fit (vi 299 -> 305 wide) |
| vi / pseudo coin-board title marks on the lump row | fixed | title lower by `accent_room()` when it has marks (vi row 4 -> 8 clear) |
| vi hub-portal Ẫ 1 px under the band; hub quit / resume | fixed | dialogs' first line at `panel_text_top()` (8, 9 accented, 11 vi): portal 0 band px |
| hub-notice (vi marks rows 1-4, tr) | fixed | PanelContainer via `panel_style()`: 0 band px |
| ar A1 signs on the wrong side (`1+`, `%10-`) (high) | fixed | `Loc.isolate_signed` wraps signed / percent numbers written in a translation in LRI .. PDI (placeholders keep `fill`'s isolates); boon card now `10%` (F4 also reworded the strings) |
| pseudo hub-prompt-* marks | fixed | as the other pills |
| hi H10 Latin runs dropped in Hindi lines | not fixed | both fonts sit on one baseline by design; raising the slimy glyphs would move every mixed line |
| zh_TW coin-board digits 1.5 px above the hanzi centre | not fixed | the documented digit rule (`digit_top`), same as every mixed line |
| pseudo hub-notice covers the props | not fixed | the box is as wide as its text; the room has no wider free band |
| LANGUAGE native-name accents under the frame (en low, every locale; th T5) | F3 | language_screen.gd's own `fit_styles` 1 / 1 margins; with this pass's metrics a row should start each name at `UIKit.GOO_INK_ROW - Lang.metrics(code).ink_top` (pt / vi rows need 16 -> 18 / 20). Changing it changes English |
| upgrades-abilities rows (en, ja, th T4 ...), title ENTER (vi, hi), settings language button (es...), level-select info panel (hi H3, accented), map-table tiles, key-controls labels, wardrobe titles, hat wheel price row | F3 | screen code; helpers ready: `panel_text_top()`, `panel_v_margins(text)`, `accent_room()`, `ink_above()` |
| result panels, Descent card / summary, HUD intro texts | F2 | F2 committed; the Descent summary now takes `panel_text_top()` (one-line switch here); hud.gd's result panel keeps `maxf(panel_style top, its own)`, so no double room |

## Not changed in English
Every English state is byte-identical to HEAD in the capture except hub-coin-board (see above): button / panel /
pod margins, widths, Loc output and the hub layout give English its old numbers (`test_i18n_f1_marks`: en
margins 3 / 3, panel 6 / 5, `panel_text_top` 8).
