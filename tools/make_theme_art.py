"""Generates the tile art for every level theme (no dependencies).

Run from the project root:  python tools/make_theme_art.py   (--check: only compare)

Each theme has its own palette, three different wall constructions (e.g. brick, cut blocks and
cobbles; the game mixes them in patches so a level's walls really vary), two decorations and its
own floors, and writes three atlases:
- assets/sprites/themes/<id>_walls.png   : 16 neighbor masks x (3 constructions * 4 damage * 3 styles)
                                           row = construction * 12 + damage * 3 + style;
                                           style 0 = plain, 1 and 2 = the theme's two decorations
- assets/sprites/themes/<id>_floors.png  : 8 floor kinds (same columns as FLOOR_TYPES) x 4 variants
- assets/sprites/themes/<id>_fillets.png : 16 inner-corner fillets
- assets/sprites/themes/<id>_border.png  : the unbreakable border outside the maze (see BORDER below)

Only atlases whose pixels changed are rewritten. `--check` redraws everything twice and compares it
with the files (exit 1 if anything differs).

Stone layouts tile seamlessly (every pattern repeats in 16 px).
"""
import colorsys
import math
import random
import struct
import sys
import zlib
from pathlib import Path

import make_placeholder_art as art
from make_placeholder_art import (
    CORNER_PAIRS, CORNER_RADIUS, FLOOR_TYPES, E, N, S, W, atlas, blank, blob, corner_cut, crack,
    fillet_tile, put, side_pixel,
)

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "themes"

# Extra letters for decorations (each theme sets the colors it uses).
EXTRA = ["T", "t", "C", "c", "q", "L", "O", "R", "I", "g", "P", "p", "r", "s", "b"]


def rgb(*c):
    return (*c, 255)


# Base letters every theme recolors: k outline, x/w/W stone highlight/light/dark, z stain,
# f/F/h floor / floor dark / floor worn, v/V growth, d/B liquid + glint, u bone.
THEMES = {
    "dungeon": {
        "name": "DARK DUNGEON",
        "layouts": ("bricks", "ashlar", "cobble"), "decos": ("moss", "stain"), "floor": "flagstone",
        "kinds": {},
        "pal": {},  # the original palette
    },
    "mossy": {
        "name": "MOSSY MINES",
        "layouts": ("rocks", "rubble", "cobble"), "decos": ("moss", "vines"), "floor": "dirt",
        "kinds": {"worn": "moss"},
        "pal": {"k": (16, 24, 18), "x": (150, 172, 128), "w": (104, 126, 90), "W": (64, 80, 56), "z": (44, 58, 40),
                "f": (38, 46, 30), "F": (26, 32, 22), "h": (50, 62, 38), "v": (98, 164, 62), "V": (52, 104, 46),
                "d": (34, 62, 70), "B": (84, 136, 144), "u": (200, 190, 160)},
    },
    "sandstone": {
        "name": "SANDSTONE SANCTUM",
        "layouts": ("blocks", "ashlar", "soldier"), "decos": ("glyphs", "sand"), "floor": "sand",
        "kinds": {"moss": "ripples", "puddle": "ripples"},
        "pal": {"k": (48, 28, 22), "x": (248, 224, 166), "w": (216, 174, 112), "W": (164, 118, 72), "z": (126, 86, 54),
                "f": (112, 84, 58), "F": (90, 66, 46), "h": (134, 102, 68), "v": (152, 140, 72), "V": (112, 100, 52),
                "d": (70, 110, 130), "B": (130, 180, 200), "u": (238, 228, 202), "s": (198, 166, 112)},
    },
    "sunken": {
        "name": "SUNKEN SHRINE",
        "layouts": ("bricks", "slabs", "rocks"), "decos": ("barnacles", "seaweed"), "floor": "tiles",
        "kinds": {"moss": "puddle", "worn": "puddle"},
        "pal": {"k": (10, 26, 32), "x": (152, 216, 198), "w": (88, 162, 150), "W": (48, 110, 106), "z": (30, 72, 78),
                "f": (24, 48, 68), "F": (16, 34, 52), "h": (34, 62, 84), "v": (62, 152, 112), "V": (30, 98, 82),
                "d": (30, 72, 124), "B": (112, 172, 222), "u": (222, 214, 190)},
    },
    "sewers": {
        "name": "TOXIC TUNNELS",
        "layouts": ("bricks", "soldier", "cobble"), "decos": ("slime_drip", "pipe"), "floor": "bricks",
        "kinds": {"moss": "sludge", "puddle": "sludge_puddle", "worn": "grate"},
        "pal": {"k": (22, 18, 16), "x": (152, 138, 112), "w": (114, 100, 80), "W": (76, 66, 52), "z": (54, 46, 36),
                "f": (46, 40, 34), "F": (32, 28, 24), "h": (58, 52, 42), "v": (150, 232, 40), "V": (82, 142, 22),
                "d": (92, 152, 22), "B": (196, 252, 96), "u": (200, 190, 160),
                "T": (170, 246, 52), "t": (88, 150, 24), "P": (120, 128, 134), "p": (70, 76, 84), "r": (150, 74, 36)},
    },
    "catacombs": {
        "name": "CREEPY CATACOMBS",
        "layouts": ("bricks", "ashlar", "rubble"), "decos": ("skull", "bonepile"), "floor": "flagstone",
        "kinds": {"moss": "bones", "worn": "bones"},
        "pal": {"k": (28, 22, 20), "x": (208, 198, 178), "w": (158, 148, 132), "W": (108, 100, 90), "z": (78, 70, 62),
                "f": (46, 38, 34), "F": (34, 28, 26), "h": (58, 50, 44), "v": (112, 120, 82), "V": (72, 80, 58),
                "d": (40, 44, 60), "B": (90, 96, 120), "u": (234, 224, 198), "b": (150, 140, 120)},
    },
    "frozen": {
        "name": "FROZEN FORTRESS",
        "layouts": ("blocks", "slabs", "rocks"), "decos": ("icicles", "frost"), "floor": "ice",
        "kinds": {"moss": "snow", "puddle": "ice_sheet", "worn": "snow"},
        "pal": {"k": (16, 24, 50), "x": (236, 248, 255), "w": (172, 208, 238), "W": (112, 152, 202), "z": (80, 114, 172),
                "f": (40, 56, 94), "F": (30, 42, 74), "h": (56, 76, 116), "v": (196, 224, 244), "V": (142, 182, 222),
                "d": (82, 132, 192), "B": (204, 232, 255), "u": (222, 232, 242), "I": (255, 255, 255)},
    },
    "obsidian": {
        "name": "OBSIDIAN OUBLIETTE",
        "layouts": ("slabs", "ashlar", "blocks"), "decos": ("gloss", "vein"), "floor": "tiles",
        "kinds": {"moss": "plain", "worn": "plain"},
        "pal": {"k": (24, 20, 40), "x": (190, 180, 238), "w": (92, 86, 130), "W": (54, 50, 78), "z": (36, 32, 56),
                "f": (36, 32, 50), "F": (22, 18, 34), "h": (46, 42, 64), "v": (124, 72, 176), "V": (82, 42, 124),
                "d": (32, 22, 52), "B": (124, 104, 184), "u": (182, 172, 202), "g": (210, 204, 240)},
    },
    "crystal": {
        "name": "CRYSTAL CAVERNS",
        "layouts": ("rocks", "facets", "cobble"), "decos": ("crystal", "sparkle"), "floor": "dirt",
        "kinds": {"moss": "shards", "worn": "shards"},
        "pal": {"k": (22, 10, 32), "x": (198, 162, 232), "w": (142, 102, 182), "W": (94, 62, 132), "z": (66, 42, 94),
                "f": (38, 28, 56), "F": (26, 18, 40), "h": (50, 38, 72), "v": (122, 222, 232), "V": (72, 152, 182),
                "d": (62, 42, 112), "B": (182, 142, 242), "u": (222, 202, 242),
                "C": (244, 214, 255), "c": (206, 112, 244), "q": (112, 52, 164)},
    },
    "volcanic": {
        "name": "VOLCANIC VAULT",
        "layouts": ("rocks", "cobble", "seams"), "decos": ("lava", "embers"), "floor": "dirt",
        "kinds": {"cracked": "lava_crack", "puddle": "lava_pool", "moss": "ash"},
        "pal": {"k": (34, 22, 22), "x": (176, 122, 96), "w": (126, 82, 66), "W": (84, 52, 44), "z": (58, 34, 30),
                "f": (54, 32, 26), "F": (34, 20, 16), "h": (70, 42, 34), "v": (90, 84, 82), "V": (60, 56, 54),
                "d": (240, 112, 32), "B": (255, 222, 92), "u": (172, 152, 142),
                "L": (255, 224, 96), "O": (242, 112, 32), "R": (152, 40, 20)},
    },
}


# ---------------------------------------------------------------- wall layouts

def layout_bricks(g, rng):
    """Brick courses 4 px tall, joints every 8 px (the original dungeon pattern)."""
    for y in range(16):
        course = y // 4
        for x in range(16):
            if y % 4 == 3 or (x + (course % 2) * 4) % 8 == 0:
                g[y][x] = "W"
            elif y % 4 == 0 and rng.random() < 0.35:
                g[y][x] = "x"
            elif rng.random() < 0.07:
                g[y][x] = "W"


def layout_blocks(g, rng):
    """Big cut blocks: 8 px courses, 16 px blocks offset by half each course."""
    for y in range(16):
        course = y // 8
        for x in range(16):
            if y % 8 == 7 or (x + course * 8) % 16 == 0:
                g[y][x] = "W"
            elif y % 8 == 0 or (x + course * 8) % 16 == 1:
                g[y][x] = "x" if rng.random() < 0.7 else "w"
            elif rng.random() < 0.05:
                g[y][x] = "W"


def layout_rocks(g, rng):
    """Rough rounded stones, four per tile (8x8), each a slightly different shade."""
    for sy in (0, 8):
        for sx in (0, 8):
            shade = rng.choice("wwW")
            for y in range(sy, sy + 8):
                for x in range(sx, sx + 8):
                    lx, ly = x - sx, y - sy
                    edge = lx in (0, 7) or ly in (0, 7)
                    corner = (lx in (0, 1, 6, 7)) and (ly in (0, 1, 6, 7)) and not (lx in (1, 6) and ly in (1, 6))
                    if edge or corner:
                        g[y][x] = "z" if corner else "W"
                    elif ly == 1 or lx == 1:
                        g[y][x] = "x" if shade == "w" else "w"
                    else:
                        g[y][x] = shade if rng.random() > 0.12 else "W"


def layout_slabs(g, rng):
    """Polished slabs (16x8) with a bright top bevel and a dark bottom bevel."""
    for y in range(16):
        for x in range(16):
            ly = y % 8
            if ly == 0:
                g[y][x] = "x" if x % 16 else "W"
            elif ly == 7:
                g[y][x] = "z"
            elif x == 0:
                g[y][x] = "W"
            else:
                g[y][x] = "w" if ly < 3 else "W"


def _stone(g, rng, x0, y0, x1, y1):
    """One stone filling [x0, x1) x [y0, y1): mortar on its right and bottom edges (the tile's
    left/top edges get theirs from the neighboring tile), a lit top-left, a random shade."""
    shade = rng.choice("wwwW")
    for y in range(y0, y1):
        for x in range(x0, x1):
            if x == x1 - 1 or y == y1 - 1:
                g[y][x] = "W" if shade == "w" else "z"
            elif y == y0 or x == x0:
                g[y][x] = "x" if shade == "w" else "w"
            else:
                g[y][x] = shade if rng.random() > 0.08 else ("W" if shade == "w" else "z")


def layout_cobble(g, rng):
    """Cobbles of mixed sizes: the tile is split again and again into smaller stones."""
    def split(x0, y0, x1, y1):
        w, h = x1 - x0, y1 - y0
        if (w <= 6 and h <= 6) or (w <= 8 and h <= 8 and rng.random() < 0.35):
            _stone(g, rng, x0, y0, x1, y1)
            return
        if w >= h:
            cut = rng.randint(x0 + 3, x1 - 3)
            split(x0, y0, cut, y1)
            split(cut, y0, x1, y1)
        else:
            cut = rng.randint(y0 + 3, y1 - 3)
            split(x0, y0, x1, cut)
            split(x0, cut, x1, y1)
    split(0, 0, 16, 16)


def layout_ashlar(g, rng):
    """Dressed stone in courses of different heights, each course cut into blocks of random length."""
    y = 0
    for height in rng.choice(((5, 6, 5), (6, 4, 6), (4, 7, 5), (7, 5, 4))):
        x = 0
        while x < 16:
            length = min(rng.choice((4, 5, 6, 7, 8)), 16 - x)
            if 16 - (x + length) < 3:
                length = 16 - x
            _stone(g, rng, x, y, x + length, y + height)
            x += length
        y += height


def layout_soldier(g, rng):
    """Upright bricks (4 wide, 8 tall), every other course shifted by 2."""
    for row in range(2):
        shift = 2 * row
        for x0 in range(-shift, 16, 4):
            _stone(g, rng, max(x0, 0), row * 8, min(x0 + 4, 16), row * 8 + 8)


def layout_rubble(g, rng):
    """A rough rubble wall: odd-shaped lumps of stone packed in dark mortar."""
    for y in range(16):
        for x in range(16):
            g[y][x] = "z"
    for _ in range(rng.randint(9, 12)):
        cx, cy = rng.uniform(0, 16), rng.uniform(0, 16)
        rx, ry = rng.uniform(2.0, 4.0), rng.uniform(1.6, 3.0)
        shade = rng.choice("wwW")
        for y in range(16):
            for x in range(16):
                d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if d <= 1.0:
                    top = ((x + 0.5 - cx) / rx) ** 2 + ((y - 0.5 - cy) / ry) ** 2 > 1.0
                    g[y][x] = ("x" if shade == "w" else "w") if top else shade
                elif d <= 1.35 and g[y][x] == "z":
                    g[y][x] = "W"


def layout_facets(g, rng):
    """ENV-09: irregular crystal plates (a seamless Voronoi, angular distance), a dark seam on each
    plate's right / bottom edge and a lit `x` edge on its top / left."""
    pts = [(rng.uniform(0, 16), rng.uniform(0, 16)) for _ in range(rng.randint(6, 8))]
    tones = [rng.choice("wwWWq") if rng.random() > 0.15 else "c" for _ in pts]

    def plate(x, y):
        best, bi = 1e9, 0
        for i, (px, py) in enumerate(pts):
            dx = min(abs(x + 0.5 - px), 16 - abs(x + 0.5 - px))
            dy = min(abs(y + 0.5 - py), 16 - abs(y + 0.5 - py))
            d = max(dx, dy) * 0.6 + (dx + dy) * 0.4
            if d < best:
                best, bi = d, i
        return bi

    cell = [[plate(x, y) for x in range(16)] for y in range(16)]
    for y in range(16):
        for x in range(16):
            me = cell[y][x]
            if cell[y][(x + 1) % 16] != me or cell[(y + 1) % 16][x] != me:
                g[y][x] = "z"
            elif cell[y][(x - 1) % 16] != me or cell[(y - 1) % 16][x] != me:
                g[y][x] = "x"
            else:
                g[y][x] = tones[me]


def layout_seams(g, rng):
    """ENV-03: dark basalt columns (4-5 px wide); about half the tiles carry a course seam on row 7
    that glows: `O` segments with an `L` core, `R` at the ends."""
    x0 = 0
    shade_cols = []
    while x0 < 16:
        width = 4 if (16 - x0) in (4, 8) or rng.random() < 0.5 else 5
        width = min(width, 16 - x0)
        shade_cols.append((x0, x0 + width, rng.choice("wwW")))
        x0 += width
    for a, b, shade in shade_cols:
        for y in range(16):
            for x in range(a, b):
                if x == b - 1:
                    g[y][x] = "z"
                elif x == a:
                    g[y][x] = "x" if shade == "w" and y % 5 else "w"
                else:
                    g[y][x] = shade if rng.random() > 0.1 else "W"
    for x in range(16):
        g[7][x] = "z"
    if rng.random() < 0.55:
        x = rng.randrange(0, 4)
        while x < 15:
            seg = rng.randint(3, 6)
            for i in range(seg):
                if x + i < 16:
                    g[7][x + i] = "R" if i in (0, seg - 1) else "O"
            if seg >= 4 and x + seg // 2 < 16:
                g[7][x + seg // 2] = "L"
            x += seg + rng.randint(2, 4)


LAYOUTS = {"facets": layout_facets, "seams": layout_seams, "bricks": layout_bricks, "blocks": layout_blocks, "rocks": layout_rocks, "slabs": layout_slabs,
           "cobble": layout_cobble, "ashlar": layout_ashlar, "soldier": layout_soldier, "rubble": layout_rubble}


# ---------------------------------------------------------------- wall decorations

def deco_moss(g, rng, open_sides):
    for _ in range(rng.randint(4, 6)):
        cx = rng.randrange(1, 15)
        cy = rng.randrange(0, 5) if N in open_sides or rng.random() < 0.5 else rng.randrange(0, 12)
        blob(g, rng, cx, cy, rng.uniform(1.4, 2.8), "vvV")


def deco_vines(g, rng, open_sides):
    for _ in range(rng.randint(2, 3)):
        x = rng.randrange(1, 15)
        for y in range(0, rng.randrange(6, 16)):
            put(g, x, y, "V" if y % 3 else "v")
            if y % 4 == 2:
                put(g, x + rng.choice((-1, 1)), y, "v")


def deco_stain(g, rng, open_sides):
    for _ in range(rng.randint(2, 3)):
        x = rng.randrange(1, 15)
        for y in range(rng.randrange(0, 4), rng.randrange(8, 16)):
            put(g, x, y, "z")
            if rng.random() < 0.25:
                x = max(0, min(15, x + rng.choice((-1, 1))))


GLYPHS = [["z.z", ".z.", "z.z"], ["zzz", "z..", "zzz"], [".z.", "zzz", ".z."], ["z..", "zz.", "zzz"], ["zzz", "z.z", "zzz"]]


def deco_glyphs(g, rng, open_sides):
    for _ in range(rng.randint(2, 3)):
        glyph = rng.choice(GLYPHS)
        x0, y0 = rng.randrange(2, 12), rng.randrange(2, 10)
        for dy, row in enumerate(glyph):
            for dx, c in enumerate(row):
                if c != ".":
                    put(g, x0 + dx, y0 + dy, c)


def deco_sand(g, rng, open_sides):
    for y in range(8, 16):
        for x in range(16):
            if rng.random() < (y - 7) / 12:
                put(g, x, y, "s")


def deco_barnacles(g, rng, open_sides):
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(1, 14), rng.randrange(2, 14)
        put(g, x, y, "u")
        put(g, x + 1, y, "x")
        put(g, x, y + 1, "k")
        put(g, x + 1, y + 1, "u")


def deco_seaweed(g, rng, open_sides):
    for _ in range(rng.randint(2, 4)):
        x = rng.randrange(1, 15)
        for y in range(15, rng.randrange(4, 10), -1):
            put(g, x, y, "v" if y % 2 else "V")
            if rng.random() < 0.3:
                x = max(0, min(15, x + rng.choice((-1, 1))))


def deco_slime_drip(g, rng, open_sides):
    for x in range(16):
        if rng.random() < 0.6:
            put(g, x, 0, "T")
    for _ in range(rng.randint(2, 4)):
        x = rng.randrange(1, 15)
        length = rng.randint(3, 10)
        for y in range(length):
            put(g, x, y, "T" if y < length - 1 else "t")
        put(g, x, length, "t")


def deco_pipe(g, rng, open_sides):
    for x in range(16):
        g[5][x] = "k"
        g[6][x] = "P"
        g[7][x] = "P" if x % 6 else "p"
        g[8][x] = "p"
        g[9][x] = "k"
    for _ in range(rng.randint(1, 3)):
        x = rng.randrange(0, 16)
        for y in range(8, rng.randrange(11, 16)):
            put(g, x, y, "r")


def deco_skull(g, rng, open_sides):
    x0, y0 = rng.randrange(2, 8), rng.randrange(2, 7)
    niche = ["kkkkkkk", "kkuuukk", "kuuuuuk", "kububuk", "kuuuuuk", "kkububk", "kkkkkkk"]
    for dy, row in enumerate(niche):
        for dx, c in enumerate(row):
            put(g, x0 + dx, y0 + dy, c)


def deco_bonepile(g, rng, open_sides):
    for _ in range(rng.randint(2, 3)):
        x, y = rng.randrange(2, 10), rng.randrange(3, 13)
        for i in range(5):
            put(g, x + i, y, "u")
        for ex in (x, x + 4):
            put(g, ex, y - 1, "u")
            put(g, ex, y + 1, "b")


def deco_icicles(g, rng, open_sides):
    for x in range(16):
        put(g, x, 0, "I" if rng.random() < 0.5 else "x")
    if S in open_sides:
        for x in range(0, 16, 2):
            length = rng.randint(1, 3)
            for y in range(15 - length, 16):
                put(g, x, y, "I" if y == 15 - length else "x")
    for _ in range(4):
        put(g, rng.randrange(16), rng.randrange(2, 12), "I")


def deco_frost(g, rng, open_sides):
    for _ in range(rng.randint(3, 4)):
        blob(g, rng, rng.randrange(1, 15), rng.randrange(1, 15), rng.uniform(1.2, 2.4), "xIv", density=0.7)


def deco_gloss(g, rng, open_sides):
    """SPR-09: a short glint (3-6 px, either diagonal), on only half of the gloss variants."""
    if rng.random() < 0.5:
        return
    n = rng.randint(3, 6)
    sx, sy = rng.randrange(1, 15 - n), rng.randrange(1, 15 - n)
    flip = rng.random() < 0.5
    for i in range(n):
        put(g, sx + i, sy + (n - 1 - i if flip else i), "g", only_opaque=True)
        put(g, sx + i + 1, sy + (n - 1 - i if flip else i), "x", only_opaque=True)


def deco_vein(g, rng, open_sides):
    for _ in range(2):
        crack(g, rng, rng.randint(6, 12), color="v")


def deco_crystal(g, rng, open_sides):
    """ENV-09: a 6x8 cluster of three pointed shards (`C` tip, `c` body, `q` base, `k` outline);
    about 3 in 4 variants carry one (1 in 4 tiles overall)."""
    if rng.random() < 0.25:
        return
    ox, oy = rng.randrange(2, 9), rng.randrange(1, 7)
    for sx, h in ((0, rng.randint(5, 6)), (2, 8), (4, rng.randint(4, 6))):
        top = oy + 8 - h
        for i in range(h):
            y = top + i
            w_ = 1 if i < 2 else 2
            for dx in range(w_):
                px = ox + sx + dx
                body = "C" if i == 0 else ("q" if i >= h - 2 else "c")
                put(g, px, y, body)
            put(g, ox + sx - 1, y, "k")
            put(g, ox + sx + w_, y, "k")
        put(g, ox + sx, top - 1, "k")


def deco_sparkle(g, rng, open_sides):
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        put(g, x, y, "C")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rng.random() < 0.5:
                put(g, x + dx, y + dy, "c")


def deco_lava(g, rng, open_sides):
    for _ in range(3):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        main = rng.choice(art.DIRS8)
        for _ in range(rng.randint(6, 11)):
            put(g, x, y, "L")
            for nx, ny in ((x + 1, y), (x, y + 1)):
                if 0 <= nx < 16 and 0 <= ny < 16 and g[ny][nx] not in "L":
                    put(g, nx, ny, "O")
            dx, dy = main if rng.random() < 0.6 else rng.choice(art.DIRS8)
            x, y = max(0, min(15, x + dx)), max(0, min(15, y + dy))


def deco_embers(g, rng, open_sides):
    for _ in range(rng.randint(4, 7)):
        put(g, rng.randrange(16), rng.randrange(16), rng.choice("ORR"))


DECOS = {name[5:]: fn for name, fn in globals().items() if name.startswith("deco_")}


def _wall_luma(theme: dict) -> float:
    r, g, b = theme["pal"].get("w", art.PAL["w"][:3])[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b


def themed_wall(theme: dict, layout: str, mask: int, damage: int, style: int, seed: int) -> list[str]:
    """Same steps as make_placeholder_art.wall_tile, with the given construction and the theme's
    decorations."""
    rng = random.Random(seed)
    open_sides = [s for s in (N, E, S, W) if not mask & s]
    g = blank("w")
    LAYOUTS[layout](g, rng)

    if S in open_sides:  # the south-facing front face: darker band
        for y in (12, 13, 14):
            for x in range(16):
                g[y][x] = "z" if y == 14 or rng.random() < 0.5 else "W"

    if style:
        DECOS[theme["decos"][style - 1]](g, rng, open_sides)

    n_cracks = [0, 2, 3, 4][damage]
    if _wall_luma(theme) > 120:  # ENV-07: bright themes get at most two cracks a tile
        n_cracks = min(n_cracks, 2)
    for _ in range(n_cracks):
        crack(g, rng, rng.randint(5, 10), two_tone=True)
    chips = [0, 0, rng.randint(2, 3), rng.randint(4, 5)][damage]
    max_depth = [0, 0, 2, 4][damage]
    for _ in range(chips):
        if not open_sides:
            x, y = rng.randrange(3, 12), rng.randrange(3, 12)
            for dy in range(2):
                for dx in range(2):
                    g[y + dy][x + dx] = "k"
            continue
        side = rng.choice(open_sides)
        width, depth = rng.randint(2, 4), rng.randint(1, max_depth)
        start = rng.randrange(1, 15 - width)
        for i in range(width):
            for d in range(depth if 0 < i < width - 1 else max(1, depth - 1)):
                x, y = side_pixel(side, start + i, d)
                g[y][x] = "."
    if damage == 3:
        corners = [(a, b) for a, b in CORNER_PAIRS if a in open_sides and b in open_sides]
        if corners:
            a, b = rng.choice(corners)
            size = rng.randint(4, 6)
            cx = 15 if E in (a, b) else 0
            cy = 15 if S in (a, b) else 0
            for y in range(16):
                for x in range(16):
                    if abs(x - cx) + abs(y - cy) < size:
                        g[y][x] = "."

    for a, b in CORNER_PAIRS:
        if a in open_sides and b in open_sides:
            for y in range(16):
                for x in range(16):
                    if corner_cut(x, y, a, b, CORNER_RADIUS):
                        g[y][x] = "."

    rim = []
    for y in range(16):
        for x in range(16):
            if g[y][x] == ".":
                continue
            for dx, dy, side in ((0, -1, N), (1, 0, E), (0, 1, S), (-1, 0, W)):
                nx, ny = x + dx, y + dy
                outside = not (0 <= nx < 16 and 0 <= ny < 16)
                if (outside and side in open_sides) or (not outside and g[ny][nx] == "."):
                    rim.append((x, y))
                    break
    for x, y in rim:
        g[y][x] = "k"

    if damage >= 2:
        for y in range(16):
            for x in range(16):
                if g[y][x] == "." and rng.random() < (0.08 if damage == 2 else 0.16):
                    g[y][x] = rng.choice("wWz")
    return ["".join(r) for r in g]


# ---------------------------------------------------------------- floors

def floor_flagstone(g, rng):
    seam = rng.randrange(5, 11)
    for x in range(16):
        g[seam][x] = "F"
    for y0, y1 in ((0, seam), (seam + 1, 16)):
        vx = rng.randrange(3, 13)
        for y in range(y0, y1):
            g[y][vx] = "F"
    for _ in range(14):
        g[rng.randrange(16)][rng.randrange(16)] = "F"
    for _ in range(4):
        g[rng.randrange(16)][rng.randrange(16)] = "h"


def floor_dirt(g, rng):
    for y in range(16):
        for x in range(16):
            r = rng.random()
            g[y][x] = "F" if r < 0.18 else ("h" if r < 0.3 else "f")


def floor_sand(g, rng):
    floor_dirt(g, rng)
    for row in range(rng.randrange(0, 4), 16, 5):
        for x in range(16):
            if (x + row) % 7 < 4:
                put(g, x, row + (x // 5) % 2, "h")


def floor_tiles(g, rng):
    for y in range(16):
        for x in range(16):
            if x % 8 == 0 or y % 8 == 0:
                g[y][x] = "F"
            elif x % 8 == 1 and y % 8 == 1:
                g[y][x] = "h"
            elif rng.random() < 0.05:
                g[y][x] = "F"


def floor_bricks(g, rng):
    for y in range(16):
        course = y // 4
        for x in range(16):
            if y % 4 == 3 or (x + (course % 2) * 4) % 8 == 0:
                g[y][x] = "F"
            elif rng.random() < 0.06:
                g[y][x] = "h"


def floor_ice(g, rng):
    for y in range(16):
        for x in range(16):
            g[y][x] = "F" if rng.random() < 0.08 else "f"
    start = rng.randrange(-6, 10)
    for i in range(16):
        put(g, start + i, i, "h")
        put(g, start + i + 3, i, "h")


FLOOR_BASES = {"flagstone": floor_flagstone, "dirt": floor_dirt, "sand": floor_sand, "tiles": floor_tiles,
               "bricks": floor_bricks, "ice": floor_ice}


def pool(g, rng, fill: str, glint: str):
    cx, cy = rng.uniform(5, 10), rng.uniform(5, 10)
    rx, ry = rng.uniform(3, 5), rng.uniform(2, 3)
    for y in range(16):
        for x in range(16):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                g[y][x] = fill
    for i in range(rng.randint(2, 3)):
        put(g, int(cx - rx / 2) + i, int(cy - ry / 2), glint)


def floor_kind(g, rng, kind: str):
    if kind == "plain":
        return
    if kind == "cracked":
        for _ in range(2):
            crack(g, rng, rng.randint(6, 10))
    elif kind == "moss":
        for _ in range(rng.randint(2, 3)):
            blob(g, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.uniform(1.5, 2.8), "vVV")
    elif kind in ("puddle", "sludge_puddle", "lava_pool", "ice_sheet"):
        pool(g, rng, "d", "B")
    elif kind == "pebbles":
        for _ in range(rng.randint(6, 9)):
            x, y = rng.randrange(1, 14), rng.randrange(1, 14)
            put(g, x, y, rng.choice("wW"))
            put(g, x + 1, y + 1, "k")
    elif kind == "bones":
        for _ in range(rng.randint(1, 2)):
            x, y = rng.randrange(2, 9), rng.randrange(3, 13)
            dx, dy = rng.choice([(1, 0), (1, 1), (1, -1)])
            for i in range(5):
                put(g, x + dx * i, y + dy * i, "u")
            for ex, ey in ((x, y), (x + dx * 4, y + dy * 4)):
                put(g, ex - dy, ey + dx, "u")
                put(g, ex + dy, ey - dx, "u")
    elif kind == "worn":
        blob(g, rng, rng.uniform(4, 11), rng.uniform(4, 11), rng.uniform(3, 4.5), "h", density=0.7)
    elif kind == "rubble":
        for _ in range(rng.randint(10, 16)):
            x, y = rng.randrange(0, 15), int(rng.triangular(0, 10, 0))
            put(g, x, y, rng.choice("wWWz"))
            if rng.random() < 0.5:
                put(g, x + 1, y, rng.choice("Wz"))
            put(g, x, y + 1, "k")
    elif kind == "ripples":
        for row in range(rng.randrange(1, 4), 16, 3):
            for x in range(16):
                if (x * 3 + row * 5) % 11 < 5:
                    put(g, x, row, "s" if "s" in art.PAL else "h")
    elif kind == "sludge":
        for _ in range(rng.randint(2, 3)):
            blob(g, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.uniform(1.5, 3.0), "vVV")
    elif kind == "grate":
        for y in range(3, 13):
            for x in range(3, 13):
                g[y][x] = "k" if (x % 2 == 0 or y in (3, 12)) else "F"
        for x in range(3, 13):
            put(g, x, 3, "W")
    elif kind == "lava_crack":
        for _ in range(2):
            x, y = rng.randrange(2, 14), rng.randrange(2, 14)
            main = rng.choice(art.DIRS8)
            for _ in range(rng.randint(6, 10)):
                put(g, x, y, "L")
                put(g, x + 1, y, "O")
                dx, dy = main if rng.random() < 0.6 else rng.choice(art.DIRS8)
                x, y = max(0, min(15, x + dx)), max(0, min(15, y + dy))
    elif kind == "ash":
        blob(g, rng, rng.uniform(4, 11), rng.uniform(4, 11), rng.uniform(3, 4.5), "vV", density=0.6)
    elif kind == "shards":
        for _ in range(rng.randint(2, 4)):
            x, y = rng.randrange(2, 13), rng.randrange(4, 14)
            for i in range(rng.randint(2, 4)):
                put(g, x, y - i, "C" if i else "c")
                put(g, x + 1, y - i, "q")
    elif kind == "snow":
        for _ in range(rng.randint(2, 3)):
            blob(g, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.uniform(1.8, 3.2), "vVI")


def themed_floor(theme: dict, kind: str, seed: int) -> list[str]:
    rng = random.Random(seed)
    g = blank("f")
    FLOOR_BASES[theme["floor"]](g, rng)
    floor_kind(g, rng, theme["kinds"].get(kind, kind))
    return ["".join(r) for r in g]


# ---------------------------------------------------------------- the border (outside the maze)
#
# assets/sprites/themes/<id>_border.png, 16 x 8 tiles (MazeTiles.add_border picks them):
# rows 0-3: corner terrain. column = which corners are rim stone (NW=1, NE=2, SW=4, SE=8; the rest
#           are bedrock), row = variant. Mask 15 = all rim stone (the theme's own wall construction,
#           darker and heavier), mask 0 = all bedrock (rows 0-1 denser texture, rows 2-3 the sparser,
#           darker deep rock). Between them the stone ends in a wobbly outlined edge that always
#           crosses a tile side at its middle, so any two neighbors join up.
# row 4:    bedrock with a themed prop (roots, strata, ice cracks, lava seams, crystals, bones ...).
# row 5:    rim stone with the theme's decorations, cracks or drips.
# rows 6-7: eight 2x2 boulders (32x32 px) sitting on bedrock (column = boulder * 2 + x).
# Shading is hue-shifted: shadows lean cool (violet), highlights warm. Every tile is fully opaque.

BORDER_COLUMNS = 16
BORDER_ROWS = 8
BORDER_PROP_ROW = 4
BORDER_RIM_ROW = 5
BORDER_BOULDER_ROW = 6
BOULDERS = 8


def hue_shift(c, amount: float, turn: float = 0.45):
    """Darker (amount < 0) and cooler toward violet, or lighter (> 0) and warmer toward gold; `turn`
    scales how far the hue moves."""
    r, g, b = (v / 255.0 for v in c[:3])
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    target = 0.70 if amount < 0 else 0.13
    a = abs(amount)
    if s < 0.06:
        h = target
    dh = ((target - h + 0.5) % 1.0) - 0.5
    h = (h + dh * min(1.0, a * turn)) % 1.0
    if amount < 0:
        v *= 1.0 - a
        s = min(1.0, s * (1.0 + a * 0.35) + 0.04 * a)
    else:
        v += (1.0 - v) * a * 0.55
        s *= 1.0 - a * 0.25
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def mix(a, b, t: float):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def _theme_rgb(theme: dict, letter: str):
    if letter in theme["pal"]:
        return (*theme["pal"][letter], 255)
    return art.PAL[letter]


# Per theme: the bedrock's own colors (rock namespace letters, see _rock_palette) and its props.
# rock: base color of the bedrock; extra: prop colors; props: row-4 prop drawers; boulders: looks.
BORDER = {
    "dungeon": {"rock": (52, 54, 74), "props": ("pebbles", "fissure", "bones", "drip", "chain"),
                "extra": {"u": (176, 166, 150), "n": (88, 120, 168), "p": (96, 98, 116)},
                "boulder": "granite"},
    "mossy": {"rock": (40, 50, 36), "props": ("roots", "moss", "roots", "pebbles", "drip"),
              "extra": {"r": (84, 66, 46), "v": (86, 146, 58), "n": (64, 112, 120)},
              "boulder": "mossy"},
    "sandstone": {"rock": (110, 76, 52), "props": ("strata_fossil", "pebbles", "fissure", "shell"),
                  "extra": {"S": (184, 140, 92), "u": (226, 214, 186)}, "strata": True,
                  "boulder": "strata"},
    "sunken": {"rock": (26, 54, 62), "props": ("barnacles", "seaweed", "drip", "pebbles"),
               "extra": {"u": (200, 196, 172), "v": (52, 132, 98), "n": (96, 170, 210)},
               "boulder": "barnacled"},
    "sewers": {"rock": (48, 44, 34), "props": ("pipe", "toxic_drip", "pebbles", "fissure"),
               "extra": {"p": (104, 112, 118), "t": (138, 70, 36), "T": (150, 226, 46)},
               "boulder": "pipe"},
    "catacombs": {"rock": (56, 46, 42), "props": ("bones", "skull", "pebbles", "fissure"),
                  "extra": {"u": (214, 204, 180)}, "boulder": "bones"},
    "frozen": {"rock": (38, 54, 98), "props": ("ice_crack", "frost", "ice_crack", "pebbles"),
               "extra": {"i": (176, 214, 246), "I": (240, 250, 255)}, "boulder": "ice"},
    "obsidian": {"rock": (20, 18, 30), "props": ("glass", "vein", "pebbles", "glass"),
                 "extra": {"g": (176, 166, 226), "v": (112, 64, 162)}, "boulder": "obsidian"},
    "crystal": {"rock": (40, 26, 60), "props": ("crystals", "sparkle", "crystals", "pebbles"),
                "extra": {"c": (204, 118, 244), "C": (244, 214, 255), "q": (112, 52, 164)},
                "boulder": "crystal"},
    "volcanic": {"rock": (40, 26, 24), "props": ("lava_seam", "embers", "lava_seam", "pebbles"),
                 "extra": {"l": (230, 150, 70), "O": (170, 74, 32), "R": (104, 36, 22)},
                 "boulder": "lava"},
}


def _rock_palette(theme_id: str) -> dict:
    """Rock-namespace letters: D deep, K dark, M base, L light, H highlight, o outline; boulder
    tones a (outline) e E m h j; plus the theme's prop colors (each with a darker partner letter
    made by upper/lower casing where listed)."""
    cfg = BORDER[theme_id]
    base = (*cfg["rock"], 255)
    pal = {"D": hue_shift(base, -0.5), "K": hue_shift(base, -0.25), "M": base,
           "L": hue_shift(base, 0.16), "H": hue_shift(base, 0.32), "o": hue_shift(base, -0.68)}
    for k, v in cfg.get("extra", {}).items():
        pal[k] = (*v, 255)
    shades = {"u": "U", "r": "Q", "v": "V", "n": "N", "p": "P", "S": "s", "i": "Y", "g": "G", "c": "Z",
              "t": "X", "T": "W", "l": "A", "O": "B"}
    for k, dark in shades.items():
        if k in pal:
            pal[dark] = hue_shift(pal[k], -0.35)
    return pal


def _rim_color(theme: dict, letter: str):
    """Rim stone: the theme's wall colors, darker and heavier (glowing bits stay brighter)."""
    c = _theme_rgb(theme, letter)
    if letter in "LO":  # lava keeps a faint glow
        return hue_shift(c, -0.3, 0.05)
    if letter in "TBCI":
        return hue_shift(c, -0.12, 0.1)
    return hue_shift(c, -0.34 if letter in "xwW" else -0.4, 0.12)


def _boulder_palette(theme: dict, theme_id: str) -> dict:
    look = BORDER[theme_id]["boulder"]
    w = _theme_rgb(theme, "w")
    W = _theme_rgb(theme, "W")
    if look == "ice":
        w, W = (150, 196, 236, 255), (96, 140, 200, 255)
    elif look == "obsidian":
        w, W = (64, 58, 96, 255), (34, 30, 52, 255)
    mid = hue_shift(mix(w, W, 0.55), -0.3)
    return {"a": hue_shift(mid, -0.7), "e": hue_shift(mid, -0.42), "E": hue_shift(mid, -0.2), "m": mid,
            "h": hue_shift(mid, 0.2), "j": hue_shift(mid, 0.42)}


def _bedrock(theme_id: str, rng, deep: bool) -> list[list[str]]:
    """Plain bedrock (fully seamless: only single pixels and pebbles kept inside the tile)."""
    g = blank("M")
    for _ in range(rng.randint(2, 4)):  # soft darker patches: texture bigger than single pixels
        cx, cy = rng.uniform(2, 14), rng.uniform(2, 14)
        radius = rng.uniform(1.5, 2.8)
        for y in range(16):
            for x in range(16):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= radius * radius and rng.random() < 0.7:
                    g[y][x] = "K"
    for y in range(16):
        for x in range(16):
            r = rng.random()
            if r < (0.08 if deep else 0.05):
                g[y][x] = "K"
            elif r < (0.115 if deep else 0.07):
                g[y][x] = "D"
            elif r < (0.125 if deep else 0.095):
                g[y][x] = "L"
    if BORDER[theme_id].get("strata"):
        for row in (2, 7, 12):  # sediment bands at the same heights at every tile side, so they run on;
            hump = rng.choice((-1.6, -1.0, 0.0, 1.0, 1.6))  # each tile bends them its own way between
            k = rng.choice((1, 2))
            for x in range(16):
                y = row + round(hump * math.sin(math.pi * k * x / 16.0))
                g[y][x] = "S" if rng.random() < 0.9 else "L"
                g[y + 1][x] = "s" if rng.random() < 0.8 else "K"
    for _ in range(rng.randint(1, 2) if deep else rng.randint(3, 5)):
        _pebble(g, rng)
    if not deep and rng.random() < 0.5:
        _fissure(g, rng, rng.randint(3, 6))
    return g


def _pebble(g, rng, x=None, y=None):
    x = rng.randrange(1, 13) if x is None else x
    y = rng.randrange(1, 13) if y is None else y
    w, h = rng.randint(2, 3), rng.randint(2, 3)
    for dy in range(h):
        for dx in range(w):
            g[y + dy][x + dx] = "L" if dx + dy == 0 else ("K" if dx == w - 1 or dy == h - 1 else "M")
    g[y][x] = "H" if rng.random() < 0.5 else "L"
    if y + h < 16 and x + 1 < 16:
        g[y + h][x + 1] = "D"


def _fissure(g, rng, length, color="D", light=None):
    x, y = rng.randrange(2, 14), rng.randrange(2, 14)
    main = rng.choice(art.DIRS8)
    for _ in range(length):
        if 0 <= x < 16 and 0 <= y < 16:
            g[y][x] = color
            if light and 0 <= y - 1 < 16 and g[y - 1][x] not in (color,):
                g[y - 1][x] = light
        dx, dy = main if rng.random() < 0.65 else rng.choice(art.DIRS8)
        x, y = x + dx, y + dy


def _rput(g, x, y, c):
    if 1 <= x < 15 and 1 <= y < 15:
        g[y][x] = c


def prop_pebbles(g, rng):
    for _ in range(rng.randint(3, 4)):
        _pebble(g, rng)


def prop_fissure(g, rng):
    _fissure(g, rng, rng.randint(7, 11), "D", "L")


def prop_bones(g, rng):
    x, y = rng.randrange(2, 7), rng.randrange(4, 12)
    dx, dy = rng.choice([(1, 0), (1, 1), (1, -1)])
    for i in range(6):
        _rput(g, x + dx * i, y + dy * i, "u")
        _rput(g, x + dx * i, y + dy * i + 1, "U")
    for ex, ey in ((x, y), (x + dx * 5, y + dy * 5)):
        _rput(g, ex - dy, ey + dx, "u")
        _rput(g, ex + dy, ey - dx, "u")
    if rng.random() < 0.6:
        _rput(g, rng.randrange(3, 13), rng.randrange(3, 13), "u")


def prop_skull(g, rng):
    x0, y0 = rng.randrange(3, 8), rng.randrange(3, 8)
    for dy, row in enumerate(["ouuuo", "uuuuu", "uDuDu", "uuuuu", "oUuUo", ".U.U."]):
        for dx, c in enumerate(row):
            if c != ".":
                _rput(g, x0 + dx, y0 + dy, c)
    _rput(g, x0 + 5, y0 + 5, "D")


def prop_chain(g, rng):
    x = rng.randrange(4, 12)
    for y in range(1, rng.randrange(9, 15)):
        _rput(g, x, y, "p" if y % 3 else "P")
        if y % 3 == 0:
            _rput(g, x - 1, y, "P")
            _rput(g, x + 1, y, "P")
    _rput(g, x, y + 1, "o")


def prop_drip(g, rng):
    for _ in range(rng.randint(1, 2)):
        x = rng.randrange(2, 14)
        top = rng.randrange(1, 5)
        for y in range(top, top + rng.randint(4, 8)):
            _rput(g, x, y, "N" if y % 2 else "K")
        _rput(g, x, y + 1, "n")


def prop_toxic_drip(g, rng):
    for _ in range(rng.randint(1, 3)):
        x = rng.randrange(2, 14)
        length = rng.randint(3, 9)
        for y in range(1, length):
            _rput(g, x, y, "W" if y < length - 1 else "T")
        _rput(g, x, length, "T")


def prop_roots(g, rng):
    """A root pushing down through the rock: a 2 px trunk that wanders and thins, with rootlets."""
    x, y = rng.randrange(4, 11), 1
    length = rng.randint(10, 13)
    for i in range(length):
        _rput(g, x, y, "r")
        if i < length * 0.6:
            _rput(g, x + 1, y, "Q")
        if rng.random() < 0.22:  # a rootlet curling off sideways
            side = rng.choice((-1, 1))
            bx, by = x + side, y
            for _ in range(rng.randint(2, 4)):
                _rput(g, bx, by, "Q")
                bx += side
                by += 1 if rng.random() < 0.6 else 0
        y += 1
        if rng.random() < 0.35:
            x += rng.choice((-1, 1))


def prop_moss(g, rng):
    for _ in range(rng.randint(2, 4)):
        cx, cy = rng.randrange(3, 13), rng.randrange(3, 13)
        for y in range(16):
            for x in range(16):
                if (x - cx) ** 2 + (y - cy) ** 2 <= rng.uniform(2.0, 6.5):
                    _rput(g, x, y, "v" if y < cy else "V")


def prop_strata_fossil(g, rng):
    x0, y0 = rng.randrange(3, 10), rng.randrange(4, 10)
    for i, (dx, dy) in enumerate(((0, 0), (1, 0), (2, 1), (2, 2), (1, 3), (0, 2), (1, 1))):
        _rput(g, x0 + dx, y0 + dy, "u" if i % 2 == 0 else "U")


def prop_shell(g, rng):
    for _ in range(rng.randint(2, 3)):
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        _rput(g, x, y, "u")
        _rput(g, x + 1, y, "U")
        _rput(g, x, y + 1, "U")


def prop_barnacles(g, rng):
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        _rput(g, x, y, "u")
        _rput(g, x + 1, y, "U")
        _rput(g, x, y + 1, "U")
        _rput(g, x + 1, y + 1, "o")


def prop_seaweed(g, rng):
    for _ in range(rng.randint(2, 3)):
        x = rng.randrange(2, 14)
        for y in range(14, rng.randrange(3, 8), -1):
            _rput(g, x, y, "v" if y % 2 else "V")
            if rng.random() < 0.3:
                x += rng.choice((-1, 1))


def prop_pipe(g, rng):
    y = rng.randrange(4, 10)
    for x in range(1, 15):
        g[y - 1][x] = "o"
        g[y][x] = "p"
        g[y + 1][x] = "P" if x % 5 else "o"
        g[y + 2][x] = "o"
    for _ in range(rng.randint(1, 2)):
        x = rng.randrange(2, 14)
        for yy in range(y + 2, min(15, y + 2 + rng.randint(2, 4))):
            g[yy][x] = "t"


def prop_ice_crack(g, rng):
    _fissure(g, rng, rng.randint(8, 13), "i", None)
    _fissure(g, rng, rng.randint(3, 6), "Y", None)
    _rput(g, rng.randrange(3, 13), rng.randrange(3, 13), "I")


def prop_frost(g, rng):
    for _ in range(rng.randint(5, 8)):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        _rput(g, x, y, "i")
        if rng.random() < 0.5:
            _rput(g, x + 1, y, "Y")
    _rput(g, rng.randrange(3, 13), rng.randrange(3, 13), "I")


def prop_glass(g, rng):
    x0 = rng.randrange(-4, 8)
    for i in range(14):
        _rput(g, x0 + i, 1 + i, "g")
        _rput(g, x0 + i + 1, 1 + i, "G")


def prop_vein(g, rng):
    _fissure(g, rng, rng.randint(8, 12), "v", None)
    _fissure(g, rng, rng.randint(4, 7), "V", None)


def prop_crystals(g, rng):
    bx, by = rng.randrange(4, 11), rng.randrange(9, 14)
    for height, dx in ((rng.randint(5, 7), 0), (rng.randint(3, 5), -2), (rng.randint(2, 4), 2)):
        for i in range(height):
            _rput(g, bx + dx, by - i, "C" if i >= height - 2 else "c")
            _rput(g, bx + dx + 1, by - i, "Z" if i < height - 1 else "c")
    _rput(g, bx - 1, by + 1, "o")
    _rput(g, bx + 3, by + 1, "o")


def prop_sparkle(g, rng):
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        _rput(g, x, y, "C")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rng.random() < 0.5:
                _rput(g, x + dx, y + dy, "Z")


def prop_lava_seam(g, rng):
    x, y = rng.randrange(3, 13), rng.randrange(3, 13)
    main = rng.choice(art.DIRS8)
    for _ in range(rng.randint(8, 12)):
        _rput(g, x, y, "l" if rng.random() < 0.35 else "O")
        for nx, ny in ((x + 1, y), (x, y + 1)):
            if 1 <= nx < 15 and 1 <= ny < 15 and g[ny][nx] not in ("l", "O"):
                g[ny][nx] = "R"
        dx, dy = main if rng.random() < 0.6 else rng.choice(art.DIRS8)
        x, y = max(1, min(14, x + dx)), max(1, min(14, y + dy))


def prop_embers(g, rng):
    for _ in range(rng.randint(4, 7)):
        _rput(g, rng.randrange(1, 15), rng.randrange(1, 15), rng.choice("ORR"))


BORDER_PROPS = {name[5:]: fn for name, fn in globals().items() if name.startswith("prop_")}


def _stone_grid(theme: dict, rng, deco=None, cracks=0, layout=0) -> list[list[str]]:
    """Rim stone: one of the theme's wall constructions as a solid (all-neighbors) wall tile."""
    g = blank("w")
    LAYOUTS[theme["layouts"][layout]](g, rng)
    if deco:
        DECOS[deco](g, rng, [])
    for _ in range(cracks):
        crack(g, rng, rng.randint(5, 9))
    return g


def _field(mask: int, rng):
    """Stone amount (> 0.5 = stone) for pixel centers -1..16 of a corner-terrain tile: the corner
    values blended bilinearly, plus a wobble that fades down toward the tile's sides."""
    corners = [(mask >> i) & 1 for i in range(4)]  # NW, NE, SW, SE
    waves = [(rng.uniform(0.18, 0.42), rng.uniform(0.18, 0.42), rng.uniform(0, math.tau)) for _ in range(3)]
    f = {}
    for y in range(-1, 17):
        for x in range(-1, 17):
            u, v = (x + 0.5) / 16.0, (y + 0.5) / 16.0
            base = (corners[0] * (1 - u) * (1 - v) + corners[1] * u * (1 - v)
                    + corners[2] * (1 - u) * v + corners[3] * u * v)
            wobble = sum(math.sin(a * x + b * y + p) for a, b, p in waves) / 3.0
            # Mostly faded out toward the sides (so neighbors still meet within a pixel or so), but not
            # fully, or every straight run of rim would bulge in the same place on every tile.
            fade = 0.35 + 0.65 * max(0.0, math.sin(math.pi * u)) * max(0.0, math.sin(math.pi * v))
            f[(x, y)] = base + 0.22 * wobble * fade
    return f


def border_terrain(theme: dict, theme_id: str, mask: int, variant: int, seed: int) -> list[list[tuple]]:
    rng = random.Random(seed)
    rock = _bedrock(theme_id, rng, deep=mask == 0 and variant >= 2)
    # Variants 0-1 are the theme's main construction, 2 and 3 its other two (the game lays them in
    # patches, like the maze's own walls).
    stone = _stone_grid(theme, rng, cracks=1 if variant == 1 else 0, layout=max(0, variant - 1))
    field = _field(mask, rng)
    return _composite(theme, theme_id, stone, rock, lambda x, y: field[(x, y)] > 0.5)


def _composite(theme, theme_id, stone, rock, is_stone):
    rpal = _rock_palette(theme_id)
    out = []
    for y in range(16):
        row = []
        for x in range(16):
            if is_stone(x, y):
                edge = any(not is_stone(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                letter = "k" if edge else stone[y][x]
                row.append(hue_shift(_theme_rgb(theme, "k"), -0.3) if edge else _rim_color(theme, letter))
            else:
                shadow = is_stone(x - 1, y - 1) or is_stone(x, y - 1)
                row.append(rpal["D"] if shadow else rpal[rock[y][x]])
        out.append(row)
    return out


def border_prop(theme: dict, theme_id: str, index: int, seed: int):
    rng = random.Random(seed)
    rock = _bedrock(theme_id, rng, deep=index % 3 == 2)
    names = BORDER[theme_id]["props"]
    BORDER_PROPS[names[index % len(names)]](rock, rng)
    return _composite(theme, theme_id, None, rock, lambda x, y: False)


def border_rim(theme: dict, theme_id: str, index: int, seed: int):
    rng = random.Random(seed)
    decos = theme["decos"]
    deco = decos[index % 2] if index % 4 != 3 else None
    stone = _stone_grid(theme, rng, deco=deco, cracks=1 + (index % 4 == 3) * 2 if index >= 8 else 0)
    return _composite(theme, theme_id, stone, None, lambda x, y: True)


def boulder(theme: dict, theme_id: str, index: int, seed: int):
    """A 32x32 boulder on bedrock (the four tiles it covers, as one pixel grid)."""
    rng = random.Random(seed)
    look = BORDER[theme_id]["boulder"]
    rpal = _rock_palette(theme_id)
    bpal = _boulder_palette(theme, theme_id)
    base = [[None] * 32 for _ in range(32)]
    for ty in range(2):
        for tx in range(2):
            rock = _bedrock(theme_id, rng, deep=True)
            for y in range(16):
                for x in range(16):
                    base[ty * 16 + y][tx * 16 + x] = rpal[rock[y][x]]
    cx, cy = rng.uniform(14.0, 18.0), rng.uniform(13.5, 18.5)
    rx, ry = rng.uniform(9.5, 13.0), rng.uniform(8.5, 11.5)
    waves = [(k, rng.uniform(0.04, 0.11), rng.uniform(0, math.tau)) for k in (2, 3, 5)]

    def inside(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        ang = math.atan2(dy, dx)
        edge = 1.0 + sum(a * math.sin(k * ang + p) for k, a, p in waves)
        return dx * dx + dy * dy <= edge * edge

    lx, ly, lz = -0.55, -0.65, 0.52
    for y in range(32):
        for x in range(32):
            if inside(x, y):
                if not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    base[y][x] = bpal["a"]
                    continue
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                nz = math.sqrt(max(0.0, 1.0 - min(1.0, nx * nx + ny * ny)))
                light = nx * lx + ny * ly + nz * lz + rng.uniform(-0.12, 0.12)
                tone = "j" if light > 0.78 else "h" if light > 0.5 else "m" if light > 0.18 else "E" if light > -0.15 else "e"
                base[y][x] = bpal[tone]
            elif inside(x - 2, y - 2) or inside(x - 1, y - 2):
                base[y][x] = rpal["o"] if inside(x - 1, y - 1) else rpal["D"]
    _boulder_detail(base, look, rng, inside, rpal, bpal, cx, cy, rx, ry)
    return base


def _boulder_detail(px, look, rng, inside, rpal, bpal, cx, cy, rx, ry):
    def put_in(x, y, c):
        if 0 <= x < 32 and 0 <= y < 32 and inside(x, y) and px[y][x] != bpal["a"]:
            px[y][x] = c

    def seam(color, glow=None, length=14):
        x, y = cx + rng.uniform(-rx * 0.5, rx * 0.5), cy - ry * 0.6
        for _ in range(length):
            put_in(int(x), int(y), color)
            if glow:
                put_in(int(x) + 1, int(y), glow)
            x += rng.uniform(-1.2, 1.2)
            y += 1

    if look in ("granite", "bones", "pipe", "barnacled"):
        seam(bpal["e"], length=rng.randint(5, 9))
    if look == "mossy":
        for y in range(32):
            for x in range(32):
                if inside(x, y) and not inside(x, y - 3) and rng.random() < 0.85:
                    put_in(x, y, rpal["v"] if rng.random() < 0.7 else rpal["V"])
    elif look == "strata":
        for y in range(int(cy - ry), int(cy + ry), 4):
            for x in range(32):
                put_in(x, y + (1 if (x // 5) % 2 else 0), rpal["S"])
    elif look == "barnacled":
        for _ in range(7):
            x, y = int(cx + rng.uniform(-rx, rx) * 0.7), int(cy + rng.uniform(-ry, ry) * 0.7)
            put_in(x, y, rpal["u"])
            put_in(x + 1, y + 1, rpal["U"])
    elif look == "ice":
        seam(rpal["I"], length=rng.randint(6, 10))
        for _ in range(4):
            put_in(int(cx - rx * 0.4) + rng.randint(-2, 2), int(cy - ry * 0.45) + rng.randint(-2, 2), rpal["I"])
    elif look == "obsidian":
        x0 = int(cx - rx * 0.6)
        for i in range(int(ry * 1.2)):
            put_in(x0 + i, int(cy - ry * 0.6) + i, rpal["g"])
    elif look == "lava":
        seam(rpal["O"], rpal["R"], length=rng.randint(10, 16))
        seam(rpal["l"], None, length=rng.randint(3, 6))
    elif look == "crystal":
        bx, by = int(cx), int(cy + ry * 0.3)
        for height, dx in ((rng.randint(9, 13), 0), (rng.randint(6, 9), -3), (rng.randint(5, 8), 3)):
            for i in range(height):
                for w_ in range(2):
                    put_in(bx + dx + w_, by - i, rpal["C"] if i >= height - 2 else (rpal["c"] if w_ == 0 else rpal["Z"]))
    elif look == "bones":
        x0, y0 = int(cx) - 2, int(cy) - 2
        for dy, row in enumerate(["uuuu", "uDuD", "uuuu", "U.U."]):
            for dx, c in enumerate(row):
                if c != ".":
                    put_in(x0 + dx, y0 + dy, rpal[c])
    elif look == "pipe":
        y = int(cy)
        for x in range(int(cx - rx) - 1, int(cx)):
            for dy, c in ((-1, "o"), (0, "p"), (1, "P"), (2, "o")):
                put_in(x, y + dy, rpal[c])
        put_in(int(cx), y, rpal["o"])
        put_in(int(cx), y + 1, rpal["o"])
        for yy in range(y + 2, y + 6):
            put_in(int(cx) - 1, yy, rpal["T"])


def border_atlas(theme_id: str, theme: dict) -> list[list[tuple]]:
    """The whole 256x128 border atlas as rows of RGBA pixels."""
    base = 90000 + list(THEMES).index(theme_id) * 1000
    tiles = {}
    for variant in range(4):
        for mask in range(16):
            tiles[(mask, variant)] = border_terrain(theme, theme_id, mask, variant, base + variant * 40 + mask)
    for i in range(BORDER_COLUMNS):
        tiles[(i, BORDER_PROP_ROW)] = border_prop(theme, theme_id, i, base + 300 + i)
        tiles[(i, BORDER_RIM_ROW)] = border_rim(theme, theme_id, i, base + 400 + i)
    for b in range(BOULDERS):
        big = boulder(theme, theme_id, b, base + 500 + b)
        for ty in range(2):
            for tx in range(2):
                tiles[(b * 2 + tx, BORDER_BOULDER_ROW + ty)] = [row[tx * 16:tx * 16 + 16] for row in big[ty * 16:ty * 16 + 16]]
    return [[px for column in range(BORDER_COLUMNS) for px in tiles[(column, row)][y]]
            for row in range(BORDER_ROWS) for y in range(16)]


# ---------------------------------------------------------------- output

def png_bytes(pixels: list[list[tuple]]) -> bytes:
    h, w = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + b"".join(bytes(p) for p in row) for row in pixels)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def read_png_pixels(path: Path):
    """Decodes an 8-bit RGBA PNG (as written here) to rows of RGBA tuples; None if unreadable."""
    if not path.exists():
        return None
    data = path.read_bytes()
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        tag, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            if depth != 8 or ctype != 6:
                return None
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride, rows, prev = w * 4, [], bytearray(w * 4)
    for y in range(h):
        kind = raw[y * (stride + 1)]
        line = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if kind == 1:
                line[i] = (line[i] + a) & 255
            elif kind == 2:
                line[i] = (line[i] + b) & 255
            elif kind == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[i:i + 4]) for i in range(0, stride, 4)])
        prev = line
    return rows


def themed_pixels(rows: list[str], pal: dict) -> list[list[tuple]]:
    full = dict(art.PAL)
    full.update({c: rgb(*v) for c, v in pal.items()})
    return [[tuple(full[c]) for c in row] for row in rows]


def all_atlases() -> dict:
    """Every themed atlas, by output path: rows of RGBA pixels."""
    for c in EXTRA:  # defaults so every letter is printable (themes override the ones they use)
        art.PAL.setdefault(c, (255, 0, 255, 255))
    out = {}
    for i, (theme_id, theme) in enumerate(THEMES.items()):
        base = 20000 + i * 1000
        out[OUT / f"{theme_id}_walls.png"] = themed_pixels(atlas([
            [themed_wall(theme, layout, mask, damage, style,
                         seed=base + v * 5000 + damage * 300 + style * 50 + mask) for mask in range(16)]
            for v, layout in enumerate(theme["layouts"]) for damage in range(4) for style in range(3)
        ]), theme["pal"])
        out[OUT / f"{theme_id}_floors.png"] = themed_pixels(atlas([
            [themed_floor(theme, kind, seed=base + 500 + variant * 20 + k) for k, kind in enumerate(FLOOR_TYPES)]
            for variant in range(4)
        ]), theme["pal"])
        out[OUT / f"{theme_id}_fillets.png"] = themed_pixels(atlas([[fillet_tile(mask) for mask in range(16)]]), theme["pal"])
        out[OUT / f"{theme_id}_border.png"] = border_atlas(theme_id, theme)
    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    first = all_atlases()
    if "--check" in sys.argv:  # tests: are the checked-in atlases exactly what this file draws (twice over)?
        second = all_atlases()
        bad = [p.name for p, px in first.items() if px != second[p] or read_png_pixels(p) != px]
        print("theme art check: %d atlases, %s" % (len(first), "OK" if not bad else "DIFFER: " + ", ".join(bad)))
        sys.exit(1 if bad else 0)
    for path, pixels in first.items():
        if read_png_pixels(path) == pixels:
            continue  # unchanged: leave the file (and its import) alone
        path.write_bytes(png_bytes(pixels))
        print(f"wrote {path.relative_to(OUT.parent.parent.parent)} ({len(pixels[0])}x{len(pixels)})")
