"""Generates placeholder pixel art PNGs (no dependencies).

Run from the project root:  python tools/make_placeholder_art.py
Replace the output with real art (e.g. from Aseprite) whenever you like.

Outputs (all 16x16 tiles):
- slime.png, chalice.png
- walls.png  : 16 columns (neighbor mask: N=1 E=2 S=4 W=8 set when that neighbor is also wall)
               x 12 rows (row = damage * 3 + style; damage 0 intact .. 3 broken; style 0 plain, 1 mossy, 2 stained)
- floors.png : 8 columns (FLOOR_TYPES order) x 4 rows (variants)
"""
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
    "l": (148, 226, 112, 255),  # goo light
    "m": (56, 183, 100, 255),   # goo mid
    "n": (37, 113, 121, 255),   # goo dark
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
}

SLIME = [
    "................",
    "................",
    "................",
    "................",
    "................",
    "......kkkk......",
    "....kkmmmmkk....",
    "...kmllmmmmmk...",
    "..kmlelmmmmmmk..",
    "..kmllmkmmkmmk..",
    "..kmmmmkmmkmmk..",
    "..kmmmmmmmmmnk..",
    "..knmmmmmmmnnk..",
    ".kknnnmmmmnnnkk.",
    ".knnnnnnnnnnnnk.",
    "..kkkkkkkkkkkk..",
]

CHALICE = [
    "................",
    "...kkkkkkkkkk...",
    "...kYyyyyyyok...",
    "...kyYyyyyyok...",
    "....kyyyyyok....",
    "....kyyyyyok....",
    ".....kyyyok.....",
    "......kyok......",
    ".......yo.......",
    ".......yo.......",
    ".......yo.......",
    "......kyok......",
    ".....kyyyok.....",
    "....kYyyyyook...",
    "....kkkkkkkkk...",
    "................",
]

N, E, S, W = 1, 2, 4, 8
DIRS8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
FLOOR_TYPES = ["plain", "cracked", "moss", "puddle", "pebbles", "bones", "worn", "rubble"]


def blank(c: str) -> list[list[str]]:
    return [[c] * 16 for _ in range(16)]


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
    return ["".join(tile[y] for tile in row) for row in tile_rows for y in range(16)]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "slime.png", SLIME)
    write_png(OUT / "chalice.png", CHALICE)
    write_png(OUT / "walls.png", atlas([
        [wall_tile(mask, damage, style, seed=1000 + damage * 300 + style * 50 + mask) for mask in range(16)]
        for damage in range(4) for style in range(3)
    ]))
    write_png(OUT / "floors.png", atlas([
        [floor_tile(kind, seed=5000 + variant * 20 + i) for i, kind in enumerate(FLOOR_TYPES)]
        for variant in range(4)
    ]))
