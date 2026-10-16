# Fonts for localization (D15)

Advisor research, 2026-10-16. Scope: which fonts each D15 language needs, how Godot 4.7 renders them crisply at 320x180, and what they cost on web. This is research only: no code or assets were changed.

**How this was checked.** Licenses were read from each repo's README or license file, or from the itch.io page. Sizes, glyph coverage and ink heights were measured on the downloaded files with fontTools. Shaping was tested with HarfBuzz (uharfbuzz), and preview sheets were rendered 1-bit (no antialiasing), the way Godot draws with antialiasing set to None. I also inspected the installed 4.7.2 web template (`godot.wasm`) directly. Anything marked *(general knowledge)* comes from my own knowledge, not from a page I fetched.

## 0. As built (chunk D, 2026-10-17)

What shipped from this research (code: `tools/make_font.py`, `tools/i18n_subset_fonts.py`, the font section of `scripts/language.gd`, `assets/shaders/text_drips.gdshader`, test `tests/test_i18n_glyphs.gd`):

- **Slimy font extended, English untouched.** `pixel.png` / `pixel_big.png` (page 0, the 86 original glyphs) are byte-identical; the new glyphs live on a second one-row page, `pixel_ext.png` (14 px = 5 accent rows + 7 body + 2 below; `pixel_big_ext.png` 28 px). 359 codepoints per font: every Latin letter of es / pt_BR / fr / de / it / pl / tr / vi (67 Vietnamese capitals incl. stacks, Ơ Ư Đ), Ł Æ Œ ẞ, İ, 21 new Cyrillic shapes (А В Е К М Н О Р С Т Х reuse the Latin glyphs), « » „ ‚ “ ” ‘ ’ … – — № ¿ ¡ º ª · °, no-break / narrow / thin / zero-width spaces; lowercase codepoints share the capital's glyph (ı → I). Accents are composed from the base letter + mark bitmaps via NFD and drawn with `yoffset=-5`, so `lineHeight=7 / base=7` stay and no layout moves; marks draw above the line box (labels don't clip). The drip shader also recognizes the 14 / 28 px page; marks below the baseline (Ç Ą Ş, Ц Щ, Vietnamese dot below) are drawn in the body shade, which the shader keeps, and no drip grows under them. `make_font.py` keeps an unchanged PNG's old bytes (zlib builds differ between machines).
- **Fallbacks** (`assets/fonts/<script>/`, WOFF2 subsets renamed "SlimeTime ..." as the OFL asks of modified fonts; license + `SOURCE-*.txt` next to each): Fusion Pixel 10 px proportional 2026.10.16 (zh_hans for zh_CN, zh_tw for zh_TW, ja, ko; drawn at 10, titles 20 = exact 2x), Noto Sans Thai 11 (titles 16), Noto Sans Devanagari 14 (titles 18), **GNU Unifont 18.0.01 16 px for Arabic (stand-in)**. Import: antialiasing none, hinting none, subpixel off, no system fallback, oversampling 1. `Language` gives each a `fixed_size` copy (`FIXED_SIZE_SCALE_INTEGER_ONLY`), so it draws at its exact integer size whatever size the label asks for. Web weight of all seven subsets: **about 98 KB** today (CJK about 5-8 KB each with only the base set + language names; Devanagari 47 KB, Thai 14 KB, Arabic 14 KB); CJK grows by roughly 26-42 KB per locale once translated (table 4.4).
- **Only the current locale's fallback is installed.** Godot's `Font.get_height` / `get_ascent` include every fallback, so installing all of them pushed every English label down (measured: Devanagari's 19 px line). So pixel.fnt / pixel_big.fnt / the tabular copy get the current locale's script font only (none for en and the Latin / Cyrillic locales: English with the gate on renders pixel-identical too). Text in another script on the same screen (the LANGUAGE screen's names) uses `Language.native_font(code)`, a FontVariation of the slimy font with that script's fallback. `Language` keeps the fonts referenced, or a freed pixel_big.fnt would come back without its fallback.
- **Subset layout scripts** are limited to the font's own script (Unifont advertises Thai in its GSUB; Godot would then pick it for Thai marks).
- **Metrics** (`Language.metrics(code)`, measured with the real fonts and checked by the glyph test): latin (en, id) = today's UIKit numbers; accented (es pt_BR fr de it pl tr ru): +3 rows above, pitch 12, button 15; vi: +5 above, pitch 14, button 17; cjk: line 14, pitch 15, button 16, title line 28; th: line 17 / 18 / 19, title 25; hi: 19 / 20 / 21, title 25; ar: 16 / 17 / 18. Titles over 20 px (cjk, th, hi) don't fit `TITLE_Y`'s 20 px box: chunk G.
- **Turkish**: no runtime i -> İ remap. Translations are capitals (style guide), so tr.po writes İ / I; the glyph test fails on a lowercase i / ı in tr msgstr outside placeholders.
- **ICU break data**: not enabled (`include_text_server_data` stays off, about 4 MB on web); Thai / zh / ja wrapping relies on U+200B (the font has it) or `AUTOWRAP_ARBITRARY`, as 4.3 recommends.
- **Rerun** `python3 tools/i18n_subset_fonts.py` (needs `pip install fonttools brotli`) and re-import after every translation update; `--check` lists missing characters. Sources are pinned (URL + sha256) and cached in `~/.cache/slime-time-fonts`.
- **Open items**: (1) the hajimehoshi/bitmapfont Arabic glyphs' OFL grant is only a README line, no license file with the glyph author's copyright: confirm with the authors before replacing the Unifont stand-in (12 px pixel Arabic would fit far better). (2) Fusion 10/12 Hangul inherits Galmuri's Nintendo-DS provenance note (2.1). (3) Arabic joining relies on Unifont's presentation forms (kept in the subset). (4) Thai / Devanagari are outline fonts drawn 1-bit: native-reader screenshot review still to do. (5) `goo_box.gd` seeds button goo from canvas item RIDs, so adding any texture (here page 1) changes the goo lumps on buttons; text pixels are identical (checked with the RID seed neutralized in a throwaway copy).

---

## 1. Summary table

| Script / locales | Font | Size (font_size) | Ink height | Line pitch | License | Notes |
|---|---|---|---|---|---|---|
| Latin: es, pt-BR, fr, de, it, pl, tr, id | **Our SlimePixel**, extended (tools/make_font.py) | 8 (title 16) | 7 caps + 3 above + 2 below | 12 (as now). DENSE 11 collides, see 3.3 | ours | 41 new letter shapes + punctuation. Accents drawn with negative yoffset. |
| Cyrillic: ru | **Our SlimePixel**, extended | 8 / 16 | as above | 12 | ours | 21 new shapes. 12 letters reuse Latin shapes. |
| Latin: vi | **Our SlimePixel** with Vietnamese stacks | 8 / 16 | 7 + **5 above** + 2 below | **14** | ours | 67 new glyphs. Stacked marks do not fit in a 7 px cell. |
| CJK: zh-Hans, zh-Hant, ja, ko | **Fusion Pixel Font 10px proportional**, one file per language (zh_hans, zh_hant, ja, ko) | 10 | 9 (CJK), Latin caps 7 | 12 (13 is comfortable) | OFL-1.1 | Subset to the glyphs we use, about 26-45 KB WOFF2 each. Titles: Fusion 12px. |
| Thai: th | **Noto Sans Thai** (static Regular, subset), drawn 1-bit. Pixel alternative: **Unifont** 16 | 11 (or 13). Unifont 16 | about 12-13 | 15-16. Unifont: 18 | OFL-1.1 (Unifont: OFL-1.1 / GPL-2+ with font exception) | No open-licensed Thai pixel font exists at 8-12 px. Long term: draw our own (see 5). |
| Arabic: ar | **Arabic glyphs from hajimehoshi/bitmapfont** (12 px PNG sheets) converted to a TTF. Quick start: **Unifont** 16 | 12. Unifont 16 | about 12 | 15-16. Unifont: 18 | OFL-1.1 (only stated in the README, see 2.4) | Letters join through HarfBuzz's presentation-form fallback, no GSUB needed (verified). |
| Devanagari: hi | **Noto Sans Devanagari** (static Regular, subset), drawn 1-bit | 14 (12 minimum) | about 16-19 incl. matras | 20 (17 at size 12) | OFL-1.1 | No usable open pixel Devanagari font exists. Unifont breaks conjuncts and matras (verified). |

Web cost: about 250-350 KB of font data for all 17 languages, if we subset. Do **not** ship the 4 MB ICU break data; use the line-break plan in 4.3 instead.

---

## 2. Candidate fonts, script by script

### 2.1 CJK (zh-Hans, zh-Hant, ja, ko)

| Font | URL | License (verified) | Native sizes | Coverage | Format / size | Fit next to our 5x7 |
|---|---|---|---|---|---|---|
| **Fusion Pixel Font** | https://github.com/TakWolf/fusion-pixel-font (release 2026.10.16) | Font: **OFL-1.1** (`LICENSE-OFL`). Build scripts: MIT. Its README lists the upstream fonts and their licenses: Ark (OFL), Misaki (free license, OFL-compatible), MisekiBitmap (OFL), BoutiqueBitmap7x7/9x9 (OFL), Cubic 11 (OFL), Galmuri (OFL). | 8, 10, 12 px; monospaced and proportional | 8px: about 28.4k chars. All 3755+3008 GB2312 hanzi, the 5401 common Big5 chars, all 11,172 Hangul syllables, kana 94%, **no Vietnamese or Cyrillic**. 10px: about 25.9k chars. Kana and Hangul complete, Vietnamese complete, Cyrillic 60%. | TTF, OTF, WOFF2, BDF, PCF, OTB. Separate files per language. Full TTF per language: **3.7 MB at 8px, 4.1 MB at 10px**. | Measured: 8px CJK ink is **7 px**, the same as our caps, but dense hanzi (鑰, 黏) turn to mush. 10px CJK ink is **9 px**, its Latin caps are **7 px** like ours, and hanzi are clearly readable. 12px CJK ink is 11 px. |
| Ark Pixel Font | https://github.com/TakWolf/ark-pixel-font | OFL-1.1 font, MIT code | 10, 12 (16px dropped in 2026.09) | Fewer hanzi; it is the base Fusion builds on | same | Use Fusion: the same design with more glyphs. |
| Zpix | https://github.com/SolidZORO/zpix-pixel-font | **Not open.** Commercial use costs RMB 7000 per product; modifying or converting the font is forbidden. | 12 | SC, TC, JP | | **Excluded.** |
| Galmuri (Korean) | https://github.com/quiple/galmuri | OFL-1.1 | Galmuri7 (8px), 9 (10px), 11 (12px), 14 (15px) | Hangul, kana, JIS kanji, Latin | 19.9 MB release zip | **Provenance flag.** The README's "Legal Stuff" section says 2,355 Hangul syllables in Galmuri9/11/14 are not the author's own drawings; they follow the Nintendo DS font. The author argues bitmap designs are not copyrightable in the US and Korea. Galmuri7's Hangul are the author's own. Fusion takes its Korean glyphs from Galmuri, so Fusion 10/12 inherits the flag. Risk is low, but write it down. |
| Cubic 11 (zh-Hant) | https://github.com/ACh-K/Cubic-11 | OFL-1.1 (`OFL.txt`); derived from M+ gothic 12r | 11x11 (12 px) | 4808 standard Taiwan chars, 5401 Big5 level 1, Tongyong level 1 | TTF | Good look, but it is already inside Fusion 12px zh_hant. |
| BoutiqueBitmap7x7 / 9x9 (zh-Hant) | https://github.com/scott0107000/BoutiqueBitmap7x7, https://github.com/scott0107000/BoutiqueBitmap9x9 | OFL-1.1 (`OFL.txt`) | 8 px / 10 px | Traditional Chinese incl. HK | TTF | Already inside Fusion 8/10 zh_hant. |
| Misaki | https://littlelimit.net/misaki.htm | Free license (https://littlelimit.net/font.htm): commercial use, modification and redistribution all allowed, no attribution required | 8x8 (kanji 7x7, half-width 3x7 in Misaki Gothic 2) | JIS X 0208 levels 1 and 2 | TTF, BDF, PNG | Already inside Fusion 8px ja. |
| k8x12 | https://littlelimit.net/k8x12.htm | Same free license as Misaki | 8x12 | JIS levels 1 and 2 | TTF, BDF, PNG | Taller Japanese option. Not needed. |
| DotGothic16 | https://github.com/google/fonts/tree/main/ofl/dotgothic16 (source: fontworks-fonts/DotGothic16) | OFL-1.1 (METADATA.pb, OFL.txt) | 16 | ja, Latin, Cyrillic | TTF, 2.07 MB | Too large for body text at 180 px tall. Possible title font only. |

**Pick:** Fusion 10px proportional, using the language file that matches the locale. Han unification means one codepoint has different correct shapes in ja and zh, so zh_hans, zh_hant, ja and ko each need their own file. For the 16 px title slot, use Fusion 12px. The other option for titles is Fusion 8px drawn at 16 (an exact 2x), which matches pixel_big's chunky look but keeps the 7x7 detail problem.

### 2.2 Thai

No open-licensed (OFL-grade) Thai *pixel* font at 8-12 px turned up in English or Thai-language searches.

| Font | URL | License | Size | Notes |
|---|---|---|---|---|
| **Noto Sans Thai** (rendered 1-bit) | https://github.com/google/fonts/tree/main/ofl/notosansthai | OFL-1.1 | 11 / 13 | Full Thai shaping (GSUB/GPOS). After making a static Regular and subsetting to Thai + ASCII: **29 KB** TTF (17.5 KB gzip). Drawn 1-bit at 11 px it reads well (preview checked) but is not pixel-designed. Ink at 11: consonants 10 rows, with marks about 12-13. |
| **GNU Unifont** 18.0.01 | https://unifoundry.com/unifont/index.html | Dual: **GPL-2+ with font embedding exception, or OFL-1.1** (pick OFL) | 16 (8x16 / 16x16) | A true pixel font. It has a GSUB with a `thai` script, and tone marks stacked correctly in my test (เล่น, ผู้, น้ำ). Thai + Arabic + ASCII subset: **75 KB**. Very heavy at 320x180: marks reach 14 px above the baseline and the full stack is about 17 px. It **will not fit in our 13 px buttons.** |
| Plain Pixel (burpyfresh) | https://burpyfresh.itch.io/plain-pixel | **CC BY 4.0** (commercial use OK, credit required) | 11 (5x11 grid) | Thai since v0.002, Arabic since v0.007, Cyrillic. 420 KB zip. **Not verified:** the itch download would not script, so I could not inspect glyphs or shaping. Worth a manual download and look; credit "Douglas Vautour (Burpy Fresh)". |
| thaixfonts (Manop, ETL) | Debian copyright: https://metadata.ftp-master.debian.org/changelogs/main/t/thaixfonts/unstable_copyright | manop/ and etlthai/: **public domain**. poonlap/: MIT. nectec/: GPL-2+ | X11 BDF | Old TIS-620 X fonts with no OpenType mark positioning. Useful only as reference shapes for drawing our own. |
| ThaiThai (ggbot) | https://ggbot.itch.io/thaithai-font | OFL-1.1 | n/a | Not a pixel font. |
| Pixellet, ARMBOX MOON | search results | Paid | | Excluded. |

### 2.3 Arabic

| Font | URL | License | Size | Notes |
|---|---|---|---|---|
| **bitmapfont Arabic glyphs** (by @MansourSorosoro, "Eternal Dream Arabization") | https://github.com/hajimehoshi/bitmapfont (`internal/arabic/0600-06ff.png`, `fe70-feff.png`) | README: "Arabic glyphs ... (OFL-1.1)". Repo code: Apache-2.0 | 12 px design (12x12 cell; half-width 6) | Two PNG sheets, 2.7 KB + 1.8 KB, covering U+0600-06FF and every presentation form (initial, medial, final, isolated, plus lam-alef ligatures). I viewed the sheet: clean 1-px strokes, dots readable. **Not a font file:** it needs converting into a TTF. Our generator already writes pixel glyphs, so that is a small step. |
| **GNU Unifont** | see above | OFL-1.1 / GPL+FE | 16 | All Arabic and presentation-form blocks. No `arab` GSUB, but **joining still works**: with GSUB removed entirely, HarfBuzz built isolated, initial, medial and final forms and the lam-alef ligature from the presentation forms (verified). Looks thin and wide. |
| PixelAE (essssam) | https://essssam.itch.io/pixel-ae | **CC0** | 8 px design (default 10) | 42-49 KB TTF. Arabic + English. A commenter says `+ $ [ ]` are missing. Whether it has contextual forms is **not verified** (download failed). |
| Arabixel Basic | https://arabiandev.itch.io/arabixel-basic-font | CC BY 4.0 | 11 | Not inspected. |
| Arabic Pixel Font - A | https://alexclay.itch.io/arabic-pixel-font-a | Not stated | | Excluded until its license is known. |

### 2.4 Devanagari (Hindi)

| Font | URL | License | Size | Notes |
|---|---|---|---|---|
| **Noto Sans Devanagari** (rendered 1-bit) | https://github.com/google/fonts/tree/main/ofl/notosansdevanagari | OFL-1.1 | 14 (12 minimum) | Full Indic shaping: conjuncts (क्ष, त्र), reph, the ि matra placed before its consonant. Static Regular subset to the Devanagari block + ASCII: **168 KB** TTF (66 KB gzip). A text-based subset will be smaller. Preview: 14 px reads clearly; 12 px works but is cramped. Ink at 14: about -6 to +13. |
| GNU Unifont | | | 16 | **Do not use.** It has no Devanagari GSUB, so ि stays after its consonant, conjuncts show as halant chains and the headline breaks (verified). Unifoundry itself calls it a last-resort font for complex scripts. |
| Seven Fifteen (burpyfresh) | https://burpyfresh.itch.io/seven-fifteen-font | CC BY 4.0 | 7x15 | The page lists Hindi plus Arabic, Thai and CJK, "prototype" v0.013. Not verified. Worth a manual look. |
| Silver (Poppy Works) | https://poppyworks.itch.io/silver | CC BY 4.0, **plus** a rule that projects above US$100k spend or earnings must contact the author | | Has Devanagari and Thai updates. The revenue rule makes it **not equally permissive**. Excluded. |
| Shobhika, Hind, Tiro | ctan.org/pkg/shobhika, fontsquirrel/hind | OFL | | Outline fonts. Noto is the safer default for 1-bit rendering. |

A note on the bitmapfont Arabic license: the OFL grant appears only as a line in that repo's README; there is no separate OFL file carrying the glyph author's copyright. Before shipping, ask hajimehoshi or @MansourSorosoro to confirm, and keep the README line with our credits.

---

## 3. Extending our own font (Latin, Cyrillic, Vietnamese)

### 3.1 Exact glyphs to add (uppercase shapes; lowercase codepoints map to the same shape, as today)

- **Spanish:** Á É Í Ó Ú Ü Ñ ¿ ¡ º ª (« » optional)
- **Portuguese (BR):** Á Â Ã À Ç É Ê Í Ó Ô Õ Ú º ª
- **French:** À Â Æ Ç É È Ê Ë Î Ï Ô Œ Ù Û Ü Ÿ « » ’ (plus U+202F narrow no-break space before ! ? : ;)
- **German:** Ä Ö Ü **ẞ (U+1E9E)**, with lowercase ß mapped to it, since everything shows as capitals. Also „ “
- **Italian:** À È É Ì Ò Ù (Í Ó Ú Î are rare) ’
- **Polish:** Ą Ć Ę Ł Ń Ó Ś Ź Ż „ ”
- **Turkish:** Ç Ğ İ Ö Ş Ü (Â Î Û occasionally). See the Turkish i trap below.
- **Indonesian:** nothing new.
- **Russian:** 33 letters. **12 reuse existing shapes:** А В Е К М Н О Р С Т Х, plus Ё reusing Ë. **21 new shapes:** Б Г Д Ж З И Й Л П У Ф Ц Ч Ш Щ Ъ Ы Ь Э Ю Я. Plus « » „ “ № —
- **Vietnamese:** 67 uppercase letters (134 codepoints including lowercase): ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂĐĨŨƠƯẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸ
- **Shared punctuation:** … – — ’ “ ” „ « » ¿ ¡ º ª №, plus no-break spaces.

Totals: 41 new accented Latin shapes outside Vietnamese, 93 with it, plus 21 Cyrillic shapes and about 12 punctuation marks. The generator can build most accents as overlays: a mark bitmap placed on top of a base letter.

### 3.2 Headroom: measured against a professional font with 7 px caps

Fusion 10px has 7 px Latin caps, the same as ours, so I measured its accented letters:
- Single accent above (Á Â Ă É Й): ink top at **+3** above the caps (1 gap row + 2 mark rows).
- Vietnamese stacks (Ấ Ẫ Ẵ Ễ): ink top at **+5**. The stack overflows Fusion's own ascent by 1 px.
- Below the baseline: Ą Д Ặ Ự reach **-2**, Ç reaches **-3**.

**Do stacked Vietnamese marks fit in 7 px? No.** Even with the Vietnamese convention of putting acute, grave or hook to the right of the circumflex (which keeps Ấ Ầ Ẩ at 3 rows), tilde over circumflex (Ẫ Ễ Ỗ) and any mark over a breve (Ằ Ắ Ẳ Ẵ) need **5 rows above the caps**. Plan for **5 px above and 2 px below** for vi. Horned letters (Ơ Ư) also need 6 px width.

### 3.3 How the extra rows fit our layout

- `LINE_PITCH 12` = 7 body + 2 drips + **3 free rows**. European accents (+3) fit exactly, but they touch the drips of the line above. Acceptable.
- `DENSE_PITCH 11` leaves only 2 free rows, so accents overlap the drips above. Use 12 for accented locales, or draw single accents as gap + 1 mark row (diaeresis, dot and macron work at 1 row; acute and grave at 1 row look like dashes).
- Vietnamese needs a **pitch of 14 or more** and 5 clear rows above single-line labels.
- Draw accents with a **negative yoffset** in the BMFont, so `lineHeight=7 / base=7` stays the same and no existing layout moves. Labels do not clip, so marks drawn above the line box show. *(Godot BMFont handling of negative yoffset: general knowledge, so test it.)*
- 13 px buttons: the caps sit 3 px from the top, so +3 accents reach the border row. Check the button frame first.
- **Titles (pixel_big, 2x):** accents double to 6 rows, but `TITLE_Y = 2` leaves only about 4 px above the caps. Either drop titles 2-4 px in accented locales, or give the big font 1x-detail accents (3-4 rows).
- Below-baseline marks (Ç Ą Ę Ş, Д Ц Щ, Vietnamese dot below) land in the 2 drip rows. Have the generator skip drips under those columns.

### 3.4 Traps

- **Precomposed only.** A BMFont cannot place combining marks, so every translation must be **NFC-normalized** in the import pipeline. Vietnamese text often arrives decomposed. *(general knowledge)*
- **The Turkish i.** Our font maps lowercase `i` to the `I` shape. In Turkish, uppercase i is **İ**, so lowercase Turkish text would render with the wrong letter. Either require uppercase source strings with İ for tr, or generate a tr variant of the font that maps i→İ and ı→I. Godot's `String.to_upper()` ignores locale *(general knowledge)*. It is called in skins_screen.gd:158-159, hat_wheel.gd:160 and autoplay.gd:217; check that none of those touch translated Turkish text.
- German ß shown in capitals: map it to ẞ, or have translators write SS.

---

## 4. Godot 4.7 specifics

### 4.1 Crisp pixel TTFs

From the Godot docs (gui_using_fonts, class_fontfile), plus our project settings:
- Use Nearest filtering. We already set `default_texture_filter=0`.
- Set **Subpixel positioning: Disabled**. The docs say this explicitly for pixel-art fonts.
- **Font size must be an integer multiple of the design size.** Fusion 10px needs font_size 10 (or 20); Unifont needs 16.
- Per-font import settings: **Antialiasing: None** (1-bit, the same as my previews), **Hinting: None**, **Generate Mipmaps: off**, **MSDF: off** (MSDF always antialiases and cannot hint). `fixed_size` and `fixed_size_scale_mode` apply only to bitmap fonts (BMFont or bitmap-strike files), so leave them at 0 for outline TTFs.
- Our project sets `gui/theme/default_font_hinting=2` (Normal). That applies to the project default font. Set Hinting None on each imported pixel TTF so the autohinter cannot move pixel-grid outlines.
- Oversampling: we use `stretch/mode="viewport"`, so the canvas is drawn at 320x180 and then scaled up. Text is rasterized at 1x and oversampling never applies *(general knowledge)*. `FontFile.oversampling` can force 1.0 if needed.
- Formats: Godot imports TTF, OTF, **WOFF2** and BMFont (class_fontfile), so we can ship WOFF2 subsets.

### 4.2 Fallbacks and Theme / FontVariation

- `Font.fallbacks` is defined on the base Font class, so FontFile and FontVariation both have it. From class_font: "If this array is empty in a FontVariation, the FontVariation.base_font's fallbacks are used instead." So a FontVariation in the Theme carries fallbacks.
- `allow_system_fallback` is on by default. **Turn it off on every font.** Desktop would quietly substitute system fonts, while web has no system fonts (the docs say system fonts work only on Windows, macOS, Linux, Android and iOS). Missing glyphs should show up in testing, not as random OS fonts on some platforms.
- Recommended setup: one Theme font per locale family, swapped when the locale changes (UIKit already builds the theme in code).
  - CJK: FontVariation(base = Fusion 10px for that language), with fallback = SlimePixel. Or the reverse, with SlimePixel primary so digits and Latin keep the goo look; the fallback then supplies CJK. Han variant choice needs a per-language file in either case, or `FontFile` language-support overrides *(general knowledge)*.
  - Mixing fonts on one line: the line takes the tallest ascent and descent of the fonts it uses *(general knowledge)*, so expect +2-4 px when CJK sits on a SlimePixel line.

### 4.3 Is shaping and BiDi in the web export?

**Yes for shaping and BiDi; no for dictionary line breaking unless we ship data.**
- In the installed 4.7.2 `web_nothreads_release.zip`, `godot.wasm` contains `TextServerAdvanced` (9 hits), Graphite symbols, and the string `res://icudt_godot.dat` / "ICU break iteration data". It contains **no `TextServerFallback`**. So HarfBuzz shaping and ICU BiDi are compiled into the web template.
- The `text_server_adv` SCsub builds HarfBuzz with ICU for `["android", "linuxbsd", "web"]`, and TextServerAdvanced is "Godot's default primary TextServer interface" (class_textserveradvanced).
- **Break-iterator data is not exported by default.** It is about 4 MB, enabled with Project Settings > Internationalization > Locale > *Include Text Server Data* (internationalizing_games docs; CTL progress report 3).
- What happens without it, from the Godot source (`text_server_adv.cpp`, `_shaped_text_update_breaks`): "No data loaded - use fallback". Line breaks then happen only at whitespace characters (`is_whitespace` in `char_utils.h`), which **includes U+200B (zero-width space)**.
- Consequences and plan:
  - **Thai** has no spaces, so it will not wrap. Insert **U+200B** between words when importing translations (offline segmentation, e.g. PyThaiNLP *(general knowledge)*), or have the translator do it. The CTL progress report recommends zero-width spaces as the alternative to ICU data.
  - **zh / ja** will not wrap either. Either set `autowrap_mode = AUTOWRAP_ARBITRARY` for those locales (CJK may break between almost any characters) *(general knowledge)*, or insert U+200B between CJK characters at import, skipping positions before closing punctuation (basic kinsoku).
  - **ko, ar, hi** use spaces, so normal word wrap works.
  - Watch: U+00A0 (no-break space) also counts as whitespace in the fallback, so it **will** break. This matters for French « » spacing.
- Arabic RTL: BiDi and mirroring work, but Godot mirrors only anchors, containers and alignment, not manual positions (internationalizing_games). UIKit places many labels with explicit `Rect2`s, so RTL layout needs its own pass. That is a layout task, not a font task.

### 4.4 Subsetting (fonttools pyftsubset)

Command shape:
```
pyftsubset <font>.ttf --text-file=<all strings for that locale>.txt \
  --layout-features='*' --no-hinting --flavor=woff2 --output-file=<out>.woff2
```
For variable Noto files, first run `fonttools varLib.instancer <font> wght=400 wdth=100`. Always add ASCII digits and punctuation and the CJK punctuation block, and re-run whenever translations change. Add a test that fails if any translated character is missing from its font.

Measured sizes (Fusion, base set = ASCII + U+3000-30FF + U+FF00-FFEF):

| Subset | 8px TTF | 8px WOFF2 | 10px TTF | 10px WOFF2 | 10px TTF gzip |
|---|---|---|---|---|---|
| + 500 hanzi | 103 KB | 20 KB | 129 KB | **26 KB** | about 29 KB (8px) |
| + 1000 hanzi | 167 KB | 31 KB | 211 KB | **42 KB** | about 45 KB (8px) |
| + 3755 hanzi (all GB2312 level 1) | 512 KB | 87 KB | 656 KB | 122 KB | |
| + 600 Hangul | 101 KB | 14 KB | 121 KB | **16 KB** | |
| all 11,172 Hangul | 1.26 MB | 110 KB | 1.59 MB | 123 KB | |
| Full file (per language) | 3.7 MB | | 4.1 MB | | |

Other subsets: Noto Thai **29 KB**, Noto Devanagari **168 KB** (block subset; 66 KB gzip), Unifont Thai+Arabic **75 KB**. A game UI like ours probably needs 500-1000 distinct hanzi per Chinese locale, so all 17 languages come to roughly **250-350 KB**. Pixel fonts are made of many small squares, so WOFF2 is about 5x smaller than TTF.

---

## 5. Per-script size, line height and risks at 320x180

| Script | font_size | Ink (measured) | Pitch | Main risks |
|---|---|---|---|---|
| Latin / Cyrillic | 8 | 7 + 3 / 2 | 12 | Accents touch the drips above; DENSE 11 collides; titles lack headroom; Turkish i. |
| Vietnamese | 8 | 7 + 5 / 2 | 14 | Stacked marks; horn width; dot below vs drips. |
| CJK | 10 | 9 (from -1 to +8) | 12-13 | Han variants (wrong file means wrong glyph shapes); wrapping without ICU; 8px is illegible for dense hanzi; full-width punctuation. Strings get *shorter* in width, so overflow is rare. |
| Thai | 11 (Noto) / 16 (Unifont) | about 13 / 17 | 15-16 / 18 | No pixel font; **stacked upper vowel + tone mark** (ที่, ผู้) needs mark positioning, which a plain BMFont cannot do; confusable pairs at small sizes (ด/ต, บ/ป, ภ/ถ, ข/ฃ) need distinct pixels; no spaces, so wrapping depends on U+200B; 13 px buttons are too short. |
| Arabic | 12 | about 12 | 15-16 | 1-px dots separate ب ت ث ن ي, so never scale by a non-integer; RTL layout pass for manual positions; Western vs Eastern digits (decide once); joining depends on HarfBuzz fallback (verified) or a GSUB we write. |
| Devanagari | 14 (12 minimum) | about 19 (matras above and below) | 20 (17) | Needs a real OpenType font (conjuncts, reph, ि reordering), so no hand-drawn BMFont is realistic; tallest script by far; headline (shirorekha) gaps at 12 px; not pixel-art styled. |

**Feel risk:** the goo drips and shading are part of SlimePixel only. Every non-Latin locale loses the slime lettering. A cheap partial fix is to keep SlimePixel for digits and Latin (HUD timer, counters) and use the script font for words only.

---

## 6. Ranked recommendations (impact vs effort)

1. **High impact, low effort:** CJK through Fusion 10px, one file per language, WOFF2 subsets built by a `tools/subset_fonts.py` that reads the translation files. Turn off system fallback. Use AUTOWRAP_ARBITRARY or U+200B for zh/ja.
2. **High impact, medium effort:** extend make_font.py with the 41+21 Latin/Cyrillic shapes via accent overlays and negative yoffset, plus NFC normalization and a Turkish variant. This keeps the slime look for 9 languages.
3. **Medium impact, medium effort:** add Vietnamese (67 glyphs) with a 14 px pitch for vi only.
4. **Medium impact, low-medium effort:** Arabic. Convert the bitmapfont 12 px sheets to a TTF with our generator; HarfBuzz joins the letters. Unifont 16 is the stopgap. Confirm the glyph license with the author first.
5. **Medium impact, low effort, weaker look:** Thai via Noto Sans Thai 11 drawn 1-bit, with U+200B inserted at import. Later, if Thai matters, draw a custom pixel Thai font (about 70 glyphs plus a small GSUB/GPOS for tone stacking). Our generator would need to output TTF instead of BMFont (fontTools can do it).
6. **Lower impact per effort:** Hindi via Noto Sans Devanagari 14. Accept the non-pixel look and the 20 px pitch. Do it last and get a native reader to review screenshots.
7. **Avoid:** Zpix (proprietary), Silver (revenue rule), Unifont for Devanagari (broken), and shipping `icudt_godot.dat` (about 4 MB) on web.

---

## Sources

Fonts:
- Fusion Pixel Font: https://github.com/TakWolf/fusion-pixel-font (README, LICENSE-OFL, docs/info-8px-proportional.md, docs/info-10px-proportional.md, release 2026.10.16)
- Ark Pixel Font: https://github.com/TakWolf/ark-pixel-font
- Zpix: https://github.com/SolidZORO/zpix-pixel-font (README "License and Pricing")
- Galmuri: https://github.com/quiple/galmuri (README "Legal Stuff", OFL.md)
- Cubic 11: https://github.com/ACh-K/Cubic-11
- BoutiqueBitmap7x7: https://github.com/scott0107000/BoutiqueBitmap7x7
- BoutiqueBitmap9x9: https://github.com/scott0107000/BoutiqueBitmap9x9
- Misaki: https://littlelimit.net/misaki.htm
- k8x12: https://littlelimit.net/k8x12.htm
- Misaki / k8x12 license: https://littlelimit.net/font.htm
- DotGothic16: https://github.com/google/fonts/tree/main/ofl/dotgothic16
- Unifont: https://unifoundry.com/unifont/index.html
- bitmapfont (Arabic glyphs): https://github.com/hajimehoshi/bitmapfont
- PixelAE: https://essssam.itch.io/pixel-ae
- Plain Pixel: https://burpyfresh.itch.io/plain-pixel
- Seven Fifteen: https://burpyfresh.itch.io/seven-fifteen-font
- Silver: https://poppyworks.itch.io/silver and https://poppyworks.itch.io/silver/devlog/502886/devanagari-update
- ThaiThai: https://ggbot.itch.io/thaithai-font
- Arabixel Basic: https://arabiandev.itch.io/arabixel-basic-font
- Arabic Pixel Font - A: https://alexclay.itch.io/arabic-pixel-font-a
- thaixfonts copyright: https://metadata.ftp-master.debian.org/changelogs/main/t/thaixfonts/unstable_copyright
- Noto Sans Thai: https://github.com/google/fonts/tree/main/ofl/notosansthai
- Noto Sans Devanagari: https://github.com/google/fonts/tree/main/ofl/notosansdevanagari

Godot docs:
- https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html
- https://docs.godotengine.org/en/stable/classes/class_fontfile.html
- https://docs.godotengine.org/en/stable/classes/class_font.html
- https://docs.godotengine.org/en/stable/classes/class_fontvariation.html
- https://docs.godotengine.org/en/stable/classes/class_textserveradvanced.html
- https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
- https://godotengine.org/article/complex-text-layouts-progress-report-3

Godot source:
- https://github.com/godotengine/godot/blob/master/modules/text_server_adv/text_server_adv.cpp
- https://github.com/godotengine/godot/blob/master/modules/text_server_adv/SCsub
- https://github.com/godotengine/godot/blob/master/core/string/char_utils.h

Local evidence:
- Installed template `~/Library/Application Support/Godot/export_templates/4.7.2.stable/web_nothreads_release.zip`
- fontTools / uharfbuzz measurements in a scratch directory (nothing written to the repo apart from this file)
