"""Generates the game's pixel font (no dependencies): assets/fonts/pixel.png + pixel.fnt (BMFont text).

Run from the project root:  python tools/make_font.py
Glyphs are 7 px tall and up to 5 px wide; widths are trimmed so the font is proportional.
Lowercase letters reuse the uppercase shapes (the game's text is all caps anyway).

Slime look: letters and digits get goo drips (1-2 px) hanging off their bottom edge, and the
glyphs are shaded (bright top, slightly darker body, darker drips). The game tints text with
the skin color, so the grey shades become darker versions of that color.
"""
import random
from pathlib import Path

from make_placeholder_art import PAL, write_png  # same dependency-free PNG writer and palette

OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts"
HEIGHT = 7
## Drips hang below the baseline, inside the line's 2 px of descender space.
DRIP_ROWS = 2
LINE_HEIGHT = HEIGHT + DRIP_ROWS
PAL.update({"1": (215, 215, 215, 255), "2": (160, 160, 160, 255)})  # body / drip shades
SPACE_ADVANCE = 4

GLYPHS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    ",": [".", ".", ".", ".", ".", "#", "#"],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    ":": [".", ".", "#", ".", ".", "#", "."],
    ";": [".", ".", "#", ".", ".", "#", "#"],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "-": ["...", "...", "...", "###", "...", "...", "..."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    "=": ["....", "....", "####", "....", "####", "....", "...."],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    "%": ["##..#", "##..#", "...#.", "..#..", ".#...", "#..##", "#..##"],
    "#": [".#.#.", ".#.#.", "#####", ".#.#.", "#####", ".#.#.", ".#.#."],
    "(": ["..#", ".#.", "#..", "#..", "#..", ".#.", "..#"],
    ")": ["#..", ".#.", "..#", "..#", "..#", ".#.", "#.."],
    "[": ["##", "#.", "#.", "#.", "#.", "#.", "##"],
    "]": ["##", ".#", ".#", ".#", ".#", ".#", "##"],
    "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
    ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
    "*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
    "&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
}


def trimmed(rows: list[str]) -> list[str]:
    """Drops empty columns on both sides so glyphs are only as wide as they look."""
    columns = [x for x in range(len(rows[0])) if any(r[x] == "#" for r in rows)]
    if not columns:
        return rows
    return [r[columns[0]:columns[-1] + 1] for r in rows]


def slimed(ch: str, rows: list[str]) -> list[str]:
    """Shades a glyph and adds goo drips under some of its bottom pixels (same every run)."""
    width = len(rows[0])
    out = [[("e" if y < 2 else "1") if c == "#" else "." for c in row] for y, row in enumerate(rows)]
    out += [["."] * width for _ in range(DRIP_ROWS)]
    if not ch.isalnum():
        return ["".join(r) for r in out]
    rng = random.Random(ord(ch) * 7919)
    bottoms = [x for x in range(width) if rows[-1][x] == "#"]
    lengths = {x: (2 if r < 0.15 else 1 if r < 0.5 else 0) for x in bottoms for r in [rng.random()]}
    if bottoms and not any(lengths.values()):
        lengths[bottoms[len(bottoms) // 2]] = 1
    if sum(1 for n in lengths.values() if n == 2) > 1:  # at most one long drip per glyph
        for x in [x for x, n in lengths.items() if n == 2][1:]:
            lengths[x] = 1
    for x, length in lengths.items():
        for d in range(length):
            out[HEIGHT + d][x] = "2"
    return ["".join(r) for r in out]


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    glyphs = {ch: trimmed(rows) for ch, rows in GLYPHS.items()}
    for ch, rows in glyphs.items():
        assert len(rows) == HEIGHT and len({len(r) for r in rows}) == 1, f"glyph {ch!r} is malformed"
    glyphs = {ch: slimed(ch, rows) for ch, rows in glyphs.items()}

    # One row of glyphs with a 1 px gap, white on transparent (the theme colors them).
    x = 0
    placed = {}
    for ch, rows in glyphs.items():
        placed[ch] = (x, len(rows[0]))
        x += len(rows[0]) + 1
    width = x
    image = ["." * width for _ in range(LINE_HEIGHT)]
    image = [list(r) for r in image]
    for ch, rows in glyphs.items():
        gx, gw = placed[ch]
        for y, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c != ".":
                    image[y][gx + dx] = c
    write_png(OUT / "pixel.png", ["".join(r) for r in image])

    chars = [f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={SPACE_ADVANCE} page=0 chnl=15"]
    for ch, (gx, gw) in placed.items():
        codes = [ord(ch)] + ([ord(ch.lower())] if ch.isalpha() else [])
        for code in codes:
            # The 1 px gap between letters sits on each glyph's LEFT (xoffset=1), not its right: a
            # string's measured width then has its spare pixel on the left, so centered text lines
            # up on its actual letter pixels instead of sitting a pixel to the left.
            chars.append(f"char id={code} x={gx} y=0 width={gw} height={LINE_HEIGHT} xoffset=1 yoffset=0 "
                         f"xadvance={gw + 1} page=0 chnl=15")
    fnt = [
        'info face="SlimePixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        'padding=0,0,0,0 spacing=1,1 outline=0',
        # The line box is the 7 px letter body: the drips hang below it, outside the box, so text is
        # centered (vertically too) on the letters themselves, not on the drips. Labels add the
        # drips' 2 px back as line spacing (UIKit theme / HUD), keeping multi-line text as before.
        f"common lineHeight={HEIGHT} base={HEIGHT} scaleW={width} scaleH={LINE_HEIGHT} pages=1 packed=0",
        'page id=0 file="pixel.png"',
        f"chars count={len(chars)}",
        *chars,
    ]
    (OUT / "pixel.fnt").write_text("\n".join(fnt) + "\n")
    print(f"wrote assets/fonts/pixel.fnt ({len(chars)} characters)")
