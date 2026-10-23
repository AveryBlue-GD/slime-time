"""IMP2-01: the boot splash and the intro card's world layer (both 320x180, nearest neighbour, stdlib only).

The splash (assets/ui/boot_splash.png) is a frame of the game, not a card: near-black fog whose every edge is
exactly project.godot's boot_splash/bg_color (the palette's "k"), the dripping logo upper-centre (drips cut to
stubs; the intro card grows them), a Lime slime in a dithered light pocket lower-left, its goo trail revealing
six Dark Dungeon wall tiles, and a faint chalice glint far right. Everything but the logo is inside a 16 px
margin (the logo is the title's own 303 px art at the title's own position, ink 15 px from the right edge).

assets/ui/intro_card_world.png is the same frame without the logo and the slime, transparent where the fog is:
scripts/ui/intro_card.gd draws it over the fog, then the live slime and logo on top, so the card's first frame
is this splash pixel for pixel.

Run from the project root after tools/make_title.py and tools/make_placeholder_art.py:  python3 -I tools/make_splash.py
"""
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_icon_ico import read_png  # noqa: E402
from make_placeholder_art import PAL  # noqa: E402

W, H = 320, 180
K = tuple(PAL["k"][:3])  # the boot bg colour #1A1C2C
MARGIN = 16
# Layout (shared with scripts/ui/intro_card.gd, which draws the slime and the logo live at these spots).
LOGO_POS = (8, 12)  # the title's own logo position
LOGO_STUB_ROWS = 54  # the splash shows the logo down to this row of the art; the card grows the drips to 64
SLIME_POS = (84, 114)  # top-left of the 2x slime (40x40)
POCKET = (96, 146, 54)  # light pocket centre and radius
CHALICE_POS = (262, 130)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def pal(key):
    return tuple(PAL[key][:3])


def load(path):
    w, h, px = read_png(ROOT / path)
    return w, h, px


def write_rgba(path, grid):
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in grid)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))
    Path(path).write_bytes(png)
    print("wrote %s (%dx%d, %d bytes)" % (Path(path).relative_to(ROOT), W, H, len(png)))


def inside(x, y):
    return MARGIN <= x < W - MARGIN and MARGIN <= y < H - MARGIN


def trail_y(x):
    """The trail's centre line: a lazy S-curl on the corridor floor (row y 144..160), growing thicker toward the slime."""
    return 151 + round(3.2 * math.sin((x - 30) / 8.5))


def main():
    world = [[(0, 0, 0, 0)] * W for _ in range(H)]  # transparent = fog

    def put(x, y, rgb):
        if 0 <= x < W and 0 <= y < H:
            world[y][x] = tuple(rgb) + (255,)

    # --- the light pocket on the corridor floor, dithered in three steps (floor shades from the palette)
    cx, cy, rad = POCKET
    shades = [pal("F"), pal("f"), pal("h")]
    for y in range(H):
        for x in range(W):
            if not inside(x, y):
                continue
            d = ((x - cx) ** 2 + ((y - cy) * 1.25) ** 2) ** 0.5
            lvl = 1.0 - d / rad
            if lvl <= 0:
                continue
            i = int(lvl * 3.4 + bayer(x, y) - 0.5)
            if i >= 1:
                put(x, y, shades[min(i, 3) - 1])

    # --- six Dark Dungeon wall tiles (row y 128..144), lit by distance from the trail's light, dithered
    wall_w, wall_h, wall_px = load("assets/sprites/themes/dungeon_walls.png")
    tiles = [(5, 2), (6, 2), (5, 2), (7, 2), (6, 2), (5, 2)]  # plain brick variants of the sheet
    for n, (tx, ty) in enumerate(tiles):
        x0, y0 = 48 + n * 16, 128
        for y in range(16):
            for x in range(16):
                gx, gy = x0 + x, y0 + y
                if not inside(gx, gy):
                    continue
                d = ((gx - cx) ** 2 + ((gy - cy) * 1.1) ** 2) ** 0.5
                lvl = 1.0 - d / (rad + 18)
                if lvl <= 0.05:
                    continue
                step = int(lvl * 3.0 + bayer(gx, gy) * 1.0)
                if step < 1:
                    continue
                src = wall_px[ty * 16 + y][tx * 16 + x]
                if src[3] == 0:
                    continue
                put(gx, gy, mix(K, tuple(src[:3]), (0.22, 0.4, 0.6)[min(step, 3) - 1]))

    # --- the goo trail behind the slime: a ribbon that thickens toward it, light top edge, dark underside
    n, m, hi, deep = pal("n"), pal("m"), pal("H"), pal("D")
    for x in range(30, 100):
        t = (x - 30) / 70.0
        half = 1 + round(2.4 * t)  # 1..3 rows above and below the centre line
        yc = trail_y(x)
        for dy in range(-half, half + 1):
            col = n
            if dy == -half:
                col = m if (x // 3) % 2 == 0 or half < 3 else hi
            elif dy == half:
                col = deep
            put(x, yc + dy, col)
    for x, dy in ((38, -4), (47, 5), (61, -5), (72, 6), (83, -6)):  # splashed droplets beside the trail
        put(x, trail_y(x) + dy, m)
        put(x, trail_y(x) + dy + 1, n)

    # --- the faint chalice glint, far right in the dark: a dim chalice (frame 0) and three gold sparkles
    cw, ch, cpx = load("assets/sprites/chalice_sheet.png")
    for y in range(20):
        for x in range(16):
            src = cpx[y][x]
            gx, gy = CHALICE_POS[0] + x, CHALICE_POS[1] + y
            if src[3] and inside(gx, gy) and bayer(gx, gy) < 0.62:
                put(gx, gy, mix(K, tuple(src[:3]), 0.38))
    for sx, sy in ((CHALICE_POS[0] + 8, CHALICE_POS[1] - 3), (CHALICE_POS[0] + 7, CHALICE_POS[1] - 2),
                   (CHALICE_POS[0] + 9, CHALICE_POS[1] - 2), (CHALICE_POS[0] + 8, CHALICE_POS[1] - 1)):
        put(sx, sy, pal("Y") if (sx, sy) == (CHALICE_POS[0] + 8, CHALICE_POS[1] - 2) else mix(K, pal("y"), 0.6))
    world_png = ROOT / "assets" / "ui" / "intro_card_world.png"
    write_rgba(world_png, world)

    # --- the splash: fog, world, the 2x slime, the logo stub
    out = [[K + (255,)] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if world[y][x][3]:
                out[y][x] = world[y][x]
    sw, sh, spx = load("assets/sprites/slime_sheet.png")
    for y in range(20):  # idle frame 1: eyes open, the body a little low
        for x in range(20):
            src = spx[y][20 + x]
            if src[3] == 0:
                continue
            col = tuple(src[:3])
            if src[3] < 255:  # the soft ground shadow: blended over what is under it
                under = out[SLIME_POS[1] + y * 2][SLIME_POS[0] + x * 2][:3]
                col = mix(under, (0, 0, 0), src[3] / 255.0)
            for dy in (0, 1):
                for dx in (0, 1):
                    out[SLIME_POS[1] + y * 2 + dy][SLIME_POS[0] + x * 2 + dx] = col + (255,)
    lw, lh, lpx = load("assets/sprites/title/logo_00.png")
    for y in range(min(lh, LOGO_STUB_ROWS)):
        for x in range(lw):
            if lpx[y][x][3] > 0:
                out[LOGO_POS[1] + y][LOGO_POS[0] + x] = tuple(lpx[y][x][:3]) + (255,)
    # every edge pixel is exactly the boot colour (the margin check): nothing but fog within 16 px of the frame,
    # except the logo (the title's own art)
    for y in range(H):
        for x in range(W):
            if not inside(x, y) and not (LOGO_POS[1] <= y < LOGO_POS[1] + LOGO_STUB_ROWS):
                assert out[y][x][:3] == K, (x, y, out[y][x])
    write_rgba(ROOT / "assets" / "ui" / "boot_splash.png", out)


if __name__ == "__main__":
    main()
