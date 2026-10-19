# Slime Time translation style guide

For the `localizer` agents (chunk H) and any human reviewer. Read with [plan.md](plan.md) (how the
pipeline works) and [fonts.md](fonts.md) (which glyphs exist). Each locale also keeps its own
glossary in `docs/i18n/glossary/<code>.md` (terms chosen once, reused everywhere).

## 1. The files and the workflow

- You edit **only** `locale/<code>.po`: the `msgstr` lines (and `# ` translator comments if useful).
  Never edit `msgctxt`, `msgid`, `msgid_plural`, the `#.` / `#:` lines or the header; never edit
  `locale/messages.pot` (it is generated).
- `msgctxt` is the key: where the text is shown (`hub.portal.random_maze`, `skin.lime`,
  `result.escaped_all`). The same English can appear under two keys and may need two different
  translations (BACK the button vs. a word in a sentence). Translate each key on its own.
- `#.` lines are notes from the code: the screen, what each placeholder is, puns, and a normalized
  **budget** line: `#. budget: max 76px, lines 1`. Respect it (section 7).
- After code changes: `python3 tools/i18n_extract.py --merge` (keeps every translation; an English
  text that changed keeps its old translation marked `#, fuzzy` with the old English in `#| msgid`;
  re-check it, fix it, delete the `#, fuzzy` line). The game ignores fuzzy entries and shows English.
- Before handing in: `python3 tools/i18n_extract.py --check --partial` (0 errors for your locale)
  and `./tools/test_all.sh test_i18n_catalog` (then chunk F's fit / glyph suites). When a locale is
  finished, add its code to `COMPLETE_LOCALES` in `tests/test_i18n_catalog.gd`.
- An empty `msgstr` shows the English text: better English than a wrong guess.

## 2. Tone

Slime Time is a short, dark, silly game about a slime escaping a dungeon before it dries up. The
voice is **dark, funny and short**: deadpan one-liners (`SPLAT. IT IS DAMP, UP IS THAT WAY`),
mild gallows humour about drying out, never cruel, never crude. Kids may play it.

- **Short beats exact.** Every label has a pixel budget. A shorter word that keeps the joke wins over
  a faithful sentence that does not fit.
- **Transcreate puns**, don't translate them literally. If the language has a pun on the same idea,
  use it; if not, keep the meaning and the rhythm and lose the pun. Known puns and wordplay:
  `ESCAPE THE FOG / OR DRY TRYING` (dry / die), `SLIMAKAZE` (kamikaze), `INKKY` (inky + a made-up
  spelling), the alliterative level names (`MOSSY MINES`, `SANDSTONE SANCTUM`: alliteration is welcome
  but optional), `GOO NOSE`, `CHALICE CONSUMED!`, the ten story one-liners.
- Address the player informally where the language has the choice (`tú` not `usted`, `du` not `Sie`,
  `tu` not `vous`, `ты` is too familiar for a UI: use the imperative without a pronoun where you can;
  Polish 2nd person singular; Japanese plain / casual UI style, no keigo; Korean 해요체 is fine for
  sentences, nouns for buttons; Chinese plain, no 您).
- Buttons are verbs or nouns, not sentences (`RESTART`, `NEW MAZE`). Keep the game's terms identical
  everywhere: write them in your glossary first (slime, goo, chalice, ticket / TIX, coin, maze, heat,
  hard mode, upgrade, hub, randomizer, descent, floor, pot, skin, hat, trail, paper, wheel, tailor).

## 3. Names: translate or keep

Owner decision (plan.md section 11): **translate descriptive names, keep coined proper names**.

| Keep as is (Latin letters) | Translate |
|---|---|
| `SLIME TIME` (the game; also baked into the title logo) | Level / theme names: `DARK DUNGEON` … `VOLCANIC VAULT` |
| `INKKY` (skin) | Skin colours: `LIME`, `MINT`, `LEMON`, `OCEAN`, `GRAPE`, `CRIMSON`, `FROST`, `BUBBLEGUM`, `EMBER`, `RAINBOW`, `STOPWATCH` |
| `CHAMELEON` (skin) | Hats: `NO HAT`, `TOP HAT`, `BEANIE`, `BASEBALL CAP`, … `CROWN`, `RAINBOW HAT` |
| `SLIMAKAZE` (ability) | Abilities `SLIME RIFLE`, `SLIME SPLAT` and every ability description |
| Pad button names `A B X Y LB RB START VIEW`, key names from the keyboard (`SPACE`, `CMD+V`) | Upgrades (`MORE SLIME`, `SPEED`, `BRIGHTNESS`, `WALL POWER`), workshop tools, trails, papers, boons, heat modifiers |
| Seeds, save codes, numbers | Everything else |

- `SLIME TIME` stays in Latin letters in every language (it is the logo).
- **Other kept names in scripts without Latin letters** (ru, ja, ko, zh_CN, zh_TW, th, ar, hi):
  transliterate `INKKY`, `CHAMELEON` and `SLIMAKAZE` into the script by sound (e.g. `ИНККИ`,
  `インキー`, `카멜레온`), once, and record the spelling in the glossary. Latin-script locales keep them
  letter for letter. Never glue a case ending onto a kept Latin name; rephrase instead (`SKIN INKKY`).
- `CHAMELEON` is kept because it is the skin's brand (the colour-picker skin), even though it is a
  real word.

## 4. Casing: ALL CAPS

The whole game is written in capitals; the slimy font only draws capitals (lowercase maps to the same
glyphs, but the checks require capitals so the text stays uniform).

- **Cased scripts** (es, pt_BR, fr, de, it, ru, pl, tr, vi, id): write every msgstr in capitals,
  accents included (`É`, `Ñ`, `Ç`, `Ą`, `Ł`, `Ё`, `Ơ`). Never drop accents on capitals (French and
  Spanish keep them: `ÉTÉ`, `ÁRBOL`). `--check` fails on any lowercase letter, unless the entry's notes
  say `mixed case` (browser dialogs, the web shell).
- **German**: `ß` has no place in caps: write `SS` (`STRASSE`, `GROSS`). `ẞ` exists in the font but
  use `SS`, it is the common caps spelling.
- **Turkish**: dotted and dotless i are different letters: `i → İ` (U+0130), `ı → I`. `LABİRENT`,
  `SEVİYE`, `KILIÇ`. Never write a lowercase `i` / `ı` inside a capital word, never use a combining
  dot (U+0307). Type `İ` directly; the code never calls `to_upper()` on translations.
- **Scripts without case** (ja, ko, zh_CN, zh_TW, th, ar, hi): write normally. Latin words inside
  them (kept names, units, `HUB`) stay in capitals.

## 5. Characters, spacing and punctuation

- **NFC**: precomposed letters only (`é` is U+00E9, not `e` + U+0301). Vietnamese especially: one
  code point per letter with its marks (`Ế`, `Ộ`). `--check` fails on non-NFC text.
- **Spaces used as layout** in the English (`BEST FLOOR {best}    PAID RUNS {paid}/{total}`,
  `SPIN  FREE`, `LEVEL {level}/{total}  HARD`): the notes say so; keep a similar gap (2-4 spaces), it
  separates two values. Do not add leading / trailing spaces the English does not have.
- **Line breaks** (`\n` in the English): one line per `\n`. You may move the break or drop it if the
  budget allows (`lines N` is the maximum), never add more lines than `lines N`.
- **French**: a narrow no-break space (U+202F, 2 px in the font) before `! ? : ;` and inside `« »`:
  `SON : OUI` (type the real U+202F character, not an escape). Typographic
  apostrophe `’` or straight `'` (pick one per locale, glossary).
- **Spanish**: opening `¡` and `¿` (`¡NUEVO RÉCORD!`).
- **German**: quotes `„…“`; Polish `„…”`; Russian `«…»`; Turkish, Italian, Portuguese `“…”` or `«…»`
  (glossary).
- **CJK** (ja, zh_CN, zh_TW): **no spaces between words**; full-width punctuation `、。！？：` for
  sentences, but keep `{placeholders}`, numbers and Latin units half-width. A space between two values
  that the English separates with spaces may stay (it is layout). Korean uses spaces between words as
  usual.
- **Thai**: no spaces between words, so the text cannot wrap. Put a **zero-width space (U+200B)**
  between words (or at least at every place a line may break) in any string longer than a few words
  (fonts.md, line breaking); it is invisible and 0 px wide. A normal space in Thai marks a phrase or
  sentence break, as usual.
- **Arabic**: write it in logical order exactly as you would type it; never reverse letters or words
  by hand, the text server shapes and orders it (right to left). Arabic comma `،` and question mark
  `؟`. Keep numbers as Western digits (`0-9`, `.`), like every locale (plan.md section 2).
- **Hindi**: Devanagari as typed; `।` for a full stop is fine but rare in UI labels; numbers stay
  Western digits.
- **Lists**: the separator between names is its own key (`common.list_sep`, `result.list_sep`…):
  `, ` in most languages, `、` in ja / zh, `، ` in Arabic.

## 6. Placeholders, numbers, plurals, units

- `{name}` placeholders are filled by the game. Keep **every** placeholder of the English, spelled
  exactly (`{count}`, `{level}`, `{total}`), move them anywhere in the sentence, never translate them,
  never add new ones. `%d` / `%s` never appear.
- Numbers are always Western digits with `.` decimals (`1.5`, `0:42.10`); the timer uses tabular
  digits and needs them.
- **Plurals**: entries with `msgid_plural` have one `msgstr[k]` per plural form of your language
  (header `Plural-Forms`): es / pt_BR / fr / de / it / tr / hi 2, ru / pl 3, ar 6, ja / ko / zh / th /
  vi / id 1. Fill every form, even if English uses the same text for both (`POT {count}`). A form
  that only ever covers one number (Arabic forms 0 / 1 / 2: zero, one, two) may write the word
  instead of `{count}`; every other form must keep `{count}`.
  Russian: 0 = 1, 21, 31…; 1 = 2-4, 22-24…; 2 = 0, 5-20, 25…  Polish: 0 = 1 only; 1 = 2-4, 22-24…;
  2 = the rest. Arabic: 0 = 0, 1 = 1, 2 = 2, 3 = 3-10, 4 = 11-99, 5 = 100-102…
- **Units are text**: `S` (seconds), `PX`, `X` (multiplier, `X1.5`), `TIX` (tickets, short), `L` / `LV`
  (level), `#` (number). Translate or keep them per locale (glossary) and use the same one
  everywhere: `+15%` stays a symbol; `3X3` may become `3×3` only if the font draws `×` (check
  `test_i18n_glyphs`). Abbreviate only where English abbreviates.

## 7. Width budgets

Screens are 320 x 180 pixels. Each string's room is measured in pixels of the real font, never
counted in letters:

- The slimy font (Latin, Cyrillic, Vietnamese) is 8 px tall; most capitals are 6 px wide with
  spacing, but `I`, `1`, punctuation and spaces are narrower (2-4 px) and `Ш Щ Ơ Ư №` wider (7-9 px).
  CJK, Thai, Arabic and Devanagari come from fallback fonts with their own widths (CJK glyphs are
  full squares, usually ~10-12 px each: a CJK string is often fewer glyphs but not fewer pixels).
- `#. budget: max Npx` = the widest the text may be. `lines N` = the most lines. No budget = still
  keep it about as long as the English.
- `test_i18n_fit.gd` (chunk F) measures every msgstr with the real font chain, placeholders filled with
  wide values (`{count}` = 888), and lists overflows. Fix overflows by rewording or abbreviating
  (glossary), then by moving a line break if `lines` allows. If nothing fits, leave a translator
  comment `# overflow: …` and tell the i18n engineer; the layout gets fixed (chunk G), text is never
  cut.
- Tight spots today (English already fills them): buttons `CHOICE_SIZE` 76 px inside, tabs 44 / 52,
  BACK 40, quit / resume 56, key list labels 84, settings column 120, reward / status lines ≈ 296.

## 8. Per locale

| Code | Notes |
|---|---|
| `es` | **Latin-American neutral Spanish**, one Spanish for every country: `tú`, no `vosotros`, no Spain-only words (`computadora`, not `ordenador`; avoid `coger`), no voseo, no country slang. `¡ ¿`. |
| `pt_BR` | Brazilian Portuguese, `você` implied; Brazilian vocabulary (`tela`, `celular`). |
| `fr` | Narrow no-break space before `! ? : ;` (section 5). Informal `tu`. |
| `de` | `SS` for ß in caps; compounds get long: prefer shorter synonyms over hyphen-splitting. Informal `du`. |
| `it` | Informal `tu`; accented capitals `À È É Ì Ò Ù`. |
| `ru` | Cyrillic caps (`Ё` where needed, `Е` acceptable if consistent: glossary). 3 plural forms. Long words: abbreviate with a period only where usual (`УР.` for level). |
| `pl` | 3 plural forms; `Ą Ć Ę Ł Ń Ó Ś Ź Ż`. Informal 2nd person. |
| `tr` | `İ / I` (section 4). Nouns after numbers stay singular (`3 BİLET`), but fill both plural forms. |
| `ja` | Katakana for kept names; no spaces; full-width punctuation; casual UI style. |
| `ko` | Spaces between words; nouns on buttons. |
| `zh_CN` | Simplified characters, mainland vocabulary; no spaces. |
| `zh_TW` | Traditional characters, Taiwan vocabulary (`遊戲`, `設定`), not just converted from zh_CN. |
| `th` | U+200B between words (section 5); no `ฯลฯ` abbreviations in labels. |
| `vi` | Stacked accents in caps (`Ấ Ầ Ẩ Ẫ Ậ`, `Ơ Ư`); NFC. Lines get taller, not wider. |
| `id` | Bahasa Indonesia, informal (`kamu` implied), no Malay-only words. |
| `ar` | Modern Standard Arabic; RTL handled by the engine (never reverse); Western digits; `،` `؟`; 6 plural forms. The whole layout is mirrored (chunk I). |
| `hi` | Standard Hindi in Devanagari, not Hinglish in Latin letters; common English loanwords in Devanagari are fine where they are what players say (`स्किन`, `लेवल`). |

## 9. Checklist before handing in

1. Every msgstr in capitals (cased scripts), NFC, Turkish `İ` correct.
2. Every placeholder kept; every plural form filled.
3. Within `max Npx` / `lines N` (run the fit test when it exists).
4. Kept names kept (`SLIME TIME`, `INKKY`, `CHAMELEON`, `SLIMAKAZE`), descriptive names translated,
   glossary updated.
5. `python3 tools/i18n_extract.py --check --partial`: no error in your file; no `#, fuzzy` left.
6. `./tools/test_all.sh test_i18n_catalog` passes; add your code to `COMPLETE_LOCALES` when done.
