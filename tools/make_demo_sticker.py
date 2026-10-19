"""Generates the title screen's DEMO sticker (no dependencies): assets/sprites/title/demo_sticker.png.

Run from the project root:  python tools/make_demo_sticker.py   (then re-import)

Shown only in demo builds (Platform.is_demo(); scripts/ui/title.gd, DEMO_STICKER_POS), under the logo's D by
the left slime. A cream sticker with a dark outline, rounded corners, its top-right corner peeled back (the
grey underside of the paper folded over the cut) and a soft drop shadow, tilted ANGLE degrees clockwise.
DEMO is the game's 5x7 font (tools/make_font.py GLYPHS) at 2x, in the slime sheet's goo shades (l / m / n,
outline G), so the title's skin shader recolors the letters with the equipped skin (rainbow too); the paper
is drawn in fixed colors the shader leaves alone (not a goo shade, not a dry-crust grey).
Goo drips hang under D, E and M; never under the O (a drip there reads DEMP).

The tilt is pixel art, not a blurry rotation: the flat sticker is built as a grid of parts (paper, flap,
letters), turned with three integer shears (Paeth's rotation: every row / column only shifts by whole pixels,
so no pixel is lost, doubled or blended), and only then are the outlines, shading, paper edge and shadow
drawn around the turned parts, so every edge is a clean 1 px line.
"""
import math
from pathlib import Path

from make_font import GLYPHS
from make_placeholder_art import PAL, write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "title" / "demo_sticker.png"
WORD = "DEMO"
SCALE = 2  # the big font's letters (2x the 5x7 glyphs)
LETTER_GAP = 3  # px between letters (room for both letters' goo outline and a pixel of paper)
ANGLE = 12.0  # degrees, clockwise (the right end lower)
PAD_LEFT = 4  # paper around the letters (px)
PAD_RIGHT = 7  # (the peeled corner's side: the flap stays clear of the O)
PAD_TOP = 4
PAD_BOTTOM = 2  # under the longest drip
RADIUS = 3  # rounded corners
PEEL = 7  # the peeled corner's size (px)
SHADOW = (2, 2)
## Drips under a letter: (glyph column of a bottom pixel, length in px). No drip under the O.
DRIPS = {"D": [(1, 3)], "E": [(4, 2)], "M": [(4, 4), (0, 1)], "O": []}

# Paper colors (fixed: none is a goo shade or a dry-crust grey, so the skin shader keeps them).
PAL["c"] = (240, 232, 206, 255)  # cream paper
PAL["p"] = (168, 170, 182, 255)  # the paper's grey underside (the peeled flap)
PAL["s"] = (0, 0, 0, 110)  # soft drop shadow
# Also used: "u" (bone: the paper's lower edge), "k" (outline), goo "l" / "m" / "n" and outline "G".


def flat() -> list[list[str]]:
    """The untilted sticker as parts: '.' empty, 'c' paper, 'p' flap, letter goo already shaded 'l' / 'm' / 'n'
    (shaded flat, so the light falls on each letter's own top edges, not on the tilt's steps)."""
    text_w = len(WORD) * 5 * SCALE + (len(WORD) - 1) * LETTER_GAP
    drip = max((n for d in DRIPS.values() for _, n in d), default=0)
    w = text_w + PAD_LEFT + PAD_RIGHT
    h = PAD_TOP + 7 * SCALE + drip + PAD_BOTTOM
    g = [["c"] * w for _ in range(h)]
    # Rounded corners (the top-right one is the peel).
    for cx, cy in ((0, 0), (0, h - 1), (w - 1, h - 1)):
        for y in range(RADIUS):
            for x in range(RADIUS):
                px, py = (x if cx == 0 else w - 1 - x), (y if cy == 0 else h - 1 - y)
                if math.hypot(RADIUS - 0.5 - x, RADIUS - 0.5 - y) > RADIUS:
                    g[py][px] = "."
    # The peel: the corner triangle above the diagonal is gone, its mirror below the diagonal is the flap.
    for v in range(PEEL + 1):
        for u in range(PEEL + 1):
            x, y = w - 1 - PEEL + u, v
            if u > v:
                g[y][x] = "."
            elif u < v and u + (PEEL - v) >= 1:
                g[y][x] = "p"
    x0 = PAD_LEFT
    for ch in WORD:
        rows = GLYPHS[ch]
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c == "#":
                    for dy in range(SCALE):
                        for dx in range(SCALE):
                            g[PAD_TOP + y * SCALE + dy][x0 + x * SCALE + dx] = "L"
        for col, length in DRIPS[ch]:
            assert rows[-1][col] == "#", f"{ch}: a drip must hang off a bottom pixel"
            for d in range(length):
                for dx in range(SCALE):
                    g[PAD_TOP + 7 * SCALE + d][x0 + col * SCALE + dx] = "L"
        x0 += 5 * SCALE + LETTER_GAP
    goo = [[c == "L" for c in row] for row in g]

    def is_goo(x, y):
        return 0 <= y < h and goo[y][x]

    for y in range(h):
        for x in range(w):
            if goo[y][x]:
                if not is_goo(x, y - 1):
                    g[y][x] = "l"  # the light catches each stroke's top
                elif not is_goo(x, y + 1) and is_goo(x, y - 2):
                    g[y][x] = "n"  # the bottom of a tall stroke, the end of a drip
                else:
                    g[y][x] = "m"
    return g


def rotate(g: list[list[str]], degrees: float) -> list[list[str]]:
    """Turns the grid clockwise by three integer shears (x, then y, then x) about its middle."""
    h, w = len(g), len(g[0])
    size = int(math.hypot(w, h)) + 6
    off_x, off_y = (size - w) // 2, (size - h) // 2
    grid = [["."] * size for _ in range(size)]
    for y in range(h):
        for x in range(w):
            grid[y + off_y][x + off_x] = g[y][x]
    theta = math.radians(degrees)
    a, b = -math.tan(theta / 2), math.sin(theta)
    mid = (size - 1) / 2

    def shear_x(src):
        out = [["."] * size for _ in range(size)]
        for y in range(size):
            shift = round(a * (y - mid))
            for x in range(size):
                if src[y][x] != "." and 0 <= x + shift < size:
                    out[y][x + shift] = src[y][x]
        return out

    def shear_y(src):
        out = [["."] * size for _ in range(size)]
        for x in range(size):
            shift = round(b * (x - mid))
            for y in range(size):
                if src[y][x] != "." and 0 <= y + shift < size:
                    out[y + shift][x] = src[y][x]
        return out

    return shear_x(shear_y(shear_x(grid)))


def render(parts: list[list[str]]) -> list[str]:
    size_y, size_x = len(parts), len(parts[0])

    def at(x, y):
        return parts[y][x] if 0 <= x < size_x and 0 <= y < size_y else "."

    out = [["."] * size_x for _ in range(size_y)]
    for y in range(size_y):
        for x in range(size_x):
            part = parts[y][x]
            if part in "lmn":
                out[y][x] = part
            elif part in "cp":
                near_letter = any(at(x + dx, y + dy) in "lmn" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near_letter:
                    out[y][x] = "G"  # the letters' goo outline
                elif part == "p":
                    out[y][x] = "p"  # (its fold edge gets the sticker's outline)
                elif at(x, y + 1) == "." or any(at(x + dx, y + dy) == "p" for dx, dy in ((-1, 0), (0, 1), (-1, 1))):
                    out[y][x] = "u"  # the paper's lower edge, and the flap's shadow on the paper
                else:
                    out[y][x] = "c"
    for y in range(size_y):  # the outline round the whole sticker
        for x in range(size_x):
            if parts[y][x] == "." and any(at(x + dx, y + dy) != "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = "k"
    drawn = [[c != "." for c in row] for row in out]
    for y in range(size_y):  # the drop shadow
        for x in range(size_x):
            sx, sy = x - SHADOW[0], y - SHADOW[1]
            if not drawn[y][x] and 0 <= sx < size_x and 0 <= sy < size_y and drawn[sy][sx]:
                out[y][x] = "s"
    rows = ["".join(r) for r in out]
    ys = [y for y, r in enumerate(rows) if r.strip(".")]
    xs = [x for x in range(size_x) if any(r[x] != "." for r in rows)]
    return [r[xs[0]:xs[-1] + 1] for r in rows[ys[0]:ys[-1] + 1]]


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    rows = render(rotate(flat(), ANGLE))
    write_png(OUT, rows)
