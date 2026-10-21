#!/usr/bin/env python3
"""Build goo-style Chinese glyphs for the trailer's on-screen text.

Collects every Chinese character (and full-width punctuation) used in the
marketing copy, takes each glyph from Fusion Pixel 12px (SIL OFL 1.1) as a
1-pixel-stroke bitmap on the same grid the goo lettering uses, and writes:

  goo_cjk.png / goo_cjk.fnt   BMFont (text format, like assets/fonts/pixel.fnt)
  goo_cjk_big.png / .fnt      the same at 2x (to pair with pixel_big.fnt)
  goo_cjk.json                {char: [row strings of '#' and '.']} for goo_text.py
  chars.txt                   the character list, one line

Drips, shading and shadow are NOT baked in: the goo renderer adds those to any
glyph bitmap, exactly as it does for the Latin letters.

Regenerate after the Chinese lines change:
  pip install fonttools brotli pillow
  python3 make_goo_cjk.py                         # reads the default marketing files
  python3 make_goo_cjk.py --text a.md b.md        # or any files
Merge into the existing Latin font (Latin glyphs untouched, CJK added as page 1):
  python3 make_goo_cjk.py --merge-into path/to/pixel.fnt [--merge-big path/to/pixel_big.fnt]
"""
import argparse, glob, io, json, os, re, sys
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_TEXT = [os.path.join(HERE, '..', '..', '..', 'docs', 'marketing', f) for f in ('posts-4-weeks.md', 'steam-page.md')] \
    + [os.path.join(HERE, '..', 'captions_zh.json')]  # (the repo: docs/marketing/ and the trailer's Chinese captions)
CELL = 12          # Fusion Pixel 12px: 12x12 cell, ascent 10, descent 2
ASCENT = 10
TRACK = 1          # extra unit between glyphs so dense ideographs don't touch (Latin goo also uses 1)
# Han ideographs, CJK punctuation, full-width forms, general punctuation used in Chinese (… —)
CJK_RE = re.compile(r'[㐀-䶿一-鿿　-〿！-｠—…“”‘’·]')


def collect(paths):
    chars = set()
    for p in paths:
        with open(p, encoding='utf-8') as f:
            chars.update(CJK_RE.findall(f.read()))
    chars.discard('　')
    return sorted(chars)


def load_sources(src):
    fonts = []
    for path in sorted(glob.glob(os.path.join(src, '*.woff2')) + glob.glob(os.path.join(src, '*.[ot]tf'))):
        t = TTFont(path)
        cmap = t.getBestCmap()
        hmtx, upm = t['hmtx'], t['head'].unitsPerEm
        t.flavor = None
        buf = io.BytesIO(); t.save(buf)
        fonts.append((cmap, hmtx, upm, ImageFont.truetype(io.BytesIO(buf.getvalue()), CELL)))
    if not fonts:
        sys.exit(f'no font files in {src}')
    return fonts


def rasterize(ch, fonts):
    for cmap, hmtx, upm, font in fonts:
        g = cmap.get(ord(ch))
        if g is None:
            continue
        adv = round(hmtx[g][0] * CELL / upm)
        # draw on a padded canvas so nothing can clip, then crop to the cell
        img = Image.new('1', (CELL * 3, CELL * 3), 0)
        d = ImageDraw.Draw(img); d.fontmode = '1'
        d.text((CELL, CELL + ASCENT), ch, font=font, fill=1, anchor='ls')
        bb = img.getbbox()
        if bb and (bb[0] < CELL or bb[1] < CELL or bb[2] > CELL + adv or bb[3] > CELL * 2):
            print(f'warning: {ch} ink outside its cell {bb}', file=sys.stderr)
        cell = img.crop((CELL, CELL, CELL + adv, CELL * 2))
        return [''.join('#' if cell.getpixel((x, y)) else '.' for x in range(adv)) for y in range(CELL)]
    return None


def write_bmfont(glyphs, out_png, out_fnt, scale, face='goo_cjk', page_id=0, base=ASCENT, yshift=0):
    """Atlas with one cell per glyph + 1px gutter. Returns the char lines for merging."""
    cols = 16
    cw, ch_ = (CELL + 1) * scale, (CELL + 1) * scale
    rows = (len(glyphs) + cols - 1) // cols
    w = 1
    while w < cols * cw: w *= 2
    h = 1
    while h < rows * ch_: h *= 2
    atlas = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    lines = []
    for i, (c, rows_) in enumerate(glyphs.items()):
        ax, ay = (i % cols) * cw, (i // cols) * ch_
        gw = len(rows_[0])
        for y, row in enumerate(rows_):
            for x, v in enumerate(row):
                if v == '#':
                    for sy in range(scale):
                        for sx in range(scale):
                            atlas.putpixel((ax + x * scale + sx, ay + y * scale + sy), (255, 255, 255, 255))
        lines.append(f'char id={ord(c)} x={ax} y={ay} width={gw * scale} height={CELL * scale} '
                     f'xoffset=0 yoffset={yshift * scale} xadvance={(gw + TRACK) * scale} page={page_id} chnl=15')
    atlas.save(out_png)
    if out_fnt:
        with open(out_fnt, 'w', encoding='utf-8') as f:
            f.write(f'info face="{face}" size={CELL * scale} bold=0 italic=0 charset="" unicode=1 stretchH=100 '
                    f'smooth=0 aa=1 padding=0,0,0,0 spacing=1,1 outline=0\n')
            f.write(f'common lineHeight={CELL * scale} base={base * scale} scaleW={w} scaleH={h} pages=1 packed=0\n')
            f.write(f'page id=0 file="{os.path.basename(out_png)}"\n')
            f.write(f'chars count={len(lines)}\n')
            f.write('\n'.join(lines) + '\n')
    return lines


def merge(latin_fnt, glyphs, scale, out_dir):
    """Write <name>_cjk.fnt next to out_dir: the Latin font unchanged + a CJK atlas as an extra page.
    CJK glyphs are placed so their ink centre lines up with the Latin cap-height centre."""
    src = open(latin_fnt, encoding='utf-8').read().splitlines()
    common = next(l for l in src if l.startswith('common '))
    kv = dict(re.findall(r'(\w+)=("[^"]*"|\S+)', common))
    base, pages = int(kv['base']) // scale, int(kv['pages'])
    # Latin caps are 7 units tall sitting on `base` (centre base-3.5); Fusion ink fills rows 1..11 of the
    # 12 cell (centre row 6), so shift the cell up until the centres meet (half a unit high).
    yshift = base - 10
    name = os.path.splitext(os.path.basename(latin_fnt))[0]
    png = os.path.join(out_dir, f'{name}_cjk_page.png')
    cjk_lines = write_bmfont(glyphs, png, None, scale, page_id=pages, yshift=yshift)
    out = []
    existing = {int(m) for l in src for m in re.findall(r'^char id=(\d+)', l)}
    cjk_lines = [l for l in cjk_lines if int(re.match(r'char id=(\d+)', l).group(1)) not in existing]
    for l in src:
        if l.startswith('common '):
            l = re.sub(r'pages=\d+', f'pages={pages + 1}', l)
        if l.startswith('chars count='):
            l = f'chars count={len(existing) + len(cjk_lines)}'
        out.append(l)
        if l.startswith('page ') and int(re.search(r'id=(\d+)', l).group(1)) == pages - 1:
            out.append(f'page id={pages} file="{os.path.basename(png)}"')
    # chars go after the last existing char line
    last = max(i for i, l in enumerate(out) if l.startswith('char '))
    out[last + 1:last + 1] = cjk_lines
    dst = os.path.join(out_dir, f'{name}_cjk.fnt')
    open(dst, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print(f'merged {len(cjk_lines)} CJK glyphs into {dst} (Latin {len(existing)} unchanged, yoffset {yshift})')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--text', nargs='+', default=DEFAULT_TEXT, help='files whose Chinese characters to cover')
    ap.add_argument('--src', default=os.path.join(HERE, 'source'), help='folder of Fusion Pixel 12px zh_hans fonts')
    ap.add_argument('--out', default=HERE)
    ap.add_argument('--merge-into', help='existing Latin BMFont (pixel.fnt) to extend')
    ap.add_argument('--merge-big', help='existing 2x Latin BMFont (pixel_big.fnt) to extend')
    a = ap.parse_args()

    chars = collect(a.text)
    fonts = load_sources(a.src)
    glyphs, missing = {}, []
    for c in chars:
        g = rasterize(c, fonts)
        (glyphs.__setitem__(c, g) if g else missing.append(c))
    if missing:
        print('MISSING from source font: ' + ''.join(missing), file=sys.stderr)

    os.makedirs(a.out, exist_ok=True)
    open(os.path.join(a.out, 'chars.txt'), 'w', encoding='utf-8').write(''.join(glyphs) + '\n')
    with open(os.path.join(a.out, 'goo_cjk.json'), 'w', encoding='utf-8') as f:
        json.dump({'cell': CELL, 'ascent': ASCENT, 'source': 'Fusion Pixel 12px monospaced zh_hans (OFL-1.1)',
                   'glyphs': glyphs}, f, ensure_ascii=False, indent=0)
    write_bmfont(glyphs, os.path.join(a.out, 'goo_cjk.png'), os.path.join(a.out, 'goo_cjk.fnt'), 1)
    write_bmfont(glyphs, os.path.join(a.out, 'goo_cjk_big.png'), os.path.join(a.out, 'goo_cjk_big.fnt'), 2,
                 face='goo_cjk_big')
    print(f'{len(glyphs)} glyphs written to {a.out}')
    if a.merge_into:
        merge(a.merge_into, glyphs, 1, a.out)
    if a.merge_big:
        merge(a.merge_big, glyphs, 2, a.out)


if __name__ == '__main__':
    main()
