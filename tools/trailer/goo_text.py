"""Trailer text in the DRY TRYING logo's lettering: thick capsule strokes with goo drips, the logo's goo
shades (recoloured to the caption's colour the way the game's palette-swap shader recolours the logo),
its white gloss dashes, dark outline and drop shadow. Marketing only (tools/trailer/trailer.py).

The letters come from tools/make_title.py's render_text (the logo's own code, so the shapes, strokes,
drips and shading are the logo's; the logo PNGs stay pixel-identical): its LETTERS where it has them,
else the game font's 5x7 glyphs (tools/make_font.py GLYPHS: A-Z, 0-9 and the punctuation), and Simplified
Chinese from tools/trailer/goo_cjk/goo_cjk.json (12x12, drawn as tall as the letters). Drips and
blob lumps are seeded from the text, so a caption renders the same every time.

Everything is drawn on a 540x960 canvas (SCALE = 2: one logo pixel = 2x2 px of the 1080x1920 frame),
which trailer.py scales up with nearest neighbour.
  caption_png(path, job)   a caption overlay: lines wrapped to the safe column, at "top" / "low" / y
  card_text_png(path, ...)  the end card's tagline, CTA and store line (centred, from a given y)
"""
import colorsys
import json
import os
import re
import struct
import sys
import zlib

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(TOOLS)
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

import make_font  # noqa: E402  (tools/: the game font's glyph table)
import make_title  # noqa: E402  (tools/: the logo's lettering)

SCALE = 2
CANVAS = (540, 960)            # 1080x1920 / SCALE
COLUMN = (20, 436)             # captions: x from 20, 436 wide (clear of the right ~15% button rail)
TOP_Y = 68                     # "top": 136 px on the frame, under the status bar
LOW_Y = 600                    # "low": 1200 px on the frame
ABOVE_GAP = 6                  # a beat's "above": the space between the caption and what it sits on
SAFE_BOTTOM = 768              # the block ends above 80% of the frame (caption, likes, progress bar)
LINE_PITCH = 62                # line tops apart: 42 px letters + the longest drips + a clear row
LINE_H = make_title.MARGIN + 7 * make_title.CELL + 24  # one rendered line's height (70)
GLYPHS = dict(make_font.GLYPHS)
GLYPHS.update(make_title.LETTERS)  # the logo's own letter shapes win (its S and G)
GLYPHS["0"] = GLYPHS["O"]  # (the font's slashed zero reads as an O-slash this big)
# Simplified Chinese (12x12 cells, drawn as tall as the 5x7 letters: make_title.glyph_cell), for the
# Douyin / Bilibili cuts (trailer.py --lang zh). Latin, digits and ASCII punctuation keep the goo letters.
CJK_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "goo_cjk", "goo_cjk.json")
with open(CJK_JSON, encoding="utf-8") as _f:
    CJK = {ch: rows for ch, rows in json.load(_f)["glyphs"].items() if ch not in GLYPHS}
GLYPHS.update(CJK)
NO_LINE_START = set("，。！？：；、…）」】—")  # (Chinese punctuation never starts a line)
NO_LINE_END = set("（「【")

WHITE = (244, 244, 244)       # UIKit.TEXT
GOLD = (255, 205, 117)        # UIKit.GOLD
DIM = (148, 176, 194)         # UIKit.TEXT_DIM
GLOSS = (244, 244, 244, 255)  # the logo's "e" (the shader leaves it white)
OUTLINE = (26, 28, 44, 255)   # the logo's "k" (UIKit.BG, left as is by the shader)
SHADOW = (8, 8, 14, 255)      # the logo's "K" drop shadow


def files_sha_input():
    """The files whose content decides how text renders (for trailer.py's caches)."""
    return [os.path.abspath(__file__), os.path.join(TOOLS, "make_title.py"), os.path.join(TOOLS, "make_font.py"),
            os.path.join(ROOT, "scripts", "skins.gd"), CJK_JSON]


# ------------------------------------------------------------------ colours

def skin_colors():
    """{skin id: (r, g, b)} from the presets in scripts/skins.gd."""
    out = {}
    with open(os.path.join(ROOT, "scripts", "skins.gd"), encoding="utf-8") as f:
        for m in re.finditer(r'id = "(\w+)".*?color = Color8\((\d+), (\d+), (\d+)\)', f.read()):
            out[m.group(1)] = tuple(int(v) for v in m.groups()[1:])
    return out


def _readable(rgb):
    """card.gd's rule: a dark skin colour (INKKY) lifted so it reads on the dark frame."""
    r, g, b = (c / 255.0 for c in rgb)
    if 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.35:
        return tuple(round((c + (1.0 - c) * 0.45) * 255) for c in (r, g, b))
    return rgb


def color_of(name, skin=""):
    """A caption colour: "white", "gold", "dim", "skin" (the beat's skin), a skin id or "#rrggbb"."""
    if name in ("", "white"):
        return WHITE
    if name == "gold":
        return GOLD
    if name == "dim":
        return DIM
    if name.startswith("#"):
        return tuple(int(name[i:i + 2], 16) for i in (1, 3, 5))
    skins = skin_colors()
    if name == "skin":
        name = skin or "lime"
    if name in skins:
        return _readable(skins[name])
    return WHITE


def _hsv(h, s, v):
    return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(s, 1.0)), max(0.0, min(v, 1.0)))) + (255,)


def shades(rgb):
    """Skins.shades (scripts/skins.gd): the goo's light / mid / dark from one base colour, as the
    palette-swap shader puts them on the logo's l / m / n pixels."""
    h, s, v = colorsys.rgb_to_hsv(*(c / 255.0 for c in rgb))
    return {
        "l": _hsv(h + 0.03, s * 0.7, min(v * 1.2 + 0.12, 1.0)),
        "m": tuple(rgb) + (255,),
        "n": _hsv(h - 0.05, min(s * 1.1, 1.0), v * 0.55),
        "e": GLOSS,
        "k": OUTLINE,
        "K": SHADOW,
    }


# ------------------------------------------------------------------ layout

def check(text):
    bad = sorted({ch for ch in text if ch != " " and ch not in GLYPHS})
    if bad:
        raise ValueError("goo text has no glyph for %r (in %r)" % ("".join(bad), text))


def width(text):
    return make_title.text_width(text, GLYPHS)


def _units(text):
    """The breakable pieces of a line: (piece, joins_previous). Words split at spaces; Chinese can also
    break between any two characters (a run of Latin / digits stays whole, punctuation stays with its
    neighbour), and those pieces join without a space."""
    out = []
    for word in text.split():
        pieces = []
        for ch in word:
            if pieces and (ch in NO_LINE_START or pieces[-1][-1] in NO_LINE_END
                           or (ch not in CJK and pieces[-1][-1] not in CJK)):
                pieces[-1] += ch
            else:
                pieces.append(ch)
        out += [(p, i > 0) for i, p in enumerate(pieces)]
    return out


def wrap(text, max_w):
    """Greedy word wrap of one caption line into lines at most `max_w` px wide (a single word wider
    than that stays on its own line; Chinese wraps between characters); a lone short word left on the
    last line takes the word before it along ("BEFORE YOU / DRY UP", not "BEFORE YOU DRY / UP")."""
    check(text)  # (a clear message for a missing glyph, before width() would raise a bare KeyError)
    out, cur = [], ""
    for piece, joins in _units(text):
        trial = (cur + ("" if joins else " ") + piece) if cur else piece
        if cur and width(trial) > max_w:
            out.append(cur)
            cur = piece
        else:
            cur = trial
    if cur:
        out.append(cur)
    if any(ch in CJK for ch in text):
        return out  # (the lone-word rule below is for spaced words)
    if len(out) > 1 and " " not in out[-1] and " " in out[-2] and width(out[-1]) < 0.5 * max(width(l) for l in out):
        head, moved = out[-2].rsplit(" ", 1)
        if width(moved + " " + out[-1]) <= max_w:
            out[-2:] = [head, moved + " " + out[-1]]
    return out


def _seed(text, k):
    return zlib.crc32(("%s|%d" % (text, k)).encode("utf-8"))


class Canvas:
    def __init__(self, size=CANVAS):
        self.w, self.h = size
        self.px = bytearray(self.w * self.h * 4)

    def blit_line(self, text, color, x, y, k=0):
        """One line of goo text, its top-left at (x, y); drips and lumps seeded from the text."""
        check(text)
        rows = make_title.render_text(text, drip_seed=_seed(text, k), body_seed=_seed(text, k + 1000), glyphs=GLYPHS)
        pal = shades(color)
        for ry, row in enumerate(rows):
            py = y + ry
            if not 0 <= py < self.h:
                continue
            for rx, ch in enumerate(row):
                px = x + rx
                if ch == "." or not 0 <= px < self.w:
                    continue
                i = (py * self.w + px) * 4
                self.px[i:i + 4] = bytes(pal[ch])

    def block(self, lines, cx, top):
        """`lines` = [(text, rgb)], each centred on x = cx, LINE_PITCH apart from `top`; drawn bottom
        line first, so an upper line's drips hang over the line below."""
        placed = [(text, color, int(round(cx - width(text) / 2.0)), top + i * LINE_PITCH) for i, (text, color) in enumerate(lines)]
        for k, (text, color, x, y) in reversed(list(enumerate(placed))):
            self.blit_line(text, color, x, y, k)

    def save(self, path):
        raw = b"".join(b"\x00" + bytes(self.px[y * self.w * 4:(y + 1) * self.w * 4]) for y in range(self.h))

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
               + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
        with open(path, "wb") as f:
            f.write(png)


def block_height(n):
    return 0 if n == 0 else (n - 1) * LINE_PITCH + LINE_H


def caption_lines(job):
    """The wrapped [(text, rgb)] of a caption job (trailer.py caption_job)."""
    lines = []
    # (a caption centred on the frame may use its width but the side margins: about 15 letters a line)
    width = CANVAS[0] - 2 * COLUMN[0] if job.get("center") == "frame" else COLUMN[1]
    for key, color_key in (("lines", "color"), ("sub", "sub_color")):
        color = color_of(job.get(color_key, "white"), job.get("skin", ""))
        for text in job.get(key, []):
            lines += [(t, color) for t in wrap(text.upper(), width)]
    return lines


def caption_png(path, job):
    lines = caption_lines(job)
    at = job.get("at", "top")
    if isinstance(at, (int, float)):
        y = int(at) * 2  # (a number is a y on the old 270x480 caption canvas)
    else:
        y = LOW_Y if at == "low" else TOP_Y
    if job.get("above") is not None:  # (the block ends just above this y of a 180x320 portrait view)
        y = max(int(job["above"]) * CANVAS[1] // 320 - ABOVE_GAP - block_height(len(lines)), TOP_Y)
    y = min(y, SAFE_BOTTOM - block_height(len(lines)))
    c = Canvas()
    c.block(lines, CANVAS[0] / 2.0 if job.get("center") == "frame" else COLUMN[0] + COLUMN[1] / 2.0, y)
    c.save(path)


def card_text_png(path, tagline, cta, store, skin, top):
    """The end card's words (tagline white, CTA in the skin's colour, store line dim), centred on the
    frame from canvas y `top`, a little gap between the groups."""
    c = Canvas()
    y = top
    for group, color in ((tagline, WHITE), (cta, color_of("skin", skin)), (store, DIM)):
        lines = []
        for text in group:
            lines += [(t, color) for t in wrap(text.upper(), 470)]
        if not lines:
            continue
        c.block(lines, CANVAS[0] / 2.0, y)
        y += block_height(len(lines)) + 8
    c.save(path)
    return y


if __name__ == "__main__":  # quick look: python tools/trailer/goo_text.py OUT.png "TEXT|MORE" [color]
    out, text = sys.argv[1], sys.argv[2]
    caption_png(out, {"lines": text.split("|"), "color": sys.argv[3] if len(sys.argv) > 3 else "white"})
