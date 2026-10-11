"""Generates placeholder pixel art PNGs (no dependencies).

Run from the project root:  python tools/make_placeholder_art.py
Replace the output with real art (e.g. from Aseprite) whenever you like.

Outputs (all 16x16 tiles/frames):
- slime_sheet.png + slime_sheet.json : every slime animation in 20x20 frames (room to squash and
  stretch a ~14 px body), one animation per row
  (the JSON lists each animation's row, frame count, fps and looping)
- shadow.png : shadow under the slime while it's in the air
- chalice_sheet.png : 4 frames of 16x20, a glint sliding along the rim
- walls.png  : 16 columns (neighbor mask: N=1 E=2 S=4 W=8 set when that neighbor is also wall)
               x 12 rows (row = damage * 3 + style; damage 0 intact .. 3 broken; style 0 plain, 1 mossy, 2 stained)
- floors.png : 8 columns (FLOOR_TYPES order) x 4 rows (variants)
- fillets.png: 16 columns (same neighbor mask as walls, for a FLOOR tile): a small curved dark
               fillet in each floor corner where two walls meet, so inner corners look rounded
"""
import json
import math
import random
import struct
import zlib
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"

# Palette (keep all art to these colors). "." = transparent.
PAL = {
    ".": (0, 0, 0, 0),
    "k": (26, 28, 44, 255),     # outline / deepest shadow
    "e": (244, 244, 244, 255),  # highlight white
    "H": (214, 250, 186, 255),  # goo highlight
    "l": (148, 226, 112, 255),  # goo light
    "m": (56, 183, 100, 255),   # goo mid
    "n": (37, 113, 121, 255),   # goo dark
    "D": (22, 66, 82, 255),     # goo deep shadow
    "G": (12, 38, 48, 255),     # goo outline
    "_": (0, 0, 0, 80),         # soft ground shadow under the slime
    "x": (194, 210, 222, 255),  # stone highlight
    "w": (148, 176, 194, 255),  # stone light
    "W": (86, 108, 134, 255),   # stone dark
    "z": (62, 74, 96, 255),     # stone stain
    "f": (51, 44, 64, 255),     # floor
    "F": (40, 34, 52, 255),     # floor dark
    "h": (66, 58, 82, 255),     # floor worn
    "v": (94, 140, 60, 255),    # moss
    "V": (52, 92, 52, 255),     # moss dark
    "d": (41, 54, 111, 255),    # puddle
    "B": (94, 130, 190, 255),   # puddle highlight
    "u": (200, 190, 168, 255),  # bone
    "Y": (255, 240, 180, 255),  # gold highlight
    "y": (255, 205, 117, 255),  # gold
    "o": (209, 136, 58, 255),   # gold shadow
    # The chalice's polished gold (lit from the left) and its details.
    "j": (222, 158, 66, 255),   # chalice gold mid
    "J": (164, 98, 40, 255),    # chalice gold shadow
    "Z": (100, 54, 26, 255),    # chalice gold deep shadow
    "Q": (44, 22, 14, 255),     # chalice outline (dark warm brown)
    "a": (54, 26, 20, 255),     # inside the cup
    "i": (168, 24, 44, 255),    # ruby
    "M": (255, 138, 150, 255),  # ruby glint
}

## The chalice, top to bottom: (half-width of the gold, part). Centered on x = 7.5 in a 16 px
## frame (so every row is an even width); the outline is added around it afterwards.
CHALICE_W, CHALICE_H = 16, 20
CHALICE_PROFILE = [
    (None, None), (None, None),
    (6, "rim_back"),  # far side of the rim, inside of the cup below it
    (6, "opening"),
    (6, "lip"),       # near edge of the rim, catching the light
    (6, "bowl"),
    (6, "band"),      # an engraved band set with a ruby
    (5, "bowl"),
    (5, "bowl"),
    (4, "bowl"),
    (3, "bowl"),
    (2, "bowl"),
    (1, "stem"),
    (2, "knot"),      # a ring on the stem
    (1, "stem"),
    (1, "stem"),
    (2, "foot"),
    (4, "foot"),
    (5, "foot_edge"),
    (None, None),
]
## Polished-metal ramp across each row (left to right, lit from the left): a dim reflected
## edge, the light side, a bright highlight band, the body, then shadow into deep shadow.
CHALICE_RAMP = [(0.1, "J"), (0.26, "y"), (0.4, "Y"), (0.62, "j"), (0.82, "J"), (1.01, "Z")]

N, E, S, W = 1, 2, 4, 8
DIRS8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
FLOOR_TYPES = ["plain", "cracked", "moss", "puddle", "pebbles", "bones", "worn", "rubble"]


def blank(c: str, size: int = 16) -> list[list[str]]:
    return [[c] * size for _ in range(size)]


def put(g, x, y, c, only_opaque=False) -> None:
    if 0 <= x < 16 and 0 <= y < 16 and not (only_opaque and g[y][x] == "."):
        g[y][x] = c


def crack(g, rng, length: int, color="k") -> None:
    """A mostly-straight jagged line from a random point."""
    x, y = rng.randrange(2, 14), rng.randrange(2, 14)
    main = rng.choice(DIRS8)
    for _ in range(length):
        put(g, x, y, color, only_opaque=True)
        dx, dy = main if rng.random() < 0.65 else rng.choice(DIRS8)
        x, y = x + dx, y + dy


def blob(g, rng, cx, cy, radius: float, colors: str, density=0.85) -> None:
    for y in range(16):
        for x in range(16):
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius and rng.random() < density:
                put(g, x, y, rng.choice(colors), only_opaque=True)


# ---------------------------------------------------------------- walls

## Exposed wall corners (two open sides meeting) are rounded off with this radius (px).
CORNER_RADIUS = 4
## Inner corners (a floor tile with walls on two touching sides) get a fillet this big.
FILLET_RADIUS = 6
CORNER_PAIRS = ((N, E), (E, S), (S, W), (W, N))


def corner_cut(x: int, y: int, a: int, b: int, radius: float) -> bool:
    """True if pixel (x, y) lies outside a quarter circle of `radius` rounding the corner
    between sides a and b (so it should be cut away / filled)."""
    right = E in (a, b)
    bottom = S in (a, b)
    # Distance into the corner from each of its two edges, in pixel-center coordinates.
    dx = (x + 0.5) - (16 - radius) if right else radius - (x + 0.5)
    dy = (y + 0.5) - (16 - radius) if bottom else radius - (y + 0.5)
    return dx > 0 and dy > 0 and dx * dx + dy * dy > radius * radius

def side_pixel(side: int, along: int, depth: int) -> tuple[int, int]:
    return {N: (along, depth), S: (along, 15 - depth), W: (depth, along), E: (15 - depth, along)}[side]


def wall_tile(mask: int, damage: int, style: int, seed: int) -> list[str]:
    rng = random.Random(seed)
    open_sides = [s for s in (N, E, S, W) if not mask & s]
    g = blank("w")

    # Brick courses 4 px tall (mortar on the 4th row), joints every 8 px, offset per course.
    # Periods divide 16, so neighbouring wall tiles join seamlessly.
    for y in range(16):
        course = y // 4
        for x in range(16):
            if y % 4 == 3 or (x + (course % 2) * 4) % 8 == 0:
                g[y][x] = "W"
            elif y % 4 == 0 and rng.random() < 0.35:
                g[y][x] = "x"
            elif rng.random() < 0.07:
                g[y][x] = "W"

    # South-facing side shows the wall's front face: darker band.
    if S in open_sides:
        for y in (12, 13, 14):
            for x in range(16):
                g[y][x] = "z" if y == 14 or rng.random() < 0.5 else "W"

    if style == 1:  # mossy: clumps on the upper half, hugging open edges
        for _ in range(rng.randint(3, 5)):
            cx = rng.randrange(1, 15)
            cy = rng.randrange(0, 4) if N in open_sides or rng.random() < 0.5 else rng.randrange(0, 9)
            blob(g, rng, cx, cy, rng.uniform(1.2, 2.4), "vvV")
    elif style == 2:  # stained: water streaks running down
        for _ in range(rng.randint(2, 3)):
            x = rng.randrange(1, 15)
            for y in range(rng.randrange(0, 4), rng.randrange(8, 16)):
                put(g, x, y, "z")
                if rng.random() < 0.25:
                    x = max(0, min(15, x + rng.choice((-1, 1))))

    # Damage: cracks, then chunks knocked out of the exposed edges.
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
    if damage == 3:  # a big corner chunk missing where two open sides meet
        corners = [(a, b) for a, b in ((N, E), (E, S), (S, W), (W, N)) if a in open_sides and b in open_sides]
        if corners:
            a, b = rng.choice(corners)
            size = rng.randint(4, 6)
            cx = 15 if E in (a, b) else 0
            cy = 15 if S in (a, b) else 0
            for y in range(16):
                for x in range(16):
                    if abs(x - cx) + abs(y - cy) < size:
                        g[y][x] = "."

    # Round off exposed corners (wall ends and lone pillars become smooth, not boxy).
    for a, b in CORNER_PAIRS:
        if a in open_sides and b in open_sides:
            for y in range(16):
                for x in range(16):
                    if corner_cut(x, y, a, b, CORNER_RADIUS):
                        g[y][x] = "."

    # Outline: opaque pixels touching a hole or an open edge get a dark rim.
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

    # Rubble pebbles lying in the broken-off gaps.
    if damage >= 2:
        for y in range(16):
            for x in range(16):
                if g[y][x] == "." and rng.random() < (0.08 if damage == 2 else 0.16):
                    g[y][x] = rng.choice("wWz")

    return ["".join(r) for r in g]


def fillet_tile(mask: int) -> list[str]:
    """Overlay for a floor tile whose neighbors in `mask` are walls: a dark curved fillet in every
    corner where two walls meet, continuing the walls' dark rims around the bend."""
    g = blank(".")
    for a, b in CORNER_PAIRS:
        if mask & a and mask & b:
            for y in range(16):
                for x in range(16):
                    if corner_cut(x, y, a, b, FILLET_RADIUS):
                        g[y][x] = "z"
    # Dark rim along the curve (fillet pixels touching the open floor), like the walls' own rims.
    for y in range(16):
        for x in range(16):
            if g[y][x] == "z" and any(
                    0 <= x + dx < 16 and 0 <= y + dy < 16 and g[y + dy][x + dx] == "."
                    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0))):
                g[y][x] = "k"
    return ["".join(r) for r in g]


# ---------------------------------------------------------------- floors

def floor_tile(kind: str, seed: int) -> list[str]:
    rng = random.Random(seed)
    g = blank("f")
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

    if kind == "cracked":
        for _ in range(2):
            crack(g, rng, rng.randint(6, 10))
    elif kind == "moss":
        for _ in range(rng.randint(2, 3)):
            blob(g, rng, rng.randrange(2, 14), rng.randrange(2, 14), rng.uniform(1.5, 2.8), "vVV")
    elif kind == "puddle":
        cx, cy = rng.uniform(5, 10), rng.uniform(5, 10)
        rx, ry = rng.uniform(3, 5), rng.uniform(2, 3)
        for y in range(16):
            for x in range(16):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    g[y][x] = "d"
        for i in range(rng.randint(2, 3)):
            put(g, int(cx - rx / 2) + i, int(cy - ry / 2), "B")
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
        cx, cy = rng.uniform(4, 11), rng.uniform(4, 11)
        blob(g, rng, cx, cy, rng.uniform(3, 4.5), "h", density=0.7)
    elif kind == "rubble":  # debris fallen from a broken wall above
        for _ in range(rng.randint(10, 16)):
            x, y = rng.randrange(0, 15), int(rng.triangular(0, 10, 0))
            put(g, x, y, rng.choice("wWWz"))
            if rng.random() < 0.5:
                put(g, x + 1, y, rng.choice("Wz"))
            put(g, x, y + 1, "k")
    return ["".join(r) for r in g]


# ---------------------------------------------------------------- slime

# Goo shades (the skin shader swaps H/l/m/n/D/G for the skin's own shades).
GOO = {"high": "H", "light": "l", "mid": "m", "dark": "n", "deep": "D", "spec": "e", "outline": "G", "eye": "k"}
HALF_DRY = {"high": "x", "light": "l", "mid": "w", "dark": "n", "deep": "W", "spec": "x", "outline": "G", "eye": "k"}
DRY = {"high": "x", "light": "x", "mid": "w", "dark": "W", "deep": "z", "spec": "x", "outline": "k", "eye": "k"}

DIR_NAMES = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
DIR_VECS = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]
CARDINALS = {"e": (1, 0), "s": (0, 1), "w": (-1, 0), "n": (0, -1)}
FRAME = 20
## Light comes from the top-left, a little in front.
LIGHT = (-0.45, -0.65, 0.62)
## Brightness bands (dot of the dome's normal with LIGHT), brightest first.
BANDS = [(0.78, "light"), (0.3, "mid"), (-0.1, "dark")]


def unit(v) -> tuple[float, float]:
    length = math.hypot(*v)
    return (v[0] / length, v[1] / length)


def slime(along=1.0, perp=1.0, d=(1, 0), sx=1.0, sy=1.0, shift=(0.0, 0.0), look=(0, 1),
          eyes="open", colors=GOO, extras=(), ground=True) -> list[str]:
    """Top-down slime blob centered in a FRAME x FRAME frame.

    The base body is an ellipse with 7x6 px radii, scaled by sx/sy, then stretched by
    `along` in direction d and `perp` across it. It's shaded as a lit dome (BANDS), with a deep
    shadow where it sits on the floor, a reflected rim light, a shine and a tinted
    outline. `look` is where the face points (eyes are hidden when it points up, away from the
    viewer). `ground` adds a soft shadow on the floor under it (off for mid-air frames).
    `extras` are (x, y, color) pixels drawn on empty space afterwards: droplets, sparkles.
    """
    g = blank(".", FRAME)
    dx, dy = unit(d)
    cx, cy = FRAME / 2 + shift[0], FRAME / 2 + shift[1]
    inside = {}
    for y in range(FRAME):
        for x in range(FRAME):
            px, py = x + 0.5 - cx, y + 0.5 - cy
            u, v = (px * dx + py * dy) / along, (-px * dy + py * dx) / perp
            nx, ny = (u * dx - v * dy) / (7.0 * sx), (u * dy + v * dx) / (6.0 * sy)
            if nx * nx + ny * ny <= 1.0:
                inside[(x, y)] = (nx, ny)

    lx, ly, lz = LIGHT
    for (x, y), (nx, ny) in inside.items():
        r2 = nx * nx + ny * ny
        nz = math.sqrt(max(1.0 - r2, 0.0)) * 1.1
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        lit = (nx * lx + ny * ly + nz * lz) / length
        shade = "deep"
        for limit, name in BANDS:
            if lit > limit:
                shade = name
                break
        if ny > 0.8:  # where the goo meets the floor
            shade = "deep"
        elif r2 > 0.7 and nx > 0.25 and ny > 0.1 and shade == "deep":
            shade = "dark"  # light bouncing back up from the floor onto the lower right edge
        g[y][x] = colors[shade]

    if inside:
        # Shine: a small bright patch up and to the left, with one pure white pixel.
        for (x, y), (nx, ny) in inside.items():
            if (nx + 0.38) ** 2 * 1.4 + (ny + 0.5) ** 2 < 0.05:
                g[y][x] = colors["high"]
        sx_, sy_ = min(inside, key=lambda p: (inside[p][0] + 0.42) ** 2 + (inside[p][1] + 0.55) ** 2)
        g[sy_][sx_] = colors["spec"]

    outline = set()
    for y in range(FRAME):
        for x in range(FRAME):
            if (x, y) not in inside and any((x + ox, y + oy) in inside for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = colors["outline"]
                outline.add((x, y))

    if ground and inside:
        # Soft shadow on the floor: the two rows under the body's bottom edge, a little narrower.
        xs = [x for x, _ in inside]
        left, right = min(xs) + 1, max(xs) - 1
        for x in range(left, right + 1):
            column = [y for (px, y) in outline if px == x]
            if column:
                bottom = max(column)
                for y in (bottom + 1, bottom + 2):
                    if y < FRAME and g[y][x] == "." and not (y == bottom + 2 and x in (left, right)):
                        g[y][x] = "_"

    if look is not None and eyes != "none":
        lx2, ly2 = unit(look)
        ax, ay = cx + lx2 * 2.2, cy - 0.5 + ly2 * 2.0
        if ly2 < -0.8:
            spots = []                                 # facing away: back of the head
        elif ly2 < -0.3:
            spots = [ax + (2.0 if lx2 > 0 else -3.0)]  # turned away: one eye peeks out
        else:
            gap = 3.0 if eyes in ("happy", "x") else 2.5
            spots = [ax - gap, ax + gap - 1.0]
        ey = int(math.floor(ay))
        shapes = {
            # (dx, dy, part): "e" = eye, "w" = glint
            "open": [(0, -1, "w"), (1, -1, "e"), (0, 0, "e"), (1, 0, "e"), (0, 1, "e"), (1, 1, "e")],
            "closed": [(0, 1, "e"), (1, 1, "e")],
            "happy": [(0, 0, "e"), (1, 0, "e"), (-1, 1, "e"), (2, 1, "e")],
            "x": [(-1, -1, "e"), (1, -1, "e"), (0, 0, "e"), (-1, 1, "e"), (1, 1, "e")],
        }[eyes]
        for spot in spots:
            ex = int(math.floor(spot))
            for ox, oy, part in shapes:
                if (ex + ox, ey + oy) in inside:
                    g[ey + oy][ex + ox] = colors["spec"] if part == "w" else colors["eye"]
        if len(spots) == 2 and ly2 > 0.3 and eyes in ("open", "happy"):
            mx, my = int(math.floor(ax - 0.5)), ey + 3
            mouth = [(0, 0), (1, 0)] if eyes == "open" else [(-1, 0), (0, 1), (1, 1), (2, 0)]
            for ox, oy in mouth:
                if (mx + ox, my + oy) in inside:
                    g[my + oy][mx + ox] = colors["outline"]

    for x, y, c in extras:
        if 0 <= x < FRAME and 0 <= y < FRAME and g[y][x] in ".":
            g[y][x] = c
    return ["".join(r) for r in g]


def splat_droplets(vec, frame: int) -> list[tuple[int, int, str]]:
    """Goo spattered along the wall the slime hit (wall lies in direction vec)."""
    across = (-vec[1], vec[0])
    spots = {0: [(6, -6, "m"), (6, 6, "m"), (5, -7, "l")], 1: [(7, -7, "n"), (7, 7, "m"), (6, 5, "n")]}.get(frame, [])
    mid = FRAME // 2
    return [(int(mid + a * vec[0] + c * across[0]), int(mid + a * vec[1] + c * across[1]), col) for a, c, col in spots]


def slime_animations() -> dict[str, tuple[list[list[str]], int, bool]]:
    """name -> (frames, fps, loop). fps 0 = frames are picked by game state, not time."""
    anims = {
        "idle": ([slime(sx=a, sy=b, shift=(0, s), eyes=e) for a, b, s, e in
                  [(1, 1, 0, "open"), (1.04, 0.95, 0.3, "open"), (1.07, 0.91, 0.5, "open"), (1.04, 0.95, 0.3, "closed")]],
                 4, True),
    }
    for name, vec in zip(DIR_NAMES, DIR_VECS):
        u = unit(vec)
        anims[f"glide_{name}"] = ([
            slime(along=a, perp=p, d=vec, shift=(u[0] * k, u[1] * k), look=u)
            for a, p, k in [(1.12, 0.9, 0.6), (1.0, 1.0, 0.0), (0.9, 1.05, -0.5), (1.0, 1.0, 0.0)]
        ], 10, True)
        anims[f"charge_{name}"] = ([
            slime(sx=1 + 0.05 * i, sy=1 - 0.11 * i, shift=(0, 0.6 * i), look=u, eyes="closed" if i == 3 else "open")
            for i in range(4)
        ], 0, False)
        anims[f"launch_{name}"] = ([
            slime(along=0.8, perp=1.1, d=vec, look=u), slime(along=1.25, perp=0.8, d=vec, look=u, ground=False),
        ], 0, False)
        anims[f"air_{name}"] = ([
            slime(along=a, perp=p, d=vec, look=u, ground=False) for a, p in [(1.25, 0.8), (1.15, 0.86), (1.06, 0.92), (0.96, 1.0)]
        ], 0, False)
        anims[f"land_{name}"] = ([
            slime(sx=a, sy=b, shift=(0, s), look=u, eyes=e)
            for a, b, s, e in [(1.16, 0.72, 1.2, "closed"), (0.94, 1.08, -0.3, "open"), (1.05, 0.95, 0.2, "open"), (1, 1, 0, "open")]
        ], 16, False)
    for name, vec in CARDINALS.items():
        anims[f"splat_{name}"] = ([
            slime(along=a, perp=p, d=vec, shift=(vec[0] * off, vec[1] * off), eyes="closed" if i < 2 else "open",
                  extras=splat_droplets(vec, i))
            for i, (a, p, off) in enumerate([(0.45, 1.15, 3.0), (0.6, 1.1, 2.4), (0.8, 1.04, 1.2), (0.95, 1.0, 0.3)])
        ], 0, False)
    anims["recover"] = ([slime(sx=1.05, sy=0.95), slime(sx=0.97, sy=1.04)], 12, False)
    anims["dry"] = ([
        slime(sx=0.95, sy=0.95, eyes="closed"),
        slime(sx=0.9, sy=0.8, shift=(0, 1), eyes="closed", colors=HALF_DRY),
        slime(sx=0.85, sy=0.6, shift=(0, 2), eyes="none", colors=DRY),
        slime(sx=0.9, sy=0.42, shift=(0, 3), eyes="none", colors=DRY),
    ], 6, False)
    sparkles = [[(3, 4, "Y"), (16, 3, "y")], [(2, 8, "y"), (17, 6, "Y"), (9, 1, "Y")], [(4, 2, "Y"), (15, 2, "y")], [(1, 5, "Y"), (18, 8, "Y")]]
    anims["celebrate"] = ([
        slime(sx=a, sy=b, shift=(0, s), eyes="happy", extras=sparkles[i], ground=s > -1)
        for i, (a, b, s) in enumerate([(1.1, 0.9, 1), (0.92, 1.1, -1.5), (1, 1, -2.5), (1.05, 0.95, -0.5)])
    ], 8, True)
    return anims


def chalice_frame(glint: int) -> list[str]:
    """One frame of the chalice; `glint` (0-3) is where the moving glint is on the rim."""
    g = [["."] * CHALICE_W for _ in range(CHALICE_H)]
    for y, (half, part) in enumerate(CHALICE_PROFILE):
        if half is None:
            continue
        left, right = 8 - half, 7 + half
        for x in range(left, right + 1):
            u = (x - left + 0.5) / (right - left + 1)
            shade = next(c for limit, c in CHALICE_RAMP if u < limit)
            if part in ("rim_back", "opening"):
                inner = left < x < right
                shade = "a" if inner else ("y" if x == left else "J")
                if part == "rim_back" and inner and u < 0.35:
                    shade = "J"  # the far rim seen from above, lit side
                elif part == "rim_back" and inner:
                    shade = "Z"
            elif part == "lip":
                shade = {"J": "j", "Z": "J"}.get(shade, shade)  # the rim catches more light
            elif part == "band":
                shade = "Z" if shade in ("J", "Z") else "J"  # engraved, darker
            elif part == "knot":
                shade = {"j": "y", "J": "j", "Z": "J"}.get(shade, shade)
            elif part == "foot_edge":
                shade = {"Y": "y", "y": "j", "j": "J", "J": "Z"}.get(shade, shade)
            g[y][x] = shade
    # The ruby on the band (2x2) with a glint.
    band = next(y for y, (_, part) in enumerate(CHALICE_PROFILE) if part == "band")
    g[band][7], g[band][8], g[band + 1][7], g[band + 1][8] = "M", "i", "i", "Z"
    # A steady highlight on the bowl, and the glint that slides along the rim.
    bowl = band + 2
    g[bowl][5] = "e"
    lip = next(y for y, (_, part) in enumerate(CHALICE_PROFILE) if part == "lip")
    gx = 4 + glint * 2
    g[lip][gx] = "e"
    g[lip][gx + 1] = "Y"
    # Dark warm outline around everything.
    for y in range(CHALICE_H):
        for x in range(CHALICE_W):
            if g[y][x] == "." and any(0 <= x + dx < CHALICE_W and 0 <= y + dy < CHALICE_H and g[y + dy][x + dx] not in ".Q"
                                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "Q"
    return ["".join(r) for r in g]


def chalice_frames() -> list[list[str]]:
    """The chalice with a glint sliding along its rim."""
    return [chalice_frame(k) for k in range(4)]


def app_icon() -> list[str]:
    """64x64 app/window icon: the idle slime in Lime green, the starting skin (same shade math as Skins.shades)."""
    import colorsys
    h, s, v = colorsys.rgb_to_hsv(56 / 255, 183 / 255, 100 / 255)
    for key, (hh, ss, vv) in {
        "1": ((h + 0.05) % 1, s * 0.35, min(v * 1.25 + 0.3, 1)),
        "q": ((h + 0.03) % 1, s * 0.7, min(v * 1.2 + 0.12, 1)),
        "r": (h, s, v),
        "t": ((h - 0.05) % 1, min(s * 1.1, 1), v * 0.55),
        "2": ((h - 0.08) % 1, min(s * 1.15, 1), v * 0.33),
        "3": ((h - 0.1) % 1, min(s * 1.2, 1), v * 0.17),
    }.items():
        PAL[key] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(hh, ss, vv)) + (255,)
    frame = [row.translate(str.maketrans("HlmnDG", "1qrt23")) for row in slime()]
    scaled = ["".join(c * 3 for c in row) for row in frame for _ in range(3)]
    pad = (64 - len(scaled)) // 2
    blank_row = "." * 64
    return [blank_row] * pad + ["." * pad + row + "." * (64 - pad - len(row)) for row in scaled] + [blank_row] * (64 - pad - len(scaled))


SHADOW = ["." * 16] * 6 + [
    "....kkkkkkkk....",
    "...kkkkkkkkkk...",
    "....kkkkkkkk....",
] + ["." * 16] * 7


# ---------------------------------------------------------------- output

def write_png(path: Path, rows: list[str]) -> None:
    h, w = len(rows), len(rows[0])
    assert all(len(r) == w for r in rows), f"{path.name}: rows must all be {w} wide"
    raw = b"".join(b"\x00" + b"".join(bytes(PAL[c]) for c in row) for row in rows)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)
    print(f"wrote {path.relative_to(OUT.parent.parent)} ({w}x{h})")


def atlas(tile_rows: list[list[list[str]]]) -> list[str]:
    """Joins a grid of 16x16 tiles (list of rows of tiles) into one image."""
    return ["".join(tile[y] for tile in row) for row in tile_rows for y in range(len(row[0]))]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    anims = slime_animations()
    columns = max(len(frames) for frames, _, _ in anims.values())
    empty = ["." * FRAME] * FRAME
    write_png(OUT / "slime_sheet.png", atlas([frames + [empty] * (columns - len(frames)) for frames, _, _ in anims.values()]))
    manifest = {name: {"row": row, "frames": len(frames), "fps": fps, "loop": loop}
                for row, (name, (frames, fps, loop)) in enumerate(anims.items())}
    (OUT / "slime_sheet.json").write_text(json.dumps({"frame_size": FRAME, "anims": manifest}, indent=1))
    print(f"wrote assets/sprites/slime_sheet.json ({len(anims)} animations, "
          f"{sum(len(f) for f, _, _ in anims.values())} frames)")
    write_png(OUT / "shadow.png", SHADOW)
    write_png(OUT / "chalice_sheet.png", atlas([chalice_frames()]))
    write_png(OUT / "walls.png", atlas([
        [wall_tile(mask, damage, style, seed=1000 + damage * 300 + style * 50 + mask) for mask in range(16)]
        for damage in range(4) for style in range(3)
    ]))
    write_png(OUT / "fillets.png", atlas([[fillet_tile(mask) for mask in range(16)]]))
    write_png(OUT / "floors.png", atlas([
        [floor_tile(kind, seed=5000 + variant * 20 + i) for i, kind in enumerate(FLOOR_TYPES)]
        for variant in range(4)
    ]))
    write_png(OUT.parent.parent / "icon.png", app_icon())
