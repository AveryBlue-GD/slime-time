# i18n inventory: every player-visible string (D15, phase 1)

Analysis only, made 2026-10-16 on branch `spring-cleaning` (after D14). No code was changed. Companion
docs: [plan.md](plan.md) (how to make it translatable), [fonts.md](fonts.md) (font research, written
separately).

## Summary

- **About 380 unique in-game strings** (≈360 translatable + ≈25 dev-only), **all built in GDScript**:
  no `.tscn` file has a `text =` property (all 13 scenes checked, 0 hits), so every string lives in
  `scripts/`, `scripts/ui/` or `scripts/autoplay/`. Plus **8 strings in `tools/web_shell.html`** and
  **1 baked into a PNG** (the `SLIME TIME` title logo).
- ≈80 strings carry numbers through `%d` / `%s` / `%.2f` formatting, ≈20 contain `\n` (multi-line),
  ≈15 sentences are glued together from fragments, 2 have hand-made English plurals, and about 70
  buttons get a fixed pixel width.
- Everything is ALL CAPS. The font (`tools/make_font.py`, 86 chars: A-Z, digits, punctuation) maps
  lowercase to the uppercase glyphs and has **no accented, Cyrillic or other glyphs**. The atlas is
  one row of 9 px glyphs, and the drip shader **recognizes the font by its atlas size** (see Risks).
- Counted with a script that pulls every string literal containing a run of 2+ capitals and drops
  paths, node names, sprite pixel rows (`"..kHlk.."`), lowercase dev logs and repeats. Per file
  (unique, before removing dev-only): game 36, controls 33, descent 32, hub 31, hud 26,
  cosmetics 22, hat_wheel 22, descent_card 21, skins_screen 17, key_controls 14, skins 13,
  workshop 13, hats 12, heat 12, story 10, themes 10, upgrades_screen 10, pause_menu 9, others ≤ 6.
  The autoplay strings (26) are debug-only.

Ways text gets built (the abbreviations are used in the tables below):
`L` literal · `F` format with numbers (`"%d" % n`) · `C` concatenation of fragments · `P` hand-made
plural · `J` list joined with `", "` · `NL` contains `\n` · `D` drawn with `draw_string` ·
`T` tabular digits · `ID` text taken from an internal id via `to_upper()` · `W` fixed px width ·
`M` measured with the real font · `6PX` width guessed from the character count.

## Areas

### 1. Title (`scripts/ui/title.gd`, `tools/make_title.py`)
| What | Strings | How | Layout |
|---|---|---|---|
| Logo `DRY TRYING` (was SLIME TIME until 2026-10-19) | 1 | **baked into `assets/sprites/title/logo_NN.png`** by `make_title.py` | bubbly art, not text |
| Tagline `ESCAPE THE FOG\nBEFORE YOU DRY UP` | 1 | L, NL | centered |
| `PLAY` / `ENTER THE HUB`, `STORY` | 3 | L | W: 176x25, and STORY = `BACK_SIZE` 40x13 (`STORY` uses 30 px of the 32 inside the 4 px margins) |

### 2. Hub (`scripts/hub.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| Station names `STORY - LEVEL %d`, `MAP TABLE`, `UPGRADES`, `QUIT`, `COIN BAG`, `RANDOMIZER`, `SETTINGS`, `HAT WHEEL`, `COSMETICS` | 9 | L, F | prompt box sized from its contents (`get_combined_minimum_size`), centered with `(320 - w) / 2` |
| Prompt notes `LOCKED`, `BEST FLOOR %d`, `SHOP`, `FREE`, `BEAT ALL %d LEVELS`, `ROTATE`, `!` | 7 | L, F | same box |
| Quit menu `LEAVE THE HUB?`, `THE GAME CLOSES`, `QUIT`, `BACK` | 4 | L | W: buttons 56x13 |
| Portal menu `RANDOMIZER`, `RANDOM MAZE`, `DESCENT`, `BACK`, `BEST FLOOR %d    PAID RUNS %d/%d` | 5 | L, F, **aligned with 4 spaces** | W: buttons 120x13 and 56x13 |
| Descent resume `RESUME`, `QUIT RUN`, `FLOOR ALREADY RESUMED`, `DESCENT RUN SAVED`, `FLOOR %d CLEARED` / `FLOOR %d` + `" - POT %d"`, `QUIT RUN CASHES OUT` / `BANKS HALF` | 8 | L, **C** | W: 56x13 (`QUIT RUN` already uses 44 of the 48 px inside) |
| Coin bag `COIN BAG`, `STORY %d/%d   IN HAND %d`, `TAP JUMP TO CLOSE` / `%s TO CLOSE`, `TAP JUMP` | 4 | F, **aligned with 3 spaces**, `%s` = a key name | centered |
| Upgrade rework notice `UPGRADES REWORKED`, `COINS RETURNED +%d` | 2 | F | centered |
Descent strings are switched off (D11) but still in the code: translate them anyway, so turning the
flag back on needs no new translation round.

### 3. Gameplay HUD and result texts (`scripts/hud.gd`, `scripts/game.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| Area line `LEVEL %d/%d%s` + `"  HARD"`, `RANDOM MAZE #%d%s%s` + `"  CODE LV%d (YOU %d)"`, `DESCENT  FLOOR %d` | 5 | **C** (suffixes added onto a format) | centered; `_place_area_texts` M-measures it and moves it down below the pods |
| Level name (theme, see 9) + story line (see 10) | – | from data | centered, M |
| Pods: `ALL FOUND` / `%d LEFT`, `ATTEMPT %d\nTIX AVAILABLE %d`, `POT %d`, ` +%d`, `PRACTICE` / `NO TICKETS` / `PAYS 1`, `PAID RUN %d/%d`, `HEAT %d`, `BOUNTY +%d`, `NEW BEST HEAT!`, `BEST HEAT %d`, `ASSIST +%d%%`, `WIND` | 15 | F, NL, C | pods 14 / 23 px tall, width from contents; stacked in the corners |
| Timer | – | `UIKit.format_time` → `M:SS.cc` | **T**: `UIKit.tabular_font()` widens `1` so the digits don't jitter |
| Reward lines `BRONZE` / `SILVER` / `GOLD`, `NEW BEST!`, `BEST ` + time, `NEW RECORD!`, `SEED ALREADY PAID TODAY - TRY NEW MAZE`, `DAILY TICKET LIMIT REACHED`, `TICKET! ATTEMPT %d = +%d`, `+%d TICKETS`, `REPLAYED SEED`, `- %s -`, assist notes `ASSIST: +%d%% SLIME, NO MEDALS/TICKETS`, `ASSIST: NO MEDALS, RECORDS OR TICKETS` | 14 | L, F, C | centered under the result |
| Win text `CHALICE CONSUMED!\nLEVEL %d CLEARED` + `\nTIME ` + time + `"   BEST "` + time, `YOU ESCAPED ALL %d MAZES!\n` + **`text.get_slice("\n", 2)`**, `\nNEW JELLY SKIN: ` + **J**, `\nUNLOCKED: ` + name + ` (ANY COLOR YOU LIKE)!`, `\nNEW SKIN: `, `\nNEW TRAIL: `, `\nALL MEDALS! NEW SKIN: ` | 10 | **C**, NL, J, F; **built line by line, then cut by line index** | centered block |
| Randomizer win `TICKET CLAIMED!\nTIME ` + … + `\nSEED ` + code | 3 | C, NL | |
| Dry-up `DRIED UP`, `OUT OF TIME!\nDRIED UP`, `DRIED UP ON FLOOR %d` | 3 | L, F | |
| Every-coin `EVERY COIN FOUND!\nNEW SKIN: ` + name, `NEW SKIN EQUIPPED: %s` | 2 | C, F | |
| Descent floor `FLOOR %d CLEARED`, `FLOOR %d BONUS +%d TICKETS`, `DESCEND `, `NEW RUN`, `\nNEW TRAIL: ` | 5 | F, C | |
| Choice row `RESTART`, `NEW MAZE`, `UPGRADES`, `ASSIST`, `REPLAY MAZE`, `REPLAY`, `CONTINUE`, `NEXT LEVEL`, `HUB` | 9 | L | W: `UIKit.CHOICE_SIZE` 84x13, three in a row (`REPLAY MAZE` is 64 of 76 px today) |
| Dev tags `DEV `, `DEV TOGGLES: NO MEDALS, RECORDS OR TICKETS`, `BRIGHT`, `NO DRAIN` | 4 | L | **dev-only: stays English** |

### 4. Tutorial cues and touch controls (`scripts/tutorial_cues.gd`, `scripts/ui/touch_controls.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `JUMP` / `SPACE`, the key name from `OS.get_keycode_string().to_upper()`, `UP DOWN LEFT RIGHT` (for the touch arrows) | 6 | **D** `draw_string` centered in a drawn keycap box; key names come from the OS (stay as they are) | box width from the text |
| Touch `JUMP` | 1 | **D**, M (`get_string_size` then centered by hand) | inside a fixed circle |

### 5. Pause menu and restart prompt (`scripts/ui/pause_menu.gd`, `scripts/ui/restart_prompt.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `PAUSED`, `RESUME`, `RESTART`, `QUIT TO HUB`, `NEW SEED`, `SEED ` + code | 6 | L, C | W: panel 120, column 100; `seed_text()` M-measures and drops `SEED ` if it doesn't fit |
| `SOUND: ` + `ON`/`OFF` | 3 | **C** label + value | W 100 |
| `QUITTING CASHES OUT THE POT` / `QUITTING BANKS HALF THE POT` | 2 | L | under the panel |
| Restart prompt `RESTART?`, `RESTART`, `UPGRADES`, `CANCEL` | 4 | L | small panel, buttons from the theme |
| Dev panel `DEV (F1 / F2)`, `BRIGHT: ` + `ON`/`OFF`, `DRAIN: ` + `OFF`/`ON` | 3 | C | **dev-only: stays English** |

### 6. Settings, save code and reset (`scripts/ui/controls.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `SETTINGS` (title), headings `OPTIONS`, `MORE` | 3 | L | title 16 px font, centered |
| `SOUND: ` / `FULLSCREEN: ` / `MOTION: ` / `FOG: ` + `ON` `OFF` `LESS` `FULL` `DARK` `NORMAL` `BRIGHT` | 11 | **C** label + value | W: `COL_W` 120x13 (`FULLSCREEN: OFF` = 84 of 112 px) |
| `VOLUME` + slider | 1 | L | **`SLIDER_W = COL_W - 54`: the 54 is "6 + VOLUME + 6" worked out by hand** |
| `CONTROLS`, `SAVE CODE`, `RESET PROGRESS` | 3 | L | W: 120x13; reset `RESET_SIZE` 92x13 ("its text + 4 px margins") |
| Save code panel `SAVE CODE`, `COPY THIS CODE TO BACK UP YOUR PROGRESS`, `COPY`, `TO LOAD A SAVE, PASTE ITS CODE HERE`, `PASTE`, `LOAD`, `CLOSE`, `CLICK THE BOX AND PRESS %s` (`CMD+V`/`CTRL+V`), `NOTHING TO PASTE - COPY A CODE FIRST`, `PASTED - PRESS LOAD`, `THIS REPLACES YOUR PROGRESS - PRESS LOAD AGAIN`, `THAT CODE DOESN'T WORK - CHECK IT'S ALL THERE`, `THAT CODE IS FROM AN OLD VERSION`, `COPIED! KEEP IT SOMEWHERE SAFE`, `COPY THE CODE FROM THE POP-UP` | 16 | L, F | panel 296x150; one-line status messages, ≈260 px max today; COPY 64x13 |
| Browser `prompt()` texts `Paste your Slime Time save code:`, `Copy your Slime Time save code:` | 2 | L, **mixed case**, shown by the browser in its own font | browser dialog |
| Reset confirm `ERASE ALL PROGRESS?`, `LEVELS, RECORDS, COINS, UPGRADES AND\nSKINS WILL BE GONE FOR GOOD`, `CONFIRM`, `CANCEL` | 4 | L, **hand-wrapped NL** | panel |

### 7. Key controls (`scripts/ui/key_controls.gd`, `scripts/platform.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `CONTROLS`, action labels `MOVE UP` … `INTERACT (HUB)`, `SLIME RIFLE`, `SLIME SPLAT`, `SLIMAKAZE` | 11 | L | W: labels `LABEL_WIDTH` 84, key buttons `KEY_WIDTH` 64, two columns; `RESTART LEVEL` / `INTERACT (HUB)` are 76 of 84 px already |
| `RESET KEYS` (98x13), `PRESS KEY`, footer `PAD: A LEAP - X USE - START PAUSE - B BACK`, `P PAUSES` / `ESC OR P PAUSES`, `ARROWS ALWAYS MOVE - %s` (+ ` - F11 FULLSCREEN`) | 6 | L, F, C | footer lines are single lines (the pad line alone is 220 px) |
| Pad names `A X START VIEW B LB Y RB` (`Platform.PAD_NAMES`) | – | button names printed on the pad | **keep as is** (they are glyph names) |

### 8. Level select, map table, HEAT (`scripts/ui/level_select.gd`, `map_select.gd`, `map_view.gd`, `heat_panel.gd`, `scripts/heat.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `LEVEL SELECT`, two help lines (`NL` each: `CLEAR A LEVEL TO UNLOCK THE NEXT\nEACH CLEAR ALSO UNLOCKS A NEW SKIN`, `HEAT UP LEVELS BEATEN ON HARD\nHEAT 2 4 7 10 PAYS 3 5 7 10 TICKETS ONCE`), `HARD MODE: NEW MAZES, NO UPGRADES, FOG RETURNS`, `HEAT %d` | 5 | L, F, NL; **numbers written out inside the sentence** | tiles: digit 16 px font, time `clip_text` in the tile; `test_level_tiles` M-checks it |
| `MAP TABLE`, `PLAY TO FILL THEM IN`, `HARD`, `BACK`, `PAPER`, `%d%% UNCOVERED` (+ `"  HARD"`) | 6 | L, F, C | W: PAPER 44x13 |
| HEAT panel `WORKS ON LEVELS ALREADY BEATEN ON HARD`, `DONE`, `+%d`, `HEAT %d/%d` | 4 | L, F | `about.clip_text`; heat title M-measured to place the flame |
| HEAT modifier names `DIM`, `BRITTLE`, `FOG BITES`, `GROUNDED`, `THIRSTY`, `RACE` + 6 descriptions (`LESS LIGHT, PATHS FADE FASTER`, `SLIME DRAINS 8% FASTER`, `BEAT 1.3 X PAR OR DRY UP`…) | 12 | L, **numbers inside the text** | rows in the panel |

### 9. Data names (`themes.gd`, `skins.gd`, `hats.gd`, `cosmetics.gd`, `upgrades.gd`, `workshop.gd`, `abilities.gd`, `descent.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| Level / theme names `DARK DUNGEON` … `VOLCANIC VAULT` | 10 | L via `Themes.display_name`, **alliterative** | HUD area line, map table; also repeated (unused for drawing) in `tools/make_theme_art.py` |
| Skin names `LIME` … `EMBER`, `CHAMELEON`, `RAINBOW`, `STOPWATCH` | 13 | L via `Skins.display_name`; `INKKY` is a made-up spelling | skins screen, win text |
| Hat names `NO HAT`, `TOP HAT` … `CROWN`, `RAINBOW HAT` | 12 | L via `Hats.display_name` | hat wheel, wardrobe |
| Trails / papers: 9 names + 9 descriptions + 2 unlock conditions (`REACH DESCENT FLOOR 10`, `HEAT 7 ON EVERY HARD LEVEL`), `SKIN GOO`, `PARCHMENT` | 22 | L | wardrobe tiles + info line |
| Upgrades `MORE SLIME`, `SPEED`, `BRIGHTNESS`, `WALL POWER` | 4 | L | upgrade rows (name centered on the row) |
| Workshop `SECOND WIND`, `QUICK CHARGE`, `STICKY`, `MAGNET`, `GOO NOSE` + effect lines | 13 | **C**: `"REFILL AT EMPTY " + now + " -> " + next` or `+ "  MAXED"`; units `S`, `X`, `PX`, `NONE` | row width |
| Abilities `SLIME RIFLE` / `SHOOTS GOO`, `SLIME SPLAT` / `BOMB 3X3`, `SLIMAKAZE` / `WALL DASH` | 6 | L, **pun** (SLIMAKAZE) | upgrade rows, key list |
| Descent boons: 11 names + 22 two-line descriptions (`+30% SLIME` / `RIGHT NOW`…) | 33 | L, **each description already split in two fixed lines** | boon cards (descent_card) |

### 10. Story (`scripts/story.gd`, `scripts/ui/story_screen.gd`, `scripts/ui/victory.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| Per-level one-liners (`SPLAT. IT IS DAMP, UP IS THAT WAY` …) | 10 | L, **jokes** | one line under the level name; `Story.MAX_WIDTH` 296 px, M-checked in `test_story.gd` (`widest_line`) |
| Intro / ending cutscene | 0 | **wordless** (pixel sprites only) | – |
| Victory `YOU ESCAPED!`, `ALL %d MAZES CLEARED\n\nUNLOCKED: %s (ANY COLOR YOU LIKE)`, `PICK YOUR COLOR`, `RANDOMIZER`, `HUB` | 5 | F, NL | |

### 11. Skins & hats screen, hat wheel (`scripts/ui/skins_screen.gd`, `hat_wheel.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| Titles `SKINS`, `HATS`, (trails page) | 3 | **ID**: `_title.text = page.to_upper()` and the page button shows the *next page's id* in uppercase | |
| Tips `NEW LEVELS EQUIP YOUR NEWEST SKIN`, `JELLY SKINS UNLOCK ON HARD MODE`, `WIN HATS ON THE PRIZE WHEEL IN THE HUB`, `BUY TRAILS IN THE PRIZE WHEEL'S SHOP` | 4 | L | one line |
| Info line `%s - %s`, `%s - %d TIX IN THE SHOP`, `  (WEARING)`, `  (SELECTED)`, `LOCKED - EARN ALL %d MEDALS (%d/%d)`, `JELLY LOCKED - HARD CLEAR L%d`, `LOCKED - FIND EVERY COIN (%d/%d)`, `LOCKED - BEAT ALL %d LEVELS`, `LOCKED - CLEAR LEVEL %d`, `LOCKED - WIN IT ON THE HAT WHEEL`, `JELLY: ON` / `OFF` | 12 | F, **C** (name + `" - "` + status, `"  (WEARING)"` stuck on) | jelly button 80x13 |
| Hat wheel `HAT WHEEL`, tabs `WHEEL` `SHOP` `BACK` (44x13), `SPIN` / `SPIN  FREE` / `SPIN  %d` (84x13), section tabs **`id.to_upper()`** (52x13), `EVERY HAT WON! NEW LOOKS IN THE SHOP`, `YOU WON THE %s!`, `THE WHEEL IS RESTING`, `NEED %d TICKETS TO SPIN`, **`%d HAT%s TO WIN`** (+ `" - %s TO SPIN"`), `EVERY HAT IS YOURS`, `WEAR THEM IN THE WARDROBE`, `WORN` / `OWNED`, `FREE`, ` - FROM THE TAILOR`, `THE TAILOR OPENS AFTER %d SPINS (%d/%d)`, `NEED %d TICKETS`, `NO LUCK NEEDED (COUNTS AS A SPIN)`, `PRESS TO TAKE IT OFF` / `PRESS TO WEAR IT`, `PRESS TO BUY`, `BUY %s?` | 26 | F, **P**, **ID**, C | W: tabs 44 and 52 px |

### 12. Upgrades / cauldron (`scripts/ui/upgrades_screen.gd`)
| What | Strings | How | Layout |
|---|---|---|---|
| `UPGRADES`, tabs `COINS` (40x13) / `TICKETS` (52x13), `TOOLS`, `PLAY`, `MAX`, `BUY %s %d?` | 7 | L, F | W tabs |
| Help lines `COINS HIDE AT DEAD ENDS IN THE STORY MAZES\nTAKE COINS BACK OUT ANY TIME`, `KEYS %s %s %s - RANDOM MAZES`, `PAD %s %s %s - RANDOM MAZES`, `TAP THEIR BUTTONS - RANDOM MAZES`, `TICKETS FROM THE RANDOMIZER - OFF IN HARD MODE`, `EARN TICKETS IN THE RANDOMIZER FIRST` | 6 | F (key names), NL | bottom help, one line each |
| Shared ticket confirm (`UIKit.add_ticket_confirm`) `BUY`, `BACK` | 2 | L | W 48x13, label 148 px |

### 13. Descent card (`scripts/ui/descent_card.gd`; switched off, D11)
21 strings: `PICK ONE`, `CASH OUT`, `DESCEND`, `FLOOR %d CLEARED`, `%d%%  NEXT FLOOR +%d%%`,
`CASH OUT +%d`, `POT %d (+%d)%s`, `HAVE %d/%d`, `PICK A BOON FIRST`, `RUN OVER`, `NEW RUN`, `HUB`,
`CASHED OUT`, `CLEARED %d FLOORS`, `DRIED UP ON FLOOR %d`, `BEST FLOOR %d`, `   NEW BEST!`,
`TIME `, `   PAID RUN %d/%d`, `  PRACTICE (%d PAID RUNS A DAY)`, `  HALF THE POT (%d)`, and
**`"+%d %s%s" % [n, "TICKET" if n == 1 else "TICKETS", why]`** (plural + glued reason). Build:
F, C, **P**, leading spaces as separators. Layout: `CHOICE_SIZE` buttons, boon tiles with two fixed lines.

### 14. Other small ones
- `scripts/ui/rotate_hint.gd` (autoload, phones in portrait): `ROTATE YOUR DEVICE\n\nSLIME TIME IS PLAYED SIDEWAYS`. Built once in `_ready` of an **autoload** (needs a refresh when the language changes).
- `scripts/ui/ui_kit.gd`: `BACK` (40x13, all screens), `BUY`, `VOLUME`.
- `scripts/ui/goo_box.gd`, `skin_text.gd`: `*` marks only.
- `scripts/ui/transition.gd`, `menu_backdrop.gd`, `color_wheel.gd`, `skin_showcase.gd`: no text.
- Debug-only, **stay English**: everything in `scripts/autoplay/` (banner `AUTOPLAY …`, `F10 STOP`, summary, logs), `scripts/dev_log.gd`, `push_warning` / `print` texts, the HUD's DEV tags and the pause menu's DEV panel (all reachable only with `--dev` / `--autoplay`, which are debug-build flags), `SpawnPicker.KIND_NAMES` (tests only), `Progress` release-build warning.

### 15. Web shell (`tools/web_shell.html`)
8 strings, plain HTML/JS, shown **before Godot starts or after it dies** (so `tr()` can't reach them):
`Your browser does not support the canvas tag.`, `… JavaScript.`, the storage-blocked banner (2
sentences, mentions `SETTINGS > SAVE CODE`) + `OK`, the WebGL-lost cover (2 sentences) + `RELOAD`,
`Slime Time can't run in this browser. …`, `An unknown error occurred.`; also `<html lang="en">`.
Mixed case, browser font.

### 16. Tests that pin English text
- ≈126 assertions in ≈40 suites compare `.text` with English literals (`"NEW BEST!" in label.text`,
  `== "SEED 123-4"`, …). They keep passing as long as tests run in English (the default); the
  per-locale tests must not reuse them.
- Width checks with the real font: `test_ui_layout.gd` (centering, the SEED button, the Descent
  summary, upgrade rows, save code boxes, all from `get_string_size`), `test_level_tiles.gd`
  (tile number / time / name widths), `test_story.gd` (`Story.widest_line() <= MAX_WIDTH`),
  `test_phase6.gd` (space width), `test_random_tickets.gd` (area label vs pods).
  `autoplay_banner.gd` **guesses** widths with 6 px per letter, 4 per space (debug-only).

## Riskiest spots (fix while wrapping, before any translator sees them)

1. **Win text surgery** (`game.gd` ≈ line 2087-2130): the message is built line by line with
   `"\nNEW SKIN: " + name` etc. and then **cut with `text.get_slice("\n", 2)`** to swap the first two
   lines for `YOU ESCAPED ALL %d MAZES!`. Any translation with a different line count breaks it.
   Rebuild as an array of whole lines, each one its own key with placeholders.
2. **Glued sentences** (fragment + value): `"REFILL AT EMPTY " + now + " -> " + next` / `"  MAXED"`
   (workshop, 5 rows), `name + " - " + status`, `+ "  (WEARING)"`, `"%s - %s"`, the area line
   `LEVEL %d/%d` + `"  HARD"` + `"  CODE LV%d (YOU %d)"`, `"POT %d (+%d)%s"`, `"+%d %s%s"` with a
   reason, `"FLOOR %d CLEARED" + " - POT %d"`, `" - FROM THE TAILOR"`, `"SPIN  %d"`, every
   `LABEL: ` + `ON`/`OFF` toggle (11 in settings, 3 in pause). Word order and colon spacing (French
   `SON : OUI`) need whole-string keys with `{name}` / `{value}` placeholders.
3. **English plurals**: `"%d HAT%s TO WIN"` (adds `S`), `"TICKET" if n == 1 else "TICKETS"`, and many
   strings that read fine in English for any n (`%d LEFT`, `NEED %d TICKETS`, `CLEARED %d FLOORS`,
   `BEAT ALL %d LEVELS`, `+%d TICKETS`, `COINS RETURNED +%d`) but need plural forms in Russian,
   Polish, Arabic (6 forms) etc. Every string with a count goes through `tr_n`.
4. **Text from ids**: `id.to_upper()` for the hat wheel's section tabs and `page.to_upper()` for the
   skins screen title and page button. Replace with keyed names. Never call `to_upper()` on
   translated text (Turkish `i` → `İ`, German `ß`; Godot's `to_upper` is not locale-aware).
5. **Widths fixed for English**: about 70 buttons with hard-coded widths (BACK 40, tabs 44 / 52,
   quit / resume 56, `CHOICE_SIZE` 84, settings column 120, `RESET_SIZE` 92 "its text + margins",
   key list labels 84, `SLIDER_W = COL_W - 54` from "VOLUME"). Today's English already nearly fills
   several of them (measured from the font's advances: `QUIT RUN` 44/48, `STORY` 30/32, `TICKETS`
   40/44, `RESTART LEVEL` 76/84, `REPLAY MAZE` 64/76, `RESET PROGRESS` 82/84). German / Russian / French run 30-40 % longer.
6. **Spaces used for alignment**: `BEST FLOOR %d    PAID RUNS %d/%d`, `STORY %d/%d   IN HAND %d`,
   `"   BEST "`, `"  HARD"`, `"   NEW BEST!"`, `"  PRACTICE (…)"`, `%d%%  NEXT FLOOR +%d%%`,
   `SPIN  FREE`. Translators will drop or double them; better as two labels or a single key whose
   spacing is the translator's call.
7. **Hand-wrapped lines**: help texts and the reset warning are split with `\n` at English word
   boundaries; Descent boon descriptions are two separate 8-10 character strings per boon (`TANK
   +15%` / `ALL RUN`). Translations need one string per text with autowrap or a translator-chosen
   break, and boons need one string with a line break inside.
8. **Width guessed from the letter count**: `AutoplayBanner.text_width` (6 px per letter). Debug-only
   today, but must not be copied; everything else already measures with `get_string_size`.
9. **The drip shader finds the slimy font by its atlas size** (`text_drips.gdshader`: one 9 px row,
   wider than 200 px; or 18 / 400 for the big font). Extending the font must keep a one-row atlas
   (or the shader test changes); fallback fonts get no drips (they pass through), which is the right
   default but makes mixed-script lines look uneven.
10. **Line box assumptions**: the theme's Label line box is the 7 px letter body + 5 px spacing,
    pods are 14 / 23 px tall, buttons 13 px. Thai and Devanagari marks go above and below the line,
    CJK at 7 px is unreadable: those scripts need taller lines (see fonts.md), which every fixed
    13 / 14 px height must survive.
11. **Puns and wordplay**: `ESCAPE THE FOG / OR DRY TRYING`, `SLIMAKAZE`, `INKKY`, alliterative level
    names, the 10 story lines, `GOO NOSE`, `CHALICE CONSUMED!`. Need transcreation notes in the
    style guide.
12. **Numbers and units inside text**: `X1.5`, `3X3`, `%.2fS`, `%d PX`, `8%`, `1.3 X PAR`, `TIX`,
    `L%d`, `LV%d`, `#%d`; `format_time` (`1:23.45`) with tabular digits. Decide one rule: Western
    digits and `.` decimals everywhere (they are glyphs the slimy font has and the timer relies
    on), units translated through keys.
13. **Baked or out-of-engine text**: the `SLIME TIME` logo PNG (keep as the brand logo in every
    language), the web shell (outside Godot), browser `prompt()` dialogs (mixed case, browser font),
    OS key names (`OS.get_keycode_string`, stay as the OS gives them).
14. **Autoload text**: `RotateHint` and any persistent node build their text once in `_ready`; a
    language switch must refresh them (or the switch reloads the scene and rebuilds autoload text).
