"""Generates the UI pixel art (no dependencies): assets/ui/*.png.

Run from the project root:  python tools/make_ui_art.py

- button_normal/hover/pressed/disabled.png : 10x10 nine-slice buttons (outline, top highlight,
  2 px bottom bevel; pressed has the bevel at the top instead, so the face looks pushed in).
  Patch margins: 2 left/right, 2 top, 3 bottom (see UIKit.make_theme).
- panel.png : 12x12 nine-slice framed panel (outline, inner rim, soft top light), 4 px margins.
- hud_pod.png : 8x8 nine-slice, a lighter-weight translucent panel for the HUD, 3 px margins.
- icon_drop / icon_clock / icon_lock / icon_check.png : 8x8 icons in white/grey shades so the
  game can tint them (the drop takes the skin color, the rest the text color).
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
    "Q": (62, 74, 96, 220),     # HUD pod rim
    # Icon shades (tinted in game).
    "1": (215, 215, 215, 255),
    "2": (150, 150, 150, 255),
})

BUTTONS = {
    "normal": [
        ".kkkkkkkk.",
        "khhhhhhhhk",
        "kffffffffk",
        "kffffffffk",
        "kffffffffk",
        "kffffffffk",
        "kffffffffk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        ".kkkkkkkk.",
    ],
    "hover": [
        ".kkkkkkkk.",
        "kAAAAAAAAk",
        "kaaaaaaaak",
        "kaaaaaaaak",
        "kaaaaaaaak",
        "kaaaaaaaak",
        "kaaaaaaaak",
        "khhhhhhhhk",
        "khhhhhhhhk",
        ".kkkkkkkk.",
    ],
    "pressed": [
        ".kkkkkkkk.",
        "kssssssssk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        "kFFFFFFFFk",
        ".kkkkkkkk.",
    ],
    "disabled": [
        ".kkkkkkkk.",
        "kGGGGGGGGk",
        "kggggggggk",
        "kggggggggk",
        "kggggggggk",
        "kggggggggk",
        "kggggggggk",
        "kggggggggk",
        "kggggggggk",
        ".kkkkkkkk.",
    ],
}

PANEL = [
    "..kkkkkkkk..",
    ".krrrrrrrrk.",
    "krPPPPPPPPrk",
    "krpppppppprk",
    "krpppppppprk",
    "krpppppppprk",
    "krpppppppprk",
    "krpppppppprk",
    "krpppppppprk",
    "krpppppppprk",
    ".krrrrrrrrk.",
    "..kkkkkkkk..",
]

HUD_POD = [
    ".QQQQQQ.",
    "QqqqqqqQ",
    "QqqqqqqQ",
    "QqqqqqqQ",
    "QqqqqqqQ",
    "QqqqqqqQ",
    "QqqqqqqQ",
    ".QQQQQQ.",
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
    for name, rows in BUTTONS.items():
        write_png(OUT / f"button_{name}.png", rows)
    write_png(OUT / "panel.png", PANEL)
    write_png(OUT / "hud_pod.png", HUD_POD)
    for name, rows in ICONS.items():
        write_png(OUT / f"icon_{name}.png", rows)
    for name, rows in WIDGETS.items():
        write_png(OUT / f"{name}.png", rows)
