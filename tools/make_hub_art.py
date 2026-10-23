"""Generates the hub's station art (no dependencies): assets/sprites/hub/*.png.

Run from the project root:  python tools/make_hub_art.py

The hub is the slime's room: stations stand evenly round its rim, all facing the center, and a
wheel on a stick in the middle turns the room (like turning the camera in Don't Starve). So every
station has three views, one per row of its sheet: front (seen from across the room: the station
at the back), side (drawn facing right; the game mirrors it for the other side) and back (the
stations nearest you). Frames run left to right. Light comes from the top-left, like everywhere
else. Goo is drawn in the slime sheet's goo shades (H/l/m/n/D/G in make_placeholder_art.PAL), so
the skin shader recolors it to the equipped skin; stone stays off the dried-crust greys.
- door.png      30x40 x4 : STORY: a mortared stone archway with moss, wall torches, a skull
                           keystone and steps going down into the dark / a pillar / a studded door;
                           frames: the torches flickering
- portal.png    30x40 x6 : RANDOMIZER: a swirling vortex in a rune-carved stone ring on a stepped
                           plinth / the ring edge-on / its dim back
- wardrobe.png  28x40 x5 : SKINS & HATS: a carved wardrobe with paneled doors, a gilt mirror, a
                           scarf caught in the door and a top hat on top / its side / its back;
                           frames: shut, mirror sparkle (2), right door ajar, wide open
- cauldron.png  30x28 x4 : UPGRADES: a riveted iron cauldron with handles, bubbling goo, coins on
                           the rim, a crackling fire under it (round: the same from every side)
- coinbag.png   24x26 x4 : COIN BAG: a burlap sack tied with rope, a coin emblem, coins spilling
                           out and glinting / its side / its back
- wheel.png     32x40 x24: HAT WHEEL (coming soon): a pegged prize wheel with hat wedges and a
                           flapper on a braced stand / edge-on / its back; a full turn in 24 steps
- signpost.png  24x34 x6 : SETTINGS: two meshed gears on a post with a wrench hanging off it /
                           edge-on / from behind; the gears turning (a looping tooth's worth)
- hatch.png     28x18 x4 : QUIT: an iron-braced trapdoor over a ladder into the dark (flat: the
                           same from every side); frames: shut, lifting, blown open with a puff, open
- maptable.png  30x36 x4 : MAP TABLE: a cartographer's desk: a map pinned on a standing board (an inked maze
                           with a goo trail and a red X), a compass, a quill in a pot of goo, a small
                           lantern and a drawer / the desk side-on (board edge-on) / the board's braced back
                           with a rolled scroll; frames: the lantern flame flickering
- daily_sign.png 16x26 x2 : DAILY MAZE (beside the portal, not on the ring): a small calendar board on a post /
                           edge-on / its plain back; frames: 0 today's daily waits (gold "!" is drawn by the game),
                           1 it was won today (a green check on the page)
- rotor.png     26x36 x4 : the wheel on a stick in the middle: a ship's wheel with handles and a
                           brass hub on a rope-wrapped post, spinning
(The room itself is drawn live by assets/shaders/hub_room.gdshader, so it can turn.)
"""
import math
import random
from pathlib import Path

from make_placeholder_art import PAL
from upscale_png import write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "hub"
CLEAR = (0, 0, 0, 0)


def c(key: str) -> tuple:
    return PAL[key]


def rgb(r: int, g: int, b: int) -> tuple:
    return (r, g, b, 255)


OUTLINE = c("k")
WOOD = [rgb(52, 30, 24), rgb(88, 54, 34), rgb(128, 82, 50), rgb(170, 118, 70), rgb(204, 156, 98)]  # dark -> light
IRON = [rgb(30, 30, 42), rgb(54, 56, 74), rgb(86, 90, 112), rgb(132, 138, 162), rgb(186, 192, 212)]
# Stone a few shades off the palette's: the skin shader treats those exact greys as dried slime
# crust and would recolor them.
STONE = [rgb(46, 54, 74), rgb(72, 88, 112), rgb(104, 124, 148), rgb(140, 164, 184), rgb(184, 200, 214)]
GOO = [c("G"), c("D"), c("n"), c("m"), c("l"), c("H")]  # outline -> highlight (skin-swapped)
GOLD = [rgb(120, 70, 24), c("o"), c("y"), c("Y")]
VOID = [rgb(10, 9, 16), rgb(18, 16, 28), rgb(28, 24, 42), rgb(40, 34, 58)]
MOSS = [c("V"), c("v")]
FIRE = [rgb(150, 40, 20), rgb(226, 96, 30), rgb(255, 176, 60), rgb(255, 236, 150)]
BURLAP = [rgb(78, 58, 36), rgb(116, 88, 54), rgb(154, 120, 76), rgb(190, 156, 104)]
RED = [rgb(120, 24, 36), rgb(176, 40, 54), rgb(220, 80, 90)]
RUNE = [rgb(110, 70, 200), rgb(180, 140, 255)]
BONE = c("u")


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px = [[CLEAR] * w for _ in range(h)]

    def put(self, x: int, y: int, col) -> None:
        if col is not None and 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = col

    def get(self, x: int, y: int) -> tuple:
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def filled(self, x: int, y: int) -> bool:
        return self.get(x, y)[3] > 0

    def rect(self, x: int, y: int, w: int, h: int, col) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, col)

    def hline(self, x0: int, x1: int, y: int, col) -> None:
        for x in range(x0, x1 + 1):
            self.put(x, y, col)

    def vline(self, x: int, y0: int, y1: int, col) -> None:
        for y in range(y0, y1 + 1):
            self.put(x, y, col)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col) -> None:
        """Fills an ellipse; `col` may be a function (x, y, u, v) -> color (None = skip), u/v in -1..1."""
        for y in range(self.h):
            for x in range(self.w):
                u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if u * u + v * v <= 1.0:
                    self.put(x, y, col(x, y, u, v) if callable(col) else col)

    def outline(self, col: tuple = OUTLINE) -> None:
        """A 1 px outline around everything drawn (outside it)."""
        filled = {(x, y) for y in range(self.h) for x in range(self.w) if self.px[y][x][3] > 0}
        for y in range(self.h):
            for x in range(self.w):
                if (x, y) not in filled and any((x + dx, y + dy) in filled for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.px[y][x] = col


def drips(cv: Canvas, x0: int, x1: int, y: int, rng: random.Random, longest: int = 4) -> None:
    """A goo lip along row y from x0 to x1 with drips of random length hanging off it."""
    for x in range(x0, x1 + 1):
        cv.put(x, y - 1, GOO[4])
        cv.put(x, y, GOO[3])
        if rng.random() < 0.35:
            n = rng.randint(1, longest)
            for d in range(1, n + 1):
                cv.put(x, y + d, GOO[3] if d < n else GOO[2])
            cv.put(x, y + n + 1, GOO[1])
        else:
            cv.put(x, y + 1, GOO[1])
    for x in range(x0, x1 + 1, 4):
        cv.put(x, y - 1, GOO[5])


def plank(cv: Canvas, x: int, y: int, w: int, h: int, rng: random.Random, vertical=True, tone=2) -> None:
    """A plank with grain streaks and the odd knot, lit on its left (or top) edge."""
    cv.rect(x, y, w, h, WOOD[tone])
    for _ in range(max(1, (w if vertical else h) // 3)):
        if vertical:
            gx = x + rng.randrange(w)
            for yy in range(y + rng.randint(0, 2), y + h - rng.randint(0, 2)):
                if rng.random() < 0.75:
                    cv.put(gx, yy, WOOD[tone - 1])
        else:
            gy = y + rng.randrange(h)
            for xx in range(x + rng.randint(0, 2), x + w - rng.randint(0, 2)):
                if rng.random() < 0.75:
                    cv.put(xx, gy, WOOD[tone - 1])
    if vertical:
        cv.vline(x, y, y + h - 1, WOOD[tone + 1])
    else:
        cv.hline(x, x + w - 1, y, WOOD[tone + 1])
    if rng.random() < 0.4 and w > 3 and h > 4:
        kx, ky = x + rng.randint(1, w - 2), y + rng.randint(1, h - 2)
        cv.put(kx, ky, WOOD[0])


def stone_blocks(cv: Canvas, mask, block_w=5, block_h=4) -> None:
    """Mortared stone blocks wherever mask(x, y) is true: each block its own shade, lit on its
    top-left edges."""
    for y in range(cv.h):
        for x in range(cv.w):
            if not mask(x, y):
                continue
            row = y // block_h
            off = (row % 2) * (block_w // 2)
            bx = (x + off) // block_w
            local_x, local_y = (x + off) % block_w, y % block_h
            shade = 1 + (bx * 7 + row * 13) % 3  # 1..3
            col = STONE[shade]
            if local_y == 0 or local_x == 0:
                col = STONE[0]  # mortar
            elif local_y == 1 or local_x == 1:
                col = STONE[min(shade + 1, 4)]
            cv.put(x, y, col)


def moss(cv: Canvas, spots, rng: random.Random) -> None:
    for x, y in spots:
        for _ in range(5):
            mx, my = x + rng.randint(-1, 1), y + rng.randint(-1, 0)
            if cv.filled(mx, my):
                cv.put(mx, my, MOSS[rng.randint(0, 1)])


## The torch flame in each of TORCH_FRAMES frames: (dx, dy, fire shade) pixels above the bracket.
TORCH_FRAMES = 4
FLAMES = [
    [(0, 2, 1), (1, 2, 2), (0, 1, 2), (1, 1, 3), (0, 0, 1)],
    [(0, 2, 2), (1, 2, 1), (0, 1, 3), (1, 1, 2), (1, 0, 2), (1, -1, 1)],
    [(0, 2, 1), (1, 2, 2), (0, 1, 3), (1, 1, 2), (0, 0, 2), (-1, 0, 1)],
    [(0, 2, 2), (1, 2, 2), (0, 1, 1), (1, 1, 3), (1, -1, 0)],
]


def torch(cv: Canvas, x: int, y: int, f: int = 0) -> None:
    """A wall torch: an iron bracket and a little flame (flickering through its frames)."""
    cv.rect(x, y + 3, 2, 4, IRON[2])
    cv.put(x, y + 3, IRON[3])
    cv.put(x - 1, y + 6, IRON[1])
    for dx, dy, shade in FLAMES[f % TORCH_FRAMES]:
        cv.put(x + dx, y + dy, FIRE[shade])


# ----------------------------------------------------------------- STORY: the archway

def _opening(x, y):
    u = (x + 0.5 - 15) / 9.5
    top = 16 - 9.5 * math.sqrt(max(0.0, 1 - u * u))
    return abs(u) <= 1 and top <= y < 39


def _arch(x, y):
    u = (x + 0.5 - 15) / 15
    top = 15 - 15 * math.sqrt(max(0.0, 1 - u * u))
    return abs(u) <= 1 and y >= top + 1 and not _opening(x, y)


def door() -> list:
    return [_door(f) for f in range(TORCH_FRAMES)]


def _door(f: int) -> list:
    cv = Canvas(30, 40)
    rng = random.Random(3)
    stone_blocks(cv, _arch)
    for y in range(40):  # inside: dark, deeper toward the top
        for x in range(30):
            if _opening(x, y):
                cv.put(x, y, VOID[min(3, max(0, (y - 12) // 7))])
    for i, sy in enumerate((30, 33, 36)):  # steps going down
        cv.hline(10 - i, 19 + i, sy, STONE[2])
        cv.hline(10 - i, 19 + i, sy + 1, STONE[0])
    # Skull keystone.
    cv.rect(12, 1, 6, 5, STONE[3])
    cv.rect(13, 2, 4, 3, BONE)
    cv.put(13, 3, OUTLINE)
    cv.put(16, 3, OUTLINE)
    cv.put(14, 5, BONE)
    cv.put(15, 5, BONE)
    drips(cv, 6, 23, 7, random.Random(4), 4)
    moss(cv, [(3, 36), (2, 25), (26, 31), (27, 19)], rng)
    torch(cv, 2, 13, f)
    torch(cv, 26, 13, f + 2)  # out of step with the other one
    cv.hline(11, 18, 39, GOO[2])  # a goo trail leading in
    cv.hline(13, 16, 38, GOO[3])
    cv.outline()
    return cv.px


def door_side() -> list:
    return [_door_side(f) for f in range(TORCH_FRAMES)]


def _door_side(f: int) -> list:
    cv = Canvas(30, 40)
    rng = random.Random(5)
    stone_blocks(cv, lambda x, y: 11 <= x <= 18 and y >= 4, 4, 4)
    cv.rect(12, 2, 6, 2, STONE[3])
    cv.vline(18, 4, 39, STONE[1])  # the inner face, toward the center
    drips(cv, 11, 18, 5, random.Random(6), 3)
    torch(cv, 19, 13, f)
    moss(cv, [(12, 35), (16, 22)], rng)
    cv.outline()
    return cv.px


def door_back() -> list:
    cv = Canvas(30, 40)
    rng = random.Random(7)
    stone_blocks(cv, _arch)
    for px in range(5, 26, 4):  # a closed plank door fills the opening, seen from behind
        plank(cv, px, 6, 4, 33, rng)
    for y in range(40):
        for x in range(30):
            if not _opening(x, y) and not _arch(x, y):
                cv.put(x, y, CLEAR)
    stone_blocks(cv, _arch)
    for by in (15, 30):  # iron bands with studs
        for x in range(30):
            if _opening(x, by):
                cv.put(x, by, IRON[4] if x % 3 == 0 else IRON[2])
    cv.ellipse(19.5, 24.5, 1.7, 1.7, IRON[3])  # ring handle
    cv.put(19, 24, WOOD[1])
    moss(cv, [(3, 36), (27, 19)], rng)
    cv.outline()
    return [cv.px] * TORCH_FRAMES


# ----------------------------------------------------------------- RANDOMIZER: the portal

def _plinth(cv: Canvas, w: int, y: int) -> None:
    x0 = (cv.w - w) // 2
    cv.rect(x0, y, w, 2, STONE[2])
    cv.hline(x0, x0 + w - 1, y, STONE[3])
    cv.rect(x0 - 2, y + 2, w + 4, 2, STONE[1])
    cv.hline(x0 - 2, x0 + w + 1, y + 2, STONE[2])


def _ring(x, y, u, v):
    lit = u * -0.6 + v * -0.8
    return STONE[3] if lit > 0.5 else STONE[2] if lit > -0.2 else STONE[1]


def portal() -> list:
    frames = []
    swirl = [rgb(36, 16, 66), rgb(80, 38, 146), rgb(136, 82, 218), rgb(212, 178, 255)]
    for f in range(6):
        cv = Canvas(30, 40)
        cv.ellipse(15, 18, 13.5, 17, _ring)

        def vortex(x, y, u, v):
            r = math.hypot(u, v)
            a = math.atan2(v, u) + r * 5.0 - f * (math.pi / 3)
            band = (math.sin(a * 2) + 1) / 2 * (1 - r * 0.6)
            return swirl[min(3, int(band * 4))] if r > 0.16 else swirl[3]
        cv.ellipse(15, 18, 9.5, 13, vortex)
        for i in range(8):  # carved runes round the ring, glowing in turn
            a = i / 8 * math.tau - math.pi / 2
            cv.put(round(15 + math.cos(a) * 11.5), round(18 + math.sin(a) * 15), RUNE[1] if (i + f) % 4 == 0 else RUNE[0])
        rng = random.Random(f)
        for _ in range(4):  # sparkles drifting out
            a = rng.uniform(0, math.tau)
            d = rng.uniform(4, 9)
            cv.put(round(15 + math.cos(a) * d), round(18 + math.sin(a) * d * 1.3), rgb(244, 232, 255))
        _plinth(cv, 20, 34)
        cv.outline()
        frames.append(cv.px)
    return frames


def portal_side() -> list:
    frames = []
    glow = [rgb(84, 40, 150), rgb(140, 84, 220), rgb(214, 180, 255)]
    for f in range(6):
        cv = Canvas(30, 40)
        cv.ellipse(15, 18, 4.5, 17, lambda x, y, u, v: STONE[3] if u < -0.3 else STONE[2] if u < 0.3 else STONE[1])
        for y in range(4, 33):  # a sliver of the vortex on the side facing the center
            cv.put(19, y, glow[(y + f) % 3])
            if (y + f * 2) % 7 == 0:
                cv.put(20, y, glow[2])
        for i in range(4):
            cv.put(13, 6 + i * 8, RUNE[1] if (i + f) % 4 == 0 else RUNE[0])
        _plinth(cv, 12, 34)
        cv.outline()
        frames.append(cv.px)
    return frames


def portal_back() -> list:
    frames = []
    dim = [rgb(20, 12, 34), rgb(36, 22, 62), rgb(56, 34, 92)]
    for f in range(6):
        cv = Canvas(30, 40)
        cv.ellipse(15, 18, 13.5, 17, lambda x, y, u, v: STONE[2] if (u * -0.6 + v * -0.8) > 0.2 else STONE[1])

        def back(x, y, u, v):
            a = math.atan2(v, u) - f * (math.pi / 3) * 0.5
            return dim[int((math.sin(a * 3) + 1) / 2 * 2.99)]
        cv.ellipse(15, 18, 9.5, 13, back)
        for i in range(8):
            a = i / 8 * math.tau
            cv.put(round(15 + math.cos(a) * 11.5), round(18 + math.sin(a) * 15), RUNE[0])
        _plinth(cv, 20, 34)
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- SKINS & HATS: the wardrobe

def _top_hat(cv: Canvas, x: int, y: int) -> None:
    cv.rect(x - 1, y + 7, 9, 2, IRON[1])   # brim
    cv.hline(x - 1, x + 7, y + 7, IRON[2])
    cv.rect(x, y, 6, 7, IRON[1])            # crown
    cv.vline(x, y, y + 6, IRON[2])
    cv.hline(x, x + 5, y, IRON[2])
    cv.hline(x, x + 5, y + 5, RED[1])       # band
    cv.put(x + 1, y + 5, RED[2])


## Wardrobe frames: 0 closed, 1-2 a sparkle on the mirror (small, big), 3 right door ajar,
## 4 right door wide open (hats and a coat hanging inside). The same five in every view.
WARDROBE_FRAMES = [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)]  # (door: 0 shut 1 ajar 2 open, sparkle)
SPARKLE = rgb(255, 255, 255)


def _wardrobe_inside(cv: Canvas, x0: int, x1: int) -> None:
    """The inside of the right half: dark, a rail, a red coat, a hat and a striped scarf."""
    cv.rect(x0, 11, x1 - x0 + 1, 24, VOID[1])
    cv.hline(x0, x1, 13, IRON[2])
    coat = [(15, 14, 4, 13)]
    for cx, cy, w, h in coat:
        if cx + w - 1 <= x1 and cx >= x0:
            cv.rect(cx, cy, w, h, RED[1])
            cv.vline(cx, cy, cy + h - 1, RED[2])
            cv.put(cx + 1, cy, IRON[2])
    if x1 >= 23:
        cv.rect(20, 15, 4, 3, IRON[1])    # a little top hat on a hook
        cv.hline(19, 24, 18, IRON[1])
        cv.hline(20, 23, 17, RED[1])
        for y in range(20, 30):           # a striped scarf
            cv.put(22, y, GOLD[2] if y % 2 else c("v"))


def _sparkle(cv: Canvas, x: int, y: int, size: int) -> None:
    if size <= 0:
        return
    cv.put(x, y, SPARKLE)
    for d in range(1, size + 1):
        for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
            cv.put(x + dx, y + dy, SPARKLE if d == 1 else rgb(206, 232, 246))


def _wardrobe_front(door: int, sparkle: int) -> list:
    cv = Canvas(28, 40)
    rng = random.Random(9)
    cv.rect(1, 10, 26, 27, WOOD[1])
    cv.rect(0, 8, 28, 3, WOOD[3])           # crown molding with carved notches
    cv.hline(0, 27, 8, WOOD[4])
    cv.hline(0, 27, 10, WOOD[1])
    for x in (4, 9, 18, 23):
        cv.put(x, 9, WOOD[2])
    plank(cv, 2, 11, 12, 24, rng, vertical=True, tone=2)  # left door (with the mirror)
    for py in (13, 24):
        cv.rect(4, py, 8, 9, WOOD[1])
        cv.rect(5, py + 1, 6, 7, WOOD[2])
        cv.hline(5, 10, py + 1, WOOD[3])
    if door == 0:                            # right door shut
        plank(cv, 14, 11, 12, 24, rng, vertical=True, tone=2)
        for py in (13, 24):
            cv.rect(16, py, 8, 9, WOOD[1])
            cv.rect(17, py + 1, 6, 7, WOOD[2])
            cv.hline(17, 22, py + 1, WOOD[3])
        cv.put(15, 22, GOLD[3])
        for i, y in enumerate(range(26, 34)):  # a scarf caught in the door
            cv.put(13 + (i % 2), y, RED[1] if i % 3 else RED[2])
    elif door == 1:                          # ajar: the door swung part way, the inside showing
        _wardrobe_inside(cv, 14, 25)
        plank(cv, 14, 11, 7, 24, random.Random(19), vertical=True, tone=3)
        cv.vline(20, 11, 34, WOOD[1])
        cv.put(19, 22, GOLD[3])
    else:                                    # wide open: the door edge-on sticking out at the side
        _wardrobe_inside(cv, 14, 25)
        cv.rect(26, 10, 2, 26, WOOD[3])
        cv.vline(27, 10, 35, WOOD[2])
    cv.vline(13, 11, 34, WOOD[0])
    # A gilt oval mirror on the left door, and the odd sparkle on it.
    cv.ellipse(7.5, 20, 4.2, 7.5, lambda x, y, u, v: GOLD[3] if u + v < -0.6 else GOLD[2] if u + v < 0.4 else GOLD[1])
    cv.ellipse(7.5, 20, 3.2, 6.5, lambda x, y, u, v: rgb(206, 232, 246) if u + v < -0.7 else rgb(140, 180, 214) if u + v < 0.4 else rgb(98, 136, 178))
    cv.put(12, 22, GOLD[3])                 # left knob
    cv.rect(1, 35, 26, 2, WOOD[0])          # base and feet
    cv.rect(2, 37, 3, 2, WOOD[1])
    cv.rect(23, 37, 3, 2, WOOD[1])
    _top_hat(cv, 17, 0)
    cv.outline()
    _sparkle(cv, 6, 17, sparkle)            # over the outline pass, so it isn't outlined
    return cv.px


def wardrobe() -> list:
    return [_wardrobe_front(door, sparkle) for door, sparkle in WARDROBE_FRAMES]


def _wardrobe_side(door: int) -> list:
    cv = Canvas(28, 40)
    rng = random.Random(10)
    cv.rect(8, 10, 12, 27, WOOD[1])
    cv.rect(7, 8, 14, 3, WOOD[3])
    cv.hline(7, 20, 8, WOOD[4])
    plank(cv, 9, 11, 9, 24, rng, vertical=True, tone=2)
    cv.rect(10, 14, 6, 18, WOOD[1])
    cv.rect(11, 15, 4, 16, WOOD[2])
    cv.vline(19, 10, 36, WOOD[0])           # the front edge, toward the center
    if door == 0:
        cv.put(20, 22, GOLD[3])             # a knob peeking round
        for y in range(26, 34):
            cv.put(20, y, RED[1])           # the scarf
    else:                                   # the door swinging out toward the center
        w = 3 if door == 1 else 7
        cv.rect(20, 11, w, 24, WOOD[2])
        cv.vline(20, 11, 34, WOOD[3])
        cv.put(20 + w - 1, 22, GOLD[3])
    cv.rect(8, 35, 12, 2, WOOD[0])
    cv.rect(9, 37, 2, 2, WOOD[1])
    cv.rect(17, 37, 2, 2, WOOD[1])
    _top_hat(cv, 11, 0)
    cv.outline()
    return cv.px


def wardrobe_side() -> list:
    return [_wardrobe_side(door) for door, _ in WARDROBE_FRAMES]


def wardrobe_back() -> list:
    cv = Canvas(28, 40)
    rng = random.Random(11)
    cv.rect(1, 10, 26, 27, WOOD[1])
    cv.rect(0, 8, 28, 3, WOOD[2])
    for x in range(1, 27, 5):
        plank(cv, x, 11, 5, 24, rng, vertical=True, tone=1 + (x // 5) % 2)
    cv.hline(1, 26, 22, WOOD[0])            # a back brace
    cv.rect(1, 35, 26, 2, WOOD[0])
    cv.rect(2, 37, 3, 2, WOOD[1])
    cv.rect(23, 37, 3, 2, WOOD[1])
    _top_hat(cv, 5, 0)
    cv.outline()
    return [cv.px] * len(WARDROBE_FRAMES)


# ----------------------------------------------------------------- UPGRADES: the cauldron

def cauldron() -> list:
    frames = []
    for f in range(4):
        cv = Canvas(30, 28)
        cv.rect(7, 25, 16, 2, WOOD[1])      # logs
        cv.hline(7, 22, 25, WOOD[2])
        rng = random.Random(f + 20)
        for x in range(8, 22):              # flames licking up under the pot
            h = rng.randint(1, 4)
            for d in range(h):
                cv.put(x, 24 - d, FIRE[min(3, d + (1 if (x + f) % 3 == 0 else 0))])

        def pot(x, y, u, v):
            lit = -u * 0.7 - v * 0.5
            return IRON[3] if lit > 0.55 else IRON[2] if lit > 0.0 else IRON[1] if lit > -0.6 else IRON[0]
        cv.ellipse(15, 14, 12, 9.5, pot)
        for rx in (6, 10, 15, 20, 24):      # rivets below the rim
            cv.put(rx, 9, IRON[4])
        for hx in (2.5, 27.5):              # ring handles
            cv.ellipse(hx, 12.5, 2, 2, IRON[2])
            cv.put(int(hx), 12, CLEAR)
        cv.rect(3, 5, 24, 3, IRON[2])       # rim
        cv.hline(3, 26, 5, IRON[4])
        cv.hline(3, 26, 7, IRON[1])
        cv.rect(5, 6, 20, 2, GOO[3])        # goo inside, bubbling
        cv.hline(5, 24, 6, GOO[4])
        for i in range(3):
            bx = 7 + i * 6 + (i * 5 % 3)
            rise = (f + i) % 4
            if rise < 3:
                cv.ellipse(bx + 0.5, 5.5 - rise, 1.2, 1.2, GOO[4])
                cv.put(bx, 5 - rise, GOO[5])
        for x, n in ((7, 4), (17, 6), (22, 3)):  # spilling over the side
            for d in range(n):
                cv.put(x, 8 + d, GOO[3] if d < n - 1 else GOO[2])
        for i, cx in enumerate((21, 24)):   # coins on the rim, twinkling in turn
            cv.put(cx, 4, GOLD[2])
            cv.put(cx + 1, 4, GOLD[3] if (f + i) % 2 else GOLD[1])
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- COIN BAG

def coinbag(view: str = "front") -> list:
    frames = []
    for f in range(4):
        cv = Canvas(24, 26)
        rx = 7.0 if view == "side" else 10.0

        def sack(x, y, u, v):
            # A slumped sack: wide and heavy at the bottom, lit from the top-left, burlap weave,
            # with a couple of creases.
            lit = -u * 0.6 - v * 0.6
            base = BURLAP[3] if lit > 0.6 else BURLAP[2] if lit > 0.0 else BURLAP[1]
            if abs(u - 0.35 * v) < 0.06 or abs(u + 0.45 + 0.3 * v) < 0.05:
                return BURLAP[1]
            return BURLAP[1] if (x + y * 2) % 5 == 0 and lit < 0.6 else base
        for y in range(26):  # pear shape: narrow neck widening into a heavy, flattened bottom
            for x in range(24):
                k = (y - 8) / 16
                if 0 <= k <= 1:
                    half = rx * (0.45 + 0.55 * math.sin(min(k * 1.25, 1.0) * math.pi / 2))
                    if k > 0.85:
                        half *= 1.0 - (k - 0.85) * 2.2
                    if abs(x + 0.5 - 12) <= half:
                        cv.put(x, y, sack(x, y, (x + 0.5 - 12) / rx, k * 2 - 1))
        cv.rect(10, 5, 5, 4, BURLAP[2])       # the neck
        cv.vline(10, 5, 8, BURLAP[3])
        for i, (x, top) in enumerate(((7, 3), (9, 1), (12, 0), (15, 1), (17, 3))):  # gathered fabric
            cv.vline(x, top, 5, BURLAP[3] if i < 2 else BURLAP[2])
            cv.vline(x + 1, top + 1, 5, BURLAP[2] if i < 2 else BURLAP[1])
        cv.hline(8, 16, 6, WOOD[3])          # rope tie with a dangling end
        cv.hline(8, 16, 7, WOOD[2])
        cv.put(17, 7, WOOD[3])
        cv.put(18, 8, WOOD[2])
        cv.put(18, 9, WOOD[2])
        if view == "front":                  # a stitched coin emblem
            cv.ellipse(12, 17, 3.3, 3.3, GOLD[2])
            cv.ellipse(12, 17, 2.2, 2.2, GOLD[1])
            cv.put(11, 16, GOLD[3])
            cv.put(12, 17, GOLD[3])
        if view != "back":                   # coins spilled in front, one twinkling
            for i, (cx, cy) in enumerate(((2, 24), (5, 25), (17, 25), (20, 23))):
                cv.rect(cx, cy, 2, 1, GOLD[2])
                cv.put(cx, cy, GOLD[3] if (i + f) % 4 == 0 else GOLD[2])
            if f == 1:
                cv.put(21, 22, rgb(255, 252, 230))
        else:
            cv.vline(12, 10, 23, BURLAP[0])  # a back seam
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- HAT WHEEL: the prize wheel

WEDGES = [rgb(200, 60, 70), rgb(236, 200, 80), rgb(60, 170, 170), rgb(140, 80, 190), rgb(230, 130, 50), rgb(70, 110, 200)]


def _wheel_stand(cv: Canvas, cx: int) -> None:
    cv.rect(cx - 1, 27, 3, 10, WOOD[2])
    cv.vline(cx - 1, 27, 36, WOOD[3])
    cv.rect(cx - 8, 36, 17, 2, WOOD[1])
    cv.hline(cx - 8, cx + 8, 36, WOOD[3])
    for dx, dy in ((-5, 35), (-3, 34), (4, 35), (3, 34)):  # braces
        cv.put(cx + dx, dy, WOOD[1])


## The prize wheel turns a full circle in WHEEL_FRAMES steps (it can stop on any of them); the
## flapper kicks over as each peg passes.
WHEEL_FRAMES = 24


def _wheel_front(k: int) -> list:
    cv = Canvas(32, 40)
    _wheel_stand(cv, 16)
    turn = k / WHEEL_FRAMES * math.tau

    def face(x, y, u, v):
        r = math.hypot(u, v)
        if r > 0.86:
            return WOOD[3] if (u + v) < 0 else WOOD[2]
        if r < 0.2:
            return GOLD[2] if u + v < 0 else GOLD[1]
        a = ((math.atan2(v, u) + math.pi - turn) / (2 * math.pi)) % 1.0
        if (a * 6) % 1 < 0.07:
            return rgb(240, 236, 226)  # divider lines
        return WEDGES[int(a * 6) % 6]
    cv.ellipse(16, 15, 13.5, 13.5, face)
    for i in range(12):  # pegs round the rim
        a = i / 12 * math.tau + turn
        cv.put(round(16 + math.cos(a) * 12.4), round(15 + math.sin(a) * 12.4), GOLD[3])
    for a6 in range(0, 6, 2):  # little hats on alternate wedges
        ang = (a6 + 0.5) / 6 * math.tau - math.pi + turn
        hx, hy = round(16 + math.cos(ang) * 7.5), round(15 + math.sin(ang) * 7.5)
        cv.rect(hx - 1, hy, 3, 1, OUTLINE)
        cv.rect(hx, hy - 2, 1, 2, OUTLINE)
    cv.rect(15, 0, 3, 2, IRON[3])  # the flapper, kicked over when a peg is passing
    kick = 1 if k % 2 else 0
    cv.put(16 + kick, 2, RED[2])
    cv.put(16 + kick, 3, RED[1])
    cv.outline()
    return cv.px


def wheel() -> list:
    return [_wheel_front(k) for k in range(WHEEL_FRAMES)]


def wheel_side() -> list:
    frames = []
    for k in range(WHEEL_FRAMES):
        cv = Canvas(32, 40)
        _wheel_stand(cv, 16)
        for y in range(2, 29):  # edge-on: a thin rim, its colors and pegs rolling past
            cv.put(15, y, WOOD[3])
            cv.put(16, y, WEDGES[((y + k) // 4) % 6])
            if (y + k) % 4 == 1:
                cv.put(17, y, GOLD[3])
        cv.rect(15, 0, 3, 2, IRON[3])
        cv.outline()
        frames.append(cv.px)
    return frames


def wheel_back() -> list:
    frames = []
    for k in range(WHEEL_FRAMES):
        cv = Canvas(32, 40)
        rng = random.Random(12)
        _wheel_stand(cv, 16)
        cv.ellipse(16, 15, 13.5, 13.5, lambda x, y, u, v: WOOD[2] if math.hypot(u, v) < 0.86 else WOOD[3])
        for y in range(3, 28):
            if rng.random() < 0.35:
                cv.put(rng.randint(8, 24), y, WOOD[1])  # grain
        turn = -k / WHEEL_FRAMES * math.tau  # turning the other way, seen from behind
        for brace in (0.0, math.pi / 2):  # cross braces, turning with the wheel
            a = turn + brace
            for r10 in range(-118, 119):
                r = r10 / 10
                x, y = 16 + math.cos(a) * r, 15 + math.sin(a) * r
                cv.put(round(x), round(y), WOOD[1])
                cv.put(round(x + math.sin(a) * 0.9), round(y - math.cos(a) * 0.9), WOOD[1])
        cv.ellipse(16, 15, 2.6, 2.6, IRON[2])
        cv.put(15, 14, IRON[4])
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- SETTINGS: the gear post

def _gear(cv: Canvas, cx: float, cy: float, r: float, teeth: int, turn: float, back=False) -> None:
    def g(x, y, u, v):
        rr = math.hypot(u, v)
        a = math.atan2(v, u) + turn
        if rr > (1.0 if math.cos(a * teeth) > 0.2 else 0.78):
            return None
        if rr < 0.28:
            return IRON[0]
        if back:
            return IRON[1] if rr > 0.5 else IRON[2]
        return IRON[4] if (u + v < -0.7) else IRON[3] if u + v < 0 else IRON[2]
    cv.ellipse(cx, cy, r, r, g)


def _post(cv: Canvas, x: int, top: int) -> None:
    plank(cv, x, top, 3, 33 - top, random.Random(13), vertical=True, tone=2)
    cv.rect(x - 4, 31, 11, 3, STONE[1])
    cv.hline(x - 4, x + 6, 31, STONE[3])


## The gears turn in GEAR_FRAMES steps that loop: the big gear (8 teeth) a tooth's worth, the
## small one (6 teeth) the other way, as fast as meshed gears would.
GEAR_FRAMES = 6
BIG_STEP = (math.tau / 8) / GEAR_FRAMES
SMALL_STEP = (math.tau / 6) / GEAR_FRAMES


def signpost() -> list:
    frames = []
    for k in range(GEAR_FRAMES):
        cv = Canvas(24, 34)
        _post(cv, 10, 12)
        _gear(cv, 11, 8, 7.5, 8, k * BIG_STEP)
        _gear(cv, 18.5, 14.5, 4.0, 6, 0.3 - k * SMALL_STEP)
        cv.vline(13, 19, 26, IRON[3])  # a wrench hanging off the post
        cv.put(12, 26, IRON[3])
        cv.put(14, 26, IRON[3])
        cv.put(13, 18, IRON[2])
        cv.outline()
        frames.append(cv.px)
    return frames


def signpost_side() -> list:
    frames = []
    for k in range(GEAR_FRAMES):
        cv = Canvas(24, 34)
        _post(cv, 10, 12)
        for y in range(1, 16):  # the big gear edge-on, its teeth rolling past
            cv.put(13, y, IRON[3])
            cv.put(14, y, IRON[2])
            if (y + k) % 3 == 0:
                cv.put(15, y, IRON[2])
        for y in range(11, 19):  # the small one, rolling the other way
            cv.put(15, y, IRON[3] if (y - k) % 2 else IRON[2])
        cv.vline(9, 19, 26, IRON[2])   # the wrench, side on
        cv.outline()
        frames.append(cv.px)
    return frames


def signpost_back() -> list:
    frames = []
    for k in range(GEAR_FRAMES):
        cv = Canvas(24, 34)
        _post(cv, 10, 12)
        _gear(cv, 11, 8, 7.5, 8, 0.2 - k * BIG_STEP, back=True)  # seen from behind: mirrored turning
        _gear(cv, 3.5, 14.5, 4.0, 6, k * SMALL_STEP, back=True)
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- QUIT: the trapdoor

## Trapdoor frames: 0 shut, 1 the lid lifting, 2 blown open with a puff of dust, 3 open.
def _hatch(lid: int, puff: bool) -> list:
    cv = Canvas(28, 18)
    rng = random.Random(14)
    cv.rect(1, 3, 26, 14, WOOD[1])          # frame
    cv.hline(1, 26, 3, WOOD[3])
    for y in range(6, 15):                   # the hole, darker deeper
        for x in range(4, 24):
            cv.put(x, y, VOID[min(3, max(0, 3 - (y - 6) // 3))])
    for y in range(7, 15, 3):                # ladder going down
        cv.hline(9, 18, y, WOOD[3] if y < 9 else WOOD[2] if y < 12 else WOOD[1])
    cv.vline(9, 6, 14, WOOD[2])
    cv.vline(18, 6, 14, WOOD[2])
    for (x, y) in ((1, 3), (25, 3), (1, 15), (25, 15)):  # iron corner brackets
        cv.rect(x, y, 2, 2, IRON[3])
    if lid == 0:                             # shut: planks over the hole, banded, a ring pull
        for py in range(5, 15, 3):
            plank(cv, 4, py, 20, 3, random.Random(py), vertical=False, tone=2)
        cv.vline(8, 5, 14, IRON[2])
        cv.vline(19, 5, 14, IRON[2])
        cv.ellipse(14, 11, 1.6, 1.3, IRON[3])
        cv.put(14, 11, WOOD[1])
    elif lid == 1:                           # lifting: the lid tilted up, a dark gap under it
        for py in range(1, 8, 3):
            plank(cv, 4, py, 20, 3, random.Random(py + 3), vertical=False, tone=3)
        cv.vline(8, 1, 7, IRON[2])
        cv.vline(19, 1, 7, IRON[2])
    else:                                    # open: the lid flipped back against the frame
        for px in range(4, 24, 5):
            plank(cv, px, 0, 5, 3, rng, vertical=False, tone=2)
        cv.hline(4, 23, 1, IRON[2])
    cv.outline()
    if puff:                                 # a puff of dust blown out of the hole
        dust = [rgb(196, 190, 200), rgb(160, 156, 170)]
        for x, y in ((3, 4), (5, 3), (2, 6), (24, 4), (25, 6), (22, 3), (12, 2), (15, 2), (0, 9), (27, 9)):
            cv.put(x, y, dust[(x + y) % 2])
            cv.put(x + 1, y, dust[1])
    return cv.px


def hatch() -> list:
    return [_hatch(0, False), _hatch(1, False), _hatch(2, True), _hatch(2, False)]


# ----------------------------------------------------------------- MAP TABLE: the cartographer's desk

# Parchment, hue-shifted: shadows lean red-brown, lights lean cream-yellow (off the bone and stone greys).
PARCHMENT = [rgb(126, 80, 60), rgb(176, 130, 88), rgb(216, 182, 126), rgb(242, 224, 172)]
INK = rgb(64, 42, 58)            # a violet-brown ink line
FEATHER = [rgb(150, 142, 172), rgb(206, 202, 218), rgb(246, 242, 232)]  # cool shadow -> warm white
## The lantern flame, per frame: (dx, dy, fire shade) inside the lantern's glass.
LANTERN_FLAMES = [
    [(1, 2, 2), (1, 1, 3), (2, 2, 1), (1, 0, 1)],
    [(1, 2, 3), (1, 1, 2), (0, 2, 1), (1, 0, 2)],
    [(1, 2, 2), (1, 1, 3), (2, 1, 1), (2, 2, 1)],
    [(1, 2, 3), (1, 1, 3), (1, 0, 2), (0, 1, 1)],
]
MAP_FRAMES = len(LANTERN_FLAMES)


def _lantern(cv: Canvas, x: int, y: int, f: int) -> None:
    """A small lantern standing at (x, y) (top-left of its 4x8 body): a ring, a cap, glass with a
    flickering flame and a base."""
    cv.put(x + 1, y, IRON[3])                # the ring handle
    cv.put(x + 2, y, IRON[2])
    cv.hline(x, x + 3, y + 1, IRON[2])       # cap
    cv.put(x, y + 1, IRON[3])
    cv.rect(x, y + 2, 4, 4, rgb(96, 58, 40))  # glass, glowing warm
    for dx, dy, shade in LANTERN_FLAMES[f % MAP_FRAMES]:
        cv.put(x + dx, y + 2 + dy, FIRE[shade])
    cv.vline(x, y + 2, y + 5, IRON[1])       # frame bars
    cv.vline(x + 3, y + 2, y + 5, IRON[1])
    cv.hline(x, x + 3, y + 6, IRON[2])       # base
    cv.hline(x, x + 3, y + 7, IRON[1])


def _pinned_map(cv: Canvas, x0: int, y0: int, w: int, h: int) -> None:
    """The map pinned on the board: parchment lit from the top-left with a curled corner, an inked
    maze, a goo trail winding through it (the skin recolors it) and a red X where the chalice is."""
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            u, v = (x - x0) / (w - 1), (y - y0) / (h - 1)
            shade = 3 if u + v < 0.5 else 2 if u + v < 1.4 else 1
            cv.put(x, y, PARCHMENT[shade])
    cv.vline(x0 + w - 1, y0 + 1, y0 + h - 1, PARCHMENT[0])   # its shadowed edges
    cv.hline(x0 + 1, x0 + w - 1, y0 + h - 1, PARCHMENT[0])
    # An inked maze: a border and a few walls on a 3 px grid.
    ink = [(0, 0, w - 3, 0), (0, 0, 0, h - 4), (w - 3, 0, w - 3, h - 4), (0, h - 4, w - 3, h - 4),
           (3, 0, 3, 6), (6, 3, 6, h - 4), (9, 0, 9, 6), (9, 9, 12, 9), (3, 9, 3, h - 4), (12, 3, 15, 3)]
    for ax, ay, bx, by in ink:
        if ax == bx:
            cv.vline(x0 + 1 + ax, y0 + 1 + ay, y0 + 1 + by, INK)
        else:
            cv.hline(x0 + 1 + ax, x0 + 1 + bx, y0 + 1 + ay, INK)
    # The goo trail: from the start (bottom-left) round the walls toward the X.
    trail = [(2, 10), (2, 8), (2, 7), (2, 6), (2, 5), (2, 4), (2, 3), (2, 2), (3, 2), (4, 2), (5, 2),
             (5, 3), (5, 4), (5, 5), (5, 6), (5, 7), (5, 8), (5, 9), (5, 10), (6, 10), (7, 10), (8, 10),
             (8, 9), (8, 8), (9, 8), (10, 8), (11, 8)]
    for i, (tx, ty) in enumerate(trail):
        cv.put(x0 + tx, y0 + ty, GOO[3] if i % 4 else GOO[4])
    cv.put(x0 + 2, y0 + 11, GOO[2])           # a drop where it starts
    gx, gy = x0 + 13, y0 + 7                  # the red X (the chalice)
    for d in (-1, 0, 1):
        cv.put(gx + d, gy + d, RED[2] if d < 1 else RED[1])
        cv.put(gx + d, gy - d, RED[1])
    for px, py in ((x0, y0), (x0 + w - 1, y0)):  # red pins in the top corners
        cv.put(px, py, RED[2])
    cv.put(x0 + w - 2, y0 + h - 2, PARCHMENT[3])  # the curled-up corner
    cv.put(x0 + w - 1, y0 + h - 2, PARCHMENT[2])
    cv.put(x0 + w - 2, y0 + h - 1, PARCHMENT[2])


def _desk_legs(cv: Canvas, xs, top: int, bottom: int) -> None:
    for x in xs:
        cv.rect(x, top, 2, bottom - top + 1, WOOD[1])
        cv.vline(x, top, bottom, WOOD[2])


def _maptable_front(f: int) -> list:
    cv = Canvas(30, 36)
    rng = random.Random(31)
    # The standing board, its legs reaching down behind the desk.
    _desk_legs(cv, (6, 22), 19, 22)
    cv.rect(4, 1, 22, 19, WOOD[1])
    cv.hline(4, 25, 1, WOOD[3])
    cv.vline(4, 1, 19, WOOD[2])
    _pinned_map(cv, 6, 3, 18, 15)
    # The desk: a lit top seen at a slant, a front with a drawer, legs.
    cv.rect(1, 21, 28, 3, WOOD[2])
    cv.hline(1, 28, 21, WOOD[4])
    for x in range(2, 28, 5):
        cv.put(x + rng.randint(0, 2), 22 + rng.randint(0, 1), WOOD[3])  # grain on the top
    plank(cv, 2, 24, 26, 6, rng, vertical=False, tone=2)
    cv.hline(2, 27, 29, WOOD[1])
    cv.rect(10, 25, 10, 4, WOOD[1])          # drawer
    cv.rect(11, 26, 8, 2, WOOD[3])
    cv.hline(11, 18, 26, WOOD[4])
    cv.put(14, 27, GOLD[3])                   # brass knob
    cv.put(15, 27, GOLD[1])
    _desk_legs(cv, (2, 26), 30, 34)
    cv.hline(1, 3, 35, WOOD[0])
    cv.hline(26, 28, 35, WOOD[0])
    # On the desk: the lantern (left), a compass, and the quill in a pot of goo (right).
    _lantern(cv, 1, 13, f)
    cv.ellipse(10.5, 22.0, 3.0, 1.9, lambda x, y, u, v: GOLD[2] if u + v < -0.3 else GOLD[1])  # compass
    cv.hline(9, 11, 22, rgb(240, 236, 226))   # its face
    cv.put(10, 22, RED[2])                    # and needle
    cv.put(11, 22, INK)
    cv.rect(21, 19, 4, 3, IRON[1])            # the pot, full of goo
    cv.hline(21, 24, 19, GOO[4])
    cv.put(22, 19, GOO[5])
    for i, (qx, qy) in enumerate(((23, 18), (23, 17), (24, 16), (24, 15), (24, 14), (25, 13), (25, 12), (25, 11))):
        cv.put(qx, qy, FEATHER[1] if i < 2 else FEATHER[2])   # the quill's feather
        if i >= 2:
            cv.put(qx + 1, qy, FEATHER[0])
    cv.put(23, 22, GOO[3])                    # a drip running down the desk front from the pot
    for y in range(24, 27):
        cv.put(23, y, GOO[3] if y < 26 else GOO[2])
    cv.outline()
    return cv.px


def _maptable_side(f: int) -> list:
    cv = Canvas(30, 36)
    rng = random.Random(32)
    cv.rect(8, 1, 2, 21, WOOD[1])             # the board edge-on, at the desk's back
    cv.vline(8, 1, 21, WOOD[3])
    cv.vline(10, 3, 17, PARCHMENT[2])         # the map's edge, toward the center
    cv.put(10, 3, RED[2])
    cv.rect(7, 21, 16, 3, WOOD[2])            # the desk top, end-on (its depth)
    cv.hline(7, 22, 21, WOOD[4])
    plank(cv, 8, 24, 14, 6, rng, vertical=False, tone=1)  # the desk's side
    cv.hline(8, 21, 29, WOOD[0])
    cv.vline(22, 24, 29, WOOD[2])             # the front edge with the drawer's knob
    cv.put(23, 26, GOLD[3])
    _desk_legs(cv, (8, 20), 30, 34)
    cv.hline(7, 9, 35, WOOD[0])
    cv.hline(20, 22, 35, WOOD[0])
    _lantern(cv, 11, 13, f)
    cv.hline(15, 18, 21, GOLD[2])             # the compass, flat
    cv.put(16, 21, RED[2])
    cv.rect(18, 18, 3, 3, IRON[1])            # the goo pot and quill
    cv.hline(18, 20, 18, GOO[4])
    for i, (qx, qy) in enumerate(((19, 17), (20, 16), (20, 15), (21, 14), (21, 13), (22, 12))):
        cv.put(qx, qy, FEATHER[2] if i else FEATHER[1])
        if i >= 2:
            cv.put(qx - 1, qy, FEATHER[0])
    cv.outline()
    return cv.px


def _maptable_back(_f: int) -> list:
    cv = Canvas(30, 36)
    rng = random.Random(33)
    for x in range(4, 26, 4):                 # the board's back: planks and a cross brace
        plank(cv, x, 1, 4, 19, rng, vertical=True, tone=1 + (x // 4) % 2)
    cv.hline(4, 25, 1, WOOD[3])
    for i in range(20):                        # the diagonal brace
        cv.put(5 + i, 2 + (i * 17) // 20, WOOD[0])
        cv.put(5 + i, 3 + (i * 17) // 20, WOOD[3])
    # A rolled-up spare map tied to the back with string.
    cv.rect(9, 7, 12, 3, PARCHMENT[2])
    cv.hline(9, 20, 7, PARCHMENT[3])
    cv.hline(9, 20, 9, PARCHMENT[1])
    cv.vline(8, 7, 9, PARCHMENT[0])
    cv.vline(21, 7, 9, PARCHMENT[1])
    cv.vline(14, 6, 10, RED[1])
    cv.put(15, 11, RED[1])
    _desk_legs(cv, (6, 22), 20, 22)
    cv.rect(1, 21, 28, 3, WOOD[2])            # the desk from behind: top edge, back panel, legs
    cv.hline(1, 28, 21, WOOD[3])
    plank(cv, 2, 24, 26, 6, rng, vertical=False, tone=1)
    cv.hline(2, 27, 29, WOOD[0])
    _desk_legs(cv, (2, 26), 30, 34)
    cv.hline(1, 3, 35, WOOD[0])
    cv.hline(26, 28, 35, WOOD[0])
    cv.outline()
    return cv.px


def maptable() -> list:
    return [_maptable_front(f) for f in range(MAP_FRAMES)]


def maptable_side() -> list:
    return [_maptable_side(f) for f in range(MAP_FRAMES)]


def maptable_back() -> list:
    return [_maptable_back(0)] * MAP_FRAMES  # the lantern is hidden behind the board


# ----------------------------------------------------------------- the wheel on a stick

def rotor() -> list:
    """The wheel on a stick in the middle of the room: a ship's wheel on a rope-wrapped post."""
    frames = []
    for f in range(4):
        cv = Canvas(26, 36)
        cv.rect(12, 19, 3, 14, WOOD[2])      # post
        cv.vline(12, 19, 32, WOOD[3])
        for y in range(22, 28):               # rope wrapping
            cv.hline(12, 14, y, BURLAP[3] if y % 2 else BURLAP[2])
        cv.rect(7, 32, 13, 3, GOO[2])        # goo pooled at its foot
        cv.hline(8, 18, 32, GOO[4])
        cv.put(10, 32, GOO[5])
        base = f * (math.pi / 4) / 4
        cx, cy = 13, 11
        for s in range(8):                    # spokes with turned handles
            a = base + s * math.pi / 4
            for r in range(3, 10):
                cv.put(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), WOOD[3] if r < 8 else WOOD[2])
            cv.put(round(cx + math.cos(a) * 11), round(cy + math.sin(a) * 11), WOOD[4])
        for a10 in range(0, 360, 5):          # the rim, lit top-left
            a = math.radians(a10)
            cv.put(round(cx + math.cos(a) * 7), round(cy + math.sin(a) * 7), WOOD[3] if math.cos(a) + math.sin(a) < 0 else WOOD[1])
        cv.ellipse(cx + 0.5, cy + 0.5, 2.4, 2.4, GOLD[1])  # brass hub
        cv.put(cx, cy, GOLD[3])
        cv.put(cx - 1, cy - 1, GOLD[2])
        cv.outline()
        frames.append(cv.px)
    return frames


# ----------------------------------------------------------------- DAILY MAZE: the calendar sign

def _daily_post(cv: Canvas) -> None:
    plank(cv, 7, 12, 2, 13, random.Random(21), vertical=True, tone=2)
    cv.rect(4, 23, 8, 3, STONE[1])
    cv.hline(4, 11, 23, STONE[3])


def daily_sign(done: bool) -> list:
    cv = Canvas(16, 26)
    _daily_post(cv)
    cv.rect(1, 1, 14, 13, WOOD[2])            # the frame
    cv.hline(1, 14, 1, WOOD[4])
    cv.rect(2, 2, 12, 11, rgb(226, 212, 176)) # the page
    cv.rect(2, 2, 12, 3, RED[1])              # the calendar's red band
    cv.hline(2, 13, 2, RED[2])
    for x in (4, 11):                         # binder rings
        cv.put(x, 1, IRON[3])
    for y in (7, 9, 11):                      # rows of days
        for x in range(3, 13, 2):
            cv.put(x, y, rgb(150, 138, 110))
    if done:                                  # a green check over the days
        for (x, y) in ((4, 9), (5, 10), (6, 11), (7, 10), (8, 9), (9, 8), (10, 7), (11, 6)):
            cv.put(x, y, rgb(40, 150, 70))
            cv.put(x, y + 1, rgb(24, 100, 50))
    cv.outline()
    return cv.px


def daily_sign_side() -> list:
    cv = Canvas(16, 26)
    _daily_post(cv)
    cv.rect(6, 1, 4, 13, WOOD[2])
    cv.vline(6, 1, 13, WOOD[4])
    cv.vline(9, 1, 13, WOOD[1])
    cv.outline()
    return cv.px


def daily_sign_back() -> list:
    cv = Canvas(16, 26)
    _daily_post(cv)
    cv.rect(1, 1, 14, 13, WOOD[1])
    cv.rect(2, 2, 12, 11, WOOD[2])
    cv.hline(2, 13, 7, WOOD[1])               # a brace across
    cv.outline()
    return cv.px


def save(name: str, rows_of_frames: list) -> None:
    """Writes a sheet: one row per view, its frames side by side."""
    rows = []
    for frames in rows_of_frames:
        for y in range(len(frames[0])):
            rows.append([px for frame in frames for px in frame[y]])
    write_png(str(OUT / f"{name}.png"), rows)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = {
        "door": [door(), door_side(), door_back()],
        "portal": [portal(), portal_side(), portal_back()],
        "wardrobe": [wardrobe(), wardrobe_side(), wardrobe_back()],
        "cauldron": [cauldron()] * 3,
        "coinbag": [coinbag("front"), coinbag("side"), coinbag("back")],
        "wheel": [wheel(), wheel_side(), wheel_back()],
        "signpost": [signpost(), signpost_side(), signpost_back()],
        "hatch": [hatch()] * 3,
        "maptable": [maptable(), maptable_side(), maptable_back()],
        "rotor": [rotor()],
    }
    for name, rows in sheets.items():
        save(name, rows)
        print(f"wrote assets/sprites/hub/{name}.png")
