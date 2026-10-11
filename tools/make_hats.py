"""Generates the hat sprites (no dependencies): assets/sprites/hats.png.

Run from the project root:  python tools/make_hats.py

One 16x12 frame per hat, side by side (the column is each hat's `column` in scripts/hats.gd).
A hat's bottom edge sits on row 9 with its outline on row 10, and the game places the frame so
that row 11 lines up with the top of the slime's head (sinking it 2 px into the goo). Hats are
lit from the left like the slime and the chalice, with a dark warm outline.

These ten are placeholders until the real hat list is decided: change a hat's drawing below,
keep HATS in the same order as Hats.LIST.
"""
from pathlib import Path

from make_placeholder_art import PAL, write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"
W, H = 16, 12

# Materials: four shades each, lit (left) to shadow (right). Letters are local to this script.
MATERIALS = {
    "felt": "1234", "ribbon": "56", "leather": "ABCD", "knit": "EFGH", "gold": "IJKL",
    "purple": "OPRS", "blue": "VWXY", "metal": "abcd", "bone": "ef", "white": "ghij",
}
PAL.update({
    "Q": (30, 20, 22, 255),     # outline
    "1": (110, 100, 132, 255), "2": (70, 62, 88, 255), "3": (44, 38, 58, 255), "4": (28, 24, 38, 255),
    "5": (226, 82, 92, 255), "6": (168, 38, 58, 255),
    "A": (196, 140, 88, 255), "B": (158, 104, 60, 255), "C": (118, 74, 42, 255), "D": (82, 50, 30, 255),
    "E": (240, 104, 96, 255), "F": (206, 62, 64, 255), "G": (158, 40, 52, 255), "H": (112, 28, 42, 255),
    "I": (255, 240, 170, 255), "J": (250, 200, 92, 255), "K": (204, 140, 48, 255), "L": (140, 86, 30, 255),
    "M": (230, 40, 70, 255),    # ruby
    "N": (60, 140, 240, 255),   # sapphire
    "O": (170, 120, 230, 255), "P": (124, 78, 196, 255), "R": (88, 52, 150, 255), "S": (58, 32, 104, 255),
    "T": (255, 226, 96, 255),   # star / pompom yellow
    "U": (250, 248, 240, 255),  # pompom white
    "V": (110, 170, 240, 255), "W": (64, 118, 214, 255), "X": (42, 82, 168, 255), "Y": (28, 52, 116, 255),
    "Z": (120, 220, 120, 255),  # propeller green
    "a": (220, 226, 236, 255), "b": (170, 178, 194, 255), "c": (118, 126, 146, 255), "d": (78, 84, 104, 255),
    "e": (246, 236, 210, 255), "f": (200, 184, 150, 255),
    "g": (255, 255, 255, 255), "h": (236, 236, 240, 255), "i": (204, 206, 216, 255), "j": (160, 162, 178, 255),
})


def blank() -> list[list[str]]:
    return [["."] * W for _ in range(H)]


def shade(material: str, x: int, left: int, right: int) -> str:
    """The material's shade for column x of a part spanning left..right (lit from the left)."""
    ramp = MATERIALS[material]
    u = (x - left + 0.5) / (right - left + 1)
    if len(ramp) == 2:
        return ramp[0] if u < 0.45 else ramp[1]
    return ramp[0] if u < 0.18 else (ramp[1] if u < 0.42 else (ramp[2] if u < 0.8 else ramp[3]))


def fill(g, material: str, x0: int, x1: int, y0: int, y1: int) -> None:
    """A shaded block covering columns x0..x1 and rows y0..y1 (inclusive)."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            g[y][x] = shade(material, x, x0, x1)


def rows(g, material: str, spans: dict[int, tuple[int, int]]) -> None:
    """A shape given as {row: (left, right)}, each row shaded across its own width."""
    for y, (x0, x1) in spans.items():
        for x in range(x0, x1 + 1):
            g[y][x] = shade(material, x, x0, x1)


def outline(g) -> list[str]:
    for y in range(H):
        for x in range(W):
            if g[y][x] == "." and any(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] not in ".Q"
                                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[y][x] = "Q"
    return ["".join(r) for r in g]


def top_hat():
    g = blank()
    fill(g, "felt", 5, 10, 1, 7)
    for y in (6, 7):
        for x in range(5, 11):
            g[y][x] = "5" if x < 7 else "6"
    fill(g, "felt", 2, 13, 8, 9)
    for x in range(2, 9):
        g[8][x] = "2"
    return outline(g)


def beanie():
    g = blank()
    rows(g, "knit", {3: (5, 10), 4: (4, 11), 5: (3, 12), 6: (3, 12), 7: (3, 12)})
    fill(g, "knit", 3, 12, 8, 9)
    for x in range(3, 13, 2):  # ribbed cuff
        g[8][x] = g[9][x] = "H"
    g[1][7], g[1][8], g[2][7], g[2][8] = "U", "U", "U", "h"  # pompom
    return outline(g)


def party_hat():
    g = blank()
    spans = {1: (7, 8), 2: (7, 8), 3: (6, 9), 4: (6, 9), 5: (5, 10), 6: (5, 10), 7: (4, 11), 8: (4, 11), 9: (3, 12)}
    rows(g, "blue", spans)
    for y, (x0, x1) in spans.items():  # diagonal stripes
        for x in range(x0, x1 + 1):
            if (x + y) % 4 == 0:
                g[y][x] = "E" if x < 8 else "F"
    g[0][7], g[0][8] = "T", "T"
    return outline(g)


def baseball_cap():
    g = blank()
    rows(g, "blue", {4: (5, 9), 5: (4, 10), 6: (3, 11), 7: (3, 11), 8: (3, 11)})
    for x in range(8, 16):  # the peak sticking out to the right
        g[9][x] = "X" if x < 13 else "Y"
    fill(g, "blue", 3, 11, 9, 9)
    g[3][7] = "W"  # the button on top
    for y in range(5, 9):
        g[y][7] = "X"  # a seam
    return outline(g)


def cowboy_hat():
    g = blank()
    rows(g, "leather", {3: (5, 7), 4: (5, 10), 5: (5, 10), 6: (5, 10), 7: (5, 10)})
    g[3][9], g[3][10] = "B", "C"  # the dent in the crown
    for x in range(5, 11):
        g[7][x] = "D"  # band
    rows(g, "leather", {8: (1, 14), 9: (2, 13)})
    g[7][0], g[7][1], g[7][14], g[7][15] = "A", "A", "C", "C"  # brim curling up
    g[8][0], g[8][15] = "A", "C"
    return outline(g)


def chef_hat():
    g = blank()
    rows(g, "white", {1: (4, 6), 2: (3, 12), 3: (3, 12), 4: (3, 12), 5: (4, 11), 6: (5, 10)})
    g[1][9], g[1][10], g[1][11] = "h", "i", "i"
    g[1][7], g[1][8] = ".", "."  # gaps between the puffs
    fill(g, "white", 4, 11, 7, 9)
    for x in range(4, 12):
        g[7][x] = "j"  # the fold of the band
    return outline(g)


def wizard_hat():
    g = blank()
    rows(g, "purple", {0: (10, 11), 1: (9, 10), 2: (8, 10), 3: (7, 10), 4: (6, 10), 5: (6, 10), 6: (5, 10), 7: (5, 11)})
    rows(g, "purple", {8: (1, 14), 9: (2, 13)})
    g[4][7], g[5][8], g[3][8] = "T", "T", "T"  # a star
    g[6][7] = "T"
    return outline(g)


def viking_helmet():
    g = blank()
    rows(g, "metal", {4: (5, 10), 5: (4, 11), 6: (4, 11), 7: (3, 12), 8: (3, 12), 9: (3, 12)})
    for x in range(3, 13):
        g[8][x] = "d" if x % 3 == 0 else "c"  # rivets on the rim
    for y, xs in {2: (0, 15), 3: (0, 15), 4: (1, 14), 5: (1, 14), 6: (2, 13)}.items():  # horns
        g[y][xs[0]] = "e"
        g[y][xs[1]] = "f"
    g[6][3], g[6][12] = "e", "f"
    return outline(g)


def propeller_cap():
    g = blank()
    rows(g, "knit", {4: (5, 10), 5: (4, 11), 6: (3, 12), 7: (3, 12), 8: (3, 12), 9: (3, 12)})
    for y in range(4, 10):  # colored panels
        for x in range(3, 13):
            if g[y][x] != "." and x >= 8:
                g[y][x] = "W" if x < 11 else "X"
    g[3][7], g[2][7] = "c", "c"  # the stalk
    for x in range(2, 13):
        g[1][x] = "Z" if x < 7 else "T"  # the propeller blades
    return outline(g)


def crown():
    g = blank()
    fill(g, "gold", 3, 12, 6, 9)
    for x in (3, 7, 8, 12):  # the points
        for y in range(3, 6):
            g[y][x] = shade("gold", x, 3, 12)
    for x in (5, 10):
        g[4][x] = g[5][x] = shade("gold", x, 3, 12)
    g[2][3], g[2][12], g[2][7], g[2][8] = "I", "K", "I", "J"  # little balls on top
    g[7][5], g[7][7], g[7][10] = "N", "M", "N"  # gems
    g[7][8] = "M"
    return outline(g)


HATS = [top_hat, beanie, party_hat, baseball_cap, cowboy_hat, chef_hat, wizard_hat, viking_helmet,
        propeller_cap, crown]


if __name__ == "__main__":
    frames = [hat() for hat in HATS]
    write_png(OUT / "hats.png", ["".join(frame[y] for frame in frames) for y in range(H)])
