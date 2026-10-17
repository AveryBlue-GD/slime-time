"""Contact sheets and the missing-glyph report for tools/i18n_capture.sh (no dependencies).

  python3 -I tools/i18n_contact_sheet.py merge  --out DIR
      Merges DIR/json/missing_<locale>.json into DIR/missing_glyphs.json and prints a summary.
  python3 -I tools/i18n_contact_sheet.py sheets --out DIR [--locales en,de,...] [--cols N] [--scale 2]
      DIR/sheets/locale_<locale>.png : every state of one language (labeled, nearest upscale).
      DIR/sheets/state_<slug>.png    : one state in every language.

Reads the sidecars the Godot driver writes (DIR/<locale>/.raw/<slug>.rgbz: two int32 sizes + zlib RGB8);
falls back to decoding the PNG. Labels use a built-in 5x7 ASCII font (state names and locale codes).
"""
import argparse
import glob
import json
import os
import struct
import sys
import zlib
from multiprocessing import Pool

ORDER = ["en", "es", "pt_BR", "fr", "de", "it", "ru", "pl", "tr", "ja", "ko", "zh_CN", "zh_TW", "th",
         "vi", "id", "ar", "hi", "pseudo"]

FONT = {
    "A": "01110 10001 10001 11111 10001 10001 10001", "B": "11110 10001 10001 11110 10001 10001 11110",
    "C": "01110 10001 10000 10000 10000 10001 01110", "D": "11110 10001 10001 10001 10001 10001 11110",
    "E": "11111 10000 10000 11110 10000 10000 11111", "F": "11111 10000 10000 11110 10000 10000 10000",
    "G": "01110 10001 10000 10111 10001 10001 01111", "H": "10001 10001 10001 11111 10001 10001 10001",
    "I": "01110 00100 00100 00100 00100 00100 01110", "J": "00111 00010 00010 00010 00010 10010 01100",
    "K": "10001 10010 10100 11000 10100 10010 10001", "L": "10000 10000 10000 10000 10000 10000 11111",
    "M": "10001 11011 10101 10101 10001 10001 10001", "N": "10001 11001 10101 10011 10001 10001 10001",
    "O": "01110 10001 10001 10001 10001 10001 01110", "P": "11110 10001 10001 11110 10000 10000 10000",
    "Q": "01110 10001 10001 10001 10101 10010 01101", "R": "11110 10001 10001 11110 10100 10010 10001",
    "S": "01111 10000 10000 01110 00001 00001 11110", "T": "11111 00100 00100 00100 00100 00100 00100",
    "U": "10001 10001 10001 10001 10001 10001 01110", "V": "10001 10001 10001 10001 10001 01010 00100",
    "W": "10001 10001 10001 10101 10101 11011 10001", "X": "10001 10001 01010 00100 01010 10001 10001",
    "Y": "10001 10001 01010 00100 00100 00100 00100", "Z": "11111 00001 00010 00100 01000 10000 11111",
    "0": "01110 10001 10011 10101 11001 10001 01110", "1": "00100 01100 00100 00100 00100 00100 01110",
    "2": "01110 10001 00001 00010 00100 01000 11111", "3": "11110 00001 00001 01110 00001 00001 11110",
    "4": "00010 00110 01010 10010 11111 00010 00010", "5": "11111 10000 11110 00001 00001 10001 01110",
    "6": "00110 01000 10000 11110 10001 10001 01110", "7": "11111 00001 00010 00100 01000 01000 01000",
    "8": "01110 10001 10001 01110 10001 10001 01110", "9": "01110 10001 10001 01111 00001 00010 01100",
    "-": "00000 00000 00000 11111 00000 00000 00000", "_": "00000 00000 00000 00000 00000 00000 11111",
    ".": "00000 00000 00000 00000 00000 01100 01100", ":": "00000 01100 01100 00000 01100 01100 00000",
    " ": "00000 00000 00000 00000 00000 00000 00000", "/": "00001 00001 00010 00100 01000 10000 10000",
    "?": "01110 10001 00001 00110 00100 00000 00100",
}
BG = (24, 24, 30)
LABEL_BG = (40, 40, 52)
LABEL_FG = (235, 235, 150)
GAP = 6
LABEL_H = 14


def label_pixels(text: str, scale: int = 2) -> list:
    """Rows of a text as lists of 0/1, glyphs drawn `scale` times bigger."""
    rows = [[] for _ in range(7)]
    for ch in text.upper():
        glyph = FONT.get(ch, FONT["?"]).split()
        for y in range(7):
            rows[y] += [int(c) for c in glyph[y]] + [0]
    out = []
    for r in rows:
        wide = [v for v in r for _ in range(scale)]
        out.extend([wide] * scale)
    return out


def read_png(path: str):
    """Fallback decoder (8-bit RGB / RGBA, any filter). Slow; the sidecar avoids it."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        length, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and ctype in (2, 6), "only 8-bit RGB / RGBA PNGs"
            ch = 4 if ctype == 6 else 3
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = w * ch
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        kind, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0
            b = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        rows.append(bytes(line) if ch == 3 else bytes(b for j, b in enumerate(line) if j % 4 != 3))
    return w, h, b"".join(rows)


def load(out: str, locale: str, slug: str):
    """(w, h, rgb bytes) or None when that state was not captured."""
    side = os.path.join(out, locale, ".raw", slug + ".rgbz")
    if os.path.exists(side):
        blob = open(side, "rb").read()
        w, h = struct.unpack("<ii", blob[:8])
        return w, h, zlib.decompress(blob[8:])
    png = os.path.join(out, locale, slug + ".png")
    return read_png(png) if os.path.exists(png) else None


def upscale(img, scale):
    """Rows (bytes) of a nearest-neighbour upscaled RGB image."""
    w, h, rgb = img
    rows = []
    for y in range(h):
        src = rgb[y * w * 3:(y + 1) * w * 3]
        wide = bytearray(w * 3 * scale)
        for k in range(scale):
            for c in range(3):
                wide[k * 3 + c::3 * scale] = src[c::3]
        rows.extend([bytes(wide)] * scale)
    return rows


def label_cell(text: str, width: int, scale: int = 2) -> list:
    """LABEL_H rows (bytes) of a label bar `width` px wide."""
    rows = []
    bits = label_pixels(text, scale)
    pad_top = (LABEL_H - len(bits)) // 2
    bg, fg = bytes(LABEL_BG), bytes(LABEL_FG)
    for y in range(LABEL_H):
        by = y - pad_top
        row = bytearray(bg * width)
        if 0 <= by < len(bits):
            for x, v in enumerate(bits[by][:width - 8]):
                if v:
                    row[(x + 4) * 3:(x + 4) * 3 + 3] = fg
        rows.append(bytes(row))
    return rows


def write_png(path: str, w: int, h: int, rows: list) -> None:
    raw = b"".join(b"\x00" + r for r in rows)
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "wb").write(png)


def build_sheet(job):
    """job = (path, title, cells [(label, image-or-None)], cols, scale)."""
    path, title, cells, cols, scale = job
    cw, ch = 320 * scale, 180 * scale
    n = len(cells)
    cols = max(1, min(cols, n))
    nrows = (n + cols - 1) // cols
    width = cols * cw + (cols + 1) * GAP
    out_rows = [bytes(BG) * width] * GAP
    title_bar = label_cell(title, width, 2)
    out_rows += title_bar + [bytes(BG) * width] * GAP
    for r in range(nrows):
        row_cells = cells[r * cols:(r + 1) * cols]
        ups = [upscale(img, scale) if img else None for _, img in row_cells]
        labels = [label_cell(text, cw) for text, _ in row_cells]
        pad = bytes(BG) * GAP
        for y in range(LABEL_H):
            line = pad
            for i in range(cols):
                line += (labels[i][y] if i < len(labels) else bytes(BG) * cw) + pad
            out_rows.append(line)
        for y in range(ch):
            line = pad
            for i in range(cols):
                if i < len(ups):
                    line += (ups[i][y] if ups[i] else bytes(BG) * cw)
                else:
                    line += bytes(BG) * cw
                line += pad
            out_rows.append(line)
        out_rows += [bytes(BG) * width] * GAP
    write_png(path, width, len(out_rows), out_rows)
    return path


def merge(out: str, locales=None) -> None:
    found = []
    seen = []
    for path in sorted(glob.glob(os.path.join(out, "json", "missing_*.json"))):
        loc = os.path.basename(path)[8:-5]
        if locales and loc not in locales:
            continue
        found += json.load(open(path))
        seen.append(loc)
    order = {c: i for i, c in enumerate(ORDER)}
    found.sort(key=lambda f: (order.get(f["locale"], 99), f["state"], f["node"]))
    json.dump({"locales_checked": sorted(seen, key=lambda c: order.get(c, 99)), "count": len(found), "findings": found},
              open(os.path.join(out, "missing_glyphs.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    by = {}
    for f in found:
        by.setdefault(f["locale"], set()).update(f["chars"])
    print(f"missing glyphs: {len(found)} findings in {len(by)} of {len(seen)} locales -> {out}/missing_glyphs.json")
    for loc, chars in by.items():
        print(f"  {loc}: {''.join(sorted(chars))}")


def sheets(out: str, locales: list, cols: int, scale: int) -> None:
    states = {}  # slug -> state name, in build order
    for loc in locales:
        p = os.path.join(out, "json", f"states_{loc}.json")
        if os.path.exists(p):
            for s in json.load(open(p)):
                states.setdefault(s["slug"], s["state"])
    # Locale sheets keep build order; state sheets cover the locales given.
    jobs = []
    sd = os.path.join(out, "sheets")
    for loc in locales:
        cells = [(slug, load(out, loc, slug)) for slug in states]
        cells = [c for c in cells if c[1] is not None]
        if cells:
            jobs.append((os.path.join(sd, f"locale_{loc}.png"), f"{loc} - {len(cells)} states", cells, cols, scale))
    for slug, name in states.items():
        cells = [(loc, load(out, loc, slug)) for loc in locales]
        cells = [c for c in cells if c[1] is not None]
        if cells:
            jobs.append((os.path.join(sd, f"state_{slug}.png"), f"{slug} - {len(cells)} locales", cells, 5, scale))
    # Jobs load their own images lazily through the cells above (already in memory); build in a pool.
    with Pool() as pool:
        done = pool.map(build_sheet, jobs)
    print(f"contact sheets: {sum(1 for d in done if '/locale_' in d)} per-locale, "
          f"{sum(1 for d in done if '/state_' in d)} per-state -> {sd}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["merge", "sheets"])
    ap.add_argument("--out", required=True)
    ap.add_argument("--locales", default="all")
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--scale", type=int, default=2)
    a = ap.parse_args()
    if a.cmd == "merge":
        merge(a.out, None if a.locales == "all" else a.locales.split(","))
    else:
        locs = ORDER if a.locales == "all" else a.locales.split(",")
        sheets(a.out, locs, a.cols, a.scale)


if __name__ == "__main__":
    main()
