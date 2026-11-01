"""Generates the spinning coins (no dependencies): assets/sprites/coins.png.

Run from the project root:  python tools/make_coins.py

One row per level theme (Themes.BY_LEVEL order), 8 frames of 12x12 per row: a half turn of the
coin, from face-on to edge-on and back (the back looks the same). Each coin has a dark outline, a
beveled rim, a face lit from the top-left with a shadowed lower-right, an embossed 5x5 emblem
(highlight above-left, shadow below-right) that squashes as the coin turns, a ridged edge you see
mid-turn, and a shine that sweeps across the face. Each theme has its own metal and emblem: a goo
drop in the dungeon, a leaf in the mines, a sun in the sanctum, a shell in the shrine, a drip in
the tunnels, a skull in the catacombs, a snowflake in the fortress, a facet in the oubliette, a
gem in the caverns, a flame in the vault. Coin.GLOW (scripts/coin.gd) matches each metal.
"""
import math
from pathlib import Path

from art_checks import outline_problems
from make_placeholder_art import PAL
from upscale_png import write_png  # writes rows of RGBA tuples

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
SIZE = 12
FRAMES = 8
CLEAR = (0, 0, 0, 0)

# rim (edge + outline), face, light (lit side), shine, emblem
COINS = {
    "dungeon": [(124, 76, 26), (238, 188, 84), (255, 226, 140), (255, 250, 220), (176, 110, 36)],
    "mossy": [(30, 80, 46), (86, 164, 96), (150, 216, 140), (226, 250, 214), (40, 110, 60)],
    "sandstone": [(138, 88, 36), (232, 184, 86), (252, 226, 160), (255, 250, 226), (150, 90, 34)],
    "sunken": [(36, 100, 112), (130, 206, 202), (200, 240, 234), (250, 255, 252), (50, 130, 140)],
    "sewers": [(92, 46, 22), (172, 94, 50), (214, 146, 88), (240, 200, 150), (140, 226, 40)],
    "catacombs": [(82, 76, 70), (196, 188, 172), (232, 226, 212), (255, 252, 244), (64, 54, 50)],
    "frozen": [(62, 100, 160), (164, 206, 238), (222, 242, 255), (255, 255, 255), (96, 150, 214)],
    "obsidian": [(8, 8, 14), (44, 42, 68), (90, 84, 130), (210, 200, 255), (150, 96, 220)],
    "crystal": [(120, 36, 104), (226, 118, 198), (250, 186, 236), (255, 240, 252), (160, 54, 146)],
    "volcanic": [(116, 28, 12), (236, 110, 32), (252, 182, 70), (255, 236, 150), (160, 44, 18)],
}
EMBLEMS = {
    "dungeon": ["..#..", ".###.", "#####", "#####", ".###."],
    "mossy": ["...##", "..###", ".###.", "###..", "#...."],
    "sandstone": ["#.#.#", ".###.", "#####", ".###.", "#.#.#"],
    "sunken": [".###.", "#####", "#.#.#", "#.#.#", ".###."],
    "sewers": ["#####", ".###.", "..#..", "..#..", "..#.."],
    "catacombs": [".###.", "#####", "#.#.#", "#####", ".#.#."],
    "frozen": ["#.#.#", ".###.", "##.##", ".###.", "#.#.#"],
    "obsidian": ["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
    "crystal": [".###.", "#####", "#####", ".###.", "..#.."],
    "volcanic": ["..#..", ".##..", ".###.", "#####", ".###."],
}
OUTLINE_FLOOR = {"obsidian": (30, 24, 52)}
GOLD, GOLD_SHADOW, GOLD_GLINT = PAL["y"], PAL["o"], PAL["Y"]  # CON-06: named from the shared palette
THEME_ORDER = ["dungeon", "mossy", "sandstone", "sunken", "sewers", "catacombs", "frozen", "obsidian",
               "crystal", "volcanic"]


def mix(a: tuple, b: tuple, f: float) -> tuple:
    return tuple(round(a[i] + (b[i] - a[i]) * f) for i in range(3)) + (255,)


def coin_frame(theme: str, k: int) -> list[list[tuple]]:
    rim, face, light, shine, emblem = [(*c, 255) for c in COINS[theme]]
    outline = mix(rim, (0, 0, 0), 0.5)
    if theme in OUTLINE_FLOOR:  # CON-03: a tinted dark, never near-black
        outline = tuple(max(a, b) for a, b in zip(outline, OUTLINE_FLOOR[theme])) + (255,)
    shade = mix(face, rim, 0.45)  # the face's shadowed lower-right
    ridge = mix(rim, (0, 0, 0), 0.25)
    angle = k * math.pi / FRAMES
    turn = abs(math.cos(angle))
    ry = 5.0
    thick = round(2.0 * math.sin(angle))  # the edge you see as it turns
    rx = max(5.0 * turn - thick / 2.0, 0.8)  # SPR-24: the edge is part of the width, so the spin only narrows
    cx = SIZE / 2.0 - thick / 2.0
    cy = SIZE / 2.0

    def in_face(x, y):
        return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0

    def in_edge(x, y):  # the face's ellipse swept `thick` px to the right
        return any(((x + 0.5 - cx - s) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 for s in range(1, thick + 1))

    g = [[CLEAR] * SIZE for _ in range(SIZE)]
    body = {(x, y) for y in range(SIZE) for x in range(SIZE) if in_face(x, y) or in_edge(x, y)}
    for x, y in body:
        if not in_face(x, y):  # ridged edge
            g[y][x] = rim if y % 2 else ridge
            continue
        u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        r = math.hypot(u, v)
        lit = -0.6 * u - 0.8 * v
        if r > 0.74:  # beveled rim: bright toward the light, dark away from it
            g[y][x] = light if lit > 0.35 else (rim if lit < -0.2 else face)
        elif lit > 0.45:
            g[y][x] = light
        elif lit < -0.4:
            g[y][x] = shade
        else:
            g[y][x] = face
    # Embossed emblem, squashed with the turn (skipped when nearly edge-on).
    if rx >= 2.2:
        marks = set()
        for x, y in body:
            if not in_face(x, y):
                continue
            # Pixel offsets from the center as if face-on: crisp 1 px cells, squashed by the turn.
            ex = math.floor((x + 0.5 - cx) / turn + 2.5)
            ey = math.floor(y + 0.5 - cy + 2.5)
            if 0 <= ex < 5 and 0 <= ey < 5 and EMBLEMS[theme][ey][ex] == "#":
                marks.add((x, y))
        deep = mix(emblem, outline, 0.25)
        for x, y in marks:
            g[y][x] = deep
            if (x - 1, y - 1) not in marks and (x - 1, y - 1) in body and in_face(x - 1, y - 1):
                g[y - 1][x - 1] = mix(light, shine, 0.5)
        for x, y in marks:
            if (x + 1, y + 1) not in marks and (x + 1, y + 1) in body and in_face(x + 1, y + 1):
                g[y + 1][x + 1] = shade
    # A shine sweeping diagonally across the face, plus a fixed glint up top-left.
    sweep = 2.0 + k * 2.6
    for x, y in body:
        if in_face(x, y) and abs((x + y) - sweep) < 0.6:
            g[y][x] = mix(g[y][x][:3], shine, 0.7)
    if rx >= 3.0:
        gx, gy = round(cx - rx * 0.45), round(cy - ry * 0.5)
        if (gx, gy) in body:
            g[gy][gx] = shine
    # Dark outline around everything.
    out = [row[:] for row in g]
    for y in range(SIZE):
        for x in range(SIZE):
            if (x, y) in body and any((x + dx, y + dy) not in body for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = outline
    if theme != "dungeon":  # SPR-10 / CON-07: every themed coin keeps a gold rim and a gold glint
        ring = [(x, y) for x, y in body if in_face(x, y) and out[y][x] != outline
                and any((x + dx, y + dy) not in body or out[y + dy][x + dx] == outline
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        best = None
        for x, y in ring:
            u, v = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            lit = -0.6 * u - 0.8 * v
            out[y][x] = GOLD if lit > -0.1 else GOLD_SHADOW
            if best is None or lit > best[0]:
                best = (lit, x, y)
        if best and rx >= 2.2:
            out[best[2]][best[1]] = GOLD_GLINT
    return out


def check() -> int:
    """CON-06 / M32: no outline darker than a max channel of 16, and the two sheets agree."""
    bad = 0
    for theme in THEME_ORDER:
        rim = COINS[theme][0]
        o = mix((*rim, 255), (0, 0, 0), 0.5)
        if theme in OUTLINE_FLOOR:
            o = tuple(max(a, b) for a, b in zip(o, OUTLINE_FLOOR[theme]))
        for msg in outline_problems({"coin " + theme: o}):
            print(msg)
            bad += 1
    print("coins check: %s" % ("OK" if not bad else "FAIL"))
    return 1 if bad else 0


if __name__ == "__main__":
    import sys
    if "--check" in sys.argv:
        sys.exit(check())
    rows = []
    for theme in THEME_ORDER:
        frames = [coin_frame(theme, k) for k in range(FRAMES)]
        for y in range(SIZE):
            rows.append([px for frame in frames for px in frame[y]])
    write_png(str(OUT / "coins.png"), rows)
