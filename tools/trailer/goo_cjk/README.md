# Goo Chinese glyphs (goo_cjk)

Simplified Chinese glyphs for the trailer's goo lettering (`tools/trailer/goo_text.py` loads `goo_cjk.json`;
`python3 tools/trailer/trailer.py --lang zh` renders the Shorts with the Chinese captions of
`tools/trailer/captions_zh.json`), covering every Chinese character in `docs/marketing/posts-4-weeks.md` and
`docs/marketing/steam-page.md` (276 glyphs incl. full-width punctuation). Marketing only: the game itself
does not use it (a `.gdignore` keeps Godot out of this folder).

## Files

| File | What |
|---|---|
| `goo_cjk.fnt` + `goo_cjk.png` | BMFont (text), 12x12 cell, 1-pixel strokes like the 5x7 Latin goo letters |
| `goo_cjk_big.fnt` + `goo_cjk_big.png` | the same at 2x, to pair with `pixel_big.fnt` |
| `goo_cjk.json` | `{glyphs: {char: [12 rows of '#'/'.']}}` for `tools/trailer/goo_text.py` |
| `chars.txt` | the covered characters |
| `goo_cjk_preview.png` | every Chinese on-screen line drawn in goo style (drips approximated) |
| `make_goo_cjk.py` | regenerates everything above from the marketing files |
| `preview_goo_cjk.py` | regenerates the preview sheet |
| `licenses/` | the source font's licences (OFL 1.1); the unmodified Fusion Pixel 12px monospaced zh_hans WOFF2 files (`source/`, ~1 MB) are in the project's shared files `fonts/goo_cjk/source/`, needed only to regenerate |

## Regenerate when the Chinese lines change

```
pip install fonttools brotli pillow
python3 make_goo_cjk.py            # covers docs/marketing/*.md + ../captions_zh.json (needs source/)
python3 preview_goo_cjk.py --text ../../../docs/marketing/posts-4-weeks.md
```
Characters the source font lacks are printed as `MISSING`.

## Wiring into the repo

- Glyphs carry no drips or shading: the goo renderer adds those to any glyph bitmap, as it does for Latin.
- Latin stays untouched. To get one font with both, run
  `python3 make_goo_cjk.py --merge-into assets/fonts/pixel.fnt --merge-big assets/fonts/pixel_big.fnt`;
  it writes `pixel_cjk.fnt` / `pixel_big_cjk.fnt` with the CJK atlas added as an extra page, and the
  CJK cell shifted so its ink centre lines up with the cap-height centre.
- Each Chinese glyph is 12 units wide plus 1 unit tracking (xadvance 13); the Latin letters are 5 wide.
  A Chinese line is therefore wider in units than an English one: draw it at a smaller pixel scale
  (the preview's "fit" number is the largest px-per-unit that fits a 1080-wide Short; the longest hook
  fits at about 6.4x, versus about 12x for 13 Latin letters). Glyphs are about 11 units tall, so at
  6.4x they come out roughly as tall as the English caps.
- The goo Latin set has capitals only, so "加入Steam愿望单" should be written "加入STEAM愿望单" on screen.

## Licence

The glyph bitmaps are derived from **Fusion Pixel Font** by TakWolf and contributors
(https://github.com/TakWolf/fusion-pixel-font), licensed under the **SIL Open Font License 1.1**.
The derived font is named `goo_cjk`, not "Fusion Pixel" (a Reserved Font Name), and stays under OFL 1.1.
Keep `licenses/LICENSE.font.txt` with the repo; the files in `source/` come from the
`@vp-tw/cjk-web-fonts-fusion-pixel-font` packaging of upstream release 2026.08.11. The scripts here are
part of the Dry Trying project.
