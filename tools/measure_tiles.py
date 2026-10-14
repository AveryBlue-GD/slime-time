"""Measures the ink of the level-select number / lock in a screenshot against each tile's center.

Usage: python3 -I tools/measure_tiles.py SHOT.png [gridx gridy tilew tileh [ymax [luma threshold]]]   (defaults 42 23 44 38 24 180)
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


THRESH = 180  # 90 for a lock-only shot (demo_level_select.tscn -- only=lock)
YMAX = 24  # rows below this belong to the status line 


def main():
    global YMAX, THRESH
    THRESH = int(sys.argv[7]) if len(sys.argv) > 7 else 180
    shot = sys.argv[1]
    YMAX = 26 if len(sys.argv) < 7 else int(sys.argv[6])
    gx, gy, tw, th = (int(v) for v in sys.argv[2:6]) if len(sys.argv) >= 6 else (42, 23, 44, 38)
    w, h, ch, rows = read_png(shot)

    def luma(x, y):
        r = rows[y]
        return 0.3 * r[x * ch] + 0.59 * r[x * ch + 1] + 0.11 * r[x * ch + 2]

    for level in range(1, 11):
        col, row = (level - 1) % 5, (level - 1) // 5
        ox, oy = gx + col * (tw + 4), gy + row * (th + 4)
        pts = [(x, y) for y in range(2, th - 4) for x in range(4, tw - 4)
               if luma(ox + x, oy + y) > THRESH and not (x >= 33 and y <= 18) and y <= YMAX]
        if not pts:
            print("L%d no light ink" % level)
            continue
        x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
        y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
        print("L%d ink x %d..%d y %d..%d  dx=%+.1f dy=%+.1f" % (
            level, x0, x1, y0, y1, (x0 + x1 + 1) / 2 - tw / 2, (y0 + y1 + 1) / 2 - th / 2))


main()
