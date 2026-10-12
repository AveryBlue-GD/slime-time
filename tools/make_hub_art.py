"""Generates the hub's art (no dependencies): assets/sprites/hub/*.png.

Run from the project root:  python tools/make_hub_art.py

The hub is the slime's room (the title screen): a slime-shaped room with stations evenly spaced
around its rim, all facing the center, and a wheel on a stick in the middle that turns the room
(like turning the camera in Don't Starve). So every station has three views, one per row of its
sheet: front (seen from across the room: the station at the top), side (drawn facing right; the
game mirrors it for the other side) and back (the stations nearest you). Frames run left to right.
Goo is drawn in the slime sheet's goo shades (H/l/m/n/D/G in make_placeholder_art.PAL), so the
skin shader recolors it to the equipped skin; stone stays off the dried-crust greys.
- door.png      26x36 x1 : STORY: an open archway into the dark / a stone pillar / a planked door
- portal.png    28x36 x6 : RANDOMIZER: a swirling vortex in a stone ring / the ring edge-on / its dim back
- wardrobe.png  26x36 x1 : SKINS & HATS: a wardrobe with a mirror and a top hat / its side / its back
- cauldron.png  26x24 x4 : UPGRADES: a cauldron of bubbling goo (round: the same from every side)
- wheel.png     30x36 x1 : HAT WHEEL (coming soon): a prize wheel / edge-on / its wooden back
- signpost.png  20x30 x1 : SETTINGS: a gear on a post / edge-on / from behind
- hatch.png     26x16 x1 : QUIT: a trapdoor in the floor (flat: the same from every side)
- rotor.png     24x34 x4 : the wheel on a stick in the middle, spinning
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
WOOD = [rgb(58, 34, 26), rgb(96, 58, 36), rgb(136, 88, 52), rgb(176, 124, 74)]  # dark -> light
IRON = [rgb(34, 34, 46), rgb(62, 64, 82), rgb(98, 102, 124), rgb(150, 156, 180)]
# Stone a few shades off the palette's: the skin shader treats those exact greys as dried slime
# crust and would recolor them.
STONE = [rgb(56, 68, 90), rgb(80, 100, 126), rgb(140, 166, 186), rgb(184, 200, 214)]
GOO = [c("G"), c("D"), c("n"), c("m"), c("l"), c("H")]  # outline -> highlight (skin-swapped)
GOLD = [c("o"), c("y"), c("Y")]
VOID = [rgb(14, 12, 22), rgb(24, 20, 36), rgb(36, 30, 52)]


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px = [[CLEAR] * w for _ in range(h)]

    def put(self, x: int, y: int, col: tuple) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = col

    def get(self, x: int, y: int) -> tuple:
        return self.px[y][x] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def rect(self, x: int, y: int, w: int, h: int, col: tuple) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, col)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, col) -> None:
        """Fills an ellipse; `col` may be a function (x, y, u, v) -> color, u/v in -1..1."""
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


def door() -> list:
    cv = Canvas(26, 36)
    # Stone arch: blocks around a dark arched opening.
    for y in range(36):
        for x in range(26):
            u = (x + 0.5 - 13) / 13
            top = 13 - 13 * math.sqrt(max(0.0, 1 - u * u))  # arch curve
            if y >= top:
                block = ((x // 5) + (y // 4)) % 2
                cv.put(x, y, STONE[2] if block else STONE[1])
                if y % 4 == 0 or (x + (y // 4) * 2) % 5 == 0:
                    cv.put(x, y, STONE[0])
    for y in range(36):
        for x in range(26):
            u = (x + 0.5 - 13) / 9
            top = 15 - 9 * math.sqrt(max(0.0, 1 - u * u))
            if abs(u) <= 1 and y >= top:
                depth = min(1.0, (y - top) / 20)
                cv.put(x, y, VOID[0] if depth < 0.6 else VOID[1] if depth < 0.85 else VOID[2])
    # A faint goo trail leading in, and goo dripping over the arch.
    for x in range(9, 18):
        cv.put(x, 35, GOO[2])
    cv.put(12, 34, GOO[3])
    cv.put(13, 34, GOO[3])
    drips(cv, 5, 20, 4, random.Random(3), 3)
    # Keystone.
    cv.rect(11, 0, 4, 3, STONE[3])
    cv.outline()
    return [cv.px]


def portal() -> list:
    frames = []
    for f in range(6):
        cv = Canvas(28, 36)
        # Standing stone ring.
        cv.ellipse(14, 17, 13, 16.5, lambda x, y, u, v: STONE[2] if (u * -0.6 + v * -0.8) > 0.2 else STONE[1])
        # Swirl: spiral bands that turn each frame.
        swirl = [rgb(40, 18, 70), rgb(84, 40, 150), rgb(140, 84, 220), rgb(214, 180, 255)]

        def vortex(x, y, u, v):
            r = math.hypot(u, v)
            a = math.atan2(v, u) + r * 5.0 - f * (math.pi / 3)
            band = (math.sin(a * 2) + 1) / 2 * (1 - r * 0.6)
            return swirl[min(3, int(band * 4))] if r > 0.18 else swirl[3]
        cv.ellipse(14, 17, 9.5, 13, vortex)
        # Sparkles drifting out.
        rng = random.Random(f)
        for _ in range(3):
            a = rng.uniform(0, 2 * math.pi)
            cv.put(round(14 + math.cos(a) * 6), round(17 + math.sin(a) * 9), rgb(240, 225, 255))
        cv.rect(4, 33, 20, 3, STONE[0])
        cv.outline()
        frames.append(cv.px)
    return frames


def wardrobe() -> list:
    cv = Canvas(26, 36)
    cv.rect(1, 8, 24, 27, WOOD[1])
    cv.rect(1, 8, 24, 2, WOOD[3])           # top molding
    cv.rect(1, 33, 24, 2, WOOD[0])          # base
    cv.rect(12, 10, 1, 23, WOOD[0])         # gap between the doors
    for x in (3, 14):                       # door panels
        cv.rect(x, 12, 9, 19, WOOD[2])
        cv.rect(x, 12, 9, 1, WOOD[3])
        cv.rect(x + 8, 12, 1, 19, WOOD[1])
    # Oval mirror on the left door.
    cv.ellipse(7.5, 21.5, 3.6, 7, lambda x, y, u, v: rgb(196, 226, 244) if u + v < -0.6 else rgb(120, 162, 204))
    # Gold knobs.
    cv.put(11, 22, GOLD[2])
    cv.put(14, 22, GOLD[2])
    # Legs.
    cv.rect(2, 35, 2, 1, WOOD[0])
    cv.rect(22, 35, 2, 1, WOOD[0])
    # A top hat sitting on top.
    cv.rect(15, 6, 9, 2, IRON[1])
    cv.rect(17, 0, 5, 6, IRON[1])
    cv.rect(17, 0, 1, 6, IRON[2])
    cv.rect(17, 4, 5, 1, rgb(168, 36, 52))
    cv.outline()
    return [cv.px]


def cauldron() -> list:
    frames = []
    for f in range(4):
        cv = Canvas(26, 24)
        # Pot body.
        cv.ellipse(13, 14, 11.5, 9, lambda x, y, u, v: IRON[2] if u < -0.55 and v < 0.2 else IRON[1] if v < 0.55 else IRON[0])
        cv.rect(2, 4, 22, 3, IRON[2])        # rim
        cv.rect(2, 4, 22, 1, IRON[3])
        # Goo surface with bubbles.
        cv.rect(4, 5, 18, 2, GOO[3])
        cv.rect(4, 5, 18, 1, GOO[4])
        rng = random.Random(7)
        for i in range(3):
            bx = 6 + i * 6 + rng.randint(0, 2)
            rise = (f + i) % 4
            if rise < 3:
                cv.put(bx, 4 - rise, GOO[4])
                cv.put(bx + 1, 4 - rise, GOO[5] if rise == 2 else GOO[3])
        # Goo running down the side.
        for x, n in ((6, 3), (16, 5), (20, 2)):
            for d in range(n):
                cv.put(x, 7 + d, GOO[3] if d < n - 1 else GOO[2])
        # A coin glinting on the rim (brighter on alternate frames).
        cv.put(21, 3, GOLD[1])
        cv.put(22, 3, GOLD[2] if f % 2 else GOLD[1])
        # Little feet.
        cv.rect(5, 22, 3, 2, IRON[0])
        cv.rect(18, 22, 3, 2, IRON[0])
        cv.outline()
        frames.append(cv.px)
    return frames


def wheel() -> list:
    cv = Canvas(30, 36)
    cv.rect(13, 26, 4, 9, WOOD[1])          # stand
    cv.rect(8, 33, 14, 3, WOOD[0])
    wedges = [rgb(200, 60, 70), rgb(236, 200, 80), rgb(60, 170, 170), rgb(140, 80, 190), rgb(230, 130, 50), rgb(70, 110, 200)]

    def face(x, y, u, v):
        r = math.hypot(u, v)
        if r > 0.86:
            return WOOD[2]
        if r < 0.18:
            return GOLD[1]
        a = (math.atan2(v, u) + math.pi) / (2 * math.pi)
        return wedges[int(a * 6) % 6]
    cv.ellipse(15, 14, 13, 13, face)
    # Tiny hat icons on alternate wedges.
    for a in range(0, 6, 2):
        ang = (a + 0.5) / 6 * 2 * math.pi - math.pi
        hx, hy = round(15 + math.cos(ang) * 7), round(14 + math.sin(ang) * 7)
        cv.rect(hx - 1, hy, 3, 1, OUTLINE)
        cv.put(hx, hy - 1, OUTLINE)
    # Pointer at the top.
    cv.rect(14, 0, 3, 2, GOLD[2])
    cv.put(15, 2, GOLD[1])
    cv.outline()
    return [cv.px]


def signpost() -> list:
    cv = Canvas(20, 30)
    cv.rect(9, 12, 3, 17, WOOD[1])           # post
    cv.rect(9, 12, 1, 17, WOOD[2])
    cv.rect(5, 28, 11, 2, STONE[1])          # base stone

    def gear(x, y, u, v):
        r = math.hypot(u, v)
        a = math.atan2(v, u)
        tooth = math.cos(a * 8) > 0.3
        if r > (1.0 if tooth else 0.78):
            return CLEAR
        if r < 0.3:
            return IRON[0]
        return IRON[3] if u + v < -0.5 else IRON[2]
    cv.ellipse(10.5, 7.5, 7.5, 7.5, gear)
    cv.outline()
    return [cv.px]


def hatch() -> list:
    cv = Canvas(26, 16)
    cv.rect(1, 1, 24, 14, WOOD[1])           # frame
    cv.rect(3, 3, 20, 10, VOID[0])           # hole
    for y in range(4, 13, 3):                # ladder rungs going down
        cv.rect(8, y, 10, 1, WOOD[2] if y < 10 else WOOD[1])
    cv.rect(8, 3, 1, 10, WOOD[2])
    cv.rect(17, 3, 1, 10, WOOD[2])
    cv.rect(1, 1, 24, 1, WOOD[3])
    cv.outline()
    return [cv.px]


def door_side() -> list:
    cv = Canvas(26, 36)
    for y in range(4, 36):  # a stone pillar seen edge-on, rounded top
        for x in range(9, 17):
            cv.put(x, y, STONE[2] if x < 12 else STONE[1])
            if y % 4 == 0:
                cv.put(x, y, STONE[0])
    cv.rect(10, 2, 6, 2, STONE[2])
    drips(cv, 9, 16, 4, random.Random(5), 3)
    cv.outline()
    return [cv.px]


def door_back() -> list:
    cv = Canvas(26, 36)
    front = door()[0]
    for y in range(36):
        for x in range(26):
            cv.put(x, y, front[y][x])
    for y in range(36):  # the opening, seen from behind: a closed plank door
        for x in range(26):
            u = (x + 0.5 - 13) / 9
            top = 15 - 9 * math.sqrt(max(0.0, 1 - u * u))
            if abs(u) <= 1 and y >= top and y < 35:
                cv.put(x, y, WOOD[2] if (x - 4) % 4 else WOOD[0])
                if y in (20, 29):
                    cv.put(x, y, IRON[1])
    cv.outline()
    return [cv.px]


def portal_side() -> list:
    frames = []
    for f in range(6):
        cv = Canvas(28, 36)
        cv.ellipse(14, 17, 4, 16.5, lambda x, y, u, v: STONE[2] if u < 0 else STONE[1])
        glow = [rgb(84, 40, 150), rgb(140, 84, 220), rgb(214, 180, 255)]
        for y in range(3, 31):  # a sliver of the vortex on the side facing the center
            cv.put(18, y, glow[(y + f) % 3])
        cv.rect(10, 33, 8, 3, STONE[0])
        cv.outline()
        frames.append(cv.px)
    return frames


def portal_back() -> list:
    frames = []
    dim = [rgb(22, 12, 36), rgb(40, 22, 66), rgb(60, 36, 96)]
    for f in range(6):
        cv = Canvas(28, 36)
        cv.ellipse(14, 17, 13, 16.5, lambda x, y, u, v: STONE[1] if (u * -0.6 + v * -0.8) > 0.2 else STONE[0])

        def back(x, y, u, v):
            a = math.atan2(v, u) - f * (math.pi / 3) * 0.5
            return dim[int((math.sin(a * 3) + 1) / 2 * 2.99)]
        cv.ellipse(14, 17, 9.5, 13, back)
        cv.rect(4, 33, 20, 3, STONE[0])
        cv.outline()
        frames.append(cv.px)
    return frames


def wardrobe_side() -> list:
    cv = Canvas(26, 36)
    cv.rect(7, 8, 12, 27, WOOD[1])
    cv.rect(7, 8, 12, 2, WOOD[3])
    cv.rect(7, 33, 12, 2, WOOD[0])
    cv.rect(9, 12, 8, 19, WOOD[2])  # side panel
    cv.rect(18, 8, 1, 27, WOOD[0])   # the front edge (facing the center)
    cv.put(19, 22, GOLD[2])          # a knob peeking round the front
    cv.rect(8, 35, 2, 1, WOOD[0])
    cv.rect(16, 35, 2, 1, WOOD[0])
    cv.rect(9, 6, 9, 2, IRON[1])     # the top hat, side on
    cv.rect(11, 0, 5, 6, IRON[1])
    cv.rect(11, 4, 5, 1, rgb(168, 36, 52))
    cv.outline()
    return [cv.px]


def wardrobe_back() -> list:
    cv = Canvas(26, 36)
    cv.rect(1, 8, 24, 27, WOOD[1])
    cv.rect(1, 8, 24, 2, WOOD[2])
    for x in range(4, 24, 5):        # back planks
        cv.rect(x, 10, 1, 23, WOOD[0])
    cv.rect(1, 33, 24, 2, WOOD[0])
    cv.rect(2, 35, 2, 1, WOOD[0])
    cv.rect(22, 35, 2, 1, WOOD[0])
    cv.rect(2, 6, 9, 2, IRON[1])     # the hat from behind
    cv.rect(4, 0, 5, 6, IRON[1])
    cv.rect(4, 4, 5, 1, rgb(168, 36, 52))
    cv.outline()
    return [cv.px]


def wheel_side() -> list:
    cv = Canvas(30, 36)
    cv.rect(13, 26, 4, 9, WOOD[1])
    cv.rect(11, 33, 8, 3, WOOD[0])
    stripes = [rgb(200, 60, 70), rgb(236, 200, 80), rgb(60, 170, 170), rgb(140, 80, 190), rgb(230, 130, 50), rgb(70, 110, 200)]
    for y in range(2, 27):           # the wheel edge-on: a thin colored rim
        cv.put(14, y, WOOD[2])
        cv.put(15, y, stripes[(y // 4) % 6])
    cv.rect(14, 0, 3, 2, GOLD[2])
    cv.outline()
    return [cv.px]


def wheel_back() -> list:
    cv = Canvas(30, 36)
    cv.rect(13, 26, 4, 9, WOOD[1])
    cv.rect(8, 33, 14, 3, WOOD[0])
    cv.ellipse(15, 14, 13, 13, lambda x, y, u, v: WOOD[1] if math.hypot(u, v) < 0.86 else WOOD[2])
    cv.rect(14, 2, 2, 24, WOOD[0])   # cross braces
    cv.rect(3, 13, 24, 2, WOOD[0])
    cv.ellipse(15, 14, 2.5, 2.5, IRON[2])
    cv.outline()
    return [cv.px]


def signpost_side() -> list:
    cv = Canvas(20, 30)
    cv.rect(9, 12, 3, 17, WOOD[1])
    cv.rect(7, 28, 7, 2, STONE[1])
    for y in range(1, 15):           # the gear edge-on, teeth sticking out
        cv.put(12, y, IRON[2])
        cv.put(13, y, IRON[1])
        if y % 3 == 0:
            cv.put(14, y, IRON[1])
    cv.outline()
    return [cv.px]


def signpost_back() -> list:
    frames = signpost()
    cv = Canvas(20, 30)
    for y in range(30):
        for x in range(20):
            p = frames[0][y][x]
            # the gear from behind: no highlight, darker
            cv.put(x, y, IRON[1] if p in (IRON[2], IRON[3]) else p)
    return [cv.px]


def rotor() -> list:
    """The wheel on a stick in the middle of the room: a ship's wheel on a post, spinning."""
    frames = []
    for f in range(4):
        cv = Canvas(24, 34)
        cv.rect(11, 18, 3, 14, WOOD[1])   # post
        cv.rect(11, 18, 1, 14, WOOD[2])
        cv.rect(7, 31, 11, 3, GOO[2])     # goo pooled at its foot
        cv.rect(8, 31, 9, 1, GOO[4])
        base = f * (math.pi / 4) / 4
        cx, cy = 12, 11
        for s in range(8):                # spokes with handles
            a = base + s * math.pi / 4
            for r in range(3, 11):
                cv.put(round(cx + math.cos(a) * r), round(cy + math.sin(a) * r), WOOD[2] if r < 9 else WOOD[3])
        for a10 in range(0, 360, 6):      # the rim
            a = math.radians(a10)
            cv.put(round(cx + math.cos(a) * 7), round(cy + math.sin(a) * 7), WOOD[1])
        cv.ellipse(cx + 0.5, cy + 0.5, 2.2, 2.2, GOLD[1])
        cv.put(cx, cy, GOLD[2])
        cv.outline()
        frames.append(cv.px)
    return frames


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
        "wheel": [wheel(), wheel_side(), wheel_back()],
        "signpost": [signpost(), signpost_side(), signpost_back()],
        "hatch": [hatch()] * 3,
        "rotor": [rotor()],
    }
    for name, rows in sheets.items():
        save(name, rows)
        print(f"wrote assets/sprites/hub/{name}.png")
