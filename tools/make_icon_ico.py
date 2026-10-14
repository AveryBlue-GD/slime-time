"""Builds icon.ico (the Windows .exe / window icon) from icon.png.

Pixel art, so every size is a nearest-neighbor scale of the 64x64 icon: 16, 32, 48, 64, 128 and 256 px.
Sizes below 256 are stored as classic 32-bit BMP (DIB) entries with an AND mask (read by every Windows
version and by Godot's Windows export template modifier); 256 is stored as PNG, as Windows expects.
Pure standard library (zlib + struct), deterministic: the same icon.png always gives the same bytes.
Run from the project root after changing icon.png:  python3 -I tools/make_icon_ico.py
Used by export_presets.cfg (Windows Desktop application/icon) and project.godot (windows_native_icon).
"""
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZES = [16, 32, 48, 64, 128, 256]


def read_png(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit("not a PNG: %s" % path)
    pos, idat, palette, trns = 8, b"", None, None
    width = height = depth = ctype = interlace = None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
    if depth != 8 or interlace != 0 or ctype not in (2, 3, 6):
        sys.exit("unsupported PNG (need 8-bit, non-interlaced RGB/RGBA/palette)")
    channels = {2: 3, 3: 1, 6: 4}[ctype]
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, prev, at = [], bytearray(stride), 0
    for _ in range(height):
        filt = raw[at]
        line = bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filt == 1:
                line[i] = (line[i] + a) & 255
            elif filt == 2:
                line[i] = (line[i] + b) & 255
            elif filt == 3:
                line[i] = (line[i] + ((a + b) >> 1)) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        rows.append(bytes(line))
        prev = line
    pixels = []
    for line in rows:
        row = []
        for x in range(width):
            if ctype == 6:
                row.append(tuple(line[x * 4:x * 4 + 4]))
            elif ctype == 2:
                row.append(tuple(line[x * 3:x * 3 + 3]) + (255,))
            else:
                idx = line[x]
                alpha = trns[idx] if trns and idx < len(trns) else 255
                row.append(palette[idx] + (alpha,))
        pixels.append(row)
    return width, height, pixels


def scale(pixels, w, h, size):
    return [[pixels[y * h // size][x * w // size] for x in range(size)] for y in range(size)]


def png_bytes(img, size):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in img)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def bmp_bytes(img, size):
    header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    xor = b"".join(bytes(c for px in row for c in (px[2], px[1], px[0], px[3])) for row in reversed(img))
    mask_stride = ((size + 31) // 32) * 4
    mask = b""
    for row in reversed(img):
        bits = bytearray(mask_stride)
        for x, px in enumerate(row):
            if px[3] == 0:
                bits[x >> 3] |= 0x80 >> (x & 7)
        mask += bytes(bits)
    return header + xor + mask


def main():
    w, h, pixels = read_png(ROOT / "icon.png")
    images = []
    for size in SIZES:
        img = scale(pixels, w, h, size)
        images.append((size, png_bytes(img, size) if size >= 256 else bmp_bytes(img, size)))
    out = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    for size, blob in images:
        dim = 0 if size >= 256 else size
        out += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    out += b"".join(blob for _, blob in images)
    (ROOT / "icon.ico").write_bytes(out)
    print("icon.ico: %d bytes, sizes %s" % (len(out), SIZES))


if __name__ == "__main__":
    main()
