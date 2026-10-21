"""Generates the game's pixel font (no dependencies): assets/fonts/pixel.png + pixel.fnt (BMFont text).

Run from the project root:  python tools/make_font.py
Glyphs are 7 px tall and up to 5 px wide; widths are trimmed so the font is proportional.
Lowercase letters reuse the uppercase shapes (the game's text is all caps anyway).

Two atlas pages, each ONE row of glyphs (assets/shaders/text_drips.gdshader finds the font by its
atlas height): page 0 (pixel.png, 9 px tall) is the original 86 glyphs, byte-identical to before the
i18n work (English renders pixel-identical); page 1 (pixel_ext.png, 14 px tall = 5 rows of accent
room + 7 body + 2 below) holds the i18n letters (docs/i18n/fonts.md section 3): accented Latin
(es, pt_BR, fr, de, it, pl, tr, vi), Cyrillic (ru) and punctuation. Their glyphs use yoffset=-5, so
the body sits on the same line box as page 0 and the accents are drawn ABOVE the line box (labels
don't clip); lineHeight / base stay 7, so no English layout moves. Accented letters are composed
from the base letter + mark bitmaps (Unicode NFD), so every new letter keeps the base's pixels.
Translations must be NFC (precomposed): a BMFont can't place combining marks.

Slime look: letters and digits get goo drips (1-2 px) hanging off their bottom edge, and the
glyphs are shaded (bright top, slightly darker body, darker drips). The game tints text with
the skin color, so the grey shades become darker versions of that color.
"""
import random
import struct
import zlib
from pathlib import Path

from make_placeholder_art import PAL
from make_placeholder_art import write_png as _write_png  # same dependency-free PNG writer and palette

OUT = Path(__file__).resolve().parent.parent / "assets" / "fonts"
HEIGHT = 7
## Drips hang below the baseline, inside the line's 2 px of descender space.
DRIP_ROWS = 2
LINE_HEIGHT = HEIGHT + DRIP_ROWS
PAL.update({"1": (215, 215, 215, 255), "2": (160, 160, 160, 255)})  # body / drip shades
SPACE_ADVANCE = 2   # word gap 3 px (1 + 2), was 4 (5 px): the owner found the words too far apart (2026-10-21)

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


def _png_pixels(png: bytes) -> tuple[bytes, bytes]:
    """A PNG's header and decompressed pixel rows (what it shows, whatever zlib packed it)."""
    i, header, idat = 8, b"", b""
    while i < len(png):
        n = struct.unpack(">I", png[i:i + 4])[0]
        tag, body = png[i + 4:i + 8], png[i + 8:i + 8 + n]
        header += body if tag == b"IHDR" else b""
        idat += body if tag == b"IDAT" else b""
        i += 12 + n
    return header, zlib.decompress(idat)


def write_png(path: Path, rows: list[str]) -> None:
    """write_png, but an image whose pixels didn't change keeps its old bytes: zlib builds differ
    between machines, and pixel.png / pixel_big.png must stay byte-identical for English."""
    old = path.read_bytes() if path.exists() else None
    _write_png(path, rows)
    if old is not None and _png_pixels(old) == _png_pixels(path.read_bytes()):
        path.write_bytes(old)


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


# ---------------------------------------------------------------------------------------------------
# i18n letters (page 1). Docs: docs/i18n/fonts.md section 3, plan.md section 7.
ABOVE = 5  # rows of accent room above the 7 px body (Vietnamese stacks need all 5)
BELOW = DRIP_ROWS  # rows under the baseline: below-marks (cedilla, ogonek, dot below) and drips
EXT_HEIGHT = ABOVE + HEIGHT + BELOW

## Marks above (rows top to bottom), drawn 1 px gap above the body; a second mark stacks on the first.
MARKS_ABOVE = {
    "\u0300": ["#..", ".#."],    # grave
    "\u0301": ["..#", ".#."],    # acute
    "\u0302": [".#.", "#.#"],    # circumflex
    "\u0303": [".#.#", "#.#."],  # tilde
    "\u0306": ["#.#", "###"],    # breve (a cup: a V would read as a caron / circumflex)
    "\u0307": ["#"],             # dot above (İ Ż)
    "\u0308": ["#.#"],           # diaeresis
    "\u0309": [".##", "..#"],    # hook above (Vietnamese)
}
## Marks below (rows from the first row under the baseline) and where they hang.
MARKS_BELOW = {
    "\u0323": (["", "#"], "center"),   # dot below (Vietnamese), a gap row then the dot
    "\u0327": ([".#", "#."], "center"),  # cedilla
    "\u0328": (["#.", ".#"], "right"),   # ogonek
}
HORN = "\u031b"  # Ơ Ư: a tick at the top right, outside the letter

## Letters / signs with no Unicode decomposition, drawn by hand: 7 body rows, optional rows below.
EXT_GLYPHS = {
    "Ł": [".#...", ".#...", ".#.#.", ".##..", "##...", ".#...", ".####"],
    "Đ": [".####.", ".#...#", ".#...#", "###..#", ".#...#", ".#...#", ".####."],
    "Æ": [".####", "#.#..", "#.#..", "#####", "#.#..", "#.#..", "#.###"],
    "Œ": [".####", "#.#..", "#.#..", "#.###", "#.#..", "#.#..", ".####"],
    "ẞ": ["####.", "#...#", "#..#.", "#.##.", "#...#", "#...#", "#.##."],
    # Cyrillic shapes that don't exist in Latin (А В Е К М Н О Р С Т Х reuse the Latin glyphs).
    "Б": ["#####", "#....", "#....", "####.", "#...#", "#...#", "####."],
    "Г": ["#####", "#....", "#....", "#....", "#....", "#....", "#...."],
    "Д": ["..##.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#"],
    "Ж": ["#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "#.#.#"],
    "З": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "И": ["#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"],
    "Л": ["..###", ".#..#", ".#..#", ".#..#", ".#..#", ".#..#", "#...#"],
    "П": ["#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"],
    "У": ["#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."],
    "Ф": ["..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#.."],
    "Ц": (["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####"], ["....#"]),
    "Ч": ["#...#", "#...#", "#...#", ".####", "....#", "....#", "....#"],
    "Ш": ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"],
    "Щ": (["#.#.#.", "#.#.#.", "#.#.#.", "#.#.#.", "#.#.#.", "#.#.#.", "######"], [".....#"]),
    "Ъ": ["##...", ".#...", ".#...", ".###.", ".#..#", ".#..#", ".###."],
    "Ы": ["#...#", "#...#", "#...#", "###.#", "#.#.#", "#.#.#", "###.#"],
    "Ь": ["#....", "#....", "#....", "####.", "#...#", "#...#", "####."],
    "Э": [".###.", "#...#", "....#", "..###", "....#", "#...#", ".###."],
    "Ю": ["#..#.", "#.#.#", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."],
    "Я": [".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"],
    # Punctuation.
    "¡": ["#", ".", "#", "#", "#", "#", "#"],
    "¿": ["..#..", ".....", "..#..", ".#...", "#....", "#...#", ".###."],
    "º": [".#.", "#.#", ".#.", "...", "###", "...", "..."],
    "ª": [".##", "#.#", ".##", "...", "###", "...", "..."],
    "«": ["....", "....", ".#.#", "#.#.", ".#.#", "....", "...."],
    "»": ["....", "....", "#.#.", ".#.#", "#.#.", "....", "...."],
    "„": ["...", "...", "...", "...", "...", "#.#", "#.#"],
    "‚": [".", ".", ".", ".", ".", "#", "#"],
    "…": [".....", ".....", ".....", ".....", ".....", ".....", "#.#.#"],
    "–": ["....", "....", "....", "####", "....", "....", "...."],
    "—": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
    "№": ["#..#.###", "##.#.#.#", "#.##.###", "#..#....", "#..#.###", "#..#....", "#..#...."],
    "·": [".", ".", ".", "#", ".", ".", "."],
    "°": [".#.", "#.#", ".#.", "...", "...", "...", "..."],
}
## The i18n letters composed from a base + marks (uppercase; lowercase maps to the same glyph).
EXT_LETTERS = (
    "ÀÁÂÃÄÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝŸĂĄĆĘĞĨİŃŚŞŨŹŻƠƯ"  # Western / Central European, Turkish
    "ẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸ"  # Vietnamese
    "ЁЙ"  # Cyrillic letters with marks
)
## Codepoints drawn with an existing glyph: Cyrillic letters shaped like Latin ones, typographic
## quotes and dashes, Turkish dotless ı (lowercase of I, like every lowercase letter here).
ALIASES = {
    "А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C",
    "Т": "T", "Х": "X", "‘": "'", "’": "'", "“": '"', "”": '"', "‐": "-", "‑": "-", "−": "-",
    "ı": "I",
}
## Spaces with no ink: no-break space (French « » and numbers), narrow / thin spaces, and the
## zero-width space translators use as a line-break hint in Thai / CJK (fonts.md 4.3).
EXT_SPACES = {"\u00a0": SPACE_ADVANCE, "\u202f": 2, "\u2009": 2, "\u200b": 0}


def compose(ch: str, base_rows: dict[str, list[str]]) -> tuple[list[str], set[int]]:
    """An i18n glyph as EXT_HEIGHT rows of '#' / '.', plus the columns that carry a below-mark."""
    import unicodedata
    drawn = EXT_GLYPHS.get(ch)
    below_rows: list[str] = []
    if drawn is not None:
        body, below_rows = drawn if isinstance(drawn, tuple) else (drawn, [])
        marks = ""
    else:
        nfd = unicodedata.normalize("NFD", ch)
        base, marks = ALIASES.get(nfd[0], nfd[0]), nfd[1:]
        body = base_rows[base] if base in base_rows else EXT_GLYPHS[base]
        body = body[0] if isinstance(body, tuple) else body
    width = len(body[0])
    pix: dict[tuple[int, int], str] = {}
    for y, row in enumerate(body):
        for x, c in enumerate(row):
            if c == "#":
                pix[(x, y)] = "#"
    for y, row in enumerate(below_rows):
        for x, c in enumerate(row):
            if c == "#":
                pix[(x, HEIGHT + y)] = "b"
    cursor = -2  # the bottom row of the next mark above (row -1 is the gap)
    stacked = 0
    for mark in marks:
        if mark in MARKS_ABOVE:
            rows = MARKS_ABOVE[mark]
            x0 = (width - len(rows[0]) + 1) // 2
            if stacked:  # Vietnamese stacks: a tone mark leans off the circumflex / breve under it
                x0 += 1 if mark in ("\u0301", "\u0309") else -1 if mark == "\u0300" else 0
            for dy, row in enumerate(rows):
                for dx, c in enumerate(row):
                    if c == "#":
                        pix[(x0 + dx, cursor - len(rows) + 1 + dy)] = "#"
            cursor -= len(rows)
            stacked += 1
        elif mark in MARKS_BELOW:
            rows, anchor = MARKS_BELOW[mark]
            mw = max(len(r) for r in rows)
            x0 = (width - mw + 1) // 2 if anchor == "center" else width - mw
            for dy, row in enumerate(rows):
                for dx, c in enumerate(row):
                    if c == "#":
                        pix[(x0 + dx, HEIGHT + dy)] = "b"
        elif mark == HORN:
            pix[(width, -1)] = "#"
            pix[(width, 0)] = "#"
        else:
            raise ValueError(f"{ch!r}: no bitmap for mark U+{ord(mark):04X}")
    xs = [x for x, _ in pix]
    ys = [y for _, y in pix]
    assert min(ys) >= -ABOVE and max(ys) < HEIGHT + BELOW, f"{ch!r} does not fit the {EXT_HEIGHT} px cell"
    left, right = min(min(xs), 0), max(max(xs), width - 1)
    out = [["."] * (right - left + 1) for _ in range(EXT_HEIGHT)]
    below_cols: set[int] = set()
    for (x, y), c in pix.items():
        out[ABOVE + y][x - left] = c
        if c == "b":
            below_cols.add(x - left)
    rows = ["".join(r) for r in out]
    # Trim empty columns on both sides (like trimmed()).
    cols = [x for x in range(len(rows[0])) if any(r[x] != "." for r in rows)]
    rows = [r[cols[0]:cols[-1] + 1] for r in rows]
    return rows, {x - cols[0] for x in below_cols}


def slimed_ext(ch: str, rows: list[str], below_cols: set[int]) -> list[str]:
    """Shades an i18n glyph like slimed(): bright top 2 body rows and marks above, body, drips under
    the bottom row (never under a below-mark). Below-marks use the body shade, which the drip shader
    tells apart from the drip shade (it keeps them and grows its own drips elsewhere)."""
    width = len(rows[0])
    out = []
    for y, row in enumerate(rows):
        body_y = y - ABOVE
        line = []
        for c in row:
            if c == ".":
                line.append(".")
            elif body_y < 2:
                line.append("e")
            else:
                line.append("1")
        out.append(line)
    bottom = ABOVE + HEIGHT - 1
    if ch.isalnum():
        rng = random.Random(ord(ch) * 7919)
        bottoms = [x for x in range(width) if rows[bottom][x] != "." and x not in below_cols]
        lengths = {x: (2 if r < 0.15 else 1 if r < 0.5 else 0) for x in bottoms for r in [rng.random()]}
        if bottoms and not any(lengths.values()):
            lengths[bottoms[len(bottoms) // 2]] = 1
        if sum(1 for n in lengths.values() if n == 2) > 1:
            for x in [x for x, n in lengths.items() if n == 2][1:]:
                lengths[x] = 1
        for x, length in lengths.items():
            for d in range(length):
                if out[bottom + 1 + d][x] == ".":
                    out[bottom + 1 + d][x] = "2"
    return ["".join(r) for r in out]


def ext_glyphs(base_rows: dict[str, list[str]]) -> dict[str, list[str]]:
    """Every page-1 glyph, slimed, in a fixed order."""
    out = {}
    for ch in list(EXT_GLYPHS) + list(EXT_LETTERS):
        if ch in out:
            continue
        rows, below_cols = compose(ch, base_rows)
        out[ch] = slimed_ext(ch, rows, below_cols)
    return out


def lower_codes(ch: str) -> list[int]:
    """The codepoint and its lowercase (if that is one other codepoint): lowercase shares the glyph."""
    codes = [ord(ch)]
    low = ch.lower()
    if ch.isalpha() and len(low) == 1 and low != ch:
        codes.append(ord(low))
    return codes


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
    # Page 1: the i18n letters, one row EXT_HEIGHT tall (see the module doc).
    base_rows = {ch: trimmed(rows) for ch, rows in GLYPHS.items()}
    ext = ext_glyphs(base_rows)
    ext_x = 0
    ext_placed = {}
    for ch, rows in ext.items():
        ext_placed[ch] = (ext_x, len(rows[0]))
        ext_x += len(rows[0]) + 1
    ext_width = ext_x
    ext_image = [["."] * ext_width for _ in range(EXT_HEIGHT)]
    for ch, rows in ext.items():
        gx, _ = ext_placed[ch]
        for y, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c != ".":
                    ext_image[y][gx + dx] = c
    write_png(OUT / "pixel_ext.png", ["".join(r) for r in ext_image])
    taken = {code for line in chars for code in [int(line.split()[1][3:])]}

    def ext_chars(scale: int) -> list[str]:
        """BMFont lines for page 1, the aliases (pointing at page-0 glyphs) and the no-ink spaces."""
        out = []
        for ch, (gx, gw) in ext_placed.items():
            for code in lower_codes(ch):
                if code not in taken:
                    out.append(f"char id={code} x={gx * scale} y=0 width={gw * scale} height={EXT_HEIGHT * scale} "
                               f"xoffset=1 yoffset={-ABOVE * scale} xadvance={gw * scale + scale} page=1 chnl=15")
        for ch, target in ALIASES.items():
            gx, gw = placed[target]
            for code in lower_codes(ch):
                if code not in taken:
                    out.append(f"char id={code} x={gx * scale} y=0 width={gw * scale} height={LINE_HEIGHT * scale} "
                               f"xoffset=1 yoffset=0 xadvance={gw * scale + scale} page=0 chnl=15")
        for ch, advance in EXT_SPACES.items():
            out.append(f"char id={ord(ch)} x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 "
                       f"xadvance={advance * scale} page=0 chnl=15")
        return out

    chars += ext_chars(1)
    fnt = [
        'info face="SlimePixel" size=8 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        'padding=0,0,0,0 spacing=1,1 outline=0',
        # The line box is the 7 px letter body: the drips hang below it, outside the box, so text is
        # centered (vertically too) on the letters themselves, not on the drips. Labels add the
        # drips' 2 px back as line spacing (UIKit theme / HUD), keeping multi-line text as before.
        # scaleH is page 0's height (the i18n page 1 is taller; Godot sizes each page from its PNG).
        f"common lineHeight={HEIGHT} base={HEIGHT} scaleW={width} scaleH={LINE_HEIGHT} pages=2 packed=0",
        'page id=0 file="pixel.png"',
        'page id=1 file="pixel_ext.png"',
        f"chars count={len(chars)}",
        *chars,
    ]
    (OUT / "pixel.fnt").write_text("\n".join(fnt) + "\n")
    print(f"wrote assets/fonts/pixel.fnt ({len(chars)} characters)")

    # The same font at 2x for 16 px text (titles). Doubled, the 2 px letter gap can be split 1 px
    # on each side of a glyph, so big centered text sits exactly on center (the 8 px font can only
    # get within half a pixel).
    write_png(OUT / "pixel_big.png", ["".join(c * 2 for c in row) for row in image for _ in range(2)])
    big_chars = [f"char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance={SPACE_ADVANCE * 2} page=0 chnl=15"]
    for ch, (gx, gw) in placed.items():
        for code in [ord(ch)] + ([ord(ch.lower())] if ch.isalpha() else []):
            big_chars.append(f"char id={code} x={gx * 2} y=0 width={gw * 2} height={LINE_HEIGHT * 2} xoffset=1 "
                             f"yoffset=0 xadvance={gw * 2 + 2} page=0 chnl=15")
    write_png(OUT / "pixel_big_ext.png", ["".join(c * 2 for c in row) for row in ext_image for _ in range(2)])
    big_chars += ext_chars(2)
    big = [
        'info face="SlimePixelBig" size=16 bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 '
        'padding=0,0,0,0 spacing=1,1 outline=0',
        f"common lineHeight={HEIGHT * 2} base={HEIGHT * 2} scaleW={width * 2} scaleH={LINE_HEIGHT * 2} pages=2 packed=0",
        'page id=0 file="pixel_big.png"',
        'page id=1 file="pixel_big_ext.png"',
        f"chars count={len(big_chars)}",
        *big_chars,
    ]
    (OUT / "pixel_big.fnt").write_text("\n".join(big) + "\n")
    print(f"wrote assets/fonts/pixel_big.fnt ({len(big_chars)} characters)")
