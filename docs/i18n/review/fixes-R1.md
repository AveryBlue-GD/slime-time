# Fix pass R1: HUD intro texts, results, pause, Descent card, RESTART?

Scope: `scripts/hud.gd`, `scripts/game.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/descent_card.gd`,
`scripts/ui/restart_prompt.gd`; tests `tests/test_i18n_r1_layout.gd` (new), `tests/test_i18n_game_layout.gd`,
`tests/test_i18n_f2_layout.gd`. Verified with `./tools/i18n_capture.sh --gate` (19 locales x 73 states, goo-ink gate
PASS) against a capture of HEAD f479e3c made in a separate worktree, diffed pixel by pixel and measured.
**English: 0 changed pixels in all 73 states.** (Arabic shows changes everywhere in the diff: another pass's
uncommitted `ui_kit.gd`, not these files.)
Shots (one state, all 19 locales): `docs/i18n/shots/fixes-R1/<state>_before.png` / `_after.png` for
descent-boon-card, hud-l10, hud-l8-assisted, pause-descent, pause-story, restart-prompt, result-dry-up,
result-randomizer-win, result-win-l3.

## Rows

| Item | Locale(s) / state | Measured before -> after |
|---|---|---|
| (a) SEED cutoff | pause-random | English back to its 92 px (`SEED_TEXT_MAX_EN`, `seed_text_max()`), a translation 90 (BUTTON_TEXT_PAD each side). Test: a 91-92 px `SEED code` keeps SEED in English; a 10-digit seed shows the code alone. The `# i18n:` hint keeps "max 92px" (the English box; the .po files need no merge). |
| (b) side clearance | HUD intro texts | `Hud.side_clearance()`: English `TEXT_CLEARANCE` 2 beside a pod again (its pre-F2 source layout), a translation 12. Slime avoidance unchanged in every locale. English captures identical. |
| (c) stale spawn rect | HUD intro texts | `player_rect` is used only while the slime is still on its spawn spot: game.gd calls `hud.release_player_rect()` the first physics frame the slime is off it. After that a re-placement (pause / RESTART? closing, a pod change) starts from where the texts are and only moves them down off a pod: never up, never to the old "under the slime" spot. Test: tops unchanged after pause + restart prompt + `_pods_changed`; a pod shown mid-level never moves them up. |
| th story line | hud-l10, story-line-l10 | The slime check reads a taller script's real ink (`UIKit.ink_rows`, drips counted) instead of its 17-row line box: story ink rows 84-96 (under the slime) -> 49-61, above it, 4 clear rows over the slime (66). Same rule moved zh_TW L8's line above the slime: 69-79, slime from 84. ar / hi L10 stay under the slime: above, their ink would reach rows 68 / 69 over the slime's top 65 (the F2 A4 / H7 fix). |
| slime peeking at a result panel | result-randomizer-win, result-win-l3, result-dry-up | `_slime_room`: a translation's re-fitted panel that covers only part of the slime moves to the nearest row where it covers the drawn body whole, else clears the slime's rect by GAP_XS above / below, inside its room (pods above, GAP_XS over the banner title's marks below); then its rows pack GAP_XS; then it may end on the slime's 1 px rect margin. A slime under a panel side widens the panel to cover it (`_cover_sides`). ja / ko randomizer: panel top 69 -> 65 (the highlight pixels at (153, 66) / (166, 65) covered); pt_BR / fr / de / it / pl / tr, th, ja / ko / zh_CN L3: 1-7 rows lower, covering the slime's last rows; es / ru L3: panel 41 -> 23, ends row 80, slime fully visible under it (covering would cross ¡NUEVO RÉCORD!'s marks); zh_TW L3: 29 -> 24, rows packed, ends 82 over the slime's ink (83; no more half slime between panel and 新紀錄！); ko / zh_TW dry-up: 174 -> 196 px wide, the slime under its left side covered. |
| pause note room | pause-descent | The note's first ink `NOTE_ROOM` (English's 18) under the panel in every language: accented 7 -> 18 (PAUSED rises by the accent rows its own letters do not use: PAUSE / PAUSA have none, title line 36 -> 30, panel 61..150 -> 55..144, note ink 162-170 / 173), CJK 4 -> 18 (the title's empty top rows: line 30 -> 24, its ink still from row 30 as English; panel 65..154 -> 55..144), hi 154, ar 151, pseudo 164 (two columns, 18 clear). English unchanged at 150. |
| VOLUME slider (from R2) | pause-story / -random / -descent | The pause column widens so the VOLUME label leaves a slider as long as English's 46 px (as R2 did for the settings columns): de 22 -> 46 (column 124), es 106, ru 118, pl 112, tr 120, th 109, vi 112, ar 118, pseudo 112; English / CJK / hi / pt_BR / fr / it / id keep 100. The widened buttons are noted (`note_text_w`), so test_i18n_screens accepts them. |
| boon icons 1x | descent-boon-card pl, vi | A face too tall under the 2x icon in the 78 px tile gets PICK ONE's rows: PICK ONE goes on the status line until a pick (as in a taller script) and the tiles start under the meter / pot line, as tall as the room (pl 47+78 -> 37+89). pl / vi: 1x -> 2x icons. pseudo: its six-line faces need 93 rows (89 there), so 1x, but now centred over the lines (was 1x inline top-left). Still 1x where a face needs more: it `VESCICA DI SCORTA` (88 + marks). |
| slash break | descent-boon-card id | A line with a slash run too wide for the tile breaks at its spaces only (`_keep_slashes`): `+1 TIKET/` / `LANTAI` -> `+1` / `TIKET/LANTAI` (pseudo `[_+1` / `TÍX/FŁÖÖR__]`). No other locale's lines change. |
| zh_TW title digit | descent-boon-card zh_TW | The 16 px title draws its digits in the script font (`OWN_DIGIT_LOCALES`): `1` rows 16-29 -> 12-29 next to hanzi 10-31, 4 clear columns each side (was 4 / 4). |
| RESTART? next to a pod | restart-prompt pseudo | The title's box keeps GAP_L from a HUD pod beside it, else it (and the panel) goes GAP_XS under those pods: pseudo 3 clear columns from ALL FOUND -> title line 30 -> 47 under the pods, panel 2 px under it, ending by row 176. pl (12 clear columns) and English unchanged. |
| (d) tests compared code with itself | test_i18n_game_layout | ABILITIES gap: GAP_S whenever the measured rows + hint fit the content area at GAP_S, GAP_XS otherwise (no plan read). Wardrobe title in a taller script: its last ink row pinned per script from the rendered captures (ja / ko / zh_CN 27, zh_TW 31, th 20, hi 20, ar 24, shadow included), and `UIKit.title_ink_end` must equal it. |

## Rules

- **Intro texts and the slime**: the spawn rect counts only until the slime moves; later placements never move the
  texts up. In a taller script the slime test uses the glyphs' ink, so a line that fits above stays above.
- **A result panel covers the slime whole or keeps clear of it** (cover, clear above / below by GAP_XS, packed rows,
  the 1 px rect margin, wider for a slime under its side), never half; English's source layout already does.
- **The pause Descent note keeps English's 18 rows** under the panel; the room comes from the title's unused rows
  first, two columns last.
- **A boon face keeps its 2x icon** by taking PICK ONE's rows before falling back to the 1x icon.
- **A modal title keeps GAP_L from a HUD pod beside it**, else it moves under the pods.

## Accepted (in the test as `SLIME_ROOM_OK`)

- vi / hi L3: the panel ends 3 rows over the slime's idle body; the drawn (celebrate) slime is hidden whole.
- ar / hi randomizer win: their two-line pods push the panel to row 74-75; the slime's top (65-73) shows over it.
  Covering needs the panel 9 rows higher, clearing it 5 rows lower than the choice row allows.

## Not mine (test_all)

- `test_i18n_f3a_layout` ar wardrobe (16 px title, rule line over the stage): another pass's uncommitted
  `scripts/ui/ui_kit.gd` / `tests/_ar_wardrobe_probe.gd`.
