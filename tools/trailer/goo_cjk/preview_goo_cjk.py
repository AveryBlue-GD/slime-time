#!/usr/bin/env python3
"""Preview sheet: every Chinese on-screen line from posts-4-weeks.md drawn with the goo glyphs.

The drips, shading and shadow here are an approximation of the trailer's goo renderer so the
lines can be checked by eye; the real Shorts get the effect from goo_text.py.
  python3 preview_goo_cjk.py [--text posts-4-weeks.md] [--out goo_cjk_preview.png]
"""
import argparse, json, os, re, zlib
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
U = 5                      # screen pixels per glyph pixel in the sheet
SAFE_UNITS = 920           # 1080 px Short minus margins, in screen px, for the fit check

# 5x7 stand-ins for the Latin goo letters that appear inside Chinese lines (preview only)
LATIN = {
    '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
    '=': ['.....', '.....', '#####', '.....', '#####', '.....', '.....'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
}


def lines_from(md):
    s = open(md, encoding='utf-8').read()
    out = []
    hooks = s.split('### Chinese versions of the hooks')[1].split('###')[0]
    for row in hooks.splitlines():
        cells = [c.strip() for c in row.strip('|').split('|')]
        if len(cells) == 4 and re.search(r'[一-鿿]', row):
            for i, c in enumerate(cells[1:], 1):
                out.append((f'Short {cells[0]}, hook {i}', c))
    onscreen = s.split('### Chinese versions of every on-screen line')[1].split('\n---')[0]
    for row in onscreen.splitlines():
        cells = [c.strip() for c in row.strip('|').split('|')]
        if len(cells) == 2 and re.search(r'[一-鿿]', cells[1]):
            out.append((cells[0], cells[1]))
    return out


def bitmap(text, glyphs):
    """Lay out one line on the 12-row CJK grid; returns list of rows."""
    cols = []
    for ch in text:
        if ch in glyphs:
            g = glyphs[ch]
        elif ch.upper() in LATIN:
            g = ['......'] * 3 + [r + '.' for r in LATIN[ch.upper()]] + ['......'] * 2
        elif ch == ' ':
            g = ['....'] * 12
        else:
            raise SystemExit(f'no glyph for {ch!r} in {text!r}: rerun make_goo_cjk.py')
        if ch in glyphs and len(g[0]) >= 12:
            g = [r + '.' for r in g]                  # 1 unit of tracking, same as xadvance 13 in the .fnt
        cols.append(g)
    return [''.join(g[y] for g in cols) for y in range(12)]


def goo(rows, color, seed):
    h, w = len(rows), len(rows[0])
    ink = {(x, y) for y in range(h) for x in range(w) if rows[y][x] == '#'}
    drips = set()
    for (x, y) in ink:
        if (x, y + 1) in ink:
            continue
        r = zlib.crc32(f'{seed}:{x}:{y}'.encode()) % 100
        if r < 35 and y >= 10:                        # drips hang only from the bottom row of a glyph
            n = 1 + r % 3
            for k in range(1, n + 1):
                if (x, y + k) in ink:
                    break
                drips.add((x, y + k))
    pad = 4
    img = Image.new('RGBA', ((w + pad) * U, (h + pad) * U), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    dark = tuple(int(c * 0.62) for c in color)
    allpix = ink | drips
    for (x, y) in allpix:                          # drop shadow
        d.rectangle([(x + 1) * U + 2, (y + 1) * U + 2, (x + 2) * U + 1, (y + 2) * U + 1], fill=(8, 9, 16, 230))
    for (x, y) in allpix:
        c = dark if (x, y) in drips and (x, y + 1) not in allpix else color
        d.rectangle([(x + 1) * U, (y + 1) * U, (x + 2) * U - 1, (y + 2) * U - 1], fill=c + (255,))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--text', default=os.path.join(HERE, '..', '..', 'marketing', 'posts-4-weeks.md'))
    ap.add_argument('--glyphs', default=os.path.join(HERE, 'goo_cjk.json'))
    ap.add_argument('--out', default=os.path.join(HERE, 'goo_cjk_preview.png'))
    a = ap.parse_args()
    glyphs = json.load(open(a.glyphs, encoding='utf-8'))['glyphs']
    items = lines_from(a.text)
    label = ImageFont.load_default(15)
    small = ImageFont.load_default(12)
    palette = [(120, 230, 140), (240, 240, 235), (250, 170, 90), (240, 130, 200), (120, 220, 230)]
    cards = []
    for i, (eng, zh) in enumerate(items):
        parts = [p.strip() for p in zh.split('/')]
        rendered = [goo(bitmap(p, glyphs), palette[i % len(palette)], zh + str(j)) for j, p in enumerate(parts)]
        widest = max(len(bitmap(p, glyphs)[0]) for p in parts)
        fit = SAFE_UNITS / widest                     # px per glyph pixel that still fits a 1080 Short
        cards.append((eng, zh, rendered, fit))
    cw = max(max(r.width for r in c[2]) for c in cards) + 40
    cw = max(cw, 560)
    col_n = 3
    heights = [44 + sum(r.height for r in c[2]) + 16 for c in cards]
    rows_h = [max(heights[k:k + col_n]) for k in range(0, len(cards), col_n)]
    W, H = cw * col_n + 20, sum(rows_h) + 90
    sheet = Image.new('RGBA', (W, H), (27, 29, 43, 255))
    d = ImageDraw.Draw(sheet)
    d.text((20, 18), 'Goo Chinese glyphs: every on-screen line (drips/shading approximated; real look comes from goo_text.py)',
           font=label, fill=(200, 205, 220))
    d.text((20, 42), f'{len(glyphs)} glyphs from Fusion Pixel 12px (SIL OFL 1.1). Fit = max px per glyph pixel on a 1080-wide Short.',
           font=small, fill=(140, 145, 165))
    y = 70
    for r0 in range(0, len(cards), col_n):
        for k, (eng, zh, rendered, fit) in enumerate(cards[r0:r0 + col_n]):
            x = 10 + k * cw
            d.rectangle([x, y, x + cw - 10, y + rows_h[r0 // col_n] - 10], fill=(20, 22, 33, 255))
            note = f'fit {fit:.1f}x' + ('' if fit >= 6 else '  (wrap this line)')
            d.text((x + 10, y + 8), eng[:58], font=small, fill=(160, 165, 185))
            d.text((x + 10, y + 24), note, font=small, fill=(120, 200, 140) if fit >= 6 else (240, 160, 90))
            yy = y + 40
            for r in rendered:
                sheet.alpha_composite(r, (x + 10, yy)); yy += r.height
        y += rows_h[r0 // col_n]
    sheet.convert('RGB').save(a.out)
    print(f'{len(cards)} lines -> {a.out}')


if __name__ == '__main__':
    main()
