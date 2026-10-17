# UI rules

Status: **final** (Phase 3 spring cleaning, 2026-10-16). Derived from the audit
([spring-cleaning/phase3-ui-audit.md](spring-cleaning/phase3-ui-audit.md)) and applied in the fix pass
([spring-cleaning/phase3-ui.md](spring-cleaning/phase3-ui.md)). The numbers live in `scripts/ui/ui_kit.gd` as named
constants (`UIKit.EDGE`, `UIKit.BOTTOM_ROW_Y`, ...); the screens in `scripts/ui/` use them, not literals (button and
tab heights, gaps, font sizes, the title line). `UIKit.POD_H2` and `UIKit.TOUCH_MIN` are rule values that only the tests
read. Not yet migrated: font sizes and gaps in `hub.gd` and the pod code of `hud.gd` (same values). `tests/test_ui_layout.gd`
and `tests/test_ui_touch.gd` check the rules on every screen they cover.

All values are base pixels at 320x180. Coordinates are top-left; spans like `x..y` are inclusive. "Ink" means the
pixels actually drawn (text letters, icon pixels), measured from rendered frames, not from control rects.

## 1. Canvas and scaling

- One 320x180 viewport, `viewport` stretch with **integer** scaling. The window shows the largest whole multiple and the
  rest is black bars. UI never re-lays out for other aspect ratios (16:10, 21:9, 4:3, phones, tablets all letterbox):
  measured layouts are identical at 1280x720, 1280x800, 2560x1080, 1024x768, 2340x1080, 2048x1536 and portrait.
  On 4:3 and tablets this uses about 66% of the screen; accepted (a non-integer mode would be a feature).
- Every position and size is a whole pixel. Centre with `UIKit.center_x(width, from, span)` (`roundf`), never leave `.5`.
- Prefer an **even width** for a box centred on the screen (the screen is even). When content forces an odd width,
  keep the box's *inner* padding symmetric and accept the 0.5 px offset of the box (hub prompts, logo).
- Portrait on a touchscreen shows the rotate cover (the same 320x180 band, scaled).

## 2. Edges and margins

| Constant | Value | Used by |
|---|---|---|
| `UIKit.EDGE` | **4** | menu chrome: BACK, the bottom-right page button, tabs (4, 4), balance pods, map tiles, DEV panel |
| `UIKit.BOTTOM_ROW_Y` | **164** | bottom-row buttons (13 tall, B = 3); `UIKit.place_bottom_row(control, -1 / 0 / 1)` |
| `UIKit.HUD_EDGE` (= `HUD.POD_MARGIN`) | **3** | in-level HUD pods and the hub's ticket pod |
| `UIKit.TITLE_Y` | **2** | screen titles: line box (0, 2)..(320, 22), 16 px font, body rows 2..15, drips to 19 |

Other locales: `UIKit.bottom_row_y()`, `UIKit.title_top()` / `title_bottom()`, `UIKit.back_size()` (section 10).

- The bottom row: **BACK at (4, 164) 40x13** on every screen (`UIKit.add_back_button(root, on_press)`); the page's own
  action mirrors it at the right edge (HEAT, PAPER, HATS / SKINS / TRAILS, RESET PROGRESS) or sits centred (JELLY,
  RESET KEYS). The title's STORY button uses the same slot.
- Text on the bottom row (map hints, the HARD checkbox) sits on BACK's text baseline (row 167).
- Documented exceptions: the Descent boon card keeps 10 px side margins (its three 96 px tiles and the buttons under
  them); the in-level touch pause button follows the HUD pods.

## 3. Spacing scale

| Constant | Step | Use |
|---|---|---|
| `UIKit.GAP_XS` | 2 | dense tiles (map tiles, shop rows), header items, stacked HUD pods |
| `UIKit.GAP_S` | 3 | stacked menu buttons (pitch 16 = 13 + 3: pause, restart, victory), tile grids |
| `UIKit.GAP_M` | 4 | toggles, tabs, button to box, controls inside one row (upgrade bar / - / + / cost), section gap |
| `UIKit.GAP_L` | 8 | result choice row (`CHOICE_GAP`), settings column gap, panel side insets |
| `UIKit.GAP_XL` | 12 | paired confirm buttons, text line pitch |

Rules:
- Use only these gaps. Inside one row all gaps are equal.
- Section gap (between a grid and the panel under it) ≥ 4.
- Keep ≥ 2 px of clear space (drips included) between any text and a box edge it doesn't belong to.
- Level tiles: the big number is centred across the tile and sits 3 px above its middle (body rows 11..24, drips to
  28, shadow 29), so 2 clear rows (30..31) separate it from the record time (body 32..38) on every tile, whatever the
  random drips (owner decision L2). The time's drip shadow touches the frame's bottom row 41, by design.

## 4. Text

- **8 px font** (`pixel.fnt`, `UIKit.FONT`): 5x7 glyphs; the letter body is 7 rows (`UIKit.TEXT_BODY`) and the drips hang
  2 rows below (`UIKit.TEXT_DRIP`). The line box is the 7 px body. The 1 px letter gap sits on each glyph's left, so a
  left-aligned label's ink starts 1 px inside its rect and ends exactly at its right edge.
- **16 px font** (`pixel_big.fnt`, `UIKit.FONT_BIG`, `UIKit.use_big_font`): titles and big numbers only. Body 14 rows,
  drips 4 rows.
- **Tabular digits** (`UIKit.tabular_font()`): a running number (the HUD timer) uses the 8 px font with "1" in a full
  6 px digit cell, so its width never changes while it counts.
- **Line pitch 12** (`UIKit.LINE_PITCH` = 7 + `UIKit.LINE_SPACING` 5). Dense lists use 11 (`UIKit.DENSE_PITCH`): the coin
  board's 10 rows and the map tiles' two lines.
- Vertical centring is measured on the **letter body**, never the drips. In a 13 px button the body is rows 3..9.
- Horizontal centring: the measured ink is within ±0.5 px of the box centre. Centre an icon and its text **as one
  group** (HEAT panel title: flame, 5 px gap, text).
- A label that shows changing values is either sized to its text (its pod grows from the anchored edge: the upgrades
  balance pod) or uses tabular digits in a fixed box (the HUD timer). Never a fixed oversize box with left-aligned text.
- Every label in one row shares one baseline (hat wheel header: tabs, title and balance on row 12; map table bottom bar
  on row 167; HUD second-row pods on row 22).
- Text side margin inside a button ≥ 4 px. The longest dynamic text must fit: a too-long text shortens (the pause SEED
  button drops the "SEED " word when "SEED 4294967295-7" would not fit its 100 px).
- **Size a label after it is in the themed tree** (`UIKit.add_label(parent, text, rect, ...)` does this). A label sized
  before keeps the default font's larger minimum size and sits off centre.
- Titles: 16 px, `UIKit.GOLD`, 2 px shadow straight down. In-panel headings: 8 px gold. The map view's title is 8 px on
  purpose (map space).
- Roles and colours (recoloured from the skin by `SkinText`):

  | Role | Colour constant | Used for |
  |---|---|---|
  | title | `UIKit.GOLD` | titles, panel headings |
  | text | `UIKit.TEXT` | body text |
  | dim | `UIKit.TEXT_DIM` | hints, secondary lines |
  | disabled | `UIKit.TEXT_OFF` | disabled text |

  Fixed tints: tickets `255,226,150`, HEAT `255,170,90`, DEV badge pink. Labels use a 1 px shadow (`BG` at 0.9).

## 5. Components

### Buttons (`UIKit.make_button` -> `TouchButton`, `GooBox`)

| Kind | Size | Constant |
|---|---|---|
| standard | **h 13**, text body rows 3..9 | `UIKit.BUTTON_H` |
| BACK / short page buttons | **40x13** | `UIKit.BACK_SIZE` |
| tabs | 40-52 x 13 | `UIKit.TAB_H` |
| panel pair | 48x13 (BUY? confirm), 56x13 (hub quit), 64x13 (save code), 70x13 (reset) | |
| result choice row (in-level results, Descent summary) | **84x13**, gap 8, y 153 | `UIKit.CHOICE_SIZE`, `CHOICE_GAP`, `CHOICE_Y` |
| Descent card buttons | 96x13 at y 153 (the tile width, under the outer tiles) | |
| stacked menu | 100x13 (pause, restart), 120x13 (settings columns, portal, victory) | |
| title CTA | 176x25, 16 px text | the only tall button |

Tiles are buttons too (level 48x42, skins 40x30, map 155x26, shop 138x13, HEAT toggles 84x34, boon 96x78).

### Panels (`UIKit.add_panel`, `panel_style`)

- GooBox frame; centred on the screen (`L == R`) or on its parent area.
- **Content inset `UIKit.PANEL_PAD` = 8** at the top (to the first text's top row or the first button) and at the bottom
  (from the last button's bottom edge, or the last text line's drips). A first line with marks starts at
  `UIKit.panel_text_top()` instead (9 accented, 11 Vietnamese: the marks start on row 6, clear of the band and lumps,
  rows 0-4); a PanelContainer gets the same from `panel_style()` (section 10.1, "No ink on the goo"). Applied to: pause and restart stacks, hub quit and
  portal dialogs, HEAT panel, Descent summary (which fits its panel to its lines). The BUY? and RESET confirms use 8 / 9.
- Modal: a dim sheet that takes clicks, plus `UIKit.lock_focus`. A modal over the in-level HUD hides the HUD texts that
  would show through (`HUD.hide_area_texts()` from pause and restart; the Descent card hides the HUD layer).

### Pods (HUD and hub)

- `hud_pod.png` 9-slice, content margins 4/4/3/3, edge margin 3.
- Height **14** (`UIKit.POD_H`) for one line, **23** (`UIKit.POD_H2`) for two. Every one-line pod is 14 (text-only pods
  included), so pods in a row share their bottom edge and mirrored rows start together (rows at y 3, 19, 35, 51).
- Icons in pods are 8x8. Taller art (the 7x9 flame, 9x9 HEAT modifier icons) goes through `UIKit.fit_icon`, an 8 px tall
  cell the art overhangs by 1 px, so the pod stays 14.
- Content ink pads equal on both sides (HUD timer 4 / 4, upgrades balance 4 / 4, hub prompt 8 / 8: the prompt's left
  content margin is 1 less to absorb the font's leading letter gap).
- The hub prompt is a goo panel (`panel_style`): its top room follows its line's marks (`panel_v_margins(text)`); a
  prompt taller than English's 18 keeps English's top row 156 by growing down, its bottom edge to 3 rows above the
  safe area's bottom (its drops stay on screen), then up. The hub's ticket pod fades out while the coin board is open
  (it sat on the board's frame; faded, not hidden, so its labels don't re-shape and move later goo lumps).
- The area name (y 20, or 44 under the randomizer's attempt pod) and the story line (15 under it; 12 in Descent) are
  placed by `HUD._place_area_texts`: each line moves down until its text, drips included, is 2 px clear of every visible
  pod. They re-place whenever a pod shows or hides.

### Icons

- The touch pause button (15x13 rect, `TouchControls.PAUSE_RECT`) draws two pause bars; in the hub on iOS / Android it draws a 7x7 pixel house instead (`home_icon`, decision D10: the button goes to the title). Both are constant pixel lists centred on the rect, whole pixels.
- 8x8 UI icons (`assets/ui/icon_*.png`: drop, clock, coin, ticket, medal, lock, check); 7x9 flame; 16x16 ability and boon
  icons; HEAT modifier icons 9x9 (RACE 8x8), drawn at 2x in the HEAT panel and centred in an 18x18 cell.

### Tiles and grids

| Grid | Tile | Gap | Placement |
|---|---|---|---|
| level select | 48x42 | 3 | centred: L34 / R34 (number 3 px above the tile middle, §3) |
| skins | 40x30 | 3 | centred (row 2 of 6 tiles: 0.5 px, accepted) |
| map table | 155x26 | 2 | L4 / R4 |
| shop | 138x13 | 2 | centred in its panel: L13 / R13 |
| HEAT toggles | 84x34 | 4 | centred in the panel |
| boon tiles | 96x78 | 6 | L10 / R10 |

- A grid is centred on the screen or on its panel, ±0.5 px.
- Mirrored badges inside tiles share an inset (level tiles: flame and pips both at 5).

## 6. States

| State | Look |
|---|---|
| normal | face `#332c40`, goo frame in the skin colour |
| hover | face `#483e5e` and the goo one shade lighter |
| pressed | face `#282234` |
| **selected** (tabs, the chosen skin / hat / trail tile, the worn shop item) | face `#282234` (pressed-in) with the lighter hover goo, in normal and hover alike: `UIKit.set_selected(button, on)` (GooBox state `"selected"`). A hovered unselected tab (light face) never looks selected |
| focus | 1 px ring in the title colour, 1 px outside the button (keyboard / controller only; a mouse click shows none) |
| disabled | dried goo, dim face and `TEXT_OFF` text |

- Text never moves between states.
- Keep ≥ 2 px between neighbouring buttons so a focus ring never touches the next button.

## 7. Touch

Physical size of 1 game px: about 1.67-2.3 pt/dp on phones (5-6x scale at DPR 2.6-3) and 3-4 pt on tablets. Target:
44 pt / 48 dp = **`UIKit.TOUCH_MIN` 22 game px** at the common 2 pt per px.

- Every menu button is a `TouchButton`. While touch is in use (`UIKit.touch_active()`: the last pointer event was a
  screen touch or drag, or the mouse event Godot emulates from one, tracked by `UIKit.note_pointer` on the root
  window's input; or `--touch`) its **hit area** is its drawn rect grown by
  `UIKit.HIT_PAD` (5) on every side, art unchanged: a 13 px button is hit over 23 px. The grown margin is shared by
  distance: a point belongs to the nearest touch target (`UIKit.TOUCH_GROUP`: buttons, plus checkboxes, sliders and text
  boxes registered with `UIKit.add_touch_target`), never to a button when it lies inside another target's own rect, so
  hit areas never overlap. Controls kept out of focus behind an open panel don't compete. With a mouse the hit area is
  exactly the drawn rect, also on a desktop or browser with touchscreen hardware (it switches per input event).
- Lone buttons and rows (BACK, tabs, result rows, hub dialogs, the upgrade - / + with 4 px between them) reach 23 px both
  ways. Stacks with a 3 px gap (pause, restart) get their pitch: 16-20 px (32-40 pt). Wider pitches for touch would be a
  layout change (see phase3-ui.md, remaining issues).
- Mirrored controls share a centre line: joystick home (40, 140), JUMP (280, 140).
- Touches in the letterbox bars still reach the controls (x < 0 counts as the joystick, x > 320 as JUMP). Keep it.

## 8. Safe areas

Phase 5 added safe-area handling (`Platform.safe_rect()` / `safe_insets()` in `scripts/platform.gd`, see
[spring-cleaning/phase5-platform.md](spring-cleaning/phase5-platform.md) M1). It applies on iOS and Android only (and
with the test overrides / `--platform=ios`); desktop and web use the whole view and keep every number above.

- `Platform.safe_rect()` maps `DisplayServer.get_display_safe_area()` into the 320x180 view (largest whole multiple,
  centred). Integer pillarboxing already keeps content clear of notches and punch-hole cameras on 19.5:9 / 20:9 phones
  (210-306 px bars), so the rect is the whole view there; exactly-16:9 phones and iPhone landscape cut into it.
- HUD pods, the hub's ticket pod and the touch pause button sit `UIKit.hud_edge()` from the sides / top: `HUD_EDGE` (3),
  or 1 px clear of the safe area where it cuts deeper.
- Touch hit areas grow by `HIT_PAD` but never past the safe area (iPhone landscape: the bottom row's margin ends at
  y 177.75, not 181, so the home-indicator strip stays the system's); the floating joystick never opens in that strip.
  Keep interactive art at y <= 176. With the whole view safe, touches in the letterbox bars still count (section 7).
- Rounded corners on exactly-16:9 phones may still clip a pod's outer corner by a pixel: check on a device (port-time).

## 9. Motion

- UI tweens animate modulate/alpha only. The goo wipe is a full-screen shader sheet that hides itself at the end. Any
  future positional tween must end on a whole pixel, at the same position the static layout uses.

## 10. Per-locale sizes and text fitting (i18n, chunks G0-G5, I)

The constants above are the **English** numbers (also Indonesian, whose metrics are English's, and everything with the
languages gate off). Every size that follows the text's height has a function in `UIKit` that reads
`Language.metrics(current locale)` and returns **exactly the constant in English** (checked by
`tests/test_ui_kit_locale.gd`; English title / settings / level select / upgrades / skins / key controls / hub and the
BUY? confirm are byte-identical to HEAD in seeded `--write-movie` captures, gate off and on). New code uses the
functions, never the constants, for anything text-tall.

| Function | English | accented (es pt_BR fr de it pl tr ru, pseudo) | vi | cjk (zh_CN ja ko) | zh_TW | th | hi / ar |
|---|---|---|---|---|---|---|---|
| `button_h()` = `tab_h()` | 13 | 16 | 18 | 16 | 18 | 19 | 21 |
| `button_v_margins()` (top / bottom) | 3 / 3 | 6 / 3 | 8 / 3 | 1 / 1 | 1 / 1 | 2 / 0 | 3 / 1 (ar 2 / 0) |
| `panel_v_margins()` (`panel_style()`: one line in a goo panel) | 6 / 5 | 9 / 5 | 11 / 5 | 3 / 2 | 3 / 1 | 5 / 1 | 6 / 3 (ar 5 / 2) |
| `panel_text_top()` (first line in a hand-laid panel) | 8 | 9 | 11 | 8 | 8 | 8 | 8 |
| `pod_h()` / `pod_h2()` | 14 / 23 | 17 / 26 | 19 / 30 | 17 / 29 | 19 / 33 | 20 / 35 | 22 / 39 |
| `line_h()` / `line_pitch()` / `dense_pitch()` | 7 / 12 / 11 | 7 / 12 / 12 | 7 / 14 / 14 | 14 / 15 / 14 | 16 / 17 / 16 | 17 / 18 / 17 | 17 / 20 / 19 (ar 19 / 20 / 19) |
| `line_spacing()` (Label theme) | 5 | 5 | 7 | 1 | 1 | 1 | 3 (ar 1) |
| `title_top()` .. `title_bottom()` | 2..22 | 8..28 | 12..32 | 2..32 | 2..36 | 2..29 | 2..29 |
| `bottom_row_y()` (ends on row 176) | 164 | 161 | 159 | 161 | 159 | 158 | 156 |
| `choice_y()` / `choice_size()` | 153 / 84x13 | 150 / 84x16 | 148 / 84x18 | 150 / 84x16 | 148 / 84x18 | 147 / 84x19 | 145 / 84x21 |
| `hit_pad()` (hit area stays >= 23) | 5 | 4 | 3 | 4 | 3 | 2 | 1 |
| `stack_pitch(gap)` | `button_h()` + gap (16 with `GAP_S` in English) | | | | | | |
| `accent_room()` (marks over a line in a tile / panel) | 0 | 2 | 4 | 0 | 0 | 0 | 0 |
| `digit_top()` (slimy digits' body under the line top) | 0 | 0 | 0 | 4 | 6 | 5 | 6 |

- **Buttons and pods size themselves**: `make_theme` / `button_style` / `panel_style(true)` carry the locale's margins, so
  every themed button is at least `button_h()` tall and every one-line pod `pod_h()`, with no per-screen work. With the
  slimy font the 3 rows under the body stay (drips) and the accents' rows go on top (accents used to land on the goo
  band of a 13 px button and vanish). With the slimy font a button is 13 + the marks' rows (`ink_above`: 3 accented, 5
  Vietnamese) tall, so the highest mark starts on row 3, under the goo's lump row (row 2), as English capitals do
  (G5: at 15 px an acute sat on the lump row and a diaeresis right under it: ZURÜCK, WRÓĆ, DŹWIĘK, TÜRKÇE). A taller
  script's line box gets 1 / 1, moved down by its `ink_nudge` (Thai, Devanagari: 1) so the letter body is centred
  (measured: BACK body 0 px off centre in th / hi, 0.5 in ja).
- **What screens must do**: position from these functions (a 13 px literal or `UIKit.BUTTON_H` used as a pitch is a bug
  in a taller locale). Gaps stay on the spacing scale (section 3); the extra height comes out of the pitch, never out of
  a gap below 2 px.
- **Widths from measured text**: `text_w(text, size)` (no RIDs for the slimy font, so measuring never moves GooBox
  lumps), `button_w(text, min_w)` = max(min_w, text + 2 x `BUTTON_TEXT_PAD` 5: one more than the style's 4 px
  content margin, because the slimy letters keep their 1 px gap on the left only and the shadow falls right, so a
  grown button keeps 3 clear columns left of its ink and 2 right of its shadow; at 4 MONEDAS / VOLTAR / BOUTIQUE put
  the last letter's shadow on the right goo lump column), `button_size`, `back_size()` (BACK,
  40 wide in English), `tab_widths(texts, min_widths, equal)` (English widths kept; once any tab grows, the whole group
  takes the widest width, so the row stays symmetric) and `layout_row(controls, widths, from, y, gap, align)`.
- **Fitting a text: `fit_text(control, box, max_size, max_lines, anchor)`**, in order: as is; a bigger box up to
  `max_size` growing from `anchor` (centre growth on whole pixels); wrapped onto `max_lines` (word breaks, anywhere
  for zh / ja, U+200B for Thai); the same font one crisp size down (16 px title -> 8 px; Devanagari 14 -> 12,
  `Language.SMALLER_FONT_PX`; no smaller size exists for the slimy 8 px font, Arabic, Thai, CJK). Never truncates,
  never scales by a fraction. `fits == false` means the layout must change (two pages / scroll).
- **Budgets** (does it fit the safe 320x180?): `content_rect(gap)` (English (4, 26) 312x134, Devanagari (4, 33) 312x119: under the title box,
  above the bottom row, inside `Platform.safe_rect()`), `stack_h / stack_fits / stack_pages(heights, gap, area_h)` for
  stacked columns, `row_budget(area_h, row_h, gap)`, `column_budget(area_w, columns, gap)`,
  `grid_budget(count, columns, area_h, cell_h, gap)` -> rows per page / pages. Switch to a two-page or scrolling
  layout only when these say it does not fit (tall scripts), so English keeps its single page.
- **Shared widgets already follow these**: the screen title (`setup_screen`), BACK (`add_back_button`, wider for
  VOLTAR / ZURÜCK, taller and higher for tall scripts, always ending on row 176), `place_bottom_row` (bottom edge kept),
  the BUY? confirm (BUY / BACK equal widths from the longer word, panel widened and re-centred, rows on `line_pitch()`),
  the VOLUME box (`button_h()` tall), TouchButton hit areas (`hit_pad()`).
- Right-to-left (Arabic): every layout is mirrored whole by one mechanism, section 10.2.

### 10.1 Rules the screens settled on (chunks G1-G4, consolidated in G5)

All helpers below live in `UIKit` (one copy; screens never keep private versions) and return the English numbers or do
nothing in English, so English and the gate-off game stay pixel-identical (seeded `--write-movie` captures).

- **`fit_text` order**: put the control in the themed tree, apply any font / size / line-spacing override, then call
  `fit_text(control, designed_rect, max_size, max_lines, anchor)`, then place anything that depends on its size. The
  steps are as is -> grow (from `anchor`, whole pixels) -> wrap (`max_lines`) -> one crisp font size down; the wrapped
  size holds in the same frame (`fit_text` refreshes the minimum size when it turns autowrap on: no deferred second
  resize). `wrap_label(label, box)` is the same for a label you already know wraps; `break_line(text, room)` breaks
  one line into two balanced ones at a space (the level select's checkbox, a result line wider than `REWARDS_W`).
- **Equal-width groups**: a row or column of one-of-many controls (tabs, the wardrobe's BACK / page button, the
  settings columns, choice rows, paired dialog buttons, the hat wheel's sections) takes `tab_widths(texts, english_w)`:
  every member keeps its English width until one text needs more, then all take the widest. Every text the control
  can show counts (all page titles of the wardrobe's page button, every state of a toggle, PRESS KEY for a key button).
  Each control sized from text records it with `note_text_w(control, texts, min_w, font_size, extra)`;
  `tests/test_i18n_screens.gd` recomputes `noted_text_w` and accepts a button wider than in English only when it is
  exactly that wide (never by node name). A CheckBox's own width is `button_w(text, 0, FONT, checkbox_extra(box))`.
- **Per-locale paging**: a fixed grid or stacked column that `grid_budget` / `stack_pages` / `row_budget` says does
  not fit gets pages only in the locales that need them; English keeps its single page. Close the gaps first, one
  scale step at a time (never below the scale: key controls try ROW_GAP 4, then `GAP_S` 3 between rows), then page.
  Rows split into balanced pages (map table, key controls: 3 + 2, not 4 + 1). Turning pages: `add_page_arrows(parent, on_step, y, left_x, right_x, w,
  h, focus)` makes `<` / `>` (`PAGER_W` 20 wide, `PagePrev` / `PageNext`, in `plain_font`), beside the title at
  `title_arrows_y()` (level select, map table) or either side of a row (the hat wheel's sections, no focus: the
  keys turn pages past a page's first / last row); `show_page_arrows(arrows, page, pages)` disables the arrow that
  would leave the pages. A screen whose bottom row has room uses one page button there instead (key controls: `1/2`,
  BACK's mirror and width). Left / right (level select) or up / down (hat wheel) past a page's edge turn the page too.
  Keys past the edge (fix pass F3b, the two grids side by side): the **level select** (one row of five a page)
  turns on right from a page's last tile to the next page's first, left from its first back to the previous page's
  last. The **map table** (two columns a page, read down the left column, then the right) turns on right from the
  right column to the same row of the next page's left column, left from the left column to the same row of the
  previous page's right column (the last row it has when that page is shorter); a locked target hands the focus to
  that page's nearest open tile, else to the arrow that turned it; up / down never turn. In a mirrored layout
  (Arabic) the reading direction's key leads on in both (`UIKit.is_mirrored`: left turns on). A tile that is not on
  a page's edge moves the focus as usual.
  **A paged grid's rows are centred** (+-1 px) in the room between the title's line box and what is under them, the
  first (fuller) page's rows; the second page starts on the same row: the level select between the title and the
  info panel, the map table between the title's shadow row and `BOTTOM_GAP` over the bottom row, the key controls'
  rows between the title and the note (fix pass F3b: three rows left a 24-40 px band under them, CJK / zh_TW / Thai /
  Devanagari). One page (English) keeps its place.
- **Panel-cover rule**: while a modal panel is open in a locale whose layout differs from English, the page's own
  controls behind it are hidden: `cover_behind(screen, keep, rect)` (only those under `rect` when given: SAVE CODE and
  RESET panels; all of them: the resized HEAT panel, the opaque map view) and `uncover(list)` on close. That includes
  the page arrows (they are added last so the other nodes keep their places). English keeps its faint ghosts
  (byte-identical), because its panels' texts already avoid the page.
- **Digit rule**: digits-only texts (level numbers, record times, %, +N, counts beside coin / ticket icons) and the
  page arrows use `plain_font(text)` (`use_plain_font(control)`): the slimy font without the script fallback, whose
  line box would push the digits 5-7 px down in CJK / Thai / Devanagari. Where a number shares a line with script text
  (the coin board's counts, the wheel's ticket balance), the slimy digits sit `digit_top()` = ascent - 7 rows under
  the line top, so an icon beside them moves down by that much.
- **Accent room**: a tile or panel laid out for English adds `accent_room()` rows (2 accented, 4 Vietnamese) above a
  line that may carry marks; `ink_above(text, size)` gives a single line's marks (0 for a line whose letters have no
  mark: ASCII, and since F1 also the unmarked Cyrillic / Latin letters, `has_mark(code)` reads the slimy font's i18n
  page), for room only a marked line needs (the title's tagline under its slimes). Marks never sit on a goo
  band: buttons are 13 + `ink_above` tall (table above).
- **No ink on the goo (fix pass F1)**: every script's 8 px ink extent is in `Language.METRICS` as `ink_top` /
  `ink_bottom` (line-relative rows: English 0 .. 8 with the drips, accented -3, Vietnamese -5, CJK 3 .. 12, zh_TW
  3 .. 13, Thai 1 .. 14, Devanagari 0 .. 16, Arabic 1 .. 17; measured on every rendered button with
  `tools/i18n_capture.sh --measure-boxes`, checked against every glyph of every translation by
  `tests/test_i18n_f1_marks.gd`). From them: a button's line starts where its first inked row lands on
  `GOO_INK_ROW` 3 (under the lump row, as English capitals; `button_v_margins`), a goo panel's where it lands on
  `PANEL_INK_TOP` 6 and its last ink on h - `PANEL_INK_BOTTOM` 4 (`panel_style()` / `panel_v_margins(text)`, English
  6 / 5; with `text`, only the marks that line has: the hub's station prompt), and a hand-laid panel's first line at
  `panel_text_top()` (PANEL_PAD 8, 9 accented, 11 Vietnamese; the hub's quit / portal / resume dialogs). Devanagari's
  8 px line box is trimmed to its ink (`Language.LINE_TRIM`: 19 -> 17, no translation inks the descent's last 2 rows),
  so its 21 px buttons hold the line from row 3 (3 / 1). The check: `tools/i18n_capture.sh` renders every state twice
  more (texts hidden, shadows hidden) and counts glyph ink (letters, marks, drips; shadows apart) inside each visible
  goo box's band / lump rows (`OUT/json/goo_ink_<locale>.json`, summary line "goo-ink check"). Since the leftover pass
  there are none in any locale (English's SAVE CODE panel and upgrades rows, the LANGUAGE names fixed): the gate below.
- **Text lines on the screens (fix pass F3b)**, every one a no-op in English except the LANGUAGE screen:
  - A label beside a button in a row takes the button's text line: the key controls' action labels get the theme's
    `button_v_margins()` as an empty style's margins (centred on the taller row they sat 2 px over the key text with
    accents, 3 Vietnamese, 1 Thai / Devanagari). A button's hand-placed text (the settings LANGUAGE button's globe +
    name) goes on row `button_v_margins().x` in the button's own font, the globe on the letter body.
  - ENTER (16 px): the line from row 5 (English), lower by that text's own marks (title.gd `mark_rows`: Й 6 rows at
    16 px) so they start on `GOO_INK_ROW`; the button grows to keep 1 row (its outline) under the drips (the accents'
    8 px theme margins had put the 16 px drips on the outline). A taller script: its glyphs' first inked row
    (`BIG_INK_TOP`, Devanagari 1) on `GOO_INK_ROW`.
  - CJK button text is centred on its ink (title ENTER / STORY: title.gd `ink_shift`, the glyphs' bitmaps): CJK
    glyphs start at their left edge and keep their spacing on the right (Hangul 2 px), so a centred line sat 1-2 px
    left.
  - LANGUAGE screen: each slimy-font name's ink (marks + body + 2 drip rows) centred between rows `GOO_INK_ROW` and
    h - 2, a row's slimy names on one line (the lowest); scripts in their own fonts keep 1 / 1 + `INK_NUDGE`.
    ENGLISH moved 2 px down (row 6, beside ESPAÑOL / PORTUGUÊS).
  - Level select info lines: `INFO_PAD` 5 in English; where the locale's ink reaches over the line box (marks) or a
    taller script inks the line box's first row (Devanagari), the first ink goes on `PANEL_INK_TOP` (6).
  - Map tiles: the name's first ink on `GOO_INK_ROW` (6 accented, 8 Vietnamese); the % line (digits) at English's
    `DENSE_PITCH` under the name's last line with the slimy font, so the accented tiles keep 41 px (3 rows a page).
  - Key controls note: `NOTE_GAP` over the bottom row (English); when that leaves it closer to the rows than to the
    bottom row it is centred between them, never less than `GAP_L` over the bottom row (Vietnamese fills the room:
    its stacked marks reach the last key row's bottom edge beside the keys).
- **Screen rules of fix pass F3a** (wardrobe, upgrades, hat wheel, HEAT panel, hub), each a no-op in English except the
  upgrades ABILITIES rows:
  - **Keep the 16 px title by making room**: a screen tries its 16 px title with the layout's other steps first (the
    wardrobe's stage on the bottom row, gaps one scale step closer, the smaller crisp font for body lines) and only then
    the 8 px font.
  - **Off-centre title**: a 16 px title wider than the room centred between the header items moves only as far as it
    must, `GAP_L` clear of the tabs (`GAP_M` if that does not fit), never centred in the leftover room (upgrades, hat
    wheel).
  - **Ink-based placement in a taller script**: line positions come from Language `ink_top` / `ink_bottom` (a 16 px
    title from its shaped glyphs, `UIKit.title_ink_end`; a smaller crisp size from `UIKit.ink_rows`), so a line box's
    empty rows are not counted as gaps. Line boxes never overlap (`test_i18n_screens`), except by rows neither line
    inks (an ABILITIES tag lifted over its name's empty rows, below).
  - **Two-line rows in goo panels** (ABILITIES): the first line's ink from row `PANEL_INK_TOP` 6, the last line's ink
    1 row over the bottom lumps (h - 5); fallbacks in order: the hint on the bottom row, rows `GAP_XS` apart, the last
    ink on h - 4, the first ink on row 5, the old 2 / 2 insets, the smaller font, pages.
  - **Name next to a price / icon**: in a right-to-left layout a name keeps 1 px more from its border / icon (Kufi has
    no side bearing); a price label sits on its name's text row (box top - 1, as English); a tile grown for a longer
    name keeps `GAP_L` between its longest name and the price where the panel has the room.
  - **Toggle name fitting** (HEAT): one line (up to `BUTTON_TEXT_PAD` from the edge) -> the smaller font -> two lines
    if the panel still fits the screen -> the 1x icon only in the toggles whose name needs it.
  - **Mixed digit rows in CJK**: digits beside CJK names go `ink_drop` (1) rows down (the coin board).
- **Leftover pass rules** (docs/i18n/review/leftovers.md), no-ops in English except the SAVE CODE panel:
  - **A slimy character's drips count as the line's ink**: in a taller script the slimy digits / Latin letters hang their
    2 drip rows below the script's own ink (zh_TW `3X3`, `第2次 = +4`: 1 row past `ink_bottom` 13; Devanagari's small
    font, Thai 1-2 rows). `UIKit.ink_rows(texts, font, size, true)` measures a text with them (the slimy bitmap
    font's cells hold the drip rows, no cache padding); `UIKit.drip_excess(text, assumed_bottom)` is how far a line
    reaches past what a layout assumed. A result panel's last row grows by it; an ABILITIES tag nearer the bottom
    lumps than h - 5 rises by it into its own empty top rows (2 clear rows kept under the name's ink).
  - **A panel over a 16 px title keeps clear of that title's own marks**: the result panel, centred down onto the
    record banner, ends `GAP_XS` over the banner title's marks (`UIKit.mark_rows(text, 16)`: 6 rows for `Ñ`), not
    only over its line box; where it is clear of them it stays where it was.
  - **The widest label beside a control keeps `GAP_L`**: the key controls' label column widens so the longest action
    label ends `GAP_L` before its key, where the keys can narrow for it (`button_w(PRESS KEY)`) and both columns still
    fit; else the column `GAP` (4).
  - **A text that may not fit its fixed-width button keeps `BUTTON_TEXT_PAD`** on each side before the button shows
    its shorter form (the pause SEED button: `SEED 123-4`, else the code alone).
  - **English panel ghosts**: a modal panel in English hides the page labels whose box reaches its goo band rows
    (`PANEL_INK_TOP` rows at the top and bottom of its rect: the SETTINGS title under SAVE CODE's top band); the
    page's buttons and the other labels keep their faint ghosts.
- **Rendered goo-ink gate**: `./tools/i18n_capture.sh --gate` (needs a window; docs/i18n/review/README.md) fails on any
  glyph ink inside a goo box's band / lump rows in any state of any locale, English included, other than the accepted
  exceptions listed in `tools/i18n_goo_ink_allow.txt` (none), and on an incomplete capture. Run it after any change
  to a screen's text layout, fonts or Language metrics; the headless suites check the same rules from the layout.
- **Script gap (CJK)**: in ja / ko / zh_CN / zh_TW, `Loc.t` / `Loc.n` put U+2007 (`Loc.SCRIPT_GAP`, no line break) after
  a slimy character (digit, Latin letter, `% ) ] ! ?`) that a CJK letter follows, and the slimy fonts get a 1 px (2 px
  at 16) glyph for it (`Language._apply_script_gap`): the slimy letters keep their 1 px gap on the left only and the
  CJK glyphs start at their left edge, so `12階`, `第1关`, `按F转动`, `1층` had 0 px between number and letter. Not in
  any other locale, never in the translations themselves.
- **Checkboxes**: `align_checkbox(box)` puts the 9 px box's bottom row 2 rows over the text's last ink row, as in
  English (a taller script's line box had it 1-3 px high: CJK 2, zh_TW 3, Thai 1; CJK letters reach `ink_drop` 1 row
  lower than the slimy body). English: unchanged.
- **Width budgets for translators**: a `# i18n:` hint's `max Npx` is the English box; where the screen widens the box
  for the text it also says `grows to Npx` (the room the layout has), and `wraps` where the text wraps there (`lines
  N`). `tests/test_i18n_fit.gd` measures every translation against that, `tests/test_i18n_screens.gd` against the real
  screens; both fail on any open finding in any locale (Arabic included since chunk I).

### 10.2 Right-to-left: mirrored layouts (chunk I)

Owner decision (docs/i18n/plan.md section 11): in Arabic the screens mirror like a native RTL game. One mechanism,
in `UIKit`, does it for every screen; screen code keeps writing the English (left-to-right) layout.

- **How**: each UI root registers with `UIKit.mirror_root(root)`: `setup_screen` does it for every menu screen; the
  hub's UI root, the HUD (its CanvasLayer), the pause menu, the restart prompt and the Descent card call it
  themselves. In an RTL locale the root stays `LAYOUT_DIRECTION_LTR` while it is built and is flipped to RTL at the
  end of that frame (deferred). Godot then mirrors the whole subtree against each parent's real width (x' = parent_w
  - x - w: hand-set positions through their offsets, anchors, container order, LEFT / RIGHT alignment, a button's
  icon side, the bidi base direction of every Label / Button). UIKit also swaps explicit `focus_neighbor_left` /
  `_right` (arrow keys follow the visual order) and mirrors Node2D sprites under a mirrored control (slime previews,
  the try-on slimes; art is never flipped). In English / LTR locales / gate off `mirror_root` does nothing.
- **`project.godot`** sets `internationalization/rendering/root_node_layout_direction = 1` (LTR): the root is left to
  right in every language, so only registered roots flip, and a control positioned before it is added to the tree
  (common here) resolves LTR. (Before chunk I such a control took the app locale's RTL with a zero-width parent and
  stored its offsets mirrored about 0: the off-screen findings of chunk G0.) English behaves exactly as before.
- **Godot's `position` is visual while RTL**: writing it there is not mirrored. So code that moves or resizes
  controls after the build (a page / tab switch, a panel opening, a re-fitted text) calls `UIKit.relayout(node)`
  first: the root drops back to LTR coordinates (reads and writes logical) for the rest of the frame and is mirrored
  again at its end. `layout_row`, `fit_text`, `wrap_label`, `cover_behind` and `place_bottom_row` call it themselves;
  the screens call it in their entry points (`show_page`, `show_tab`, `open`, `refresh`...). Anything that only changes
  text or visibility needs nothing (sizes from minimum sizes keep the logical left edge). A value set every frame
  (the HUD meter's fill) is set through its offsets (`offset_right`), which are logical in both directions.
- **Keys**: arrows move focus visually (Godot's geometry + the swapped neighbours). Code that maps a left / right key
  or LB / RB to previous / next uses `UIKit.reading_dir()` or `UIKit.is_mirrored(control)` (level select page keys,
  upgrades tabs). A single page button (the wardrobe's) keeps RB = next.
- **What mirrors**: menus, columns, tab rows (tab order reverses), BACK (bottom right), page arrows (NEXT on the
  left; the `<` / `>` glyphs are bidi-mirrored by the text server, so each still points away from the screen's
  middle), HUD pods (meter right, level left; the meter drains toward its outer end), dialogs, the hat wheel's
  header and SHOP grid, the language grid (ENGLISH top right).
- **What does not mirror** (deliberately): the game world and the hub room (Node2D, never under a mirror root), the
  touch controls (thumb placement), text drawn with `draw_string`, the logo, map pictures and the hat wheel's wheel
  (textures / custom drawing keep their art), numbers and times (LTR runs inside the RTL line), and anything under
  `UIKit.keep_ltr(item)` (the drifting menu backdrop). Labels outside every mirror root (the rotate hint) take
  `UIKit.text_direction()` (RTL in Arabic) so punctuation lands right.
- **Bidi text**: translations carry no control characters. `Loc.fill` (Arabic only, `Loc.isolate_ltr`) wraps each
  placeholder "word" that comes out without Arabic letters (a number with its sign / unit / slash: `+5`, `30%`,
  `X1.5`, `1/3`, `(+0)`; a Latin key or pad name) in U+2066 LRI .. U+2069 PDI: it reads LTR as one unit and counts as
  one neutral word in the Arabic line, so the sign stays before the number and space-separated values (`{a} {b} {c}`
  pad letters) follow the line's right-to-left order. `UIKit.text_w` / `plain_font` treat bidi controls as
  zero-width (`UIKit.is_format_char`). Signed numbers written in a translation itself (`+30%`, `-10%`, `(+0)`, `10%`:
  no placeholder) get the same isolate from `Loc.t` / `Loc.n` (`Loc.isolate_signed`, fix pass F1), so the sign and the
  % stay where an Arabic reader expects them (they drew `1+` and `%10-`).
- **Fitting without a smaller font** (Arabic has none: Kufi merges dots under 12 px): the HEAT toggles draw their
  icon at 1x before wrapping a name (two-line names would make the panel taller than the screen), and the upgrades
  ABILITIES rows go on pages (a `1/2` button mirroring BACK) when they don't fit one page.
- **Tests**: `tests/test_i18n_rtl.gd` (every menu: each control at the mirror of its LTR place, BACK bottom right,
  tab / tile / arrow order, inside 320x180; dynamic re-layouts; keys; HUD sides; game world and hub room unmirrored;
  `Loc.fill` isolates); `tests/test_i18n_screens.gd` measures a mirrored text where Godot draws it (alignment and
  icon side swapped).

