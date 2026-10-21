"""Generates the hat sprites (no dependencies): assets/sprites/hats.png and their dyes, hat_dyes.png.

Run from the project root:  python tools/make_hats.py   (--check: only compare with hats.png)

Hats fit the slime instead of sitting on it: each one's underside is shaped to the slime's dome,
so brims ring the head and caps, helmets and crowns hug down over its top and sides. The dome is
measured off the slime's own sheet (assets/sprites/slime_sheet.png, the same way the game finds
Slime.head_point / head_width), so a hat fits whatever the head looks like.

Because the slime squashes and stretches, every hat comes in five fitted widths plus a loose one,
one row each (the order matches Hats.Width):
  0 NARROW    stretched into a leap, or a little squeezed (head 12 px across)
  1 NORMAL    at rest (13-14 px)
  2 WIDE      squashed flat to charge or land (17+ px)
  3 SQUEEZED  squeezed sideways against a wall in a splat (11 px or less)
  4 BROAD     a little squashed (15-16 px)
  5 LOOSE     off the head (popped off by a leap, or on the hat wheel): its own shape, with the
              dark inside showing where the head would be
Hats.width_for(Slime.head_width) picks the row; WIDTH_CLASSES below must agree with it.

Frames are 32x16, one column per hat (its `column` in scripts/hats.gd). The top of the slime's
head goes on pixel (16, 11) of the frame (HEAD below; x 16 is the line between the two middle
pixels, like the slime's own center), so a hat reaches about 3 px down the dome.

Craft rules (the slime's own): lit from the top-left; every material is a hue-shifted ramp (lights
warmer, shadows cooler, see ramp()); each hat has one dark outline in its main material's hue,
shifted cool like the slime's (never black); no dithering or scattered noise; a few deliberate
details that read at 1x. Hats stay compact: brims 2-3 px past the head at most and nothing much
taller than 7 px above it, so the slime still reads as the star. The rainbow hat (a rainbow
arching over the head from two little clouds) is the rare one on the hat wheel; the game flows its
colors (assets/shaders/rainbow_hat.gdshader).

Two hats are animated (FRAMES): the propeller cap's propeller spins (8 frames, an eighth of a turn
each) and the raincloud rains (4 frames). Frame 0 is the hat's own column (its still frame: the
hat wheel's wedges draw it); the other frames come after every hat's column (columns()), and
Hat._animate plays them (Hats.frames / fps).

The output is a pure function of this file and the slime sheet (deterministic). HATS is in column order (each
hat's `column` in Hats.LIST; LIST itself puts the rainbow hat last, for the wheel).
"""
import colorsys
import json
import math
from pathlib import Path

from upscale_png import read_png, write_png

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites"
W, H = 32, 16
HEAD = (16, 11)  # where the top of the slime's head sits in a frame
CLEAR = (0, 0, 0, 0)
NARROW, NORMAL, WIDE, SQUEEZED, BROAD, LOOSE = range(6)
ROWS = 6
# Head widths (Slime.head_width: 3 px below the top of the body) each fitted row is for.
WIDTH_CLASSES = {SQUEEZED: (0, 11), NARROW: (12, 12), NORMAL: (13, 14), BROAD: (15, 16), WIDE: (17, 99)}
# How tall each width draws its hats (crowns, cones, horns) next to normal: squashed flatter,
# stretched taller.
HEIGHT = {NARROW: 1.08, NORMAL: 1.0, WIDE: 0.84, SQUEEZED: 1.0, BROAD: 0.93, LOOSE: 1.0}
# Animations a hat is worn through (it's popped off for launch and air).
WORN = ("idle", "glide_", "charge_", "land_", "splat_", "recover", "celebrate")


# ---------------------------------------------------------------- the slime's measured head

def body_rows(px, x0, y0, size):
    """The slime body's rows in one sheet frame: [(y, left, right)], from its largest 4-connected
    blob of opaque pixels (so loose sparkles and goo flecks don't count). Matches Slime.gd."""
    solid = {(x, y) for y in range(size) for x in range(size) if px[y0 + y][x0 + x][3] > 127}
    best, seen = set(), set()
    for start in sorted(solid, key=lambda p: (p[1], p[0])):
        if start in seen:
            continue
        blob, todo = set(), [start]
        seen.add(start)
        while todo:
            x, y = todo.pop()
            blob.add((x, y))
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in solid and n not in seen:
                    seen.add(n)
                    todo.append(n)
        if len(blob) > len(best):
            best = blob
    rows = {}
    for x, y in best:
        lo, hi = rows.get(y, (x, x))
        rows[y] = (min(lo, x), max(hi, x))
    return [(y, *rows[y]) for y in sorted(rows)]


def measure_domes():
    """The slime's head per width class, measured over the worn frames of that class:
    `dome`  half-widths on each row down from its top (the median, so the rest pose, by far the
            most seen, fits snugly),
    `span`  its half-width at its widest (in the slimmest frame: brims reach a little past this),
    (Where a frame's eyes sit high, the game lifts the hat just enough to clear them: Hats.lift.)"""
    _, _, px = read_png(str(OUT / "slime_sheet.png"))
    manifest = json.loads((OUT / "slime_sheet.json").read_text())
    size = int(manifest["frame_size"])
    samples = {k: [[] for _ in range(8)] for k in WIDTH_CLASSES}
    spans = {k: [] for k in WIDTH_CLASSES}
    for name, info in manifest["anims"].items():
        if not name.startswith(WORN):
            continue
        for f in range(int(info["frames"])):
            x0, y0 = f * size, int(info["row"]) * size
            rows = body_rows(px, x0, y0, size)
            if len(rows) < 4:
                continue
            head_w = rows[3][2] - rows[3][1] + 1
            cls = next(k for k, (lo, hi) in WIDTH_CLASSES.items() if lo <= head_w <= hi)
            for i in range(8):
                r = rows[min(i, len(rows) - 1)]
                samples[cls][i].append((r[2] - r[1] + 1) / 2.0)
            spans[cls].append(max((r[2] - r[1] + 1) / 2.0 for r in rows))
    heads = {}
    for cls, per_row in samples.items():
        d = [sorted(v)[len(v) // 2] for v in per_row]
        for i in range(1, len(d)):  # a dome never gets narrower going down
            d[i] = max(d[i], d[i - 1])
        heads[cls] = {"dome": d, "span": min(spans[cls])}
    heads[LOOSE] = heads[NARROW]
    return heads


# ---------------------------------------------------------------- colors

def rgb(r, g, b):
    return (r, g, b, 255)


def _hsv(r, g, b, dh, ds, dv, add=0.0):
    hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    r2, g2, b2 = colorsys.hsv_to_rgb((hh + dh) % 1.0, max(0.0, min(1.0, s * ds)), max(0.0, min(1.0, v * dv + add)))
    return rgb(round(r2 * 255), round(g2 * 255), round(b2 * 255))


def ramp(r, g, b):
    """A material's four shades, lit to shadow: [light, mid, dark, deep]. Lights drift warmer and
    paler, shadows cooler and richer (Skins.shades' recipe, toned down for cloth and metal)."""
    return [_hsv(r, g, b, 0.025, 0.75, 1.12, 0.08), rgb(r, g, b), _hsv(r, g, b, -0.03, 1.08, 0.72),
            _hsv(r, g, b, -0.06, 1.12, 0.5)]


def ink(r, g, b):
    """A hat's outline: its main material taken very dark and shifted cool, like the slime's
    outline (Skins.shades outline); greys and whites get a cool blue-violet."""
    hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.15:
        hh, s = 0.68, 0.45
    r2, g2, b2 = colorsys.hsv_to_rgb((hh - 0.06) % 1.0, min(1.0, max(0.5, s * 1.2)), max(0.13, v * 0.2))
    return rgb(round(r2 * 255), round(g2 * 255), round(b2 * 255))


FELT = ramp(66, 58, 86)
RIBBON = ramp(200, 52, 66)
KNIT = ramp(206, 64, 70)
CREAM = [rgb(255, 254, 246), rgb(236, 236, 244), rgb(204, 208, 228), rgb(164, 168, 198)]
GOLD = [rgb(255, 242, 170), rgb(246, 196, 82), rgb(204, 132, 46), rgb(142, 78, 34)]
LEATHER = ramp(164, 106, 62)
PURPLE = ramp(124, 78, 196)
BLUE = ramp(62, 116, 214)
METAL = [rgb(214, 222, 236), rgb(150, 160, 186), rgb(106, 114, 146), rgb(70, 74, 104)]
BONE = [rgb(252, 244, 222), rgb(222, 204, 166), rgb(176, 152, 116)]
RED = ramp(220, 60, 72)
YELLOW = ramp(244, 200, 64)
GREEN = ramp(76, 176, 92)
VELVET = ramp(150, 30, 60)
RUBY, SAPPHIRE, EMERALD = rgb(236, 56, 84), rgb(84, 150, 246), rgb(74, 206, 120)
WIZARD_TRIM = YELLOW            # the wizard hat's band and stars (a dye can swap it: DYE_CLASH)
BLADE_A, BLADE_B = RED, YELLOW  # the propeller's two blades (dyed together: DYEABLE)


class Hat:
    """One hat at one width: a 32x16 grid, the dome it fits, and helpers to paint shaded shapes."""

    def __init__(self, width: int, head: dict, frame: int = 0):
        self.width = width
        self.px = [[CLEAR] * W for _ in range(H)]
        self.dome = head["dome"]
        self.rx = max(self.dome[:5])              # the head's half-width near its top
        self.span = head["span"]                  # ...and at its widest: brims reach past this
        self.sx = self.rx / NORMAL_RX             # how much wider than normal
        self.sy = HEIGHT[width]
        self.cx, self.top = HEAD
        self.frame = frame                        # which frame of an animated hat
        self.ink = rgb(30, 20, 30)
        self.lining = rgb(24, 18, 30)

    def put(self, x, y, col):
        if 0 <= x < W and 0 <= y < H and col is not None:
            self.px[y][x] = col

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < W and 0 <= y < H else CLEAR

    def filled(self, x, y):
        return self.get(x, y)[3] > 0

    def Y(self, dy: float) -> float:
        """A vertical offset from the top of the head, scaled to this height."""
        return self.top + dy * self.sy

    def dome_width(self, y: float) -> float:
        """Half-width of the slime's head at row y (pixel center y; 0 above its top)."""
        i = math.floor(y - self.top)
        if i < 0:
            return 0.0
        return self.dome[min(i, len(self.dome) - 1)]

    def on_head(self, x: float, y: float) -> bool:
        return abs(x - self.cx) < self.dome_width(y)

    def shape(self, test, ramp_, light="dome"):
        """Paints every pixel where test(x, y) is true, shaded across the shape by `ramp_`, lit
        from the top-left: 'dome' (round), 'cyl' (an upright cylinder: lit down its left side) or
        'flat' (a brim: its top edge lit, its underside dark)."""
        pts = [(x, y) for y in range(H) for x in range(W) if test(x + 0.5, y + 0.5)]
        if not pts:
            return []
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        n = len(ramp_)
        for x, y in pts:
            u = (x - x0 + 0.5) / (x1 - x0 + 1) * 2 - 1
            v = (y - y0 + 0.5) / (y1 - y0 + 1) * 2 - 1
            if light == "cyl":
                lit = -u * 0.9 - v * 0.2
                idx = 0 if lit > 0.5 else 1 if lit > -0.25 else 2 if lit > -0.7 else 3
            elif light == "flat":
                top = (x, y - 1) not in pts
                idx = 0 if top and u < 0.2 else 1 if top or y < y1 else 2
                if idx == 1 and u > 0.75:
                    idx = 2
            else:
                lit = -u * 0.62 - v * 0.62
                idx = 0 if lit > 0.42 else 1 if lit > -0.15 else 2 if lit > -0.6 else 3
            self.put(x, y, ramp_[min(idx, n - 1)])
        return pts

    def ellipse(self, cx, cy, rx, ry, ramp_, **kw):
        return self.shape(lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0, ramp_, **kw)

    def cap(self, rise: float, down: float, ramp_, extra=0.6, light="dome", thick=1.5):
        """A cap hugging the head: its crown is the dome raised `rise` px (rounded like the head),
        and lower down it stays within `thick` px of the head (plus `extra` on each side), down to
        `down` px below the top of the head. So it wraps round the head instead of mushrooming."""
        lift = rise * self.sy
        y_bot = self.top + down * min(1.0, self.sy)  # (a stretched head is taller: don't reach further down it)

        def inside(x, y):
            if y > y_bot:
                return False
            crown = self.dome_width(y + lift)
            if crown > 0:  # never a pointy top, even on a narrow squeezed head
                crown = max(crown, self.rx * 0.6)
            if crown > 0 and self.dome_width(y + lift - 1) == 0:  # round off the very top row
                crown = max(1.5, crown - 1.5)
            hug = max(self.dome_width(y + thick), self.rx * 0.6)
            return crown > 0 and abs(x - self.cx) <= min(crown, hug) + extra
        return self.shape(inside, ramp_, light=light)

    def recolor(self, test, col):
        """Repaints already-painted pixels where test(x, y, old_color) holds (pixel coords)."""
        for y in range(H):
            for x in range(W):
                if self.filled(x, y) and test(x, y, self.px[y][x]):
                    self.px[y][x] = col(x, y, self.px[y][x]) if callable(col) else col

    def finish(self):
        """The loose version shows its dark inside where the head would be; then the outline."""
        if self.width == LOOSE:
            for y in range(self.top, H):
                xs = [x for x in range(W) if self.filled(x, y)]
                if not xs:
                    continue
                for x in range(xs[0], xs[-1] + 1):
                    if not self.filled(x, y) and self.on_head(x + 0.5, y + 0.5):
                        self.put(x, y, self.lining)
        filled = {(x, y) for y in range(H) for x in range(W) if self.filled(x, y)}
        for y in range(H):
            for x in range(W):
                if (x, y) not in filled and any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.px[y][x] = self.ink


def fx(v: float) -> int:
    return math.floor(v)


# ---------------------------------------------------------------- the hats

def top_hat(h: Hat):
    h.ink, h.lining = ink(*FELT[1][:3]), FELT[3]
    brim_y = h.Y(1.3)
    h.ellipse(h.cx, brim_y, h.span + 1.6, 1.3, FELT, light="flat")              # brim ringing the head
    half = max(2.5, round(h.rx * 0.7 * 2) / 2)                               # crown: an upright cylinder
    h.shape(lambda x, y: abs(x - h.cx) <= half and h.Y(-6.0) <= y <= brim_y - 0.5, FELT, light="cyl")
    h.recolor(lambda x, y, c: abs(x + 0.5 - h.cx) <= half and h.Y(-1.7) <= y + 0.5 <= h.Y(-0.2),   # band
              lambda x, y, c: RIBBON[0] if x + 0.5 < h.cx - half + 2 else RIBBON[1] if x + 0.5 < h.cx + half - 1.5 else RIBBON[2])
    if half >= 4:                                                             # gold buckle on the band
        bx, by = fx(h.cx + half * 0.35), fx(h.Y(-1.0))
        h.put(bx, by, GOLD[0])
        h.put(bx + 1, by, GOLD[2])
    for y in range(fx(h.Y(-5.5)), fx(h.Y(-2.0))):                             # sheen down the crown
        h.put(fx(h.cx - half + 1.5), y, FELT[0])
    h.finish()


def beanie(h: Hat):
    h.ink, h.lining = ink(*KNIT[1][:3]), KNIT[3]
    h.cap(4.0, 3.4, KNIT, extra=0.6)                                         # knit dome hugging the head
    cuff_y = fx(h.Y(0.6))
    h.recolor(lambda x, y, c: y >= cuff_y,                                    # ribbed cuff, folded up
              lambda x, y, c: KNIT[2] if (x - fx(h.cx)) % 2 == 1 else KNIT[0] if x + 0.5 < h.cx - h.rx * 0.3 else KNIT[1])
    h.recolor(lambda x, y, c: y == cuff_y - 1 and h.get(x, y + 1) in KNIT, KNIT[3])   # the fold's shadow
    h.ellipse(h.cx, h.Y(-3.6) - 0.6, 1.6 if h.width != SQUEEZED else 1.2, 1.4, CREAM)  # pompom
    h.finish()


def party_hat(h: Hat):
    h.ink, h.lining = ink(*BLUE[1][:3]), BLUE[3]
    tip = (h.cx, h.Y(-6.8))                                                   # (a 2 px tip: centered)
    base_y, half = h.Y(1.2), max(2.5, h.rx * 0.78)

    def cone(x, y):
        if not (tip[1] <= y <= base_y):
            return False
        t = (y - tip[1]) / (base_y - tip[1])
        return abs(x - (tip[0] + (h.cx - tip[0]) * t)) <= half * t + 0.5
    pts = h.shape(cone, YELLOW, light="cyl")
    bottom = max(y for x, y in pts)
    stripes = {fx(tip[1] + (base_y - tip[1]) * t) for t in (0.42, 0.74)}
    for x, y in pts:
        if y == bottom:                                                       # red rim
            h.put(x, y, RED[1] if x + 0.5 < h.cx + half * 0.4 else RED[2])
        elif y in stripes:                                                    # two bands round the cone
            h.put(x, y, BLUE[0] if x + 0.5 < h.cx - 1 else BLUE[1] if x + 0.5 < h.cx + half * 0.5 else BLUE[2])
    h.ellipse(tip[0], tip[1] - 0.6, 1.4, 1.3, RED)                            # pompom
    h.finish()


def baseball_cap(h: Hat):
    h.ink, h.lining = ink(*BLUE[1][:3]), BLUE[3]
    crown = h.cap(4.0, 1.4, BLUE, extra=0.5)                                  # crown hugging the head
    c = fx(h.cx)                                                              # (pixels c-1, c: the middle two)
    top = min(y for x, y in crown)
    h.put(c - 1, top, BLUE[0])                                                # button on top, 2 px: centered
    h.put(c, top, BLUE[1])
    b0 = max(y for x, y in crown)                                             # the bill, out over the brow:
    half = (max(x for x, y in crown if y == b0) - min(x for x, y in crown if y == b0) + 1) / 2
    h.recolor(lambda x, y, col: y == b0, BLUE[3])                             # the crown's band in its shadow,
    for k, (reach, shade) in enumerate(((half - 0.6, 0), (half - 3.4, 2)), start=1):  # the bill's lit top
        for x in range(W):                                                    # curving down in front
            u = (x + 0.5 - h.cx) / reach
            if abs(u) <= 1.0:
                h.put(x, b0 + k, BLUE[shade] if shade or u < 0.3 else BLUE[1])
    if h.width != SQUEEZED:                                                   # a white badge on the front
        for x in (c - 1, c):
            h.put(x, b0 - 2, CREAM[0] if x < c else CREAM[1])
    h.finish()


def cowboy_hat(h: Hat):
    h.ink, h.lining = ink(*LEATHER[1][:3]), LEATHER[3]
    brim_y = h.Y(1.4)
    reach = h.span + 1.9
    brim = h.ellipse(h.cx, brim_y, reach, 1.4, LEATHER, light="flat")         # brim round the head
    for x, y in brim:                                                         # its tips curl up
        if abs(x + 0.5 - h.cx) > reach - 1.2 and y == min(yy for xx, yy in brim if xx == x):
            h.put(x, y - 1, LEATHER[0] if x + 0.5 < h.cx else LEATHER[1])
    crown_half = max(2.5, h.rx * 0.66)

    def crown(x, y):
        if not (h.Y(-4.6) <= y <= brim_y - 0.5):
            return False
        hw = crown_half + (y - h.Y(-4.6)) * 0.12
        pinch = abs(x - h.cx) < 1.0 and y < h.Y(-3.6)                         # the crease on top
        return abs(x - h.cx) <= hw and not pinch
    h.shape(crown, LEATHER, light="cyl")
    h.recolor(lambda x, y, c: c in LEATHER and h.Y(-1.0) <= y + 0.5 <= h.Y(0.2) and abs(x + 0.5 - h.cx) <= crown_half + 1,
              lambda x, y, c: LEATHER[3] if x + 0.5 > h.cx + 1 else LEATHER[2])  # hat band
    h.put(fx(h.cx - crown_half * 0.4), fx(h.Y(-0.4)), METAL[0])              # silver concho
    h.finish()


def chef_hat(h: Hat):
    h.ink, h.lining = ink(*CREAM[2][:3]), CREAM[3]
    band = h.cap(0.6, 2.0, CREAM, extra=0.5, light="cyl")                     # band round the head
    for x, y in band:                                                         # pleats
        if (x - fx(h.cx)) % 3 == 1 and h.Y(0.4) <= y + 0.5:
            h.put(x, y, CREAM[2])
    puff = max(2.2, h.rx * 0.42)                                              # three puffs on top
    sides = set()
    for dx in (-1, 1):
        sides |= set(h.ellipse(h.cx + dx * puff * 1.1, h.Y(-2.2), puff + 0.4, 2.2 * h.sy, CREAM))
    middle = set(h.ellipse(h.cx, h.Y(-3.4), puff + 0.3, 2.3 * h.sy, CREAM))
    for x, y in middle:                                                       # creases where the puffs meet
        if any((x + dx, y + dy) in sides - middle for dx, dy in ((1, 0), (-1, 0), (0, 1))) and y < fx(h.Y(-0.4)):
            h.put(x, y, CREAM[2])
    h.finish()


def wizard_hat(h: Hat):
    h.ink, h.lining = ink(*PURPLE[1][:3]), PURPLE[3]
    h.ellipse(h.cx, h.Y(1.4), h.span + 1.8, 1.3, PURPLE, light="flat")         # brim round the head
    base_y, half = h.Y(0.9), max(2.5, h.rx * 0.74)
    tip_y = h.Y(-8.0)

    def cone(x, y):
        if not (tip_y <= y <= base_y):
            return False
        t = (y - tip_y) / (base_y - tip_y)
        lean = (1 - t) ** 2 * 3.2 * min(1.0, h.sx)                            # the tip flops over
        return abs(x - (h.cx + lean)) <= half * t + 0.5
    h.shape(cone, PURPLE, light="cyl")
    h.recolor(lambda x, y, c: y == fx(h.Y(0.2)) and c in PURPLE[:3] and abs(x + 0.5 - h.cx) < half,  # gold band
              lambda x, y, c: WIZARD_TRIM[0] if x + 0.5 < h.cx else WIZARD_TRIM[1])
    if h.width != SQUEEZED:                                                   # a star
        sx, sy = fx(h.cx + half * 0.3), fx(h.Y(-3.4))
        h.put(sx, sy, WIZARD_TRIM[0])
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if h.get(sx + dx, sy + dy) in PURPLE:
                h.put(sx + dx, sy + dy, WIZARD_TRIM[1])
    h.finish()


# A viking horn, the left one, as pixels up from its root on the helmet's shoulder: (dx out, dy up,
# shade: 0 lit, 1 mid, 2 dark). Out and up from the helmet, the tip turning upright: a crescent.
HORNS = {
    "big": [(0, 0, 1), (1, 0, 0), (0, 1, 0), (1, 1, 1), (2, 1, 0), (2, 2, 1), (3, 2, 0), (3, 3, 0), (3, 4, 1)],
    "low": [(0, 0, 1), (1, 0, 0), (0, 1, 0), (1, 1, 1), (2, 1, 0), (2, 2, 1), (3, 2, 0), (3, 3, 1)],
    "small": [(0, 0, 1), (1, 0, 0), (1, 1, 1), (2, 1, 0), (2, 2, 1)],
}


def viking_helmet(h: Hat):
    h.ink, h.lining = ink(*METAL[2][:3]), METAL[3]
    h.cap(3.6, 3.4, METAL, extra=0.5)                                         # dome helmet over the head
    rim_y = fx(h.Y(1.0))
    c = fx(h.cx)                                                              # (pixels c-1, c: the middle two)
    h.recolor(lambda x, y, col: y >= rim_y,                                   # riveted brass rim
              lambda x, y, col: GOLD[0] if y == rim_y and (x - c) % 3 == 1 else GOLD[1] if x + 0.5 < h.cx + 2 else GOLD[2])
    h.recolor(lambda x, y, col: x in (c - 1, c) and y < rim_y,               # crest ridge, 2 px: centered
              lambda x, y, col: METAL[0] if x == c - 1 else METAL[1])
    root_y = fx(h.Y(-0.6))                                                    # horns from the helmet's shoulders
    xs = [x for x in range(W) if h.filled(x, root_y)]
    horn = HORNS["small" if h.width == SQUEEZED else "low" if h.width == WIDE else "big"]
    for dx, dy, shade in horn:                                                # left, then mirrored on the right
        h.put(xs[0] - dx, root_y - dy, BONE[shade])
        h.put(W - 1 - (xs[0] - dx), root_y - dy, BONE[min(2, shade + 1)])
    h.finish()


PROPELLER_FRAMES = 8


def propeller_cap(h: Hat):
    h.ink, h.lining = ink(*BLUE[1][:3]), BLUE[3]
    pts = h.cap(3.4, 3.0, BLUE, extra=0.5)
    panels = [RED, YELLOW, BLUE, GREEN]
    rows = {}
    for x, y in pts:
        lo, hi = rows.get(y, (x, x))
        rows[y] = (min(lo, x), max(hi, x))
    top, bottom = min(rows), max(rows)
    for x, y in pts:                                                          # four panels meeting at the top
        lo, hi = rows[y]
        u = (x + 0.5 - h.cx) / ((hi - lo + 1) / 2)                            # -1 .. 1 across this row
        v = (y - top) / max(1, bottom - top) * 2 - 1
        r = panels[max(0, min(3, int((u + 1) * 2)))]
        lit = -u * 0.8 - v * 0.3
        h.put(x, y, r[0] if lit > 0.5 else r[1] if lit > -0.45 else r[2])
    c = fx(h.cx)                                                              # (pixels c-1, c: the middle two)
    h.put(c - 1, top, METAL[0])                                               # button and stem: 2 px wide
    h.put(c, top, METAL[1])
    for y in (top - 1, top - 2):
        h.put(c - 1, y, METAL[1])
        h.put(c, y, METAL[2])
    hub = top - 3                                                             # hub, and the blades
    h.put(c - 1, hub, METAL[0])
    h.put(c, hub, METAL[1])
    for dx, dy, col in propeller_blades(h.width, h.frame, c):
        h.put(c + dx, hub + dy, col)
    h.finish()


def propeller_blades(width: int, frame: int, c: int):
    """The propeller's blades in turn `frame` of PROPELLER_FRAMES (an eighth of a turn apart; the
    game spins through them, faster as the slime moves and leaps): [(dx, dy from the hub, color)].
    The disc they turn in is seen tipped, its left side away from us (frame 0, the hat's still
    frame: the red blade out left, tipped up; the yellow out right, tipped down), so a blade's tip
    sits a px up behind the stem and a px down in front of it; edge on, the far blade peeks over the
    hub and the near one covers the top of the stem."""
    out = []
    for blade, angle in ((BLADE_A, 180 - 45 * frame), (BLADE_B, -45 * frame)):
        a = math.radians(angle)
        x, depth = math.cos(a), math.sin(a)                                   # -1 left .. 1 right; 1 far
        dy = max(-1, min(1, round(x - depth + 0.001 * x)))                    # where the tip sits, up or down
        side = -1 if x < 0 else 1
        lit, shade = (blade[0], blade[1]) if side < 0 else (blade[1], blade[2])
        def at(dx):                                                           # dx out from the hub's side
            return dx if side > 0 else -1 - dx
        if abs(x) < 0.3:                                                      # edge on, 2 px over the stem
            out.append((depth, [(-1, dy, blade[2] if depth > 0 else blade[0]), (0, dy, blade[2] if depth > 0 else blade[1])]))
        elif width == SQUEEZED:
            px = [(at(1), 0, lit)] + ([(at(2), dy, shade)] if abs(x) > 0.9 else [])
            out.append((depth, px))
        elif abs(x) > 0.9:                                                    # side on: long, its tip a px up or down
            out.append((depth, [(at(1), 0, lit), (at(2), 0, lit), (at(2), dy, lit), (at(3), dy, shade)]
                        if side < 0 else [(at(1), 0, lit), (at(2), 0, lit), (at(2), dy, shade), (at(3), dy, shade)]))
        elif dy:                                                              # turned away or towards us: shorter
            out.append((depth, [(at(1), 0, lit), (at(1), dy, lit), (at(2), dy, shade)]))
        else:
            out.append((depth, [(at(1), 0, lit), (at(2), 0, shade)]))
    out.sort(key=lambda d: -d[0])                                             # the far blade first
    return [p for _, px in out for p in px]


def crown(h: Hat):
    h.ink, h.lining = ink(*GOLD[2][:3]), VELVET[3]
    h.cap(2.8, -0.6, VELVET, extra=-0.5)                                        # velvet cap inside
    points = 3                                                                # (more would just read as noise at 1x)
    y_tip, y_base = h.Y(-4.0), h.Y(-1.2)

    def ring(x, y):
        if not (y_tip <= y <= h.Y(1.6)):
            return False
        hw = max(h.dome_width(y), h.rx * 0.7) + 0.6
        if abs(x - h.cx) > hw:
            return False
        if y < y_base and h.width == SQUEEZED:                                # (no room to taper: three prongs)
            return y >= y_tip + (0 if abs(x - h.cx) <= 1.0 else 1) and (abs(x - h.cx) <= 1.0 or abs(x - h.cx) >= hw - 1.0)
        if y < y_base:                                                        # three points, the middle one tallest
            for c, tip in ((0.0, y_tip), (-(hw - 1.1), y_tip + 0.6), (hw - 1.1, y_tip + 0.6)):
                if y >= tip:
                    t = (y_base - y) / (y_base - tip)                         # 0 at the base, 1 at the tip
                    if abs(x - (h.cx + c)) <= (0.9 + hw * 0.1) * (1 - t) + 0.5:
                        return True
            return False
        return True
    h.shape(ring, GOLD, light="cyl")
    jy = fx(h.Y(0.0))                                                         # jewels on the band
    gems = ((0.0, RUBY),) if h.width == SQUEEZED else ((-0.55, SAPPHIRE), (0.0, RUBY), (0.55, EMERALD))
    for dx, col in gems:
        xs = [fx(h.cx) - 1, fx(h.cx)] if dx == 0 else [fx(h.cx + dx * h.rx - 0.5) + (1 if dx > 0 else 0)]
        for x in xs:                                                          # (the middle one 2 px, so it's centered)
            if h.get(x, jy) in GOLD:
                h.put(x, jy, col)
    h.finish()


# The rainbow's bands, outside in; the game turns their hues round so the rainbow flows.
RAINBOW = [rgb(236, 64, 76), rgb(246, 142, 52), rgb(252, 222, 74), rgb(92, 204, 96), rgb(70, 140, 236),
           rgb(150, 92, 220)]
CLOUD = CREAM


def rainbow_hat(h: Hat):
    # A rainbow arching over the head, its feet in two little clouds resting on the dome's sides.
    h.ink, h.lining = ink(110, 70, 160), rgb(40, 30, 60)
    cx, cy = h.cx, h.Y(1.4)
    ox, oy = h.rx + 0.6, 6.6 * h.sy                                          # outer edge of the arch
    bands = min(len(RAINBOW), max(3, fx(min(ox, oy) - 1.5)))
    for x in range(W):
        for y in range(H):
            if y + 0.5 > cy:
                continue
            u, v = (x + 0.5 - cx) / ox, (y + 0.5 - cy) / oy
            d = math.sqrt(u * u + v * v)                                      # 1 at the outer edge
            k = int((1 - d) * min(ox, oy))                                    # ~1 px bands
            if d <= 1.0 and k < bands:
                h.put(x, y, RAINBOW[k])
    for side in (-1, 1):                                                      # the clouds
        cloud_x = cx + side * (ox - 1.8)
        h.ellipse(cloud_x, h.Y(1.0), 2.4 * min(1.0, h.sx + 0.15), 1.5, CLOUD)
        h.ellipse(cloud_x - side * 1.2, h.Y(0.0), 1.5, 1.2, CLOUD)
    h.finish()
    if h.width != SQUEEZED:                                                   # a twinkle by the arch
        sx, sy = fx(cx + ox * 0.55), fx(cy - oy - 0.3)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if not h.filled(sx + dx, sy + dy) or h.get(sx + dx, sy + dy) == h.ink:
                h.put(sx + dx, sy + dy, CLOUD[0] if (dx, dy) == (0, 0) else YELLOW[0])


# A rain cloud: soft cool greys (lit warm-white on its top-left bumps, a blue-grey belly) and
# rain drops in a pale sky blue that reads on every skin and in the dark.
STORM = [rgb(236, 238, 248), rgb(190, 196, 216), rgb(140, 148, 178), rgb(104, 110, 146)]
RAIN = [rgb(196, 232, 255), rgb(108, 170, 236)]
RAIN_FRAMES = 4


# The cloud's shape at each width, its bottom row on top of the 3 px of rain over the head: a big
# puff in the middle between two small ones (the notches between them read as its outline), a
# rounded underside. Drawn by hand (a cloud of circles came out a lumpy hill at this size); as
# wide as the head, so its outline is at most a px past it. Flying (LOOSE) it keeps its NORMAL shape.
CLOUDS = {
    SQUEEZED: ["...###...",
               ".##.####.",
               "#########",
               ".#######."],
    NARROW: ["....####....",
             ".##.#####.#.",
             "############",
             ".##########."],
    NORMAL: [".....####.....",
             "..##.#####.##.",
             ".############.",
             "##############",
             ".############."],
    BROAD: ["......####......",
            "..###.######.##.",
            ".##############.",
            "################",
            ".##############."],
    WIDE: ["......######......",
           "..###.#######.###.",
           "##################",
           ".################."],
}
CLOUDS[LOOSE] = CLOUDS[NORMAL]


def raincloud(h: Hat):
    # A little cloud hovering 3 px over the head, raining on it: each drop falls out of the
    # cloud's belly and splashes on the head just above its outline (never on the face), the
    # three a phase apart, so some rain is always falling (RAIN_FRAMES frames, looped).
    h.ink, h.lining = ink(*STORM[2][:3]), STORM[3]
    mask = CLOUDS[h.width]
    belly = h.top - 5                                                         # its bottom row: 3 px of rain under its outline
    left = fx(h.cx) - len(mask[0]) // 2
    cloud = {(left + i, belly - len(mask) + 1 + j) for j, row in enumerate(mask) for i, ch in enumerate(row) if ch == "#"}
    right = max(x for x, y in cloud)
    for x, y in cloud:                                                        # lit from the top-left:
        u = (x - left) / max(1, right - left)                                 # 0 at its left, 1 at its right
        if y == belly:
            col = STORM[3] if u > 0.6 else STORM[2]                           # the shadowed belly
        elif (x, y - 1) not in cloud:
            col = STORM[0] if u < 0.75 else STORM[1]                          # the tops of the puffs
        elif (x + 1, y) not in cloud or (u > 0.8 and (x, y + 1) not in cloud):
            col = STORM[2]                                                    # its shaded right side
        elif u < 0.25 and (x - 1, y) not in cloud:
            col = STORM[0]
        else:
            col = STORM[1]
        h.put(x, y, col)
    h.finish()
    c = fx(h.cx)
    spread = 2 if h.width in (SQUEEZED, NARROW) else 3                         # (over the flat top of the head)
    for k, dx in enumerate((-spread, 0, spread - 1)):                         # three drops, staggered
        x = c + dx

        def land(xx):                                                         # the head's outline in column xx
            return h.top + 1 if h.width == LOOSE else next((y for y in range(h.top, H) if h.on_head(xx + 0.5, y + 0.5)), H)
        phase = (h.frame + k * 3) % RAIN_FRAMES
        fall = list(range(belly + 2, land(x)))                                # rows between cloud and head
        if phase < 2 and len(fall) >= 2:                                      # falling: a 2 px streak, out
            y = fall[0] if phase == 0 else fall[-2]                           # of the cloud, then down onto the head
            h.put(x, y, RAIN[1])
            h.put(x, y + 1, RAIN[0])
        elif phase == 2 and h.width != LOOSE:                                 # a splash on the head, hugging it
            level = [xx for xx in (x - 1, x, x + 1) if land(xx) == land(x)]   # (only where it's as high:
            for xx in level:                                                  # on a narrow top, a spurt up)
                h.put(xx, land(x) - 1, RAIN[0] if xx != x else RAIN[1])
            if len(level) == 1:
                h.put(x, land(x) - 2, RAIN[0])


HATS = [top_hat, beanie, party_hat, baseball_cap, cowboy_hat, chef_hat, wizard_hat, viking_helmet,
        propeller_cap, crown, rainbow_hat, raincloud]
# Animated hats: how many frames each has. Frame 0 is in the hat's own column (HATS order, and
# its still frame: the hat wheel's wedges); the rest follow every hat's column, hat by hat in
# HATS order (Hats.LIST `anim_column`).
FRAMES = {propeller_cap: PROPELLER_FRAMES, raincloud: RAIN_FRAMES}

HEADS = measure_domes()
NORMAL_RX = max(HEADS[NORMAL]["dome"][:5])


def columns():
    """The sheet's columns: (hat, frame), every hat's frame 0 first, then the animated hats' others."""
    out = [(make, 0) for make in HATS]
    for make in HATS:
        out += [(make, f) for f in range(1, FRAMES.get(make, 1))]
    return out


def build():
    """Every hat at every width: rows of RGBA pixels for the whole sheet."""
    rows = []
    for width in range(ROWS):
        frames = []
        for make, frame in columns():
            hat = Hat(width, HEADS[width], frame)
            make(hat)
            frames.append(hat.px)
        for y in range(H):
            rows.append([p for frame in frames for p in frame[y]])
    return rows


# ---------------------------------------------------------------- dyes (assets/sprites/hat_dyes.png)
# Hat dyes, bought with tickets in the hat wheel's SHOP (Hats.DYES: the same ids in the same order).
# Each dye redraws the dyeable hats with one material swapped for the dye's ramp (so the shading,
# outline and lining follow it, as if the hat had been drawn in that color). hat_dyes.png is a block
# of ROWS x 16 px per dye, in DYES order, laid out like hats.png (same columns), with only the
# dyeable hats drawn: Hats.dye_region = Hats.region moved down by the dye's block.
DYES = [
    ("cherry", (206, 52, 62)),
    ("tangerine", (232, 128, 48)),
    ("butter", (240, 204, 76)),
    ("clover", (72, 168, 84)),
    ("teal", (44, 156, 156)),
    ("cobalt", (62, 110, 214)),
    ("plum", (124, 78, 196)),
    ("bubblegum", (236, 120, 176)),
    ("midnight", (52, 50, 72)),
    ("snow", (232, 232, 240)),
]


def pale_ramp(r, g, b):
    """A soft material's four shades (cloth that is white undyed: the chef hat, clouds): a pale light."""
    return [_hsv(r, g, b, 0.0, 0.25, 1.0, 0.12), rgb(r, g, b), _hsv(r, g, b, -0.03, 1.1, 0.82), _hsv(r, g, b, -0.06, 1.15, 0.64)]


def cloud_ramp(r, g, b, white=0.45):
    """A cloud's shades: the dye taken `white` of the way to white first, so it stays a fluffy pastel."""
    return pale_ramp(*(round(c + (255 - c) * white) for c in (r, g, b)))


def small_cloud_ramp(r, g, b):
    """The rainbow hat's little clouds: less pale than the raincloud, so the dye reads at their size."""
    return cloud_ramp(r, g, b, 0.15)


# Which globals each dyeable hat takes the dye on, and how its ramp is made.
DYEABLE = {
    top_hat: (("FELT",), ramp),
    beanie: (("KNIT",), ramp),
    baseball_cap: (("BLUE",), ramp),
    cowboy_hat: (("LEATHER",), ramp),
    chef_hat: (("CREAM",), pale_ramp),
    wizard_hat: (("PURPLE",), ramp),
    propeller_cap: (("BLADE_A", "BLADE_B"), ramp),   # the propeller (its spinner on top)
    rainbow_hat: (("CLOUD",), small_cloud_ramp),            # its two clouds (not the flowing arch)
    raincloud: (("STORM",), cloud_ramp),
}
# A dye that would hide a detail swaps that detail's material too: (hat, dye) -> {global: ramp}.
DYE_CLASH = {
    (wizard_hat, "butter"): {"WIZARD_TRIM": PURPLE},   # gold band and stars on a yellow hat
    (top_hat, "cherry"): {"RIBBON": FELT},             # a red ribbon on a red hat
}
# The flowing hat's dyed pixels get this alpha: assets/shaders/rainbow_hat.gdshader leaves them as drawn.
KEEP_ALPHA = 254


def draw_dyed(make, width, frame, dye, base):
    names, make_ramp = DYEABLE[make]
    swap = {name: make_ramp(*base) for name in names}
    swap.update(DYE_CLASH.get((make, dye), {}))
    saved = {name: globals()[name] for name in swap}
    globals().update(swap)
    try:
        hat = Hat(width, HEADS[width], frame)
        make(hat)
    finally:
        globals().update(saved)
    if make is rainbow_hat:  # (the clouds keep their dye while the arch's colors flow)
        dyed = set(swap["CLOUD"])
        hat.px = [[(c[0], c[1], c[2], KEEP_ALPHA) if c in dyed else c for c in row] for row in hat.px]
    return hat.px


def build_dyes():
    """Every dye's block: the dyeable hats at every width, the others left clear."""
    rows = []
    blank = [[CLEAR] * W for _ in range(H)]
    for dye, base in DYES:
        for width in range(ROWS):
            frames = [draw_dyed(make, width, frame, dye, base) if make in DYEABLE else blank for make, frame in columns()]
            for y in range(H):
                rows.append([p for frame in frames for p in frame[y]])
    return rows


if __name__ == "__main__":
    import sys
    rows = build()
    dyes = build_dyes()
    if "--check" in sys.argv:  # tests: are the checked-in sheets exactly what this file draws (twice over)?
        _, _, current = read_png(str(OUT / "hats.png"))
        same = [list(map(tuple, r)) for r in current] == rows and build() == rows
        _, _, current = read_png(str(OUT / "hat_dyes.png"))
        same = same and [list(map(tuple, r)) for r in current] == dyes
        print("hats.png and hat_dyes.png are up to date" if same else "hats.png or hat_dyes.png differs from tools/make_hats.py")
        sys.exit(0 if same else 1)
    write_png(str(OUT / "hats.png"), rows)
    write_png(str(OUT / "hat_dyes.png"), dyes)
    print(f"wrote assets/sprites/hats.png ({len(HATS)} hats, {len(columns())} columns x {ROWS} widths, {W}x{H} each)")
    print(f"wrote assets/sprites/hat_dyes.png ({len(DYES)} dyes x {len(DYEABLE)} hats)")
