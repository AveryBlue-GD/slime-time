"""IMP-05: the boot splash (assets/ui/boot_splash.png, 320x180): the title logo over the slime icon on the
palette's darkest colour ("k"). Pure standard library, nearest neighbour only; project.godot's
application/boot_splash/image points at it (fullsize=false, use_filter=false, bg_color = the same dark).

Run from the project root after tools/make_title.py and tools/make_placeholder_art.py:  python3 -I tools/make_splash.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_icon_ico import read_png  # noqa: E402
from make_placeholder_art import PAL, write_png  # noqa: E402

W, H = 320, 180
BG = "k"


def main():
    lw, lh, logo = read_png(ROOT / "assets" / "sprites" / "title" / "logo_00.png")
    iw, ih, icon = read_png(ROOT / "icon.png")
    step = iw // 64  # icon.png is the 64 px art scaled up; take every step-th pixel back to 64
    icon = [row[::step] for row in icon[::step]]
    ih = len(icon)
    inv = {tuple(v): k for k, v in PAL.items() if k != "."}
    grid = [[tuple(PAL[BG]) for _ in range(W)] for _ in range(H)]

    def blit(img, w, h, x0, y0):
        for y in range(h):
            for x in range(w):
                px = img[y][x]
                if px[3] > 0:
                    grid[y0 + y][x0 + x] = tuple(px[:3]) + (255,)

    blit(logo, lw, lh, (W - lw) // 2, 22)
    blit(icon, 64, ih, (W - 64) // 2, 22 + lh + 14)
    # write_png maps palette letters, so register the few extra colours under spare keys
    keys, rows = {}, []
    spare = (c for c in "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" if c not in PAL)
    for row in grid:
        out = ""
        for px in row:
            if px not in keys:
                keys[px] = inv.get(px) or next(spare)
                PAL[keys[px]] = px
            out += keys[px]
        rows.append(out)
    write_png(ROOT / "assets" / "ui" / "boot_splash.png", rows)


if __name__ == "__main__":
    main()
