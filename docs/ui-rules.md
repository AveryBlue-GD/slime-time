# UI rules (draft)

Status: **draft** from the Phase 3 spring-cleaning audit ([spring-cleaning/phase3-ui-audit.md](spring-cleaning/phase3-ui-audit.md)).
These rules describe what most current screens already do, as measured from rendered pixels. Each "Deviations" list
names the screens that break a rule, with the audit's issue ID. When the fix half lands, the numbers should move into
`scripts/ui/ui_kit.gd` as named constants (proposed names are given), and screens should use them instead of literals.

All values are base pixels at 320x180. Coordinates are top-left, and spans like `x..y` are inclusive.

## 1. Canvas and scaling

- One 320x180 viewport, `viewport` stretch with **integer** scaling. The window shows the largest whole multiple and
  the rest is black bars. UI never re-lays out for other aspect ratios (16:10, 21:9, 4:3, phones, tablets all just
  letterbox). On 4:3 and tablets this uses about 66% of the screen; that is accepted, not a bug.
- Every position and size is a whole pixel. Centre with `roundf` / `floori`, never leave `.5`.
- Give centred boxes an **even width** (the screen is even). An odd width always leaves a 0.5-1 px asymmetry.
  Deviations: logo 291 (T2), hub prompts 115/179 (U1b), skins row 2 (S1).
- Portrait on a touchscreen shows the rotate cover (the same 320x180 band, scaled).

## 2. Edges and margins

| Constant (proposed) | Value | Used by |
|---|---|---|
| `UIKit.EDGE` | **4** | menu chrome: BACK (4,164), page/next button bottom right (R4), tabs (4,4), HEAT button, PAPER button |
| `UIKit.BOTTOM_ROW_Y` | **164** | bottom-row buttons, 13 tall, so B=3 |
| `HUD.POD_MARGIN` (exists) | **3** | in-level HUD pods and the hub ticket/medal pod |
| title label | `(0,2)-(320,22)`, 16 px font | body rows 2..15, drips to 19 |

Deviations:
- Controls page bottom row at y160 (K1).
- Settings BACK as a 120-wide column button at (36,154) (C2).
- Title STORY at y163 (T1).
- Map grid L3/R3 (M3).
- Descent card margins 10 (R5).
- DEV panel R6 (P3).
- Maps HARD checkbox ink R6 and 1 px low (M1).

## 3. Spacing scale

Measured majority:

| Step | Use |
|---|---|
| 2 | between dense tiles (map tiles), header items, HUD pods stacked (VBox gap 2) |
| 3 | stacked menu buttons (pitch 16 = 13 + 3: pause, restart, victory), tile grids (skins, level select) |
| 4 | toggles (HEAT), section tabs (HATS/TRAILS/PAPERS), button to box (save code), key rows (pitch 17) |
| 8 | result choice row, settings column gap, panel inner side inset (HEAT panel, shop) |
| 12 | paired confirm buttons (BUY/BACK, CONFIRM/CANCEL), text line pitch |

Rules:
- Use only 2 / 3 / 4 / 8 / 12 for gaps. Inside one row, all gaps are equal. Deviation: the upgrades row is 3 / 2 / 4 (G2).
- Section gap (between a grid and the panel under it) ≥ 4. Deviation: level select 2 (L7).
- Keep ≥ 2 px of clear space (drips included) between any text and a box edge it doesn't belong to. Deviations: story line
  under the HUD pods 0 px (H5), save-code line under the box 0 px (C1), big level number drips into the record time 0 px (L2).

## 4. Text

- **8 px font** (`pixel.fnt`): 5x7 glyphs. The letter body is 7 rows and the drips hang 2 rows below. The line box is the 7
  px body. The 1 px letter gap sits on each glyph's left, so a left-aligned label's ink starts 1 px inside its rect.
- **16 px font** (`pixel_big.fnt`, `UIKit.use_big_font`): titles and big numbers only. The body is 14 rows and the drips
  hang 4 rows below.
- **Line pitch 12** (7 + `UIKit.LINE_SPACING` 5) for multi-line text. Dense lists may use 11 (coin board 10 rows, map tiles):
  record such exceptions here (U5, M3).
- Vertical centring is measured on the **letter body**, never the drips. In a 13-px button the body is rows 3..9 (3 above,
  3 below).
- Horizontal centring: measured ink is within ±0.5 px of the box centre (0.5 is the odd/even remainder). Centre an icon and
  its text **as one group**, not the text alone. Deviation: HEAT panel title, group 6 px left (L4).
- A fixed-width label that reserves room for longer values (timer, balances) must **centre** its text, or its pod must
  size to content. Deviations: HUD timer pod 4/15 (H1), upgrades balance pod 4/16 (G1).
- Every label in one row shares one baseline. Deviations: hat-wheel header 12 vs 13 (U6), maps bottom bar 167 vs 168 (M1),
  HUD second row 22 vs 21 (H3).
- Text side margin inside a button ≥ 4 px (GooBox face). The longest dynamic text must fit. Deviation: the pause SEED
  button grows to 106 px with a 10-digit seed (P4).
- Size a Label **after** it is added to the themed tree. A label sized before can keep the default font's larger minimum
  width. Deviation: hub quit "THE GAME CLOSES" is 172 wide, 6 px off (U2, X6).
- Roles and colours (recoloured from the skin by `SkinText`):

  | Role | Colour constant | Used for |
  |---|---|---|
  | title | `UIKit.GOLD` | titles, panel headings |
  | text | `UIKit.TEXT` | body text |
  | dim | `UIKit.TEXT_DIM` | hints, secondary lines |
  | disabled | `UIKit.TEXT_OFF` | disabled text |

  Fixed tints: tickets `255,226,150`, HEAT `255,170,90`, DEV badge pink. Labels use a 1 px shadow (`BG` at 0.9), and titles
  use a 2 px shadow straight down.

## 5. Components

### Buttons (`UIKit.make_button`, `GooBox`)

| Kind | Size | Notes |
|---|---|---|
| standard | **h 13** | text body rows 3..9 |
| BACK / short page buttons | **40x13** | |
| tabs | 40-52 x 13 | |
| panel pair | 48x13 (confirm), 64x13 (save code), 70x13 (reset) | |
| result choice row | **84x13**, gap 8, y153 | |
| stacked menu | 100x13 (pause/restart), 120x13 (settings columns, victory) | |
| title CTA | 176x25 | the only tall button |

Deviation: 15 px tall buttons in the hub portal and quit menus and the Descent card and summary (U3, R4, X2) should become 13.

### Panels (`UIKit.add_panel`, `panel_style`)

- GooBox frame. Content margin 6 top, 5 bottom. Centred on screen (`L == R`).
- A button stack inside a panel gets the same insets top and bottom. Deviations:
  - The restart prompt has 20 px of empty face under its last button (P1).
  - The pause and restart stacks sit flush on the goo band (P2).
  - The Descent summary panel is 58 px taller than its text (R2).
  - The portal menu's insets are 10 / 13 (U4).
  - The HEAT panel's insets are 7 / 13 (L6).
- Modal: a dim sheet `Color(0,0,0,0.45)` that takes clicks, plus `UIKit.lock_focus`. A modal that sits over the in-level
  HUD hides the HUD texts that would show through or collide (H7, R1).

### Pods (HUD and hub)

- `hud_pod.png` 9-slice, content margins 4/4/3/3, edge margin 3.
- Height **14** for one line (the 8x8 icon sets it), **23** for two lines. Pods in the same row have equal heights.
  Deviations: the level pod is 13 (H2), so its mirror pod sits 1 px higher (H3). The HEAT pod is 15 (H4).
- Icons in pods are 8x8 (ink ≤ 8x7). Deviation: 9x9 HEAT modifier icons (H4).
- Hub station prompt: GooBox pod, centred at y156 (`PROMPT_Y`), separation 5, even width.

### Icons

- 8x8 UI icons (`assets/ui/icon_*.png`: drop, clock, coin, ticket, medal, lock, check).
- 7x9 flame.
- 16x16 ability and boon icons.
- 18x18 HEAT modifier icons in the panel. Deviation: RACE is 16x16 (L5).

### Tiles and grids

| Grid | Tile | Gap |
|---|---|---|
| level select | 48x42 | 3 |
| skins | 40x30 | 3 |
| map table | 156x26 | 2 |
| shop | 138x13 | 2 |
| HEAT toggles | 84x34 | 4 |
| boon tiles | 96x78 | 6 |

- A grid is centred on the screen or on its panel, ±0.5 px. Deviations: level grid L30/R38 (L1), shop grid L14/R12 inside
  the panel (U7).
- Mirrored badges inside tiles share an inset (level tiles: flame and pips both at 5).

## 6. States

| State | Look (measured) |
|---|---|
| normal | face `#332c40`, goo frame in the skin colour (dark band `#280109` with the default skin) |
| hover | face `#483e5e` and a brighter goo frame |
| pressed | face `#282234` (darker) |
| focus | 1 px ring in the title colour, 1 px outside the button (`expand_margin 1`). Shown for keyboard/gamepad focus only (a mouse click shows none: engine behaviour) |
| disabled | dim face and `TEXT_OFF` text |
| **selected (tabs)** | needs its own style. Today it reuses hover, so a hovered tab looks selected (U8). Proposed: the pressed face plus a title-colour underline or ring |

- Text never moves between states.
- Keep ≥ 2 px between neighbouring buttons so a focus ring never touches the next button (≥ 4 px for touch, see 7).

## 7. Touch

Physical size of 1 game px: about 1.67-2.3 pt/dp on phones (5-6x scale at DPR 2.6-3) and 3-4 pt on tablets.
Target: ≥ 44 pt / 48 dp.

| Control | Size | Status |
|---|---|---|
| JUMP | r19 | ok |
| joystick | r20, knob r8, floats on the left half | ok |
| abilities | r11 drawn, r13 hit | ok |
| pause | 15x13 drawn, +5 hit margin | borderline at 5x |

Rules:
- Mirrored controls share a centre line. Deviation: the joystick centre y140 and JUMP y142 (TC1).
- Menus on touch: 13-px buttons are 22-30 pt tall. Give buttons a hit area ≥ 22 game px tall when touch is active (grow the
  click rect, not the art). Keep ≥ 4 px between neighbouring targets. Deviation: upgrade "-"/"+" 16x13 with a 2 px gap
  (TT1, TT2).
- Touches in the letterbox bars still reach the controls (x < 0 counts as joystick, x > 320 as JUMP). Keep it that way.

## 8. Safe areas

- The web shell uses `viewport-fit=cover`, and there is no safe-area code. Integer pillarboxing keeps the content clear of
  notches and punch-hole cameras on 19.5:9 / 20:9 phones (210-306 px bars).
- Exactly-16:9 phones have no bars. Keep important HUD content ≥ 4 game px (≥ 24 px physical) from corners. The rounded
  corners will still clip the HUD pods' outer corners there (AR3).
- iPhone landscape: the bottom bar (45 px) is narrower than the home-indicator zone (63 px). Keep interactive content at
  y ≤ 176 (AR2).

## 9. Motion

- UI tweens animate modulate/alpha only. The goo wipe is a full-screen shader sheet that hides itself at the end. Any
  future positional tween must end on a whole pixel, at the same position the static layout uses.
