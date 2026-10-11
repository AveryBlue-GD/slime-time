"""Generates the themed tile art for levels 2-10 and random mazes (no dependencies).

Run from the project root:  python tools/make_theme_art.py
(Level 1, "Dank Dungeon", uses the original walls.png / floors.png / fillets.png from
make_placeholder_art.py.)

Each theme has its own palette, its own stone layout and its own decorations, and writes three
atlases with the same layout as the originals, so the game can swap them in:
- assets/sprites/themes/<id>_walls.png   : 16 neighbor masks x (4 damage * 3 styles)
                                           style 0 = plain, 1 and 2 = the theme's two decorations
- assets/sprites/themes/<id>_floors.png  : 8 floor kinds (same columns as FLOOR_TYPES) x 4 variants
- assets/sprites/themes/<id>_fillets.png : 16 inner-corner fillets

Stone layouts tile seamlessly (every pattern repeats in 16 px).
"""
import random
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
    "mossy": {
        "name": "MOSSY MINES",
        "layout": "rocks", "decos": ("moss", "vines"), "floor": "dirt",
        "kinds": {"worn": "moss"},
        "pal": {"k": (16, 24, 18), "x": (150, 172, 128), "w": (104, 126, 90), "W": (64, 80, 56), "z": (44, 58, 40),
                "f": (38, 46, 30), "F": (26, 32, 22), "h": (50, 62, 38), "v": (98, 164, 62), "V": (52, 104, 46),
                "d": (34, 62, 70), "B": (84, 136, 144), "u": (200, 190, 160)},
    },
    "sandstone": {
        "name": "SANDSTONE SANCTUM",
        "layout": "blocks", "decos": ("glyphs", "sand"), "floor": "sand",
        "kinds": {"moss": "ripples", "puddle": "ripples"},
        "pal": {"k": (48, 28, 22), "x": (248, 224, 166), "w": (216, 174, 112), "W": (164, 118, 72), "z": (126, 86, 54),
                "f": (112, 84, 58), "F": (90, 66, 46), "h": (134, 102, 68), "v": (152, 140, 72), "V": (112, 100, 52),
                "d": (70, 110, 130), "B": (130, 180, 200), "u": (238, 228, 202), "s": (198, 166, 112)},
    },
    "sunken": {
        "name": "SUNKEN SHRINE",
        "layout": "bricks", "decos": ("barnacles", "seaweed"), "floor": "tiles",
        "kinds": {"moss": "puddle", "worn": "puddle"},
        "pal": {"k": (10, 26, 32), "x": (152, 216, 198), "w": (88, 162, 150), "W": (48, 110, 106), "z": (30, 72, 78),
                "f": (24, 48, 68), "F": (16, 34, 52), "h": (34, 62, 84), "v": (62, 152, 112), "V": (30, 98, 82),
                "d": (30, 72, 124), "B": (112, 172, 222), "u": (222, 214, 190)},
    },
    "sewers": {
        "name": "TOXIC TUNNELS",
        "layout": "bricks", "decos": ("slime_drip", "pipe"), "floor": "bricks",
        "kinds": {"moss": "sludge", "puddle": "sludge_puddle", "worn": "grate"},
        "pal": {"k": (22, 18, 16), "x": (152, 138, 112), "w": (114, 100, 80), "W": (76, 66, 52), "z": (54, 46, 36),
                "f": (46, 40, 34), "F": (32, 28, 24), "h": (58, 52, 42), "v": (150, 232, 40), "V": (82, 142, 22),
                "d": (92, 152, 22), "B": (196, 252, 96), "u": (200, 190, 160),
                "T": (170, 246, 52), "t": (88, 150, 24), "P": (120, 128, 134), "p": (70, 76, 84), "r": (150, 74, 36)},
    },
    "catacombs": {
        "name": "CREEPY CATACOMBS",
        "layout": "bricks", "decos": ("skull", "bonepile"), "floor": "flagstone",
        "kinds": {"moss": "bones", "worn": "bones"},
        "pal": {"k": (28, 22, 20), "x": (208, 198, 178), "w": (158, 148, 132), "W": (108, 100, 90), "z": (78, 70, 62),
                "f": (46, 38, 34), "F": (34, 28, 26), "h": (58, 50, 44), "v": (112, 120, 82), "V": (72, 80, 58),
                "d": (40, 44, 60), "B": (90, 96, 120), "u": (234, 224, 198), "b": (150, 140, 120)},
    },
    "frozen": {
        "name": "FROZEN FORTRESS",
        "layout": "blocks", "decos": ("icicles", "frost"), "floor": "ice",
        "kinds": {"moss": "snow", "puddle": "ice_sheet", "worn": "snow"},
        "pal": {"k": (16, 24, 50), "x": (236, 248, 255), "w": (172, 208, 238), "W": (112, 152, 202), "z": (80, 114, 172),
                "f": (40, 56, 94), "F": (30, 42, 74), "h": (56, 76, 116), "v": (196, 224, 244), "V": (142, 182, 222),
                "d": (82, 132, 192), "B": (204, 232, 255), "u": (222, 232, 242), "I": (255, 255, 255)},
    },
    "obsidian": {
        "name": "OBSIDIAN OUBLIETTE",
        "layout": "slabs", "decos": ("gloss", "vein"), "floor": "tiles",
        "kinds": {"moss": "plain", "worn": "plain"},
        "pal": {"k": (6, 6, 10), "x": (154, 144, 214), "w": (72, 68, 104), "W": (42, 40, 62), "z": (28, 26, 44),
                "f": (24, 22, 34), "F": (14, 12, 22), "h": (32, 30, 46), "v": (124, 72, 176), "V": (82, 42, 124),
                "d": (32, 22, 52), "B": (124, 104, 184), "u": (182, 172, 202), "g": (210, 204, 240)},
    },
    "crystal": {
        "name": "CRYSTAL CAVERNS",
        "layout": "rocks", "decos": ("crystal", "sparkle"), "floor": "dirt",
        "kinds": {"moss": "shards", "worn": "shards"},
        "pal": {"k": (22, 10, 32), "x": (198, 162, 232), "w": (142, 102, 182), "W": (94, 62, 132), "z": (66, 42, 94),
                "f": (38, 28, 56), "F": (26, 18, 40), "h": (50, 38, 72), "v": (122, 222, 232), "V": (72, 152, 182),
                "d": (62, 42, 112), "B": (182, 142, 242), "u": (222, 202, 242),
                "C": (244, 214, 255), "c": (206, 112, 244), "q": (112, 52, 164)},
    },
    "volcanic": {
        "name": "VOLCANIC VAULT",
        "layout": "rocks", "decos": ("lava", "embers"), "floor": "dirt",
        "kinds": {"cracked": "lava_crack", "puddle": "lava_pool", "moss": "ash"},
        "pal": {"k": (14, 8, 8), "x": (132, 98, 92), "w": (92, 66, 64), "W": (62, 42, 42), "z": (44, 30, 30),
                "f": (38, 24, 22), "F": (24, 14, 12), "h": (52, 32, 28), "v": (90, 84, 82), "V": (60, 56, 54),
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


LAYOUTS = {"bricks": layout_bricks, "blocks": layout_blocks, "rocks": layout_rocks, "slabs": layout_slabs}


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
    start = rng.randrange(-8, 10)
    for i in range(16):
        for w_ in range(2):
            put(g, start + i + w_, i, "g" if w_ == 0 else "x", only_opaque=True)


def deco_vein(g, rng, open_sides):
    for _ in range(2):
        crack(g, rng, rng.randint(6, 12), color="v")


def deco_crystal(g, rng, open_sides):
    for _ in range(rng.randint(1, 2)):
        bx, by = rng.randrange(3, 13), rng.randrange(8, 15)
        for height, dx in ((rng.randint(4, 7), 0), (rng.randint(3, 5), -2), (rng.randint(2, 4), 2)):
            x = bx + dx
            for i in range(height):
                put(g, x, by - i, "C" if i > height - 2 else "c")
                put(g, x + 1, by - i, "q" if i < height - 1 else "c")


def deco_sparkle(g, rng, open_sides):
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        put(g, x, y, "C")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if rng.random() < 0.5:
                put(g, x + dx, y + dy, "c")


def deco_lava(g, rng, open_sides):
    for _ in range(2):
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


def themed_wall(theme: dict, mask: int, damage: int, style: int, seed: int) -> list[str]:
    """Same steps as make_placeholder_art.wall_tile, with the theme's layout and decorations."""
    rng = random.Random(seed)
    open_sides = [s for s in (N, E, S, W) if not mask & s]
    g = blank("w")
    LAYOUTS[theme["layout"]](g, rng)

    if S in open_sides:  # the south-facing front face: darker band
        for y in (12, 13, 14):
            for x in range(16):
                g[y][x] = "z" if y == 14 or rng.random() < 0.5 else "W"

    if style:
        DECOS[theme["decos"][style - 1]](g, rng, open_sides)

    for _ in range([0, 2, 3, 4][damage]):
        crack(g, rng, rng.randint(5, 10))
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


# ---------------------------------------------------------------- output

def write_themed(path: Path, rows: list[str], pal: dict) -> None:
    saved = dict(art.PAL)
    art.PAL.update({c: rgb(*v) for c, v in pal.items()})
    try:
        art.write_png(path, rows)
    finally:
        art.PAL.clear()
        art.PAL.update(saved)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for c in EXTRA:  # defaults so every letter is printable (themes override the ones they use)
        art.PAL.setdefault(c, (255, 0, 255, 255))
    for i, (theme_id, theme) in enumerate(THEMES.items()):
        base = 20000 + i * 1000
        write_themed(OUT / f"{theme_id}_walls.png", atlas([
            [themed_wall(theme, mask, damage, style, seed=base + damage * 300 + style * 50 + mask) for mask in range(16)]
            for damage in range(4) for style in range(3)
        ]), theme["pal"])
        write_themed(OUT / f"{theme_id}_floors.png", atlas([
            [themed_floor(theme, kind, seed=base + 500 + variant * 20 + k) for k, kind in enumerate(FLOOR_TYPES)]
            for variant in range(4)
        ]), theme["pal"])
        write_themed(OUT / f"{theme_id}_fillets.png", atlas([[fillet_tile(mask) for mask in range(16)]]), theme["pal"])
