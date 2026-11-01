"""BM-01 LURKERS (visual review M1 / M21): assets/sprites/lurkers.png, 3 kinds x 12 frames of 16x16, palette PAL + LURKER_PAL.

Row = kind (CRAWLER = wide pill-bug with legs, SNIFFER = teardrop with a long nose, LANTERN-EATER = big mouth with a
dull lure). One constant stone ramp in every theme, darker than any wall (SPR-22 / CON-21): W top, z mid, U underside
(z mixed half way into k), k outline, plus a 1 px e wet glint on the top-left of the head. A 6-10 px accent per kind, none
of it gold (gold is for rewards): crawler = R seams + R antenna tips on body-colour stalks, sniffer = M nose, paws and
belly line, lantern-eater = a B lure (non-emissive, under the fog). Drawn facing right; lurkers.gd flips the sprite (and
the eye pixels) to face left. Every frame has a closed k outline (SPR-26): `--check` fails on a gap.

Frames: 0 dormant, 1-4 creep (8 fps), 5-6 notice, 7-9 lunge (crouch, stretch, snap back), 10-11 stunned (4 fps).
The eye pixels per kind/frame are printed as a GDScript table for scripts/lurkers.gd (EYES): the coloured glints
are drawn there above the fog, on the sheet's k eye pixels.

Run: python3 tools/make_lurkers.py [--check]   (--check regenerates in memory and fails on outline gaps / thin accents)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_placeholder_art as art  # noqa: E402

# CON-06 / M32: the lurker colours, named and built from PAL (U = z mixed half way into k; R = a non-gold orange-red).
LURKER_PAL = {
    "U": tuple((a + b) // 2 for a, b in zip(art.PAL["z"], art.PAL["k"])),
    "R": (240, 96, 64, 255),
}
art.PAL.update(LURKER_PAL)
ACCENT = {0: "R", 1: "M", 2: "B"}  # the letter whose pixels are the kind's accent area (sniffer's nose tip is i, not counted)

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
    (0, 0, 1.00, 0.80, "open", 0),   # 7 lunge: crouch
    (1, 0, 1.08, 0.86, "wide", 1),   # 8 lunge: stretch toward the slime
    (1, 0, 0.98, 1.06, "wide", 2),   # 9 lunge: snap back
    (1, 0, 1.04, 0.72, "dash", 0),   # 10 stunned, squashed (1 px right and narrower: the k ring stays closed)
    (1, 0, 1.04, 0.76, "dash", 1),   # 11 stunned, 1 px tilt (the dizzy pixels orbit above, drawn by lurkers.gd)
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
    """z body, W on the top two rows of each column, U on the bottom row."""
    h = [row[:] for row in g]
    for y in range(S):
        for x in range(S):
            if g[y][x] != "W":
                continue
            up1 = y > 0 and g[y - 1][x] != "."
            up2 = y > 1 and g[y - 2][x] != "."
            dn = y < S - 1 and g[y + 1][x] != "."
            if not up1 or not up2:
                h[y][x] = "W"
            elif not dn:
                h[y][x] = "U"
            else:
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


def row_right(g, y):
    xs = [x for x in range(S) if g[y][x] != "."]
    return max(xs) if xs else 0


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
        # R seams between the plates (3 px each, the rest of the seam in the underside tone)
        mid = (top + max(ys)) // 2
        for sxp in (cx - 1.5, cx + 1.8):
            xi = int(sxp)
            for y in range(top + 1, max(ys)):
                if g[y][xi] != ".":
                    g[y][xi] = "R" if abs(y - mid) <= 1 else "U"
        offs = [0, 1, 0, -1][ph % 4] if walking else 0
        for i, lx in enumerate((3, 6, 9)):
            up = walking and (i + ph) % 2 == 0
            ly = bottom + (0 if up else 1)
            lxx = lx + offs
            after.append((lxx, ly, "k"))
            after.append((lxx + 1, ly, "k"))
        wig = ph % 2
        # SPR-23: antenna stalks in body colour, touching the head, with an R tip
        for sy_, tip_dy in ((top + 1 + wig, -1), (top + 3 - wig, 1)):
            bx = row_right(g, sy_) + 1
            after.append((bx, sy_, "W"))
            after.append((bx + (1 if bx < 14 else 0), sy_ + tip_dy, "R"))
    elif kind == 1:
        nb = [0, 1, 0, -1][ph % 4] if walking else 0
        ny = int(cy - 1.4) + 1 + max(nb, 0)
        nx0 = row_right(g, ny) + 1
        for i in range(3):
            after.append((nx0 + i, ny, "M"))
        after.append((nx0 + 3, ny, "i"))
        pw = ph % 2
        after.append((int(cx) + 1 + pw, bottom, "M"))
        after.append((int(cx) + 3 - pw, bottom, "M"))
        for x in range(S):  # the belly line: the middle of the underside row in pink
            if g[bottom - 1][x] == "U" and abs(x - int(cx + 0.5)) <= 1:
                g[bottom - 1][x] = "M"
    else:
        jaw = {0: 0, 1: 1, 2: 2, 3: 3, 4: 2, 5: 1, 6: 1, 7: 0, 8: 3, 9: 2, 10: 1, 11: 1}[f]
        my = int(cy + 0.5)
        mx0, mx1 = int(cx + 0.5), int(cx + rx) - 1
        jaw = min(jaw, bottom - 2 - my)  # SPR-26: the jaw stays inside the body line
        for x in range(mx0, mx1 + 1):
            put(g, x, my, "k")
        for j in range(1, jaw + 1):
            lo, hi = mx0 + 1, mx1
            if j == jaw and jaw >= 2:
                lo, hi = lo + 1, hi - 1  # rounded corners
            for x in range(lo, hi + 1):
                if g[my + j][x] != ".":
                    put(g, x, my + j, "a")
            if g[my + j][mx0] != ".":
                put(g, mx0, my + j, "k")
        if jaw >= 1:
            put(g, mx0 + 2, my + 1, "e")
            put(g, mx1 - 1, my + 1, "e")
        sx0 = int(cx) + 1
        sway = ph % 2
        lt = max(top - 3, 1)  # the lure's top row (kept off the frame edge so its outline closes)
        after.append((sx0, top - 1, "W"))
        after.append((sx0 + 1, max(top - 2, lt + 1), "B"))
        for ox in range(3):  # the lure pulses: 3x2, with a 4th pixel on its top row every other creep frame (non-emissive B)
            after.append((sx0 + 2 + ox, lt, "B"))
            after.append((sx0 + 2 + ox, lt + 1, "B"))
        if sway:
            after.append((sx0 + 5, lt, "B"))
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
    # CON-21: a 1 px wet glint on the top-left of the head (the slime / chalice light direction)
    top_row = min(y for y in range(S) if any(c in "WzU" for c in g[y]))
    row_x = [x for x in range(S) if g[top_row][x] in "WzU"]
    if len(row_x) >= 3:
        g[top_row][row_x[0] + 1] = "e"
    elif row_x:
        g[top_row + 1][row_x[0]] = "e"
    pts = []
    for fx, fy in k["eyes"]:
        ex = int(round(cx + fx * rx))
        ey = int(round(cy + fy * ry))
        pts.append((ex, ey))
        if eyes == "shut":
            put(g, ex, ey, "U")
        elif eyes == "open":
            put(g, ex, ey, "k")
        elif eyes == "wide":
            put(g, ex, ey, "k")
            put(g, ex, ey - 1, "k")
        else:  # "dash" (stunned): 1 px k dashes, the dizzy pixels are drawn above the fog by lurkers.gd
            put(g, ex, ey + 1, "k")
    return g, pts, eyes


def check_outline(g):
    """SPR-26: every body pixel must be walled in by k (or another body pixel): no opaque pixel touches transparency or
    the frame edge, except the k outline itself."""
    bad = []
    for y in range(S):
        for x in range(S):
            if g[y][x] in ".k":
                continue
            for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ddx, y + ddy
                if not (0 <= nx < S and 0 <= ny < S) or g[ny][nx] == ".":
                    bad.append((x, y))
                    break
    return bad


def build():
    frames_all, table, tops = [], [], []
    for kind in range(3):
        frames, kp, tp = [], [], []
        for f in range(NFRAMES):
            g, pts, mode = frame(kind, f)
            frames.append(g)
            kp.append(pts if mode in ("open", "wide") else [])
            if mode == "dash":
                top_y = min(y for y in range(S) if any(c in "WzUe" for c in g[y]))
                body_x = [x for x in range(S) if g[top_y][x] in "WzUe"]
                tp.append((sum(body_x) // len(body_x), top_y))
        frames_all.append(frames)
        table.append(kp)
        tops.append(tp)
    return frames_all, table, tops


def check() -> int:
    for key in LURKER_PAL:
        assert max(art.PAL[key][:3]) >= 16, f"palette {key} is near black"
    frames_all, _, _ = build()
    problems = 0
    for kind, frames in enumerate(frames_all):
        for f, g in enumerate(frames):
            for x, y in check_outline(g):
                print(f"outline gap: kind {kind} frame {f} at ({x}, {y})")
                problems += 1
        for f in (1, 2, 3, 4):
            n = sum(row.count(ACCENT[kind]) for row in ("".join(r) for r in frames[f]))
            if not 6 <= n <= 10:
                print(f"accent {ACCENT[kind]}: kind {kind} frame {f} has {n} px (want 6-10)")
                problems += 1
    print("lurkers --check:", "FAIL" if problems else "ok")
    return 1 if problems else 0


def main() -> None:
    if "--check" in sys.argv:
        sys.exit(check())
    frames_all, table, tops = build()
    rows = [""] * (S * 3)
    for kind in range(3):
        for y in range(S):
            rows[kind * S + y] = "".join("".join(frames_all[kind][f][y]) for f in range(NFRAMES))
    art.write_png(art.OUT / "lurkers.png", rows)
    print("EYES (per kind, per frame: [x, y] pairs; empty = no glint):")
    for kp in table:
        print([[list(p) for p in pts] for pts in kp])
    print("DIZZY (per kind: the head's top centre on stun frames 10, 11):", tops)
    sys.exit(check())


if __name__ == "__main__":
    main()
