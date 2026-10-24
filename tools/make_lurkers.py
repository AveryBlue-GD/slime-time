"""BM-01 LURKERS: the sprite sheet assets/sprites/lurkers.png (3 kinds x 4 frames of 12x12, palette PAL).

Row = kind (CRAWLER, SNIFFER, LANTERN-EATER). Frames 0-2 = the wobble, frame 3 = eyes shut (dormant).
The eyes' pixel positions per frame are printed; scripts/lurkers.gd keeps them in EYES (the glints that
show through the fog are drawn there, in code, above the fog layer).

Run: python3 tools/make_lurkers.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_placeholder_art as art  # noqa: E402

SIZE = 12
# Wobble: (half width, half height, centre y). The body squashes and stretches around the same base line.
SHAPES = [(5.0, 4.0, 7.0), (5.5, 3.5, 7.5), (4.5, 4.5, 6.5), (5.0, 4.0, 7.0)]
EYE_X = (4, 7)


def body(frame: int, kind: int) -> list[list[str]]:
    rx, ry, cy = SHAPES[frame]
    g = [["."] * SIZE for _ in range(SIZE)]

    def inside(x: int, y: int) -> bool:
        return ((x - 5.5) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0

    for y in range(SIZE):
        for x in range(SIZE):
            if inside(x, y):
                g[y][x] = "w"
    for y in range(SIZE):
        for x in range(SIZE):
            if g[y][x] == "w":
                edge = any(not (0 <= x + dx < SIZE and 0 <= y + dy < SIZE and inside(x + dx, y + dy))
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge:
                    g[y][x] = "k"  # IMP3-07: a dark 1 px outline, so the pale body reads inside the lit pocket
                elif x + y < 10:
                    g[y][x] = "x"
    ey = eye_y(frame)
    for ex in EYE_X:
        if frame == 3:
            g[ey][ex] = "z"  # shut
            g[ey][ex + 1] = "z"
        else:
            g[ey][ex] = "k"
            g[ey][ex + 1] = "k"
            g[ey - 1][ex] = "e"
    if kind == 1:  # SNIFFER: a long pink snout
        g[ey + 2][5] = "M"
        g[ey + 2][6] = "M"
        g[ey + 3][5] = "i"
    elif kind == 2:  # LANTERN-EATER: a wide mouth with one tooth
        for x in range(3, 9):
            g[ey + 2][x] = "k"
        g[ey + 3][4] = "k"
        g[ey + 3][7] = "k"
        g[ey + 2][5] = "e"
    else:  # CRAWLER: two stubby feet
        base = int(cy + ry)
        for x in (3, 8):
            if 0 <= base < SIZE:
                g[min(base, SIZE - 1)][x] = "W"
    return g


def eye_y(frame: int) -> int:
    return int(SHAPES[frame][2]) - 1


def main() -> None:
    rows: list[str] = []
    for kind in range(3):
        frames = [body(f, kind) for f in range(4)]
        for y in range(SIZE):
            rows.append("".join("".join(frames[f][y]) for f in range(4)))
    art.write_png(art.OUT / "lurkers.png", rows)
    print("eye rows per frame:", [eye_y(f) for f in range(4)], "eye x:", EYE_X)


if __name__ == "__main__":
    main()
