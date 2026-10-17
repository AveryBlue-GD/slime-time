# Re-check: ja, ko, zh_CN, zh_TW (after F1-F4 and the leftover pass)

Re-reviewed 2026-10-17 from fresh captures of all 56 states (map-table and map-view included) for en, ja, ko, zh_CN and
zh_TW, compared with the old captures state by state (pixel diff, then 2x / 4x crops). Positions are 320x180 frame
pixels (x, y). Gaps were measured from the frames as text-colour ink columns / rows, not from code.
`missing_glyphs.json` is empty and the goo-ink json is `[]` for all four locales. The `story-intro-card-*` captures are
unchanged and still have no caption in any locale, English included.

Status: **fixed** = gone in the new capture; **accepted** = listed in leftovers.md / F4 with a reason I agree with;
**open** = still visible, with no accepted reason.

## ja

| Original row | Status | Evidence (new capture) |
|---|---|---|
| slimy digit glued to kana / kanji (med) | fixed | `Loc.SCRIPT_GAP`: hub-resume `12階` 0 -> 1 clear column (`2` x 42-46, 階 from 48); level-select-hard `10枚` 1 (x 255); `賞金0`, `次の階+60%`, `Fで閉じる` (2), `100%踏破` (x 160) all 1+ |
| title STORY `ストーリー` 1 px left (low) | fixed | ink 3 / 3 columns from the fill (English 3 / 2) |
| 報酬枠 / 霧 / 袋 dense at 10 px (low) | accepted | glossary term in 7 strings, a native reviewer's call (F4, leftovers). Agreed: legible as drawn |
| coin-bag pod covers the bag (low) | fixed | pod top 149 -> 156, the bag sprite is clear |
| ABILITIES tag on the bottom goo (low) | fixed | T6 / B4+ (F3a), goo-ink 0 |
| `コイン返却+888` no space (low) | fixed | `コイン返却 +888` |
| hud-randomizer area name on the slime (low) | fixed | name under the timer, slime clear |
| wardrobe page titles in the body font (low) | fixed | 20 px titles on all three pages |
| `残り火　（選択中）` 14 px gap (low) | fixed | one space |

New findings:

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| result-randomizer-win | results panel / player slime | The panel moved down about 20 px (top edge y 49 -> 69) and now leaves the top of the player slime showing above its top edge: 2 highlight pixels at (153, 66) and (166, 65) plus the dark top of the sprite. In English the panel (top 55) hides the slime. A regression from the old capture | low | scripts/hud.gd (results panel placement) |
| pause-descent | `やめると賞金の半分を受け取る` note | 5 clear rows between the panel's bottom lumps (y 155) and the note (161-169); English has 16 (133 -> 150), zh_TW 27. Same in the old capture | low | scripts/ui/pause_menu.gd (note y) |
| upgrades-abilities | hint `まずランダマイザーでチケットを稼ごう` | The taller rows (F3a) pushed the hint from under the list onto the bottom row beside BACK. It is centred and well clear of BACK, as already accepted for zh_TW / vi, but English keeps it under the list. Noted only | low | scripts/ui/upgrades_screen.gd |

## ko

| Original row | Status | Evidence |
|---|---|---|
| slimy digit glued to Hangul (med) | fixed | hub-resume `12층` 0 -> 2 clear columns; level-select-hard `10장` 2, `1회` 1+ |
| tagline 를 / 틀 / 출 squeeze (low) | accepted | the squeeze is in the 10 px bitmaps and glyph spacing does not change it (leftovers). Agreed |
| pause-random seed button filled (low) | fixed | code only, as in English: L4 R4 -> L17 R16 |
| coin-bag pod covers the bag (low) | fixed | pod clear of the bag |
| ABILITIES tag on the bottom goo (low) | fixed | goo-ink 0, 1+ clear row |
| hud-randomizer area name on the slime (low) | fixed | name under the timer |
| wardrobe page titles in the body font (low) | fixed | 20 px titles |

New findings:

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| result-randomizer-win | results panel / player slime | Panel top at y 70: the slime's highlight pixels (153, 66) and (166, 65) show above it. (166, 65) was already visible in the old capture, (153, 66) is new. English hides the slime | low | scripts/hud.gd (results panel placement) |
| pause-descent | `나가면 판돈의 절반만 받아요` note | 5 clear rows under the panel's lumps (English 16) | low | scripts/ui/pause_menu.gd |
| upgrades-abilities | hint `먼저 랜덤마이저에서 티켓을 모으세요` | Moved onto the bottom row beside BACK (was under the list). Centred and clear; noted only | low | scripts/ui/upgrades_screen.gd |

## zh_CN

| Original row | Status | Evidence |
|---|---|---|
| slimy digit / F glued to hanzi (med) | fixed | hub-prompt-story `第1关` 0 -> 1 clear column (`1` x 174-176, 关 from 178); `12层` 1; `按F关闭` 1-2 |
| 模 / 继续 mush at 10 px (med) | fixed | `随机关卡` (portal title, prompt, victory, hint), `回到游戏` / `回到本局` / `前进` on RESUME / CONTINUE |
| hud-l8-assisted story line on the ASSIST pod row (med) | fixed | line under the pod |
| 级 in 升级 (low) | accepted | no simpler natural word, a font matter (F4). Agreed |
| 雾 / 袋 / 烬 / 佩 dense (low) | fixed (佩) / accepted (rest) | `（使用中）`; the rest are legible from context (F4) |
| pause-random seed button filled (low) | fixed | code only, L17 R16 |
| ABILITIES tag on the bottom goo (low) | fixed | goo-ink 0 |
| hud-randomizer name on the slime; wardrobe titles in the body font (low) | fixed | name under the timer; 20 px titles |

New findings:

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| descent-boon-card | DESCEND button `继续深入` | The same 继续 that F4 replaced on RESUME / CONTINUE (纟 radicals filled in) is still on the DESCEND button, which shows on every floor. F4 left it because it was not flagged. A word without 继 (e.g. `深入下一层`, if the glyphs are in the subset) would match the fix | low | locale/zh_CN.po `descent.descend`, `descent.confirm` |
| pause-descent | `退出只能拿走奖池的一半` note | 5 clear rows under the panel's lumps (English 16) | low | scripts/ui/pause_menu.gd |
| upgrades-abilities | hint `先在随机关卡中赢取奖券` | Moved onto the bottom row beside BACK. Centred and clear; noted only | low | scripts/ui/upgrades_screen.gd |

## zh_TW

| Original row | Status | Evidence |
|---|---|---|
| hud-randomizer area name over the player slime (high) | fixed | name under the timer (y 25-41), slime clear |
| slimy digit / F glued to hanzi (med) | fixed (gaps) / open (title size) | `第1關` 0 -> 1 clear column (x 179), `12層` 1, `按F關閉` 2 / 1. Part still open: in the descent-boon-card 24 px title `第1層過關` the slimy `1` is rows 16-29 next to hanzi rows 10-31 (6 rows short at the top, its bottom 2 rows above theirs). Now 3 px from 層, so it reads, but it is still the one mismatched glyph in a title |
| result-win-l3 compact NEW RECORD banner (med) | fixed | big 24 px banner, panel lines paired |
| 燼 / 寶 / 繼續 dense at 12 px (low) | open | unchanged (wardrobe `餘燼`, coin board `火山寶庫`, RESUME `繼續`). F4 left zh_TW `繼續` "without a review row", but this row is that review row; leftovers.md has no reason for it. Legible at 12 px, so low |
| coin-board digits 1.5 px above the hanzi centre (low) | fixed | digit centre 48 on the name's 48 (F3a) |
| key-controls 3 rows a page, 40 px empty band (low) | fixed | rows centred (18 / 22 px above / below); still paged 3 + 2, which is the fit |
| ABILITIES hint on the bottom row; tags on the goo (low) | fixed (tags) / accepted (hint) | tags B4, goo-ink 0; the hint is centred, 63 columns clear of BACK (leftovers). Agreed |
| wardrobe page titles in the body font (low) | fixed | 24 px titles |

New findings:

| State | Element | Problem | Severity | Suspected file |
|---|---|---|---|---|
| result-win-l3 | player slime between the panel and the banner | With the big banner back, the panel ends at about y 86, and the top of the player slime (x about 154-166, y 86-93) shows between the panel's bottom lumps and `新紀錄！`, half a slime squeezed between the two. In English and ja / ko / zh_CN the panel covers it | low | scripts/hud.gd (results panel / banner placement) |

## Counts

| Locale | Original rows | Fixed | Accepted | Still open | New |
|---|---|---|---|---|---|
| ja | 9 | 8 | 1 | 0 | 3 low |
| ko | 7 | 6 | 1 | 0 | 3 low |
| zh_CN | 8 | 6 (+ 佩) | 2 | 0 | 3 low |
| zh_TW | 8 | 6 (+ 1 partly) | 1 | 2 low (燼 / 寶 / 繼續; boon-title digit size) | 1 low |

No high or medium issue remains or is new in these four locales. Nothing is clipped, missing or untranslated, no
regional glyph forms are wrong, and digit / CJK gaps are 1+ columns everywhere I measured.
