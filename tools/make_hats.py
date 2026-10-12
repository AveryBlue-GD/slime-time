"""Generates the hat sprites (no dependencies): assets/sprites/hats.png.

Run from the project root:  python tools/make_hats.py

Hats fit the slime instead of sitting on it: each one's underside is shaped to the slime's dome,
so brims ring the head and caps, helmets and crowns hug down over its top and sides. And because
the slime squashes and stretches, every hat comes in three widths (one row each): 0 narrow and
tall (the slime stretched into a leap), 1 normal, 2 wide and flat (squashed to charge or land).
The game picks the row that matches the slime's frame (Slime.head_width).

Frames are 32x16, one column per hat (its `column` in scripts/hats.gd). The top of the slime's
head goes on pixel (16, 11) of the frame (HEAD below), so a hat reaches about 4 px down the dome.
Hats are lit from the top-left like everything else, with a dark warm outline.

Hats stay compact: brims stick out only 2-3 px past the head and nothing towers more than about
7 px above it, so the slime still reads as the star. The rainbow hat (a rainbow arching over the
head from two little clouds) is the rare one on the hat wheel; the game flows its colors.

These are placeholders until the real hat list is decided: change a hat's drawing below and
keep HATS in the same order as Hats.LIST.
"""
import math
from pathlib import Path

from upscale_png import write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
W, H = 32, 16
HEAD = (16, 11)  # where the top of the slime's head sits in a frame
CLEAR = (0, 0, 0, 0)
OUTLINE = (30, 20, 22, 255)
# Widths: (horizontal scale, vertical scale) of the dome the hat fits: stretched, normal, squashed.
WIDTHS = [(0.85, 1.15), (1.0, 1.0), (1.22, 0.82)]
# The slime's dome at normal size, measured off its idle frame: about 16 px wide with a flattish
# top (half-widths 5, 6, 7, 8 px on the four rows under the top of its head).
DOME = (8.0, 5.5)


def rgb(r, g, b):
    return (r, g, b, 255)


# Material ramps, lit (left/top) to shadow (right/bottom).
FELT = [rgb(110, 100, 132), rgb(70, 62, 88), rgb(44, 38, 58), rgb(28, 24, 38)]
RIBBON = [rgb(232, 96, 104), rgb(176, 40, 58), rgb(120, 24, 40)]
KNIT = [rgb(244, 112, 100), rgb(208, 64, 66), rgb(160, 40, 52), rgb(110, 28, 42)]
WHITE = [rgb(255, 255, 255), rgb(236, 236, 242), rgb(206, 208, 220), rgb(160, 164, 182)]
GOLD = [rgb(255, 244, 180), rgb(250, 204, 96), rgb(206, 142, 50), rgb(140, 86, 30)]
LEATHER = [rgb(204, 150, 96), rgb(164, 108, 62), rgb(120, 76, 44), rgb(82, 50, 30)]
PURPLE = [rgb(176, 126, 236), rgb(128, 80, 200), rgb(90, 52, 152), rgb(58, 32, 104)]
BLUE = [rgb(120, 178, 244), rgb(68, 120, 216), rgb(44, 84, 170), rgb(28, 52, 116)]
METAL = [rgb(226, 232, 242), rgb(176, 184, 200), rgb(122, 130, 150), rgb(80, 86, 106)]
BONE = [rgb(250, 242, 220), rgb(214, 198, 164), rgb(170, 152, 118)]
RED = [rgb(232, 72, 84), rgb(178, 36, 52)]
YELLOW = [rgb(255, 228, 110), rgb(232, 180, 50)]
GREEN = [rgb(130, 220, 120), rgb(70, 160, 80)]
VELVET = [rgb(196, 40, 70), rgb(132, 22, 48)]
RUBY, SAPPHIRE, EMERALD = rgb(236, 50, 80), rgb(70, 140, 240), rgb(70, 200, 110)


class Hat:
    """One hat at one width: a 20x16 grid, the dome it fits, and helpers to paint shaded shapes."""

    def __init__(self, sx: float, sy: float):
        self.px = [[CLEAR] * W for _ in range(H)]
        self.sx, self.sy = sx, sy
        self.rx = DOME[0] * sx       # the dome's half-width at this size
        self.ry = DOME[1] * sy
        self.cx, self.top = HEAD

    def put(self, x, y, col):
        if 0 <= x < W and 0 <= y < H and col is not None:
            self.px[y][x] = col

    def get(self, x, y):
        return self.px[y][x] if 0 <= x < W and 0 <= y < H else CLEAR

    def X(self, dx: float) -> float:
        """A horizontal offset from the hat's center, scaled to this width."""
        return self.cx + dx * self.sx

    def Y(self, dy: float) -> float:
        """A vertical offset from the top of the head, scaled to this height."""
        return self.top + dy * self.sy

    def dome_width(self, y: float) -> float:
        """Half-width of the slime's dome at row y (0 above its top)."""
        d = y + 0.5 - self.top
        if d <= 0:
            return 0.0
        return self.rx * math.sqrt(max(0.0, 1 - ((self.ry - d) / self.ry) ** 2))

    def shape(self, test, ramp, light_dir=(-0.7, -0.5)):
        """Paints every pixel where test(x, y) is true, shaded across the shape by `ramp`."""
        pts = [(x, y) for y in range(H) for x in range(W) if test(x + 0.5, y + 0.5)]
        if not pts:
            return []
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        for x, y in pts:
            u = (x - x0 + 0.5) / (x1 - x0 + 1) * 2 - 1
            v = (y - y0 + 0.5) / (y1 - y0 + 1) * 2 - 1
            lit = u * light_dir[0] + v * light_dir[1]
            n = len(ramp)
            idx = 0 if lit > 0.55 else 1 if lit > 0.0 else 2 if lit > -0.55 else 3
            self.put(x, y, ramp[min(idx, n - 1)])
        return pts

    def ellipse(self, cx, cy, rx, ry, ramp, **kw):
        return self.shape(lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0, ramp, **kw)

    def band(self, y0: float, y1: float, ramp, extra: float = 0.7):
        """A band hugging the dome between rows y0 and y1, `extra` px wider than it on each side:
        what makes a hat sit around the head instead of on it."""
        def inside(x, y):
            if not (y0 <= y <= y1):
                return False
            hw = max(self.dome_width(y), self.rx * 0.55) + extra
            return abs(x - self.cx) <= hw
        return self.shape(inside, ramp)

    def outline(self):
        filled = {(x, y) for y in range(H) for x in range(W) if self.px[y][x][3] > 0}
        for y in range(H):
            for x in range(W):
                if (x, y) not in filled and any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.px[y][x] = OUTLINE


# ---------------------------------------------------------------- the hats

def top_hat(h: Hat):
    h.ellipse(h.cx, h.Y(1.6), h.rx + 2.0, 1.8 * h.sy, FELT)                       # brim ringing the head
    h.shape(lambda x, y: abs(x - h.cx) <= h.rx * 0.72 and h.Y(-6.5) <= y <= h.Y(1.2), FELT)  # crown
    for x in range(W):                                                          # red band
        for y in range(H):
            if h.get(x, y) in FELT and h.Y(-1.4) <= y + 0.5 <= h.Y(0.6) and abs(x + 0.5 - h.cx) <= h.rx * 0.72:
                h.put(x, y, RIBBON[0] if x + 0.5 < h.cx else RIBBON[1])
    bx = round(h.cx + h.rx * 0.35)                                              # gold buckle
    by = round(h.Y(-0.5))
    h.put(bx, by, GOLD[1])
    h.put(bx + 1, by, GOLD[2])
    for y in range(round(h.Y(-5.6)), round(h.Y(-2))):                           # sheen down the crown
        h.put(round(h.cx - h.rx * 0.5), y, FELT[0])
    h.outline()


def beanie(h: Hat):
    h.band(h.Y(-3.6), h.Y(1.5), KNIT, extra=0.8)                                # knit dome hugging the head
    h.ellipse(h.cx, h.Y(-0.8), h.rx + 0.6, 4.5 * h.sy, KNIT)
    for x in range(W):                                                          # ribbed cuff
        for y in range(H):
            if h.get(x, y) in KNIT and h.Y(0.4) <= y + 0.5 <= h.Y(3.2):
                h.put(x, y, KNIT[1] if x % 2 == 0 else KNIT[2])
    for x in range(W):                                                          # knit rows
        for y in range(H):
            if h.get(x, y) in KNIT and y + 0.5 < h.Y(0.4) and (x + y) % 3 == 0:
                h.put(x, y, KNIT[2])
    h.ellipse(h.cx, h.Y(-5.6), 2.0, 1.8, WHITE)                                 # pompom
    h.put(round(h.cx) - 1, round(h.Y(-6.3)), WHITE[0])
    h.outline()


def party_hat(h: Hat):
    tip = (h.cx + 1, h.Y(-8.0))
    base_y, half = h.Y(1.3), h.rx * 0.8

    def cone(x, y):
        if not (tip[1] <= y <= base_y):
            return False
        t = (y - tip[1]) / (base_y - tip[1])
        return abs(x - (tip[0] + (h.cx - tip[0]) * t)) <= half * t + 0.4
    pts = h.shape(cone, [YELLOW[0], YELLOW[0], YELLOW[1], YELLOW[1]])
    for x, y in pts:                                                            # diagonal stripes
        if (x + y * 2) % 6 < 2:
            h.put(x, y, BLUE[1] if x + 0.5 < h.cx else BLUE[2])
    for x, y in pts:                                                            # polka dots
        if (x * 7 + y * 5) % 11 == 0:
            h.put(x, y, RED[0])
    h.band(h.Y(0.4), h.Y(1.8), [WHITE[1], WHITE[2], WHITE[3]], extra=0.5)       # elastic rim round the head
    h.ellipse(tip[0], tip[1] - 0.8, 1.6, 1.4, [RED[0], RED[0], RED[1], RED[1]])  # pompom
    h.outline()


def baseball_cap(h: Hat):
    h.band(h.Y(-3.0), h.Y(1.4), BLUE, extra=0.6)                                # crown hugging the head
    h.ellipse(h.cx, h.Y(-0.4), h.rx + 0.5, 3.8 * h.sy, BLUE)
    for x in range(W):                                                          # panel seams
        for y in range(H):
            if h.get(x, y) in BLUE and abs(x + 0.5 - h.cx) < 0.6 and y + 0.5 < h.Y(1.0):
                h.put(x, y, BLUE[3])
    h.ellipse(h.cx + h.rx + 0.5, h.Y(1.0), 2.8, 1.3, BLUE)                      # short brim out to the side
    for x in range(W):                                                          # stitching on the brim
        y = round(h.Y(1.0))
        if h.get(x, y) in BLUE and x + 0.5 > h.cx + h.rx - 0.5 and x % 2:
            h.put(x, y, WHITE[1])
    h.put(round(h.cx), round(h.Y(-4.0)), RED[0])                                # top button
    h.outline()


def cowboy_hat(h: Hat):
    brim = h.ellipse(h.cx, h.Y(1.4), h.rx + 3.0, 2.0 * h.sy, LEATHER)          # brim round the head
    for x, y in brim:                                                           # curled-up edges
        if abs(x + 0.5 - h.cx) > h.rx + 1.8:
            h.put(x, y - 1, LEATHER[1])

    def crown(x, y):
        if not (h.Y(-5.2) <= y <= h.Y(1.0)):
            return False
        hw = h.rx * 0.72 + (y - h.Y(-5.2)) * 0.1
        dent = abs(x - h.cx) < 1.2 and y < h.Y(-4.0)                            # the crease on top
        return abs(x - h.cx) <= hw and not dent
    h.shape(crown, LEATHER)
    for x in range(W):                                                          # band with a silver concho
        for y in range(H):
            if h.get(x, y) in LEATHER and h.Y(-1.2) <= y + 0.5 <= h.Y(0.4) and abs(x + 0.5 - h.cx) <= h.rx * 0.85:
                h.put(x, y, LEATHER[3])
    h.put(round(h.cx - h.rx * 0.3), round(h.Y(-0.5)), METAL[1])
    h.outline()


def chef_hat(h: Hat):
    h.band(h.Y(-2.2), h.Y(1.8), WHITE, extra=0.6)                               # pleated band round the head
    for x in range(W):
        for y in range(H):
            if h.get(x, y) in WHITE and x % 2 == 0 and y + 0.5 > h.Y(-2.0):
                h.put(x, y, WHITE[2])
    for dx, dy, r in ((-3.0, -4.4, 2.7), (3.0, -4.4, 2.7), (0.0, -5.6, 3.1)):   # puffs on top
        h.ellipse(h.X(dx), h.Y(dy), r * min(h.sx, 1.1), r * 0.9, WHITE)
    h.outline()


def wizard_hat(h: Hat):
    h.ellipse(h.cx, h.Y(1.5), h.rx + 2.2, 1.8 * h.sy, PURPLE)                   # brim round the head
    base_y, half = h.Y(1.0), h.rx * 0.78

    def cone(x, y):
        if not (h.Y(-8.5) <= y <= base_y):
            return False
        t = (y - h.Y(-8.5)) / (base_y - h.Y(-8.5))
        lean = (1 - t) ** 2 * 3.5                                               # the tip flops over
        return abs(x - (h.cx + lean)) <= half * t + 0.5
    pts = h.shape(cone, PURPLE)
    for (x, y) in pts:                                                          # stars
        if (x * 5 + y * 3) % 13 == 0:
            h.put(x, y, YELLOW[0])
    mx, my = round(h.cx - 1), round(h.Y(-3.5))                                  # a crescent moon
    h.put(mx, my, YELLOW[0])
    h.put(mx, my + 1, YELLOW[0])
    h.put(mx + 1, my + 2, YELLOW[1])
    h.outline()


def viking_helmet(h: Hat):
    h.band(h.Y(-3.4), h.Y(1.8), METAL, extra=0.6)                               # dome helmet over the head
    h.ellipse(h.cx, h.Y(-0.6), h.rx + 0.5, 4.0 * h.sy, METAL)
    for x in range(W):                                                          # rivet band
        y = round(h.Y(0.8))
        if h.get(x, y) in METAL:
            h.put(x, y, METAL[2] if x % 2 else METAL[0])
    for y in range(round(h.Y(-3.4)), round(h.Y(2.6))):                          # nose guard down the front
        h.put(round(h.cx), y, METAL[3] if y > round(h.Y(1.0)) else METAL[2])
    for side in (-1, 1):                                                        # horns curving up and out
        for i in range(6):
            t = i / 5
            x = h.cx + side * (h.rx + 0.2 + t * 2.2)
            y = h.Y(-1.0) - t * t * 4.5
            col = BONE[0] if i < 2 else BONE[1] if i < 4 else BONE[2]
            h.put(round(x), round(y), col)
            if i < 4:
                h.put(round(x), round(y) + 1, BONE[1] if i < 3 else BONE[2])
    h.outline()


def propeller_cap(h: Hat):
    h.band(h.Y(-3.0), h.Y(1.4), METAL, extra=0.6)
    pts = h.ellipse(h.cx, h.Y(-0.4), h.rx + 0.5, 3.8 * h.sy, METAL)
    panels = [RED, YELLOW, BLUE, GREEN]
    for x in range(W):                                                          # colored panels
        for y in range(H):
            if h.get(x, y) in METAL:
                k = int(((x + 0.5 - h.cx) / (h.rx + 0.5) + 1) * 2)
                ramp = panels[max(0, min(3, k))]
                h.put(x, y, ramp[0] if y + 0.5 < h.Y(-2.0) else ramp[1])
    h.ellipse(h.cx - h.rx - 0.3, h.Y(1.0), 2.2, 1.2, BLUE)                      # little brim
    px, py = round(h.cx), round(h.Y(-4.6))                                      # the propeller
    h.put(px, py + 1, METAL[2])
    for dx in range(1, 4):
        h.put(px - dx, py - (1 if dx > 2 else 0), RED[0] if dx < 2 else RED[1])
        h.put(px + dx, py + (1 if dx > 2 else 0) - 1, YELLOW[0] if dx < 2 else YELLOW[1])
    h.put(px, py, METAL[1])
    h.outline()


def crown(h: Hat):
    h.band(h.Y(-1.0), h.Y(1.0), VELVET, extra=0.5)                              # velvet inside, showing on top
    def ring(x, y):
        if not (h.Y(-4.0) <= y <= h.Y(1.6)):
            return False
        hw = max(h.dome_width(y), h.rx * 0.7) + 0.8
        if abs(x - h.cx) > hw:
            return False
        if y < h.Y(-1.4):                                                       # five points
            phase = (x - (h.cx - hw)) / (2 * hw) * 4
            return abs(phase - round(phase)) < 0.28
        return True
    pts = h.shape(ring, GOLD)
    for x in range(W):                                                          # a bright lower rim
        y = round(h.Y(1.2))
        if h.get(x, y) in GOLD:
            h.put(x, y, GOLD[1])
    for (dx, col) in ((-0.5, RUBY), (0.15, SAPPHIRE), (0.55, EMERALD)):          # jewels
        x = round(h.cx + dx * h.rx)
        y = round(h.Y(-0.4))
        if h.get(x, y) in GOLD:
            h.put(x, y, col)
    h.outline()


# The rainbow's bands, outside in; the game turns their hues round so the rainbow flows.
RAINBOW = [rgb(236, 64, 76), rgb(246, 142, 52), rgb(252, 222, 74), rgb(92, 204, 96), rgb(70, 140, 236),
           rgb(150, 92, 220)]
CLOUD = [rgb(255, 255, 255), rgb(240, 242, 250), rgb(214, 218, 234), rgb(176, 182, 206)]


def rainbow_hat(h: Hat):
    # A rainbow arching over the head, its feet in two little clouds resting on the dome's sides.
    cx, cy = h.cx, h.Y(1.4)
    ox, oy = h.rx + 0.4, 7.4 * h.sy                                             # outer edge of the arch
    for x in range(W):
        for y in range(H):
            if y + 0.5 > cy:
                continue
            u, v = (x + 0.5 - cx) / ox, (y + 0.5 - cy) / oy
            d = math.sqrt(u * u + v * v)                                       # 1 at the outer edge
            k = int((1 - d) * oy / 1.0)                                        # 1 px bands
            if d <= 1.0 and k < len(RAINBOW):
                h.put(x, y, RAINBOW[k])
    for side in (-1, 1):                                                        # the clouds
        fx = cx + side * (ox - 2.4)
        h.ellipse(fx, h.Y(1.0), 2.6, 1.6, CLOUD)
        h.ellipse(fx - side * 1.6, h.Y(0.0), 1.6, 1.3, CLOUD)
    sx, sy = round(cx + ox * 0.45), round(cy - oy - 0.5)                      # a twinkle by the arch
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
        h.put(sx + dx, sy + dy, CLOUD[0] if (dx, dy) == (0, 0) else YELLOW[0])
    h.outline()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):                         # the twinkle floats free
        if h.get(sx + dx, sy + dy) == OUTLINE:
            h.put(sx + dx, sy + dy, CLEAR)


HATS = [top_hat, beanie, party_hat, baseball_cap, cowboy_hat, chef_hat, wizard_hat, viking_helmet,
        propeller_cap, crown, rainbow_hat]


if __name__ == "__main__":
    rows = []
    for sx, sy in WIDTHS:
        frames = []
        for make in HATS:
            hat = Hat(sx, sy)
            make(hat)
            frames.append(hat.px)
        for y in range(H):
            rows.append([p for frame in frames for p in frame[y]])
    write_png(str(OUT / "hats.png"), rows)
    print(f"wrote assets/sprites/hats.png ({len(HATS)} hats x {len(WIDTHS)} widths, {W}x{H} each)")
