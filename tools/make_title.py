"""Generates the big bubbly "DRY TRYING" title logo (no dependencies): assets/sprites/title/logo_NN.png.

Run from the project root:  python tools/make_title.py   (then re-import)

The game was renamed from Slime Time to Dry Trying on 2026-10-19 (owner).

Letters are drawn on a 5x7 cell grid; every filled cell becomes a fat blob and neighboring blobs
are joined with thick capsules, so strokes come out round and gooey. Goo drips (with a bulb at
the end) hang off the bottom edge, with short ones inside letter holes.
The letter bodies come from one fixed seed; the drips from a different seed per variant, so the
VARIANTS files have identical letters and different drips. The title screen (scripts/ui/title.gd,
LOGO_VARIANTS / logo_texture) shows a different variant than last time on every visit, so the drips
look fresh each time without any run-time drawing.
The logo uses the slime sheet's goo shades (l/m/n plus white gloss), so the game's palette-swap
shader recolors it to the equipped skin, rainbow included.
"""
import math
import random
from pathlib import Path

from make_placeholder_art import PAL, write_png

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites" / "title"
VARIANTS = 12  # keep equal to LOGO_VARIANTS in scripts/ui/title.gd
BODY_SEED = 7
CELL = 6
RADIUS = 3.3  # strokes ~7 px thick; holes stay ~5 px open so letters still read clearly
LETTER_GAP = 3
SPACE = 10
MARGIN = 4
PAL["K"] = (8, 8, 14, 255)  # drop shadow, darker than the menu background

LETTERS = {
    "S": [".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###."],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
}
TEXT = "DRY TRYING"


def segment_distance(px, py, ax, ay, bx, by) -> float:
    vx, vy = bx - ax, by - ay
    length_sq = vx * vx + vy * vy
    t = 0.0 if length_sq == 0 else max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / length_sq))
    return math.hypot(px - (ax + t * vx), py - (ay + t * vy))


def letter_capsules(rows: list[str], ox: float, oy: float, rng: random.Random,
                    drip_rng: random.Random) -> list[tuple]:
    """Capsules (ax, ay, bx, by, radius) that make up one gooey letter (rng) plus its drips (drip_rng)."""
    filled = {(x, y) for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"}
    capsules = []
    for x, y in sorted(filled):
        cx, cy = ox + x * CELL + CELL / 2, oy + y * CELL + CELL / 2
        capsules.append((cx, cy, cx, cy, RADIUS + rng.uniform(-0.2, 0.6)))  # lumpy, bubbly blobs
        for dx, dy in ((1, 0), (0, 1), (1, 1), (-1, 1)):
            if (x + dx, y + dy) not in filled:
                continue
            # Diagonals only where they're the only link (M's middle), not across L-corners.
            if dx and dy and ((x + dx, y) in filled or (x, y + dy) in filled):
                continue
            capsules.append((cx, cy, cx + dx * CELL, cy + dy * CELL, RADIUS - 0.2))
    bottom = len(rows) - 1
    for x, y in sorted(filled):
        if (x, y + 1) in filled:
            continue
        # Long drips hang off the bottom edge; inside holes only short ones, so they don't
        # cross the gap and blur the letter shape.
        if drip_rng.random() > (0.7 if y == bottom else 0.3):
            continue
        cx = ox + x * CELL + CELL / 2 + drip_rng.uniform(-0.8, 0.8)
        cy = oy + y * CELL + CELL / 2
        end = cy + RADIUS + (drip_rng.choice([3, 4, 6, 8, 10, 13]) if y == bottom else drip_rng.choice([1, 2]))
        width = drip_rng.uniform(1.4, 2.0)
        capsules.append((cx, cy, cx, end, width))
        capsules.append((cx, end, cx, end, width + 0.6))  # the drop at the end of the drip
    return capsules


def render(drip_seed: int) -> list[str]:
    rng = random.Random(BODY_SEED)
    drip_rng = random.Random(drip_seed)
    width = MARGIN * 2 + sum(SPACE if ch == " " else len(LETTERS[ch][0]) * CELL + LETTER_GAP for ch in TEXT)
    height = MARGIN + 7 * CELL + 24
    capsules, x = [], MARGIN
    for ch in TEXT:
        if ch == " ":
            x += SPACE
            continue
        capsules += letter_capsules(LETTERS[ch], x, MARGIN, rng, drip_rng)
        x += len(LETTERS[ch][0]) * CELL + LETTER_GAP

    inside = [[False] * width for _ in range(height)]
    for ax, ay, bx, by, r in capsules:  # each capsule only touches the pixels of its bounding box
        for py in range(max(0, int(min(ay, by) - r) - 1), min(height, int(max(ay, by) + r) + 2)):
            row = inside[py]
            for px in range(max(0, int(min(ax, bx) - r) - 1), min(width, int(max(ax, bx) + r) + 2)):
                if not row[px] and segment_distance(px + 0.5, py + 0.5, ax, ay, bx, by) <= r:
                    row[px] = True

    def ins(px, py):
        return 0 <= px < width and 0 <= py < height and inside[py][px]

    g = [["." for _ in range(width)] for _ in range(height)]
    for py in range(height):
        for px in range(width):
            if ins(px - 2, py - 2) and not ins(px, py):
                g[py][px] = "K"  # drop shadow
    for py in range(height):
        for px in range(width):
            if ins(px, py):
                depth = 0  # how far below the top edge of the goo this pixel is
                while ins(px, py - depth - 1):
                    depth += 1
                if depth <= 1:
                    g[py][px] = "l"
                elif not ins(px, py + 1) or not ins(px, py + 2):
                    g[py][px] = "n"
                else:
                    g[py][px] = "m"
                # Glossy highlight dashes just under the top edge, away from the sides.
                if depth == 2 and ins(px - 1, py) and ins(px + 1, py) and (px // 2) % 4 == 0:
                    g[py][px] = "e"
            elif any(ins(px + dx, py + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g[py][px] = "k"
    return ["".join(r) for r in g]


if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("logo_*.png"):
        old.unlink()
    for i in range(VARIANTS):
        rows = render(1000 + i)
        write_png(OUT_DIR / f"logo_{i:02d}.png", rows)
    print(f"{VARIANTS} logos, {len(rows[0])}x{len(rows)}, in {OUT_DIR}")
