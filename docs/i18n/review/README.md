# Reviewing every screen in every language

`./tools/i18n_capture.sh` captures every screen / overlay / HUD state in every locale so a reviewer can scan
a language (or one screen across languages) in a single image. Part of localization D15 (see `../plan.md`).

```
./tools/i18n_capture.sh [--locales en,de,...|all] [--states slug,...|all] [--out DIR] [-j N] [--keep-backdrop] [--measure-boxes] [--no-sheets] [--gate]
```

- Default out: `build/i18n-shots/` (git-ignored through `/build/`). Never `.screens/` (screenshot.sh clears it; the script refuses it).
- Locales: `en`, the 17 translations, `pseudo` (default all 19). One Godot process per locale, `-j N` in parallel (default 6).
- States: the 56 states `tests/test_i18n_screens.gd` builds (title, level select, upgrades, wardrobe, settings, hub and its
  overlays, HUD cases, results, pause, Descent ...). Names are slugs, e.g. `hub-prompt-hats`, `hud-l7-hard-heat-63`;
  the full list is in `OUT/json/states_<locale>.json`.
- Runs need a window (not headless); a window per process flashes briefly. Do not kill other Godot processes.

## Output
- `OUT/<locale>/<state>.png`: the raw 320x180 frame (also `.raw/*.rgbz`, a sidecar the sheet builder reads fast).
- `OUT/sheets/locale_<locale>.png`: all states of one language, labeled, 2x nearest upscale.
- `OUT/sheets/state_<slug>.png`: one state in every language.
- `OUT/missing_glyphs.json`: findings of the missing-glyph check; `OUT/logs/<locale>.log`: Godot output.

## Reproducibility
Fixed 60 fps, the global RNG seeded (20261017) before every screen opens (same maze, SEED text), the
drifting menu backdrop (maze and mist; the flat background stays) hidden unless `--keep-backdrop`. Each state is
frozen (its scene's processing off) while it is rendered and checked, the text drips use one fixed seed and the
rainbow hat's clock-driven hue is held on step 0 (`Hats.frozen_flow_step`: its per-step textures used to shift every
later RID, so the RID-seeded goo lumps of the states after the hat wheel changed between runs), and every goo box's
lumps are seeded from its place in the tree instead of its RID (`GooBox.seed_ids`, set just before each render: a
build that shapes one text more or hides a node no longer moves the lumps of every later state). Two runs of the
same build give the same pixels in every state, and two builds differ only where their screens do; compare them
pixel by pixel with that (the leftover pass: 19 locales x 56 states, the consolidation commit byte-identical).
A Godot run that dies before its summary (rare, not reproducible) is run once more by the script. The hub's physics is held while its station prompts are shown (it would hide them).

## Goo-ink check (fix pass F1)
Every captured state is rendered twice more, all texts transparent and then only the Labels' shadows: the pixels
that change are the texts' glyph ink (letters, marks, drips; shadows apart). For every visible goo box (GooBox:
buttons, tabs, panels, pills; boxes covered by a later one skipped) the ink inside its rect but in its band zone
(outline + band + the deepest its lumps reach, at the top, bottom and sides) is counted, and the ink right on one
of its goo pixels. `OUT/json/goo_ink_<locale>.json` lists each box with ink there (`zone`, `on_goo` pixels, the rows);
the run prints "goo-ink check (glyph ink px on goo / in band rows)" per locale. `--measure-boxes` also writes each
box's ink extent (`OUT/json/box_ink_<locale>.json`: box-relative first / last ink column and row), the numbers the
Language METRICS ink_top / ink_bottom come from.

## Goo-ink gate
`./tools/i18n_capture.sh --gate` (any `--out`, e.g. a /tmp dir; all locales, all states) exits 1 when the goo-ink check
finds glyph ink on a goo band / lump row in any state of any locale, English included, that is not listed in
`tools/i18n_goo_ink_allow.txt` ("locale state-slug box-id  # why"; empty: no accepted exceptions), or when a locale
captured fewer states than the suite builds. It prints "goo-ink gate: PASS" / "FAIL" and each unexpected finding. The
headless suites (`./tools/test_all.sh`) check the layout rules behind it; this gate checks the rendered pixels, and
needs a window, so it runs by hand before committing a change to text layout, fonts or Language metrics.

## Missing-glyph check
For every visible Label / Button with text, each character (spaces, controls and invisible bidi / joiner marks are skipped)
is looked up with `Font.has_char` on the font the control really uses (`get_theme_font("font")`, the locale's fallback
chain installed). Each finding: locale, state, node id, text, the missing characters and code points. Empty
`findings` means every drawn character resolves. Not covered: text drawn with `draw_string`, textures, the web shell.

## How it works
`tests/capture_i18n.gd` extends `tests/test_i18n_screens.gd` and overrides `_scan` (save the frame + check glyphs) and `_open`
(seed + hide backdrop), so the state builders are shared, not copied; adding a state to the test adds it here.
`tools/i18n_contact_sheet.py` (`merge`, `sheets`) is dependency-free Python. Throwaway save only; the real save is untouched
(the script prints its md5 before and after).
