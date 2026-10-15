# UI rules

Status: **final** (Phase 3 spring cleaning, 2026-10-16). Derived from the audit
([spring-cleaning/phase3-ui-audit.md](spring-cleaning/phase3-ui-audit.md)) and applied in the fix pass
([spring-cleaning/phase3-ui.md](spring-cleaning/phase3-ui.md)). The numbers live in `scripts/ui/ui_kit.gd` as named
constants (`UIKit.EDGE`, `UIKit.BOTTOM_ROW_Y`, ...); screens use them, not literals. `tests/test_ui_layout.gd` and
`tests/test_ui_touch.gd` check the rules on every screen they cover.

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
- Keep ≥ 2 px of clear space (drips included) between any text and a box edge it doesn't belong to. Exception: the level
  tiles' big number, whose drips end on the row right above the record time (0 clear rows, no overlap) so the number
  stays centred on the tile (see phase3-ui.md, remaining issues).

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
  (from the last button's bottom edge, or the last text line's drips). Applied to: pause and restart stacks, hub quit and
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
- The area name (y 20, or 44 under the randomizer's attempt pod) and the story line (15 under it; 12 in Descent) are
  placed by `HUD._place_area_texts`: each line moves down until its text, drips included, is 2 px clear of every visible
  pod. They re-place whenever a pod shows or hides.

### Icons

- 8x8 UI icons (`assets/ui/icon_*.png`: drop, clock, coin, ticket, medal, lock, check); 7x9 flame; 16x16 ability and boon
  icons; HEAT modifier icons 9x9 (RACE 8x8), drawn at 2x in the HEAT panel and centred in an 18x18 cell.

### Tiles and grids

| Grid | Tile | Gap | Placement |
|---|---|---|---|
| level select | 48x42 | 3 | centred: L34 / R34 |
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

- Every menu button is a `TouchButton`. With a touchscreen (or `--touch`) its **hit area** is its drawn rect grown by
  `UIKit.HIT_PAD` (5) on every side, art unchanged: a 13 px button is hit over 23 px. The grown margin is shared by
  distance: a point belongs to the nearest touch target (`UIKit.TOUCH_GROUP`: buttons, plus checkboxes, sliders and text
  boxes registered with `UIKit.add_touch_target`), never to a button when it lies inside another target's own rect, so
  hit areas never overlap. Controls kept out of focus behind an open panel don't compete. Without touch the hit area is
  exactly the drawn rect.
- Lone buttons and rows (BACK, tabs, result rows, hub dialogs, the upgrade - / + with 4 px between them) reach 23 px both
  ways. Stacks with a 3 px gap (pause, restart) get their pitch: 16-20 px (32-40 pt). Wider pitches for touch would be a
  layout change (see phase3-ui.md, remaining issues).
- Mirrored controls share a centre line: joystick home (40, 140), JUMP (280, 140).
- Touches in the letterbox bars still reach the controls (x < 0 counts as the joystick, x > 320 as JUMP). Keep it.

## 8. Safe areas

- The web shell uses `viewport-fit=cover`, and there is no safe-area code. Integer pillarboxing keeps the content clear of
  notches and punch-hole cameras on 19.5:9 / 20:9 phones (210-306 px bars).
- Exactly-16:9 phones have no bars. Keep important HUD content ≥ 3-4 game px (18-24 px physical) from corners; large
  rounded corners still clip the HUD pods' outer corners there.
- iPhone landscape: the bottom bar (45 px) is narrower than the home-indicator zone (63 px). Keep interactive art at
  y ≤ 176. The touch hit areas of bottom-row buttons now reach y 181 (into the bar). Both are Phase 5 items.

## 9. Motion

- UI tweens animate modulate/alpha only. The goo wipe is a full-screen shader sheet that hides itself at the end. Any
  future positional tween must end on a whole pixel, at the same position the static layout uses.
