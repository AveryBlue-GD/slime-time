"""Generates the spinning coins (no dependencies): assets/sprites/coins.png.

Run from the project root:  python tools/make_coins.py

One row per level theme (Themes.BY_LEVEL order), 8 frames of 10x10 per row: a half turn of the
coin, from face-on to edge-on and back (the back looks the same). Each theme's coin has its own
metal and a tiny emblem: a goo drop in the dungeon, a leaf in the mines, a sun in the sanctum,
a shell in the shrine, a drip in the tunnels, a skull in the catacombs, a snowflake in the
fortress, a facet in the oubliette, a gem in the caverns, a flame in the vault.
"""
import math
from pathlib import Path

from upscale_png import write_png  # writes rows of RGBA tuples

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
SIZE = 10
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
    "dungeon": [".#.", "###", "###"],
    "mossy": ["..#", ".##", "#.."],
    "sandstone": ["#.#", ".#.", "#.#"],
    "sunken": ["###", "#.#", "#.#"],
    "sewers": ["###", ".#.", ".#."],
    "catacombs": ["###", "#.#", ".#."],
    "frozen": [".#.", "###", ".#."],
    "obsidian": [".#.", "#.#", ".#."],
    "crystal": ["###", "###", ".#."],
    "volcanic": [".#.", "##.", "###"],
}
THEME_ORDER = ["dungeon", "mossy", "sandstone", "sunken", "sewers", "catacombs", "frozen", "obsidian",
               "crystal", "volcanic"]


def coin_frame(theme: str, k: int) -> list[list[tuple]]:
    rim, face, light, shine, emblem = [(*c, 255) for c in COINS[theme]]
    angle = k * math.pi / FRAMES
    rx = max(4.0 * abs(math.cos(angle)), 0.7)
    ry = 4.0
    cx = cy = SIZE / 2.0
    inside = set()
    for y in range(SIZE):
        for x in range(SIZE):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                inside.add((x, y))
    g = [[CLEAR] * SIZE for _ in range(SIZE)]
    for x, y in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            g[y][x] = rim
        elif x + 0.5 < cx - rx * 0.15:
            g[y][x] = light  # the side facing the light
        else:
            g[y][x] = face
    if rx >= 3.4:  # face-on enough to see the emblem and a shine
        for dy, row in enumerate(EMBLEMS[theme]):
            for dx, c in enumerate(row):
                if c == "#":
                    g[3 + dy][4 + dx] = emblem
        g[2][3] = shine
    elif rx < 1.5:  # edge-on: a thin bright bar
        for x, y in inside:
            if 1 < y < SIZE - 2:
                g[y][x] = light if x + 0.5 <= cx else face
    return g


if __name__ == "__main__":
    rows = []
    for theme in THEME_ORDER:
        frames = [coin_frame(theme, k) for k in range(FRAMES)]
        for y in range(SIZE):
            rows.append([px for frame in frames for px in frame[y]])
    write_png(str(OUT / "coins.png"), rows)
