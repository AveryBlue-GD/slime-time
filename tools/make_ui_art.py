"""Generates the UI pixel art (no dependencies): assets/ui/*.png.

Run from the project root:  python tools/make_ui_art.py

(Buttons and panels are drawn by GooBox/UIKit styleboxes; the old button_*.png and panel.png sheets were unused and removed.)
- hud_pod.png : 8x8 nine-slice, a lighter-weight translucent panel for the HUD, 3 px margins.
- icon_drop / icon_clock / icon_lock / icon_check.png : 8x8 icons in white/grey shades so the
  game can tint them (the drop takes the skin color, the rest the text color); icon_coin.png and icon_ticket.png (a notched voucher) are
  drawn in gold.
- check_off / check_on.png (9x9) and grabber / grabber_hover.png (5x9): checkbox and slider knob.
"""
from pathlib import Path

from make_placeholder_art import PAL, write_png

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
    "medal": [  # a ribbon and a disc: gold when earned, dim when not
        ".e....e.",
        "..e..e..",
        "..e11e..",
        ".e1111e.",
        ".e1221e.",
        ".e1111e.",
        "..eeee..",
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
    "check_off": [
        ".kkkkkkk.",
        "kFFFFFFFk",
        "kFfffffhk",
        "kFfffffhk",
        "kFfffffhk",
        "kFfffffhk",
        "kFfffffhk",
        "khhhhhhhk",
        ".kkkkkkk.",
    ],
    "check_on": [
        ".kkkkkkk.",
        "kFFFFFFFk",
        "kFffffeek",
        "kFfffee1k",
        "kFeeee1hk",
        "kFfee1fhk",
        "kFfe1ffhk",
        "khhhhhhhk",
        ".kkkkkkk.",
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


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "hud_pod.png", HUD_POD)
    for name, rows in ICONS.items():
        write_png(OUT / f"icon_{name}.png", rows)
    for name, rows in WIDGETS.items():
        write_png(OUT / f"{name}.png", rows)
