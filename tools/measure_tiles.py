"""Measures the ink of the level-select number / lock in a screenshot against each tile's center.

Usage: python3 -I tools/measure_tiles.py SHOT.png [--gaps] ...   (--gaps: also prints, for tiles with a record
time, the clear pixel rows above the time (below the number's letter body) and below it (above the tile's
bottom frame edge), plus how far its drips reach.)
Usage: python3 -I tools/measure_tiles.py SHOT.png [gridx gridy tilew tileh [ymax [luma threshold]]]   (defaults 30 22 48 42 28 180)
Number = light pixels (luma > 140) left of the medal pips and above the status row; on a locked
tile the lock = the brightest tint pixels (luma > 110) within the tile. Prints each tile's ink box
and the ink center minus the tile center in px (0 = dead center; half pixels come from odd sizes).
"""
import struct
import sys
import zlib


def read_png(path):
    d = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(d):
        n, t = struct.unpack(">I4s", d[pos:pos + 8])
        b = d[pos + 8:pos + 8 + n]
        if t == b"IHDR":
            w, h, _, ct = struct.unpack(">IIBB", b[:10])
        if t == b"IDAT":
            idat += b
        pos += 12 + n
    ch = 4 if ct == 6 else 3
    raw, st, rows, prev, i = zlib.decompress(idat), w * ch, [], bytearray(w * ch), 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + st])
        i += 1 + st
        for x in range(st):
            a = line[x - ch] if x >= ch else 0
            b_ = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b_) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b_) // 2) & 255
            elif f == 4:
                p = a + b_ - c
                pa, pb, pc = abs(p - a), abs(p - b_), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b_ if pb <= pc else c))) & 255
        rows.append(line)
        prev = line
    return w, h, ch, rows


GAP = 3  # px between tiles (level_select.gd GRID_GAP)
THRESH = 180  # 90 for a lock-only shot (demo_level_select.tscn -- only=lock)
YMAX = 24  # rows below this belong to the status line 


def main():
    global YMAX, THRESH
    gaps = "--gaps" in sys.argv
    if gaps:
        sys.argv.remove("--gaps")
    THRESH = int(sys.argv[7]) if len(sys.argv) > 7 else 180
    shot = sys.argv[1]
    YMAX = 28 if len(sys.argv) < 7 else int(sys.argv[6])
    gx, gy, tw, th = (int(v) for v in sys.argv[2:6]) if len(sys.argv) >= 6 else (30, 22, 48, 42)
    w, h, ch, rows = read_png(shot)

    def luma(x, y):
        r = rows[y]
        return 0.3 * r[x * ch] + 0.59 * r[x * ch + 1] + 0.11 * r[x * ch + 2]

    for level in range(1, 11):
        col, row = (level - 1) % 5, (level - 1) // 5
        ox, oy = gx + col * (tw + GAP), gy + row * (th + GAP)
        pts = [(x, y) for y in range(2, th - 4) for x in range(4, tw - 4)
               if luma(ox + x, oy + y) > THRESH and not (x >= 33 and y <= 18) and y <= YMAX]
        if not pts:
            print("L%d no light ink" % level)
            continue
        x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
        y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
        print("L%d ink x %d..%d y %d..%d  dx=%+.1f dy=%+.1f" % (
            level, x0, x1, y0, y1, (x0 + x1 + 1) / 2 - tw / 2, (y0 + y1 + 1) / 2 - th / 2))
        if gaps:
            # Letter body of the number: light rows (luma > 180) from the top of the face.
            num_rows = [y for y in range(3, th - 3) if any(luma(ox + x, oy + y) > 180 for x in range(6, tw - 10))]
            num_bottom = max(y for y in num_rows if y < th // 2 + 8) if num_rows else None
            # Time text: dim light pixels (luma 100..178) in rows that have >= 4 of them (drips are 1-2 columns).
            def dim_row(y):
                return [x for x in range(5, tw - 6) if 100 < luma(ox + x, oy + y) < 179]
            # The 7 text rows = the 7-row window with the most dim pixels (the number's drips are sparse).
            wins = [(sum(len(dim_row(y + k)) for k in range(7)), y) for y in range(num_bottom + 1, th - 7)]
            if not wins:
                continue
            if max(wins)[0] < 40:
                continue  # no record time on this tile
            ty0 = max(wins)[1]
            ty1 = ty0 + 6
            tpts = [(x, y) for y in range(ty0, th - 1) for x in dim_row(y) if x >= 0]
            tx0, tx1 = min(x for x, _ in tpts if _ <= ty1), max(x for x, _ in tpts if _ <= ty1)
            drip = max(y for _, y in tpts)
            # Bottom frame edge: first row from the top below the text whose pixel at x=2 is the frame green.
            def green(y):
                px = [rows[oy + y][(ox + x) * ch:(ox + x) * ch + 3] for x in range(6, tw - 6)]
                return sum(1 for q in px if q[1] > 80 and q[1] > 2 * q[0] + 20) >= len(px) // 2
            edge = next((y for y in range(ty1 + 1, th + 3) if green(y)), th - 1)
            print("   time x %d..%d (margins L%d R%d) rows %d..%d | number bottom row %d | gap above %d px, gap below %d px (to frame edge row %d; drips reach row %d, %d clear)" % (
                tx0, tx1, tx0, tw - 1 - tx1, ty0, ty1, num_bottom, ty0 - num_bottom - 1, edge - ty1 - 1, edge, drip, edge - drip - 1))


main()
