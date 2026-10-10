"""Nearest-neighbor upscale of a PNG (no dependencies), for inspecting pixel art screenshots.

Usage: python tools/upscale_png.py IN.png OUT.png [SCALE=4] [x y w h]  (optional crop, in source pixels)
"""
import struct
import sys
import zlib


def read_png(path: str) -> tuple[int, int, list[list[tuple]]]:
    data = open(path, "rb").read()
    pos, idat, width = 8, b"", 0
    while pos < len(data):
        length, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if tag == b"IHDR":
            width, height, depth, color_type = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and color_type in (2, 6), "only 8-bit RGB/RGBA PNGs"
            channels = 4 if color_type == 6 else 3
        elif tag == b"IDAT":
            idat += body
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(height):
        kind, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - channels] if x >= channels else 0
            b = prev[x]
            c = prev[x - channels] if x >= channels else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x:x + channels]) + ((255,) if channels == 3 else ()) for x in range(0, stride, channels)])
        prev = line
    return width, height, rows


def write_png(path: str, rows: list[list[tuple]]) -> None:
    h, w = len(rows), len(rows[0])
    raw = b"".join(b"\x00" + b"".join(bytes(p) for p in row) for row in rows)

    def chunk(tag: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body))

    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    w, h, rows = read_png(src)
    if len(sys.argv) > 7:
        x, y, cw, ch = map(int, sys.argv[4:8])
        rows = [r[x:x + cw] for r in rows[y:y + ch]]
    out = [[p for p in row for _ in range(scale)] for row in rows for _ in range(scale)]
    write_png(dst, out)
    print(f"wrote {dst} ({len(out[0])}x{len(out)})")
