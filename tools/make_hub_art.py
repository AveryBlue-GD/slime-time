"""Generates the hub room's station sprites (no dependencies): assets/sprites/hub/*.png.

Run from the project root:  python tools/make_hub_art.py

The hub is the slime's room (the title screen): each station is an object you glide up to.
Frames sit side by side in each PNG. Goo is drawn in the slime sheet's goo shades (H/l/m/n/D/G
in make_placeholder_art.PAL), so the skin shader recolors it to the equipped skin.
- door.png      26x36, 1 frame : stone archway into the dark, goo dripping over it (STORY)
- portal.png    28x36, 6 frames: a stone ring with a swirling vortex inside (RANDOMIZER)
- wardrobe.png  26x36, 1 frame : a wooden wardrobe with a mirror, a top hat on top (SKINS & HATS)
- cauldron.png  26x24, 4 frames: an iron cauldron of bubbling goo, coins glinting (UPGRADES)
- wheel.png     30x36, 1 frame : a prize wheel on a stand with hat wedges (HAT WHEEL, coming soon)
- signpost.png  20x30, 1 frame : a wooden post with a gear on it (SETTINGS)
- hatch.png     26x16, 1 frame : a trapdoor in the floor with a ladder going down (QUIT)
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


def save(name: str, frames: list) -> None:
    rows = [[px for frame in frames for px in frame[y]] for y in range(len(frames[0]))]
    write_png(str(OUT / f"{name}.png"), rows)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in [("door", door), ("portal", portal), ("wardrobe", wardrobe), ("cauldron", cauldron),
                       ("wheel", wheel), ("signpost", signpost), ("hatch", hatch)]:
        save(name, make())
        print(f"wrote assets/sprites/hub/{name}.png")
