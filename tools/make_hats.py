"""Generates the hat sprites (no dependencies): assets/sprites/hats.png.

Run from the project root:  python tools/make_hats.py

One 16x12 frame per hat, side by side (the column is each hat's `column` in scripts/hats.gd).
A hat's brim sits on row 9 with its outline on row 10, and the game places the frame so that
row 11 lines up with the top of the slime's head (sinking it 2 px into the goo). Hats are lit
from the left like the slime and the chalice, with a dark warm outline.

The TOP HAT is a placeholder until the real hat list is decided: add a function per hat below,
list it in HATS, and add a matching entry to Hats.LIST.
"""
from pathlib import Path

from make_placeholder_art import PAL, write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
W, H = 16, 12

PAL.update({
    "Q": (30, 20, 22, 255),     # hat outline
    "1": (110, 100, 132, 255),  # felt highlight
    "2": (70, 62, 88, 255),     # felt light
    "3": (44, 38, 58, 255),     # felt
    "4": (28, 24, 38, 255),     # felt shadow
    "5": (226, 82, 92, 255),    # ribbon light
    "6": (168, 38, 58, 255),    # ribbon
})


def shade(x: int, left: int, right: int) -> str:
    """Felt lit from the left: highlight, light, body, shadow."""
    u = (x - left + 0.5) / (right - left + 1)
    return "1" if u < 0.18 else ("2" if u < 0.4 else ("3" if u < 0.8 else "4"))


def outline(g: list[list[str]]) -> list[str]:
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] not in ".Q"
                                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "Q"
    return ["".join(r) for r in g]


def top_hat() -> list[str]:
    g = [["."] * W for _ in range(H)]
    for y in range(1, 8):      # the crown
        for x in range(5, 11):
            g[y][x] = shade(x, 5, 10)
    for y in (6, 7):           # the ribbon band
        for x in range(5, 11):
            g[y][x] = "5" if x < 7 else "6"
    for y in (8, 9):           # the brim, wider, its top edge catching the light
        for x in range(2, 14):
            g[y][x] = "2" if y == 8 and x < 9 else shade(x, 2, 13)
    return outline(g)


HATS = [top_hat]


if __name__ == "__main__":
    frames = [hat() for hat in HATS]
    write_png(OUT / "hats.png", ["".join(frame[y] for frame in frames) for y in range(H)])
