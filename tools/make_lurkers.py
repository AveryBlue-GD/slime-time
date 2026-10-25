"""BM-01 LURKERS (visual review M1): assets/sprites/lurkers.png, 3 kinds x 12 frames of 16x16, palette PAL.

Row = kind (CRAWLER = wide pill-bug with legs, SNIFFER = teardrop with a long nose, LANTERN-EATER = big mouth with a
dull lure). Stone ramp kept (W body, w top light, z underside, k outline); one non-emissive accent per kind (o antenna
tips, M nose, B lure). Drawn facing right; lurkers.gd flips the sprite (and the eye pixels) to face left.

Frames: 0 dormant, 1-4 creep (8 fps), 5-6 notice, 7-9 lunge (crouch, stretch, snap back), 10-11 stunned (4 fps).
The eye pixels per kind/frame are printed as a GDScript table for scripts/lurkers.gd (EYES): the coloured glints
are drawn there above the fog, on the sheet's k eye pixels.

Run: python3 tools/make_lurkers.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_placeholder_art as art  # noqa: E402

S = 16
BASE = 13  # the body's lowest row
NFRAMES = 12
# frame -> (dx, hop, sx, sy, eye mode, phase); eye mode: shut / open / wide / x
STATES = [
    (0, 0, 1.00, 0.90, "shut", 0),   # 0 dormant: settled
    (0, 0, 1.00, 1.00, "open", 0),   # 1-4 creep (same volume)
    (0, 0, 1.00, 1.00, "open", 1),
    (0, 0, 1.00, 1.00, "open", 2),
    (0, 0, 1.00, 1.00, "open", 3),
    (0, 1, 0.95, 1.12, "wide", 0),   # 5 notice: eyes widen, 1 px hop
    (0, 0, 1.00, 1.04, "wide", 1),   # 6
    (-1, 0, 1.08, 0.80, "open", 0),  # 7 lunge: crouch
    (1, 0, 1.22, 0.86, "wide", 1),   # 8 lunge: stretch toward the slime
    (1, 0, 0.98, 1.06, "wide", 2),   # 9 lunge: snap back
    (0, 0, 1.12, 0.70, "x", 0),      # 10 stunned, squashed
    (0, 0, 1.12, 0.74, "x", 1),      # 11 stunned, 1 px tilt
]
KINDS = {
    0: dict(cx=6.6, rx=5.6, ry=3.6, eyes=((0.35, -0.25), (0.78, -0.25))),
    1: dict(cx=5.4, rx=4.0, ry=5.0, eyes=((0.30, -0.35), (0.80, -0.35))),
    2: dict(cx=6.2, rx=5.4, ry=4.6, eyes=((0.10, -0.50), (0.55, -0.50))),
}


def ellipse(g, cx, cy, rx, ry, ch="W"):
    for y in range(S):
        for x in range(S):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                g[y][x] = ch


def shade(g):
    """W body, w on the top two rows of each column, z on the bottom row."""
    h = [row[:] for row in g]
    for y in range(S):
        for x in range(S):
            if g[y][x] != "W":
                continue
            up1 = y > 0 and g[y - 1][x] != "."
            up2 = y > 1 and g[y - 2][x] != "."
            dn = y < S - 1 and g[y + 1][x] != "."
            if not up1 or not up2:
                h[y][x] = "w"
            elif not dn:
                h[y][x] = "z"
    return h


def outline(g):
    h = [row[:] for row in g]
    for y in range(S):
        for x in range(S):
            if g[y][x] != ".":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and g[ny][nx] != ".":
                    h[y][x] = "k"
                    break
    return h


def put(g, x, y, ch):
    if 0 <= x < S and 0 <= y < S:
        g[y][x] = ch


def frame(kind, f):
    dx, hop, sx, sy, eyes, ph = STATES[f]
    k = KINDS[kind]
    rx, ry = k["rx"] * sx, k["ry"] * sy
    bottom = BASE + 1 - hop
    cy = bottom - ry
    cx = k["cx"] + dx
    walking = f in (1, 2, 3, 4)
    g = [["."] * S for _ in range(S)]
    after = []  # parts drawn over the outlined body: (x, y, ch)
    ellipse(g, cx, cy, rx, ry)
    if kind == 1:
        ellipse(g, cx + 2.6, cy - 1.4, 2.6 * sx, 2.4 * sy)
    g = shade(g)
    ys = [y for y in range(S) if any(c != "." for c in g[y])]
    xs = [x for x in range(S) if any(g[y][x] != "." for y in range(S))]
    top, right = min(ys), max(xs)
    if kind == 0:
        for sxp in (cx - 1.5, cx + 1.8):
            xi = int(sxp)
            for y in range(top + 1, max(ys)):
                if g[y][xi] != ".":
                    g[y][xi] = "z"
        offs = [0, 1, 0, -1][ph % 4] if walking else 0
        for i, lx in enumerate((3, 6, 9)):
            up = walking and (i + ph) % 2 == 0
            ly = bottom + (0 if up else 1)
            lxx = lx + offs
            after.append((lxx, ly, "k"))
            after.append((lxx + 1, ly, "k"))
        wig = ph % 2
        ax = right + 1
        after.append((ax, top + 1 + wig, "k"))
        after.append((ax + 1, top + wig, "o"))
        after.append((ax, top + 3 - wig, "k"))
        after.append((ax + 1, top + 3 - wig + 1, "o"))
    elif kind == 1:
        nb = [0, 1, 0, -1][ph % 4] if walking else 0
        ny = int(cy - 1.4) + 1 + max(nb, 0)
        for i in range(3):
            after.append((right + 1 + i, ny, "M"))
        after.append((right + 4, ny + 1, "i"))
        pw = ph % 2
        after.append((int(cx) + 1 + pw, bottom, "W"))
        after.append((int(cx) + 3 - pw, bottom, "W"))
    else:
        jaw = {0: 0, 1: 1, 2: 2, 3: 3, 4: 2, 5: 1, 6: 1, 7: 0, 8: 4, 9: 2, 10: 1, 11: 1}[f]
        my = int(cy + 0.5)
        mx0, mx1 = int(cx + 0.5), int(cx + rx) - 1
        for x in range(mx0, mx1 + 1):
            put(g, x, my, "k")
        for j in range(1, jaw + 1):
            for x in range(mx0 + 1, mx1 + 1):
                put(g, x, my + j, "a")
            put(g, mx0, my + j, "k")
        if jaw >= 1:
            put(g, mx0 + 1, my + 1, "e")
            put(g, mx1 - 1, my + 1, "e")
        sx0 = int(cx) + 1
        sway = ph % 2
        after.append((sx0, top - 1, "W"))
        after.append((sx0 + 1, top - 2, "W"))
        after.append((sx0 + 2 + sway, top - 3, "B"))
        after.append((sx0 + 3 + sway, top - 3, "B"))
        after.append((sx0 + 2 + sway, top - 2, "B"))
    g = outline(g)
    for x, y, c in after:
        put(g, x, y, c)
    g2 = [row[:] for row in g]
    for x, y, c in after:
        if c == "k":
            continue
        for ddx, ddy in ((1, 0), (-1, 0), (0, -1), (0, 1)):
            nx, ny2 = x + ddx, y + ddy
            if 0 <= nx < S and 0 <= ny2 < S and g2[ny2][nx] == ".":
                g2[ny2][nx] = "k"
    g = g2
    pts = []
    for fx, fy in k["eyes"]:
        ex = int(round(cx + fx * rx))
        ey = int(round(cy + fy * ry))
        pts.append((ex, ey))
        if eyes == "shut":
            put(g, ex, ey, "z")
        elif eyes == "open":
            put(g, ex, ey, "k")
        elif eyes == "wide":
            put(g, ex, ey, "k")
            put(g, ex, ey - 1, "k")
        else:
            for ox, oy in ((-1, -1), (1, -1), (0, 0), (-1, 1), (1, 1)):
                put(g, ex + ox, ey + oy, "k")
    return g, pts, eyes


def main() -> None:
    rows = [""] * (S * 3)
    table = []
    for kind in range(3):
        frames = []
        kp = []
        for f in range(NFRAMES):
            g, pts, mode = frame(kind, f)
            frames.append(g)
            kp.append(pts if mode in ("open", "wide") else [])
        for y in range(S):
            rows[kind * S + y] = "".join("".join(frames[f][y]) for f in range(NFRAMES))
        table.append(kp)
    art.write_png(art.OUT / "lurkers.png", rows)
    print("EYES (per kind, per frame: [x, y] pairs; empty = no glint):")
    for kp in table:
        print([[list(p) for p in pts] for pts in kp])


if __name__ == "__main__":
    main()
