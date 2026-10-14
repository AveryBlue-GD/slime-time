"""Crops a region of a PNG and scales it up (nearest) for pixel inspection.
Usage: python3 -I tools/zoom_crop.py IN.png x y w h scale OUT.png
"""
import struct
import sys
import zlib

sys.path.insert(0, __file__.rsplit("/", 1)[0])


def main():
    import importlib.util
    spec = importlib.util.spec_from_file_location("mt", __file__.rsplit("/", 1)[0] + "/measure_tiles.py")
    src = open(spec.origin).read().rsplit("\nmain()", 1)[0]
    ns = {}
    exec(src, ns)
    w, h, ch, rows = ns["read_png"](sys.argv[1])
    x, y, cw, chh, s = (int(v) for v in sys.argv[2:7])
    out = bytearray()
    for yy in range(y, y + chh):
        line = bytearray()
        for xx in range(x, x + cw):
            px = bytes(rows[yy][xx * ch:xx * ch + 3])
            line += px * s
        for _ in range(s):
            out += b"\x00" + line

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", cw * s, chh * s, 8, 2, 0, 0, 0)) \
        + chunk(b"IDAT", zlib.compress(bytes(out))) + chunk(b"IEND", b"")
    open(sys.argv[7], "wb").write(png)


main()
