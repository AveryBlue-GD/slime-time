"""Generates the UI pixel art (no dependencies): assets/ui/*.png.

Run from the project root:  python tools/make_ui_art.py

(Buttons and panels are drawn by GooBox/UIKit styleboxes; the old button_*.png and panel.png sheets were unused and removed.)
- hud_pod.png : 8x8 nine-slice, a lighter-weight translucent panel for the HUD, 3 px margins.
- icon_drop / icon_clock / icon_lock / icon_check.png : 8x8 icons in white/grey shades so the
  game can tint them (the drop takes the skin color, the rest the text color); icon_coin.png and icon_ticket.png (a notched voucher) are
  drawn in gold.
- icon_globe.png : 8x8 (7x7 ink) globe on the SETTINGS LANGUAGE button (i18n, shown only with the gate on).
- check_off / check_on.png (9x9) and grabber / grabber_hover.png (5x9): checkbox and slider knob.
"""
import zlib
from pathlib import Path

from make_placeholder_art import PAL
from make_placeholder_art import write_png as _write_png

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"

PAL.update({
    # Button faces (purple-grey, matching the floor tones).
    "a": (72, 62, 94, 255),     # hover body
    "A": (104, 92, 130, 255),   # hover highlight
    "s": (30, 26, 40, 255),     # pressed top shadow
    "g": (34, 30, 44, 255),     # disabled body
    "G": (44, 40, 56, 255),     # disabled rim
    # Panels.
    "p": (30, 30, 48, 235),     # panel body
    "P": (44, 44, 68, 240),     # panel top light
    "r": (62, 74, 96, 255),     # panel rim (stone stain)
    "q": (26, 28, 44, 190),     # HUD pod body (translucent)
    "Q": (62, 74, 96, 235),     # HUD pod rim
    "O": (10, 10, 20, 235),     # HUD pod dark outline
    "H": (112, 130, 158, 235),  # HUD pod top highlight
    # Icon shades (tinted in game).
    "3": (226, 232, 240, 255),  # silver medal mid / dark
    "4": (140, 150, 180, 255),
    "5": (246, 190, 130, 255),  # bronze medal light / mid / dark
    "6": (214, 140, 84, 255),
    "7": (140, 84, 50, 255),
    "1": (215, 215, 215, 255),
    "2": (150, 150, 150, 255),
})



# Dark outline, light rim with a brighter top edge (the same two-step frame the goo boxes have).
HUD_POD = [
    ".OOOOOO.",
    "OHHHHHHO",
    "OQqqqqQO",
    "OQqqqqQO",
    "OQqqqqQO",
    "OQqqqqQO",
    "OQQQQQQO",
    ".OOOOOO.",
]

ICONS = {
    "drop": [
        "...ee...",
        "...e1...",
        "..ee11..",
        ".eee111.",
        ".ee1112.",
        ".e11122.",
        "..1222..",
        "........",
    ],
    "clock": [
        "..1111..",
        ".1eeee1.",
        "1eeke2e1",
        "1eekkee1",
        "1eeeeee1",
        ".1eeee1.",
        "..1111..",
        "........",
    ],
    "lock": [
        "..2222..",
        ".2....2.",
        ".2....2.",
        "eeeeeeee",
        "e111111e",
        "e11kk11e",
        "e112211e",
        "eeeeeeee",
    ],
    "coin": [  # drawn in gold (not tinted): shown with a white modulate
        "..kkkk..",
        ".kYyyyk.",
        "kYyyyyok",
        "kyyoyyok",
        "kyyoyyok",
        "kyyyyook",
        ".kyoook.",
        "..kkkk..",
    ],
    "ticket": [  # drawn in gold (not tinted): a voucher with a notch bitten out of each side
        "........",
        "yyyyyyyy",
        "yYYYYYYy",
        ".YYooYY.",
        ".YYooYY.",
        "yYYYYYYy",
        "oooooooo",
        "........",
    ],
    "medal": [  # CON-04 reward icon: full colour, k outline; V ribbon in ruby `i`, gold disc `y o Y`
        "ii....ii",
        ".ii..ii.",
        "..iiii..",
        "..kkkk..",
        ".kYyyyk.",
        ".kyyoyk.",
        ".kyooyk.",
        "..kkkk..",
    ],
    "medal_silver": [  # the same medal in silver (tier 2 on the result panel)
        "ii....ii",
        ".ii..ii.",
        "..iiii..",
        "..kkkk..",
        ".ke333k.",
        ".k3334k.",
        ".k3443k.",
        "..kkkk..",
    ],
    "medal_bronze": [  # and in bronze (tier 1)
        "ii....ii",
        ".ii..ii.",
        "..iiii..",
        "..kkkk..",
        ".k5666k.",
        ".k6676k.",
        ".k6776k.",
        "..kkkk..",
    ],
    "medal_off": [  # not (yet) earned: white shades, tinted dim in game
        "22....22",
        ".22..22.",
        "..2222..",
        "..kkkk..",
        ".ke111k.",
        ".k1121k.",
        ".k1221k.",
        "..kkkk..",
    ],
    "globe": [  # the LANGUAGE button in SETTINGS: a ring, land (light) on a dimmer sea; tinted like the text
        "..eee...",
        ".e112e..",
        "e11222e.",
        "e12211e.",
        "e22111e.",
        ".e221e..",
        "..eee...",
        "........",
    ],
    "dice": [  # the RANDOMIZE button in the wardrobe: a die showing five
        "eeeeeee.",
        "eg111ge.",
        "e11111e.",
        "e11g11e.",
        "e11111e.",
        "eg111ge.",
        "eeeeeee.",
        "........",
    ],
    "check": [
        "........",
        "......ee",
        ".....ee1",
        "e...ee1.",
        "ee.ee1..",
        ".eee1...",
        "..e1....",
        "........",
    ],
}


# Checkbox (9x9) and slider grabber (5x9), drawn in the button colors.
WIDGETS = {
    # UI-03: a light 1 px frame (H, >= 3:1 on the panel) so an unchecked box is visible; off = dark inside.
    "check_off": [
        ".HHHHHHH.",
        "HsssssssH",
        "HsssssssH",
        "HsssssssH",
        "HsssssssH",
        "HsssssssH",
        "HsssssssH",
        "HsssssssH",
        ".HHHHHHH.",
    ],
    "check_on": [
        ".HHHHHHH.",
        "HFFFFFFFH",
        "HFffffeeH",
        "HFfffee1H",
        "HFeeee1hH",
        "HFfee1fhH",
        "HFfe1ffhH",
        "HhhhhhhhH",
        ".HHHHHHH.",
    ],
    "grabber": [
        ".kkk.",
        "kAAAk",
        "kaaak",
        "kaAak",
        "kaaak",
        "kaAak",
        "kaaak",
        "khhhk",
        ".kkk.",
    ],
    "grabber_hover": [
        ".kkk.",
        "keeek",
        "kAAAk",
        "kAeAk",
        "kAAAk",
        "kAeAk",
        "kAAAk",
        "kaaak",
        ".kkk.",
    ],
}


UTILITY = ("drop", "clock", "lock", "dice", "globe", "check")


def outlined(rows: list[str]) -> list[str]:
    out = [list(r) for r in rows]
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == ".":
                near = ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                if any(0 <= nx < len(row) and 0 <= ny < len(rows) and rows[ny][nx] != "." for nx, ny in near):
                    out[y][x] = "k"
    return ["".join(r) for r in out]


def _pixels(png: bytes) -> tuple[bytes, bytes]:
    """(IHDR, decompressed IDAT) of a PNG, to compare images whatever zlib build compressed them."""
    pos, header, data = 8, b"", b""
    while pos < len(png):
        size = int.from_bytes(png[pos:pos + 4], "big")
        tag, body = png[pos + 4:pos + 8], png[pos + 8:pos + 8 + size]
        if tag == b"IHDR":
            header = body
        elif tag == b"IDAT":
            data += body
        pos += 12 + size
    return header, zlib.decompress(data)


def write_png(path: Path, rows: list[str]) -> None:
    """Writes the PNG, but keeps an existing file's bytes when its pixels are unchanged (zlib builds
    differ between machines, and the shipped art must stay byte-identical)."""
    old = path.read_bytes() if path.exists() else None
    _write_png(path, rows)
    if old is not None and old != path.read_bytes() and _pixels(old) == _pixels(path.read_bytes()):
        path.write_bytes(old)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "hud_pod.png", HUD_POD)
    for name, rows in ICONS.items():
        if name in UTILITY:  # CON-04: a 1 px `k` outline wherever the 8x8 cell has room for it
            rows = outlined(rows)
        write_png(OUT / f"icon_{name}.png", rows)
    for name, rows in WIDGETS.items():
        write_png(OUT / f"{name}.png", rows)
