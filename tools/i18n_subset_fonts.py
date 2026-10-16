"""Builds the i18n fallback fonts (docs/i18n/plan.md section 7, docs/i18n/fonts.md): subsets of
open-licensed fonts holding only the glyphs the translations use, so the web export stays light.

    python3 -m pip install fonttools brotli        # once (pyftsubset + WOFF2)
    python3 tools/i18n_subset_fonts.py             # rebuild assets/fonts/{cjk,thai,arabic,devanagari}/
    python3 tools/i18n_subset_fonts.py --check     # only report characters missing from the fonts
    ./tools/godot.sh --path . --headless --import  # then re-import

**Re-run after every translation update** (locale/*.po): the CJK subsets only carry the characters
found in the .po files (plus a base set), so a new translated string may use a glyph that isn't in
the font yet. tests/test_i18n_glyphs.gd fails (listing the characters) when that happens.

What goes into each subset: every character of the msgstr texts of the locales the font serves (NFC),
the native language names (Language.LOCALES in scripts/language.gd: the LANGUAGE screen shows them all,
whatever the current language), and a safe base set per script (ASCII, the script's whole Unicode block
for Thai / Arabic / Devanagari; CJK punctuation, kana for ja, full-width forms). Layout features are kept (Thai / Devanagari
shaping), hinting is dropped (Godot draws them with hinting off), output is WOFF2.

Sources: downloaded once from the official releases (pinned version + sha256), cached outside the
repo (~/.cache/slime-time-fonts, or --cache DIR). The license files next to each output are committed;
this script writes a SOURCE.txt beside them (where the font came from, its version and checksum).
The subsets are renamed ("SlimeTime ...") as the OFL asks of modified fonts (Fusion Pixel has a
Reserved Font Name).
"""
import argparse
import hashlib
import io
import re
import sys
import unicodedata
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"
LOCALE_DIR = ROOT / "locale"

FUSION_ZIP = ("https://github.com/TakWolf/fusion-pixel-font/releases/download/2026.10.16/"
              "fusion-pixel-font-10px-proportional-ttf-v2026.10.16.zip")
SOURCES = {
    "fusion": {
        "url": FUSION_ZIP,
        "sha256": "9e45c7b1dac86704cde5d1d1024c31a7a9303cebd3f6a8ee87f2abd0e3e70319",
        "version": "Fusion Pixel Font 2026.10.16, 10px proportional TTF (GitHub release)",
    },
    "fusion12": {
        "url": FUSION_ZIP.replace("10px", "12px"),
        "sha256": "6dd1c8415c829a94aff70e0d24c9a154037bd9bc42cfea77448eac0a2a81c00f",
        "version": "Fusion Pixel Font 2026.10.16, 12px proportional TTF (GitHub release)",
    },
    "noto_thai": {
        "url": "https://raw.githubusercontent.com/google/fonts/8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/"
               "ofl/notosansthai/NotoSansThai%5Bwdth,wght%5D.ttf",
        "sha256": "5a1c559bb539583c8a1fd99d1c5b9491e5e14478c9cd2bd0970d5c3096cc9ef8",
        "version": "Noto Sans Thai (google/fonts @ 8b0a1d0), variable, instanced to wght 400 / wdth 100",
    },
    "noto_deva": {
        "url": "https://raw.githubusercontent.com/google/fonts/2bc5d431b584d89e646214bf6cfa75494e76ceea/"
               "ofl/notosansdevanagari/NotoSansDevanagari%5Bwdth,wght%5D.ttf",
        "sha256": "14ec4af41f27482216d1c2229f417ff9b1425e1babb014e57d1d40d03229853e",
        "version": "Noto Sans Devanagari (google/fonts @ 2bc5d43), variable, instanced to wght 400 / wdth 100",
    },
    "noto_kufi": {
        "url": "https://raw.githubusercontent.com/google/fonts/eb4f2fde9aa730c58ba547d2def669066b6ad87e/"
               "ofl/notokufiarabic/NotoKufiArabic%5Bwght%5D.ttf",
        "sha256": "494f6b61469d7a02a2d63f0fc4930bb007388d8cfe551de5eb98354e100889f3",
        "version": "Noto Kufi Arabic (google/fonts @ eb4f2fd), variable, instanced to wght 400",
    },
}


def ranges(*spans: tuple[int, int]) -> str:
    return "".join(chr(c) for a, b in spans for c in range(a, b + 1))


ASCII = ranges((0x20, 0x7E))
CJK_BASE = ASCII + ranges((0x3000, 0x303F), (0xFF01, 0xFF5E), (0x2018, 0x201D), (0x2026, 0x2026), (0x00B7, 0x00B7))
KANA = ranges((0x3040, 0x30FF))

## Arabic letters, harakat, digits and punctuation (not the whole block: its Quranic marks reach far
## above the letters and would set the line box, see FIT_VMETRICS).
ARABIC_BASE = ranges((0x060C, 0x060C), (0x061B, 0x061B), (0x061F, 0x061F), (0x0621, 0x0652), (0x0660, 0x066D),
                     (0x0670, 0x0670), (0x200B, 0x200F), (0x25CC, 0x25CC))

## Every output font: (path under assets/fonts, source, member in the source zip, locales whose
## translations it covers, base characters, family name). LAYOUT_SCRIPTS keeps only that script's
## OpenType layout tables: a font that advertises another script (Unifont, the old Arabic stand-in, listed Thai) would be picked
## by Godot's fallback for that script's marks and draw nothing.
OUTPUTS = [
    ("cjk/slime_cjk_zh_cn.woff2", "fusion", "fusion-pixel-10px-proportional-zh_hans.ttf", ["zh_CN"], CJK_BASE,
     "SlimeTime CJK SC"),
    # Traditional Chinese uses the 12 px build (Cubic 11's Taiwan glyphs): the 10 px build draws dense
    # Traditional characters from BoutiqueBitmap9x9's 9x9 grid, where 繁 / 體 (17 / 23 strokes) read as 無 / 罶.
    ("cjk/slime_cjk_zh_tw.woff2", "fusion12", "fusion-pixel-12px-proportional-zh_tw.ttf", ["zh_TW"], CJK_BASE,
     "SlimeTime CJK TC"),
    ("cjk/slime_cjk_ja.woff2", "fusion", "fusion-pixel-10px-proportional-ja.ttf", ["ja"], CJK_BASE + KANA,
     "SlimeTime CJK JP"),
    ("cjk/slime_cjk_ko.woff2", "fusion", "fusion-pixel-10px-proportional-ko.ttf", ["ko"], CJK_BASE,
     "SlimeTime CJK KR"),
    ("thai/slime_thai.woff2", "noto_thai", None, ["th"], ASCII + ranges((0x0E00, 0x0E7F), (0x200B, 0x200D), (0x25CC, 0x25CC)),
     "SlimeTime Thai"),
    ("devanagari/slime_devanagari.woff2", "noto_deva", None, ["hi"],
     ASCII + ranges((0x0900, 0x097F), (0x200B, 0x200D), (0x25CC, 0x25CC), (0x20B9, 0x20B9)), "SlimeTime Devanagari"),
    ("arabic/slime_arabic.woff2", "noto_kufi", None, ["ar"],
     ASCII + ARABIC_BASE, "SlimeTime Arabic"),
]


LAYOUT_SCRIPTS = {
    "noto_thai": ["thai", "DFLT", "latn"],
    "noto_deva": ["deva", "dev2", "DFLT", "latn"],
    "noto_kufi": ["arab", "DFLT", "latn"],
}


## Sources whose vertical metrics are cut down to the ink of the glyphs actually kept. Noto Kufi Arabic's
## ascender / descender (1282 / -615 per 1000) make room for stacked Quranic marks: drawn at 12 px that is
## a 24 px line box for 13 px of letters. The subset keeps none of those marks, so its hhea / typo / win
## metrics become the subset's own glyph bounds (every kept glyph, ligatures and harakat included, so
## nothing draws outside the line box). Godot uses them for every line holding an Arabic glyph.
FIT_VMETRICS = {"noto_kufi"}


def fit_vmetrics(font) -> tuple[int, int]:
    """Sets the font's ascender / descender to its glyphs' ink bounds; returns them (font units)."""
    from fontTools.pens.boundsPen import BoundsPen
    glyphs = font.getGlyphSet()
    top, bottom = 0, 0
    for name in font.getGlyphOrder():
        pen = BoundsPen(glyphs)
        glyphs[name].draw(pen)
        if pen.bounds:
            bottom = min(bottom, pen.bounds[1])
            top = max(top, pen.bounds[3])
    top, bottom = int(round(top)), int(round(bottom))
    hhea, os2 = font["hhea"], font["OS/2"]
    hhea.ascent, hhea.descent, hhea.lineGap = top, bottom, 0
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = top, bottom, 0
    os2.usWinAscent, os2.usWinDescent = top, -bottom
    return top, bottom


def fetch(source: str, cache: Path) -> bytes:
    """The source file's bytes, from the cache or downloaded (checked against the pinned sha256)."""
    info = SOURCES[source]
    path = cache / Path(info["url"]).name.replace("%5B", "[").replace("%5D", "]")
    if not path.exists():
        cache.mkdir(parents=True, exist_ok=True)
        print(f"downloading {info['url']}")
        with urllib.request.urlopen(info["url"]) as response:
            path.write_bytes(response.read())
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != info["sha256"]:
        sys.exit(f"{path}: sha256 {digest} is not the pinned {info['sha256']} (delete it to re-download)")
    return data


def po_texts(code: str) -> str:
    """Every msgstr of locale/<code>.po (all plural forms), NFC, with the escapes resolved."""
    path = LOCALE_DIR / f"{code}.po"
    if not path.exists():
        return ""
    out, current = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        m = re.match(r'msgstr(\[\d+\])?\s+"(.*)"$', line)
        if m:
            current = [m.group(2)]
            out.append(current)
        elif line.startswith('"') and current is not None:
            current.append(line[1:-1])
        else:
            current = None
    text = "".join("".join(parts) for parts in out)
    text = text.replace('\\"', '"').replace("\\n", "\n").replace("\\t", " ").replace("\\\\", "\\")
    return unicodedata.normalize("NFC", text)


def native_names() -> str:
    """The native language names from Language.LOCALES (shown on the LANGUAGE screen in every locale)."""
    src = (ROOT / "scripts" / "language.gd").read_text(encoding="utf-8")
    block = src[src.index("const LOCALES"):src.index("]\n", src.index("const LOCALES")) + 1]
    return "".join(re.findall(r'\["[A-Za-z_]+", "([^"]+)"\]', block))


def wanted(locales: list[str], base: str) -> set[str]:
    chars = set(base) | set(native_names())
    for code in locales:
        chars |= set(po_texts(code))
    return {c for c in chars if c not in "\n\r\t"}


def build(cache: Path, check_only: bool) -> int:
    from fontTools import subset
    from fontTools.ttLib import TTFont
    from fontTools.varLib import instancer

    missing_total = 0
    zips: dict[str, zipfile.ZipFile] = {}
    for rel, source, member, locales, base, family in OUTPUTS:
        data = fetch(source, cache)
        if member:
            zips.setdefault(source, zipfile.ZipFile(io.BytesIO(data)))
            data = zips[source].read(member)
        font = TTFont(io.BytesIO(data))
        if "fvar" in font:
            axes = {axis.axisTag for axis in font["fvar"].axes}
            font = instancer.instantiateVariableFont(font, {k: v for k, v in {"wght": 400, "wdth": 100}.items() if k in axes})
        cmap = font.getBestCmap()
        chars = wanted(locales, base)
        needed = set()
        for code in locales:
            needed |= set(po_texts(code))
        missing = sorted(c for c in needed if ord(c) not in cmap and c not in " \n" and not c.isascii())
        if missing:
            missing_total += len(missing)
            print(f"{rel}: {len(missing)} translated characters the source font lacks: {''.join(missing)}")
        if check_only:
            out = FONTS / rel
            if out.exists():
                have = TTFont(out).getBestCmap()
                gone = sorted(c for c in chars if ord(c) in cmap and ord(c) not in have)
                if gone:
                    missing_total += len(gone)
                    print(f"{rel}: stale subset, re-run this script: {''.join(gone)}")
            continue
        options = subset.Options()
        options.layout_features = ["*"]
        if source in LAYOUT_SCRIPTS:
            options.layout_scripts = LAYOUT_SCRIPTS[source]
        options.hinting = False
        options.flavor = "woff2"
        options.name_IDs = ["*"]
        options.notdef_outline = True
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=[ord(c) for c in chars])
        subsetter.subset(font)
        if source in FIT_VMETRICS:
            top, bottom = fit_vmetrics(font)
            print(f"{rel}: vertical metrics fitted to the ink: ascender {top}, descender {bottom}")
        name = font["name"]
        for record in list(name.names):
            if record.nameID in (1, 4, 16, 21):
                record.string = family
            elif record.nameID in (3, 6, 20):
                record.string = family.replace(" ", "")
        out = FONTS / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        font.flavor = "woff2"
        font.save(out)
        info = SOURCES[source]
        (out.parent / f"SOURCE-{out.stem}.txt").write_text(
            f"{out.name}: a subset of {info['version']}\n"
            f"Downloaded from {info['url']}\nsha256 {info['sha256']}\n"
            f"Built by tools/i18n_subset_fonts.py ({len(chars)} characters requested, "
            f"{len(font.getBestCmap())} in the font). Renamed to \"{family}\" (OFL: modified version).\n"
            "License: see the OFL / LICENSE files in this folder.\n", encoding="utf-8")
        print(f"wrote assets/fonts/{rel} ({out.stat().st_size / 1024:.1f} KB, {len(font.getBestCmap())} chars)")
    return missing_total


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache" / "slime-time-fonts")
    parser.add_argument("--check", action="store_true", help="only report missing characters")
    args = parser.parse_args()
    missing = build(args.cache, args.check)
    if args.check and missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
