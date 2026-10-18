#!/usr/bin/env python3
"""Slime Time string extractor (docs/i18n/plan.md, chunk B). Standard library only.

Reads every `Loc.t(ctx, msgid, args)` / `Loc.n(ctx, singular, plural, count, args)` call in scripts/ and
writes the gettext template locale/messages.pot. `ctx` and the English text(s) must be plain string
literals at the call site (anything else is an error with its file:line).

Usage (from the repo root or anywhere):
  python3 tools/i18n_extract.py              writes locale/messages.pot (deterministic: same code, same file)
  python3 tools/i18n_extract.py --merge      ...and updates every locale/<code>.po from it, creating missing
                                             ones with the right header (Language, Plural-Forms). Existing
                                             translations and translator comments are kept; a changed English
                                             text keeps its old translation marked `#, fuzzy` (Godot skips fuzzy
                                             entries, so the English shows until a translator checks it);
                                             entries whose key left the code move to the end as `#~` obsolete
                                             (revived if the key comes back with the same text).
  python3 tools/i18n_extract.py --pending    changes nothing; lists per locale the entries the catch-up session must do
                                             (new, changed English / fuzzy, untranslated) - docs/i18n/pending.md.
  python3 tools/i18n_extract.py --check      changes nothing; exits 1 on any error:
                                             - messages.pot is out of date with the code, or a .po is not merged;
                                             - bad call sites, a printf format (%d, %s, %.2f, %%) in a msgid,
                                               a placeholder the call's literal args dict does not fill;
                                             - per .po: header Language = file name, Plural-Forms = the table
                                               below, plural form count, placeholders of every msgstr / plural
                                               form = the English ones, no printf formats, NFC normalization,
                                               `lines N` budgets, ALL CAPS for cased scripts (unless the entry's
                                               notes say "mixed case"), Turkish casing sanity, untranslated or
                                               fuzzy entries;
                                             - code completeness: string literals in scripts/ that look like
                                               player-visible English (a run of 2+ capitals, or a capitalized
                                               sentence) outside Loc calls, minus the dev allowlist.
           --partial                         with --check: untranslated / fuzzy / stale entries (English changed
                                             since the last --merge: new, changed, removed) and a .po that is
                                             behind messages.pot are notes, not errors; the .pot, the code scan,
                                             the web table and the header / text checks of up-to-date entries stay
                                             strict. The tests pass it while I18N_ENGLISH_ONLY is on
                                             (tests/i18n_mode.gd).
           --no-code-scan                    with --check: skip the code completeness scan.
  python3 tools/i18n_extract.py --web-json [--out FILE]
                                             the web shell's string table (chunk J): {locale: {key: text}} for
                                             every entry whose ctx starts with "web.", English as fallback.
  python3 tools/i18n_extract.py --web-embed  rewrite the generated I18N_TABLE block of tools/web_shell.html (also
                                             done by --merge). The English source of the "web.*" strings is the
                                             I18N_EN block of that file (`// i18n:` comment above a one-line
                                             `'web.key': 'text',`); --check fails when the embedded table is out
                                             of date or when its LANGUAGES_ENABLED differs from
                                             Economy.LANGUAGES_TEST in scripts/economy.gd (flip both together).

Hints for translators go in `# i18n:` comments, trailing on a line of the call or on the comment lines right
above it (they apply to every call that starts on the next code line):
    label.text = Loc.t("hud.pod.heat", "HEAT {heat}", {heat = heat})  # i18n: HUD pod, max 50px; {heat} = heat level
    # i18n: max 296px, lines 2. Pun on "dry"; keep it short.
The whole hint becomes a translator comment (`#.`). `max N` / `max Npx` is the width budget in pixels of the
8 px font, `lines N` (or `N lines`) the line budget; they are also written as one normalized line
`#. budget: max Npx, lines N` (smallest over all call sites) that the tests read.
`# i18n: ignore` on a line (or alone on the line above) keeps its literals out of the code completeness scan
(for text that must stay English: dev-only labels, key and pad names, ids).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import unicodedata
from dataclasses import dataclass, field

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Locale table: code -> (English name, nplurals, Plural-Forms expression, python rule). Godot reads the
# expression from the .po header; the python rule mirrors it for the checks (form index for n).
PLURALS: dict[str, tuple[str, int, str, object]] = {
    "es": ("Spanish (Latin America, neutral)", 2, "(n != 1)", lambda n: 0 if n == 1 else 1),
    "pt_BR": ("Portuguese (Brazil)", 2, "(n > 1)", lambda n: 1 if n > 1 else 0),
    "fr": ("French", 2, "(n > 1)", lambda n: 1 if n > 1 else 0),
    "de": ("German", 2, "(n != 1)", lambda n: 0 if n == 1 else 1),
    "it": ("Italian", 2, "(n != 1)", lambda n: 0 if n == 1 else 1),
    "ru": ("Russian", 3,
           "(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)",
           lambda n: 0 if n % 10 == 1 and n % 100 != 11 else
           1 if 2 <= n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) else 2),
    "pl": ("Polish", 3,
           "(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)",
           lambda n: 0 if n == 1 else 1 if 2 <= n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) else 2),
    "tr": ("Turkish", 2, "(n != 1)", lambda n: 0 if n == 1 else 1),
    "ja": ("Japanese", 1, "0", lambda n: 0),
    "ko": ("Korean", 1, "0", lambda n: 0),
    "zh_CN": ("Chinese (Simplified)", 1, "0", lambda n: 0),
    "zh_TW": ("Chinese (Traditional)", 1, "0", lambda n: 0),
    "th": ("Thai", 1, "0", lambda n: 0),
    "vi": ("Vietnamese", 1, "0", lambda n: 0),
    "id": ("Indonesian", 1, "0", lambda n: 0),
    "ar": ("Arabic", 6,
           "(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5)",
           lambda n: 0 if n == 0 else 1 if n == 1 else 2 if n == 2 else
           3 if 3 <= n % 100 <= 10 else 4 if n % 100 >= 11 else 5),
    "hi": ("Hindi", 2, "(n > 1)", lambda n: 1 if n > 1 else 0),
}
LOCALES = list(PLURALS)
# Locales whose script has upper / lower case: the game is ALL CAPS there.
CASED = {"es", "pt_BR", "fr", "de", "it", "ru", "pl", "tr", "vi", "id"}

PLACEHOLDER = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
PRINTF = re.compile(r"%%|%[-+ 0#]*\d*(?:\.\d+)?[sdifxXcvo]")
BUDGET_MAX = re.compile(r"\bmax\s*[=:]?\s*(\d+)\s*(?:px)?\b", re.I)
BUDGET_LINES = re.compile(r"\blines?\s*[=:]?\s*(\d+)\b|\b(\d+)\s*lines?\b", re.I)

# Code completeness scan: files that are dev-only (stay English), and (file, literal) pairs allowed.
DEV_FILES = ("scripts/autoplay/", "scripts/dev_log.gd", "scripts/loc.gd", "scripts/language.gd")
DEV_CALLS = re.compile(r"\b(print|prints|printerr|printt|print_rich|print_debug|push_warning|push_error|assert"
                       r"|DevLog\.\w+|_log|_dev_\w*)\s*\(")
# Every other literal on a line holding one of these is dev text too (a dev panel's "OFF").
ALLOW: dict[str, set[str]] = {
    # Pad button names are printed on the pad, key names come from the keyboard (plan section 2: stay as they are).
    "scripts/platform.gd": {"START", "VIEW", "LB", "RB"},
    "scripts/tutorial_cues.gd": {"SPACE", "UP", "DOWN", "LEFT", "RIGHT"},
    "scripts/ui/controls.gd": {"CMD+V", "CTRL+V"},
    # Save code prefix, log reasons, test-only names, the dev tags / dev panel (debug flags only).
    "scripts/progress.gd": {"SLIME2-", "SLIME"},
    "scripts/spawn_picker.gd": {"EDGE", "NEAR", "ANY"},
    "scripts/game.gd": {"dry-up RESTART", "REPLAY MAZE", "BRIGHT", "NO DRAIN"},
    "scripts/ui/restart_prompt.gd": {"prompt RESTART"},
    "scripts/hud.gd": {"DEV ", "DEV TOGGLES: NO MEDALS, RECORDS OR TICKETS"},
    "scripts/ui/descent_card.gd": {"  DEV TOGGLES"},
    "scripts/ui/pause_menu.gd": {"DEV (F1 / F2)", "BRIGHT: ", "DRAIN: "},
}


# ---------------------------------------------------------------------------------------------------------
# GDScript tokenizer (just enough: strings, comments, identifiers, punctuation).

@dataclass
class Tok:
    kind: str  # "str", "id", "op", "num", "comment"
    value: str
    line: int
    end_line: int


_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
        '"': '"', "'": "'", "\\": "\\"}


class TokenizeError(Exception):
    pass


def tokenize(src: str) -> list[Tok]:
    toks: list[Tok] = []
    i, line, n = 0, 1, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if c == "\\" and i + 1 < n and src[i + 1] in "\r\n":  # line continuation
            i += 1
            continue
        if c == "#":
            j = src.find("\n", i)
            j = n if j < 0 else j
            toks.append(Tok("comment", src[i:j], line, line))
            i = j
            continue
        prefix = ""
        if c in "r&^" and i + 1 < n and src[i + 1] in "\"'":
            prefix, i = c, i + 1
            c = src[i]
        if c in "\"'":
            start_line = line
            raw = prefix == "r"
            quote = src[i:i + 3] if src[i:i + 3] in ('"""', "'''") else c
            i += len(quote)
            out = []
            while True:
                if i >= n:
                    raise TokenizeError(f"unterminated string from line {start_line}")
                if src.startswith(quote, i):
                    i += len(quote)
                    break
                ch = src[i]
                if ch == "\n":
                    if len(quote) == 1:
                        raise TokenizeError(f"line break inside a string at line {line}")
                    line += 1
                if ch == "\\" and i + 1 < n:
                    nxt = src[i + 1]
                    if raw:
                        out.append(ch + nxt if nxt != quote[0] else nxt)
                        i += 2
                        continue
                    if nxt in _ESC:
                        out.append(_ESC[nxt])
                        i += 2
                        continue
                    if nxt == "u" or nxt == "U":
                        width = 4 if nxt == "u" else 6
                        out.append(chr(int(src[i + 2:i + 2 + width], 16)))
                        i += 2 + width
                        continue
                    if nxt == "\n":
                        line += 1
                        i += 2
                        continue
                    out.append(nxt)
                    i += 2
                    continue
                out.append(ch)
                i += 1
            toks.append(Tok("str" if prefix in ("", "r") else "name", "".join(out), start_line, line))
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            toks.append(Tok("id", src[i:j], line, line))
            i = j
            continue
        if c.isdigit():
            j = i
            while j < n and (src[j].isalnum() or src[j] in "._"):
                j += 1
            toks.append(Tok("num", src[i:j], line, line))
            i = j
            continue
        toks.append(Tok("op", c, line, line))
        i += 1
    return toks


# ---------------------------------------------------------------------------------------------------------
# Entries

@dataclass
class Entry:
    ctx: str
    msgid: str
    plural: str | None = None
    msgstr: list[str] = field(default_factory=lambda: [""])
    comments: list[str] = field(default_factory=list)   # "#." extracted (from the code)
    tcomments: list[str] = field(default_factory=list)  # "# " translator comments
    refs: list[str] = field(default_factory=list)       # "#:"
    flags: list[str] = field(default_factory=list)      # "#,"
    previous: list[str] = field(default_factory=list)   # "#|" raw lines
    max_px: int | None = None
    lines: int | None = None

    @property
    def fuzzy(self) -> bool:
        return "fuzzy" in self.flags

    def translated(self) -> bool:
        return not self.fuzzy and all(s != "" for s in self.msgstr)


@dataclass
class Problems:
    errors: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)

    def err(self, msg: str) -> None:
        self.errors.append(msg)


def _rel(path: str, root: str) -> str:
    return os.path.relpath(path, root).replace(os.sep, "/")


def script_files(root: str) -> list[str]:
    out = []
    for base, dirs, files in os.walk(os.path.join(root, "scripts")):
        dirs.sort()
        for f in sorted(files):
            if f.endswith(".gd"):
                out.append(os.path.join(base, f))
    return sorted(out, key=lambda p: _rel(p, root))


def _hint_text(comment: str) -> str | None:
    m = re.match(r"#+\s*i18n\s*:\s*(.*)$", comment.strip())
    return m.group(1).strip() if m else None


def _split_args(toks: list[Tok], open_idx: int) -> tuple[list[list[Tok]], int]:
    """Arguments of the call whose "(" is at open_idx: token lists split at top-level commas, and the index of
    the closing ")"."""
    args: list[list[Tok]] = [[]]
    depth = 0
    i = open_idx
    while i < len(toks):
        t = toks[i]
        if t.kind == "op" and t.value in "([{":
            depth += 1
            if depth > 1:
                args[-1].append(t)
        elif t.kind == "op" and t.value in ")]}":
            depth -= 1
            if depth == 0:
                return ([a for a in args if a] if any(args) else []), i
            args[-1].append(t)
        elif t.kind == "op" and t.value == "," and depth == 1:
            args.append([])
        elif t.kind != "comment" and i != open_idx:
            args[-1].append(t)
        i += 1
    raise TokenizeError(f"unclosed call at line {toks[open_idx].line}")


def _dict_keys(arg: list[Tok]) -> set[str] | None:
    """Keys of a literal dictionary argument ({level = n, "total": t}), or None if it is not a literal."""
    if not arg or arg[0].kind != "op" or arg[0].value != "{" or arg[-1].value != "}":
        return None
    keys: set[str] = set()
    depth = 0
    expect_key = True
    for k, t in enumerate(arg):
        if t.kind == "op" and t.value in "([{":
            depth += 1
            if depth == 1:
                expect_key = True
            continue
        if t.kind == "op" and t.value in ")]}":
            depth -= 1
            continue
        if depth == 1 and t.kind == "op" and t.value == ",":
            expect_key = True
            continue
        if depth == 1 and expect_key:
            nxt = arg[k + 1] if k + 1 < len(arg) else None
            if t.kind in ("id", "str") and nxt is not None and nxt.kind == "op" and nxt.value in "=:":
                keys.add(t.value)
            expect_key = False
    return keys


def extract(root: str, probs: Problems) -> tuple[dict[str, Entry], list[tuple[str, int, str]]]:
    """Every Loc call -> entries by ctx (in file / line order). Also returns the literals outside Loc calls
    (file, line, text) for the completeness scan."""
    entries: dict[str, Entry] = {}
    loose: list[tuple[str, int, str]] = []
    for path in script_files(root):
        rel = _rel(path, root)
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        try:
            toks = tokenize(src)
        except TokenizeError as e:
            probs.err(f"{rel}: {e}")
            continue
        code_lines = sorted({t.line for t in toks if t.kind != "comment"})
        hints_on: dict[int, list[str]] = {}
        comment_only: dict[int, str] = {}
        for t in toks:
            if t.kind == "comment":
                h = _hint_text(t.value)
                if h is not None:
                    hints_on.setdefault(t.line, []).append(h)
        for t in toks:
            if t.kind == "comment" and t.line not in code_lines:
                comment_only[t.line] = t.value

        def hints_above(line: int) -> list[str]:
            out: list[str] = []
            ln = line - 1
            while ln in comment_only:
                h = _hint_text(comment_only[ln])
                if h is not None:
                    out.insert(0, h)
                ln -= 1
            return out

        def ignored(line: int) -> bool:
            for h in hints_on.get(line, []) + hints_above(line):
                if h.lower().startswith("ignore"):
                    return True
            return False

        in_call: set[int] = set()
        i = 0
        while i < len(toks):
            t = toks[i]
            if (t.kind == "id" and t.value == "Loc" and i + 3 < len(toks) and toks[i + 1].value == "."
                    and toks[i + 2].kind == "id" and toks[i + 2].value in ("t", "n")
                    and toks[i + 3].value == "("):
                fn = toks[i + 2].value
                where = f"{rel}:{t.line}"
                try:
                    args, close = _split_args(toks, i + 3)
                except TokenizeError as e:
                    probs.err(f"{rel}: {e}")
                    break
                nlit = 2 if fn == "t" else 3
                lits: list[str] = []
                for a in args[:nlit]:
                    if len(a) == 1 and a[0].kind == "str":
                        lits.append(a[0].value)
                        in_call.add(id(a[0]))
                if len(lits) < nlit:
                    probs.err(f"{where}: Loc.{fn} needs {nlit} plain string literals first (key, English text"
                              f"{', plural' if fn == 'n' else ''})")
                    i = close + 1
                    continue
                ctx, msgid = lits[0], lits[1]
                plural = lits[2] if fn == "n" else None
                if fn == "n" and len(args) < 4:
                    probs.err(f"{where}: Loc.n needs a count")
                args_idx = 2 if fn == "t" else 4
                keys = _dict_keys(args[args_idx]) if len(args) > args_idx else set()
                _check_call(where, ctx, msgid, plural, keys, fn, probs)
                hints = hints_above(t.line)
                for ln in range(t.line, toks[close].end_line + 1):
                    hints += [h for h in hints_on.get(ln, []) if h not in hints]
                hints = [h for h in hints if not h.lower().startswith("ignore")]
                _add(entries, Entry(ctx, msgid, plural, [""] if plural is None else ["", ""],
                                    comments=hints, refs=[rel]), where, probs)
                i += 4
                continue
            if t.kind == "str" and id(t) not in in_call:
                loose.append((rel, t.line, t.value) if not ignored(t.line) else (rel, -1, ""))
            i += 1
        # Literals on dev-call lines are dev text.
        dev_lines = set()
        for ln, text in enumerate(src.split("\n"), 1):
            if DEV_CALLS.search(text):
                dev_lines.add(ln)
        loose = [x for x in loose if not (x[0] == rel and x[1] in dev_lines)]
    for e in entries.values():
        _budgets(e)
    extract_web(root, entries, probs)
    return entries, [x for x in loose if x[1] > 0]


WEB_SHELL = "tools/web_shell.html"
WEB_SRC_RE = re.compile(r"^\s*'(web\.[a-z0-9_.]+)':\s*'((?:[^'\\]|\\.)*)',?\s*$")
JS_ESC = re.compile(r"\\(.)")


def _js_unescape(s: str) -> str:
    return JS_ESC.sub(lambda m: "\n" if m.group(1) == "n" else m.group(1), s)


def extract_web(root: str, entries: dict[str, Entry], probs: Problems) -> None:
    """The web shell's strings: lines between `// i18n-source:begin` and `// i18n-source:end` in
    tools/web_shell.html, each with the `// i18n:` comment lines right above it."""
    path = os.path.join(root, WEB_SHELL)
    if not os.path.exists(path):
        return
    with open(path, encoding="utf-8") as fh:
        lines = fh.read().split("\n")
    inside = False
    hints: list[str] = []
    for n, line in enumerate(lines, 1):
        t = line.strip()
        if t == "// i18n-source:begin":
            inside = True
            continue
        if t == "// i18n-source:end":
            inside = False
            continue
        if not inside:
            continue
        if t.startswith("// i18n:"):
            hints.append(_js_unescape(t[len("// i18n:"):].strip()))
            continue
        m = WEB_SRC_RE.match(line)
        if not m:
            if t:
                probs.err(f"{WEB_SHELL}:{n}: not a `'web.key': 'text',` line inside the i18n-source block")
            hints = []
            continue
        ctx, msgid = m.group(1), _js_unescape(m.group(2))
        where = f"{WEB_SHELL}:{n}"
        _check_call(where, ctx, msgid, None, None, "t", probs)
        _add(entries, Entry(ctx, msgid, None, [""], comments=hints, refs=[WEB_SHELL]), where, probs)
        e = entries[ctx]
        _budgets(e)
        hints = []


def web_table(entries: dict[str, Entry], locale_dir: str, with_en: bool, fallback: bool) -> dict[str, dict[str, str]]:
    table: dict[str, dict[str, str]] = {}
    if with_en:
        table["en"] = {e.ctx: e.msgid for e in entries.values() if e.ctx.startswith("web.")}
    for code in LOCALES:
        path = os.path.join(locale_dir, f"{code}.po")
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as fh:
            po = parse_po(fh.read(), path)
        row = {e.ctx: (e.msgstr[0] if e.translated() else e.msgid)
               for e in po.entries if e.ctx.startswith("web.") and (fallback or e.translated())}
        if row:
            table[code] = row
    return table


TABLE_BEGIN, TABLE_END = "// i18n-table:begin", "// i18n-table:end"


def embed_web(root: str, entries: dict[str, Entry]) -> tuple[str, str] | None:
    """(current html, html with the I18N_TABLE block regenerated), or None without a web shell."""
    path = os.path.join(root, WEB_SHELL)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as fh:
        html = fh.read()
    a, b = html.find(TABLE_BEGIN), html.find(TABLE_END)
    if a < 0 or b < a:
        return html, html
    table = web_table(entries, os.path.join(root, "locale"), with_en=False, fallback=False)
    js = json.dumps(table, ensure_ascii=False, sort_keys=True, indent=1)
    js = js.replace("\u2028", "\\u2028").replace("\u2029", "\\u2029").replace("</", "<\\/")
    block = f"{TABLE_BEGIN}\nconst I18N_TABLE = {js};\n"
    return html, html[:a] + block + html[b:]


def check_web(root: str, entries: dict[str, Entry], probs: Problems) -> None:
    got = embed_web(root, entries)
    if got is None:
        return
    html, fresh = got
    if TABLE_BEGIN not in html or TABLE_END not in html:
        probs.err(f"{WEB_SHELL}: the i18n-table:begin / end markers are missing")
        return
    if html != fresh:
        probs.err(f"{WEB_SHELL}: the embedded I18N_TABLE is out of date (run tools/i18n_extract.py --merge)")
    m = re.search(r"^const LANGUAGES_ENABLED = (true|false);", html, re.M)
    eco = os.path.join(root, "scripts", "economy.gd")
    if not m:
        probs.err(f"{WEB_SHELL}: `const LANGUAGES_ENABLED = true|false;` is missing")
    elif os.path.exists(eco):
        with open(eco, encoding="utf-8") as fh:
            g = re.search(r"^const LANGUAGES_TEST\s*:?=\s*(true|false)", fh.read(), re.M)
        if not g:
            probs.err("scripts/economy.gd: `const LANGUAGES_TEST := true|false` not found")
        elif g.group(1) != m.group(1):
            probs.err(f"{WEB_SHELL}: LANGUAGES_ENABLED = {m.group(1)} but Economy.LANGUAGES_TEST = {g.group(1)} "
                      f"(they must flip together)")


def _check_call(where: str, ctx: str, msgid: str, plural: str | None, keys: set[str] | None, fn: str,
                probs: Problems) -> None:
    if not re.fullmatch(r"[a-z0-9_]+(\.[a-z0-9_]+)+", ctx):
        probs.err(f"{where}: key {ctx!r} is not area.thing[.variant] (lowercase, dots)")
    for text in [msgid] + ([plural] if plural is not None else []):
        if text.strip() == "":
            probs.err(f"{where}: empty English text for {ctx}")
        if PRINTF.search(text):
            probs.err(f"{where}: printf format in {text!r} ({ctx}); use named placeholders like {{count}}")
        if unicodedata.normalize("NFC", text) != text:
            probs.err(f"{where}: {ctx} English text is not NFC")
    names = set(PLACEHOLDER.findall(msgid)) | (set(PLACEHOLDER.findall(plural)) if plural else set())
    if plural is not None and "count" not in names:
        pass  # a plural may leave the number out ("{count}" is filled anyway)
    if keys is not None:
        filled = set(keys) | ({"count"} if fn == "n" else set())
        missing = names - filled
        if missing:
            probs.err(f"{where}: {ctx} placeholders {sorted(missing)} are not in the args dict")


def _add(entries: dict[str, Entry], e: Entry, where: str, probs: Problems) -> None:
    old = entries.get(e.ctx)
    if old is None:
        entries[e.ctx] = e
        return
    if old.msgid != e.msgid or old.plural != e.plural:
        probs.err(f"{where}: key {e.ctx} already used for {old.msgid!r}"
                  f"{' / ' + repr(old.plural) if old.plural else ''} ({', '.join(old.refs)}); "
                  f"one key = one English text")
        return
    for c in e.comments:
        if c not in old.comments:
            old.comments.append(c)
    for r in e.refs:
        if r not in old.refs:
            old.refs.append(r)


def _budgets(e: Entry) -> None:
    for c in e.comments:
        m = BUDGET_MAX.search(c)
        if m:
            v = int(m.group(1))
            e.max_px = v if e.max_px is None else min(e.max_px, v)
        m = BUDGET_LINES.search(c)
        if m:
            v = int(m.group(1) or m.group(2))
            e.lines = v if e.lines is None else min(e.lines, v)


def budget_line(e: Entry) -> str | None:
    parts = []
    if e.max_px is not None:
        parts.append(f"max {e.max_px}px")
    if e.lines is not None:
        parts.append(f"lines {e.lines}")
    return "budget: " + ", ".join(parts) if parts else None


# ---------------------------------------------------------------------------------------------------------
# PO reading / writing

def _po_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\n", "\\n") + '"'


def _po_field(name: str, s: str, prefix: str = "") -> list[str]:
    if "\n" in s:
        parts = s.split("\n")
        chunks = [p + "\n" for p in parts[:-1]] + ([parts[-1]] if parts[-1] else [])
        return [f"{prefix}{name} \"\""] + [prefix + _po_quote(c) for c in chunks]
    return [f"{prefix}{name} {_po_quote(s)}"]


def _po_unquote(s: str) -> str:
    s = s.strip()
    if len(s) < 2 or s[0] != '"' or s[-1] != '"':
        raise ValueError(f"bad PO string {s!r}")
    out, i = [], 1
    while i < len(s) - 1:
        c = s[i]
        if c == "\\" and i + 1 < len(s) - 1:
            nxt = s[i + 1]
            out.append({"n": "\n", "t": "\t", "r": "\r", '"': '"', "\\": "\\"}.get(nxt, nxt))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def entry_lines(e: Entry, template: bool, obsolete: bool = False) -> list[str]:
    out: list[str] = []
    pre = "#~ " if obsolete else ""
    out += [f"# {c}" if c else "#" for c in e.tcomments]
    if not obsolete:
        out += [f"#. {c}" for c in e.comments]
        b = budget_line(e)
        if b and f"#. {b}" not in out:
            out.append(f"#. {b}")
        if e.refs:
            out.append("#: " + " ".join(e.refs))
        if e.flags:
            out.append("#, " + ", ".join(e.flags))
        out += e.previous
    out += _po_field("msgctxt", e.ctx, pre)
    out += _po_field("msgid", e.msgid, pre)
    if e.plural is not None:
        out += _po_field("msgid_plural", e.plural, pre)
        forms = [""] * 2 if template else e.msgstr
        for k, s in enumerate(forms):
            out += _po_field(f"msgstr[{k}]", "" if template else s, pre)
    else:
        out += _po_field("msgstr", "" if template else e.msgstr[0], pre)
    return out


@dataclass
class PoFile:
    header_comments: list[str]
    header: str
    entries: list[Entry]
    obsolete: list[Entry]


def parse_po(text: str, where: str) -> PoFile:
    blocks: list[list[str]] = [[]]
    for raw in text.split("\n"):
        line = raw.rstrip("\r")
        if line.strip() == "":
            if blocks[-1]:
                blocks.append([])
            continue
        blocks[-1].append(line)
    blocks = [b for b in blocks if b]
    header_comments: list[str] = []
    header = ""
    entries: list[Entry] = []
    obsolete: list[Entry] = []
    for bi, b in enumerate(blocks):
        is_obsolete = any(l.startswith("#~") for l in b) and not any(
            l.startswith(("msgid", "msgctxt", "msgstr")) for l in b)
        e = Entry("", "", None, [])
        cur: str | None = None
        has_id = False
        for line in b:
            if is_obsolete and line.startswith("#~"):
                line = line[2:].lstrip(" ")
                if line.startswith("|"):
                    continue
            if line.startswith("#."):
                e.comments.append(line[2:].strip())
                continue
            if line.startswith("#:"):
                e.refs += line[2:].split()
                continue
            if line.startswith("#,"):
                e.flags += [f.strip() for f in line[2:].split(",") if f.strip()]
                continue
            if line.startswith("#|"):
                e.previous.append(line)
                continue
            if line.startswith("#"):
                e.tcomments.append(line[1:].lstrip(" ") if len(line) > 1 else "")
                continue
            m = re.match(r"^(msgctxt|msgid_plural|msgid|msgstr(?:\[(\d+)\])?)\s+(\".*\")\s*$", line)
            if m:
                key, idx, val = m.group(1), m.group(2), _po_unquote(m.group(3))
                if key == "msgctxt":
                    e.ctx = val
                    cur = "ctx"
                elif key == "msgid":
                    e.msgid, has_id = val, True
                    cur = "id"
                elif key == "msgid_plural":
                    e.plural = val
                    cur = "plural"
                else:
                    k = int(idx) if idx is not None else 0
                    while len(e.msgstr) <= k:
                        e.msgstr.append("")
                    e.msgstr[k] = val
                    cur = f"str{k}"
                continue
            if line.startswith('"'):
                val = _po_unquote(line)
                if cur == "ctx":
                    e.ctx += val
                elif cur == "id":
                    e.msgid += val
                elif cur == "plural":
                    e.plural = (e.plural or "") + val
                elif cur and cur.startswith("str"):
                    e.msgstr[int(cur[3:])] += val
                else:
                    raise ValueError(f"{where}: stray string line {line!r}")
                continue
            raise ValueError(f"{where}: cannot read line {line!r}")
        if not has_id:
            if e.tcomments and not entries and not header:
                header_comments = e.tcomments
                continue
            raise ValueError(f"{where}: block {bi + 1} has no msgid")
        if e.msgid == "" and e.ctx == "" and not entries and not header:
            header = e.msgstr[0] if e.msgstr else ""
            header_comments = e.tcomments
            continue
        if not e.msgstr:
            e.msgstr = [""]
        _budgets(e)
        (obsolete if is_obsolete else entries).append(e)
    return PoFile(header_comments, header, entries, obsolete)


def header_fields(header: str) -> dict[str, str]:
    out = {}
    for line in header.split("\n"):
        if ":" in line:
            k, v = line.split(":", 1)
            out[k.strip()] = v.strip()
    return out


def plural_forms(code: str) -> str:
    _, n, expr, _ = PLURALS[code]
    return f"nplurals={n}; plural={expr};"


def locale_header(code: str) -> str:
    return ("Project-Id-Version: Slime Time\n"
            f"Language: {code}\n"
            "MIME-Version: 1.0\n"
            "Content-Type: text/plain; charset=UTF-8\n"
            "Content-Transfer-Encoding: 8bit\n"
            f"Plural-Forms: {plural_forms(code)}\n")


def write_po(header_comments: list[str], header: str, entries: list[Entry], obsolete: list[Entry],
             template: bool) -> str:
    out = [f"# {c}" if c else "#" for c in header_comments]
    out += ['msgid ""', 'msgstr ""'] + [_po_quote(l + "\n") for l in header.rstrip("\n").split("\n") if l]
    for e in entries:
        out.append("")
        out += entry_lines(e, template)
    for e in obsolete:
        out.append("")
        out += entry_lines(e, False, obsolete=True)
    return "\n".join(out) + "\n"


POT_HEADER_COMMENTS = [
    "Slime Time translation template. GENERATED by tools/i18n_extract.py from the Loc.t / Loc.n calls in",
    "scripts/: never edit by hand. Translators edit locale/<code>.po (see docs/i18n/style-guide.md).",
]
POT_HEADER = ("Project-Id-Version: Slime Time\n"
              "MIME-Version: 1.0\n"
              "Content-Type: text/plain; charset=UTF-8\n"
              "Content-Transfer-Encoding: 8bit\n"
              "Plural-Forms: nplurals=2; plural=(n != 1);\n")


def locale_comments(code: str) -> list[str]:
    return [f"Slime Time, {PLURALS[code][0]} ({code}). Fill in the msgstr lines; never edit msgctxt / msgid.",
            "Rules: docs/i18n/style-guide.md. After code changes: python3 tools/i18n_extract.py --merge"]


def build_pot(entries: dict[str, Entry]) -> str:
    return write_po(POT_HEADER_COMMENTS, POT_HEADER, list(entries.values()), [], template=True)


def merge(template: dict[str, Entry], code: str, old: PoFile | None) -> str:
    nplurals = PLURALS[code][1]
    by_ctx = {e.ctx: e for e in old.entries} if old else {}
    obs_by_ctx = {e.ctx: e for e in old.obsolete} if old else {}
    out_entries: list[Entry] = []
    for t in template.values():
        prev = by_ctx.pop(t.ctx, None)
        if prev is None and t.ctx in obs_by_ctx and obs_by_ctx[t.ctx].msgid == t.msgid:
            prev = obs_by_ctx.pop(t.ctx)
        e = Entry(t.ctx, t.msgid, t.plural, comments=list(t.comments), refs=list(t.refs),
                  max_px=t.max_px, lines=t.lines)
        forms = nplurals if t.plural is not None else 1
        e.msgstr = [""] * forms
        if prev is not None:
            e.tcomments = prev.tcomments
            old_strs = prev.msgstr if prev.msgstr else [""]
            if prev.plural is None and t.plural is not None:
                old_strs = old_strs[:1] * forms
            for k in range(forms):
                e.msgstr[k] = old_strs[k] if k < len(old_strs) else ""
            same = prev.msgid == t.msgid and prev.plural == t.plural
            had = any(s for s in e.msgstr)
            if not same and had:
                e.flags = ["fuzzy"]
                e.previous = ["#| msgid " + _po_quote(prev.msgid)]
                if prev.plural is not None:
                    e.previous.append("#| msgid_plural " + _po_quote(prev.plural))
            elif same and prev.fuzzy and had:
                e.flags = ["fuzzy"]
                e.previous = prev.previous
        out_entries.append(e)
    obsolete = [e for e in list(by_ctx.values()) + list(obs_by_ctx.values()) if any(s for s in e.msgstr)]
    for e in obsolete:
        e.comments, e.refs, e.flags, e.previous = [], [], [], []
    header = old.header if old and old.header else locale_header(code)
    fields = header_fields(header)
    if "Language" not in fields or "Plural-Forms" not in fields:
        header = locale_header(code)
    comments = old.header_comments if old and old.header_comments else locale_comments(code)
    return write_po(comments, header, out_entries, obsolete, template=False)


# ---------------------------------------------------------------------------------------------------------
# Checks

def _placeholders(s: str) -> set[str]:
    return set(PLACEHOLDER.findall(s))


def _single_n_forms(code: str) -> set[int]:
    """Plural forms that cover exactly one n (they may leave {count} out: Arabic "one" / "two")."""
    rule = PLURALS[code][3]
    seen: dict[int, list[int]] = {}
    for n in range(0, 2000):
        seen.setdefault(rule(n), []).append(n)  # type: ignore[operator]
    return {k for k, ns in seen.items() if len(ns) == 1}


def check_po(code: str, path: str, template: dict[str, Entry], probs: Problems, partial: bool) -> None:
    rel = f"locale/{code}.po"
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    try:
        po = parse_po(text, rel)
    except ValueError as e:
        probs.err(str(e))
        return
    fields = header_fields(po.header)
    if fields.get("Language") != code:
        probs.err(f"{rel}: header Language is {fields.get('Language')!r}, expected {code!r}")
    if fields.get("Plural-Forms") != plural_forms(code):
        probs.err(f"{rel}: header Plural-Forms is {fields.get('Plural-Forms')!r}, expected {plural_forms(code)!r}")
    canonical = write_po(po.header_comments, po.header, po.entries, po.obsolete, template=False)
    merged = merge(template, code, po)
    # --partial (English-only mode, tests/i18n_mode.gd): English changed since the last --merge. New, changed or gone
    # entries make this .po "behind" the template; that is a note then, any other difference stays an error.
    behind = partial and (
        any(e.ctx not in template or e.msgid != template[e.ctx].msgid or e.plural != template[e.ctx].plural
            for e in po.entries)
        or any(c not in {e.ctx for e in po.entries} for c in template))
    if canonical != merged and behind:
        probs.notes.append(f"{rel}: behind messages.pot (new / changed / removed English entries; "
                           f"run tools/i18n_extract.py --merge, then translate)")
    elif canonical != merged:  # same content as a fresh merge (string line wrapping may differ)
        a_lines, b_lines = canonical.split("\n"), merged.split("\n")
        k = next((i for i, (x, y) in enumerate(zip(a_lines, b_lines)) if x != y), min(len(a_lines), len(b_lines)))
        got = a_lines[k] if k < len(a_lines) else "(end)"
        want = b_lines[k] if k < len(b_lines) else "(end)"
        probs.err(f"{rel}: has {got!r} where the merged file has {want!r}")
        probs.err(f"{rel}: not in merged form: out of date with messages.pot or hand-reordered "
                  f"(run tools/i18n_extract.py --merge, it keeps every translation)")
    nplurals = PLURALS[code][1]
    single = _single_n_forms(code)
    missing = 0
    fuzzy = 0
    for e in po.entries:
        t = template.get(e.ctx)
        where = f"{rel} [{e.ctx}]"
        if t is None:
            continue  # reported by the merge comparison
        # --partial: a stale entry (English changed: fuzzy, or another msgid than the template) has its text problems
        # as notes; the game shows English there until the translator has been through it.
        stale = partial and (e.fuzzy or e.msgid != t.msgid or e.plural != t.plural)
        err = probs.notes.append if stale else probs.err
        if e.plural is not None and len(e.msgstr) != nplurals:
            err(f"{where}: {len(e.msgstr)} plural forms, {code} has {nplurals}")
        if e.fuzzy:
            fuzzy += 1
        if not e.translated():
            missing += 1
        notes = " ".join(t.comments).lower()
        want = _placeholders(t.msgid) | (_placeholders(t.plural) if t.plural else set())
        for k, s in enumerate(e.msgstr):
            if s == "":
                continue
            got = _placeholders(s)
            need = want - ({"count"} if t.plural is not None and k in single else set())
            if not (need <= got <= want):
                err(f"{where}: placeholders {sorted(got)} in {s!r}, English has {sorted(want)}")
            if PRINTF.search(s) and not PRINTF.search(t.msgid):
                err(f"{where}: printf format in {s!r}")
            if unicodedata.normalize("NFC", s) != s:
                err(f"{where}: not NFC normalized: {s!r} (write precomposed letters)")
            if t.lines is not None and s.count("\n") + 1 > t.lines:
                err(f"{where}: {s.count(chr(10)) + 1} lines, budget {t.lines}")
            if s.strip() != s and t.msgid.strip() == t.msgid:
                err(f"{where}: leading / trailing spaces in {s!r} (the English has none)")
            bare = PLACEHOLDER.sub("", s)
            if code in CASED and "mixed case" not in notes:
                lower = [ch for ch in bare if ch.isalpha() and ch != ch.upper() and ch not in "ß"]
                if lower or "ß" in bare:
                    err(f"{where}: lowercase letters in {s!r}: the game is ALL CAPS"
                              f"{' (German: SS or ẞ for ß)' if 'ß' in bare else ''}")
            if code == "tr":
                if "\u0307" in s:
                    err(f"{where}: combining dot U+0307 in {s!r} (wrong casing: use İ U+0130)")
                if "mixed case" not in notes and re.search(r"[A-ZÇĞİÖŞÜ][iı]|[iı][A-ZÇĞİÖŞÜ]", bare):
                    err(f"{where}: lowercase i / ı inside a capital word in {s!r} (use İ / I)")
            if code == "th" and re.search(r"[\u0E00-\u0E7F]{16,}", bare):
                probs.notes.append(f"{where}: long Thai run without U+200B / space (it cannot wrap there)")
    if missing:
        msg = f"{rel}: {missing} of {len(po.entries)} entries untranslated ({fuzzy} fuzzy)"
        (probs.notes.append if partial else probs.err)(msg)


def looks_player_visible(text: str) -> bool:
    s = text.strip()
    if len(s) < 2:
        return False
    if re.search(r"(res|user|uid)://|\.(gd|tscn|tres|png|ogg|wav|cfg|json|po|fnt|shader)\b", s):
        return False
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", s) and re.search(r"[a-z]", s):
        return False  # identifiers, node names, CamelCase
    if re.fullmatch(r"[A-Z0-9_]+", s) and "_" in s:
        return False  # CONSTANT_IDS
    if re.fullmatch(r"[.\w#@*+\-]+", s) and len(set(s)) <= 8 and "." in s:
        return False  # sprite rows ("..kHlk..")
    if re.search(r"[A-Z]{2,}", s):
        return True
    if re.fullmatch(r"[A-Z][a-z']+(?: [A-Za-z',.!?:-]+){2,}", s):
        return True  # a capitalized sentence (browser prompts)
    return False


def code_scan(root: str, loose: list[tuple[str, int, str]], probs: Problems) -> None:
    dev_lines = {(rel, line) for rel, line, text in loose if text in ALLOW.get(rel, set())}
    for rel, line, text in loose:
        if rel.startswith(DEV_FILES) or (rel, line) in dev_lines:
            continue
        if looks_player_visible(text):
            probs.err(f"{rel}:{line}: English text outside Loc: {text!r} "
                      f"(wrap it in Loc.t, or add `# i18n: ignore` if it must stay English)")


# ---------------------------------------------------------------------------------------------------------

def pending(entries: dict[str, Entry], locale_dir: str, pot: str, pot_path: str) -> int:
    """--pending: per locale, the entries the catch-up session must translate: new (missing from the .po or
    empty), fuzzy / changed English (old translation kept), and gone (obsolete, only counted). Changes nothing."""
    total = 0
    for code in LOCALES:
        path = os.path.join(locale_dir, f"{code}.po")
        if not os.path.exists(path):
            print(f"{code}: no .po file")
            continue
        with open(path, encoding="utf-8") as fh:
            po = parse_po(fh.read(), path)
        have = {e.ctx: e for e in po.entries}
        rows = []
        for ctx, t in entries.items():
            e = have.get(ctx)
            if e is None:
                rows.append(("new", ctx, t.msgid))
            elif e.msgid != t.msgid or e.plural != t.plural or e.fuzzy:
                rows.append(("changed", ctx, t.msgid))
            elif not e.translated():
                rows.append(("untranslated", ctx, t.msgid))
        gone = [e.ctx for e in po.entries if e.ctx not in entries]
        total += len(rows)
        print(f"{code}: {len(rows)} pending" + (f", {len(gone)} gone from the code" if gone else ""))
        for kind, ctx, msgid in rows:
            print(f"  {kind:12} {ctx} | {msgid!r}")
    stale_pot = (not os.path.exists(pot_path)) or open(pot_path, encoding="utf-8").read() != pot
    if stale_pot:
        print("note: locale/messages.pot is out of date with the code (run tools/i18n_extract.py)")
    print(f"i18n pending: {total} entries over {len(LOCALES)} locales")
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=ROOT, help="project root (default: this repo)")
    ap.add_argument("--merge", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--partial", action="store_true")
    ap.add_argument("--no-code-scan", action="store_true")
    ap.add_argument("--pending", action="store_true")
    ap.add_argument("--web-json", action="store_true")
    ap.add_argument("--web-embed", action="store_true")
    ap.add_argument("--out", default="")
    ap.add_argument("--self-test", action="store_true", help="run the extractor's own tests in a temp folder")
    a = ap.parse_args(argv)
    if a.self_test:
        return self_test()
    root = os.path.abspath(a.root)
    locale_dir = os.path.join(root, "locale")
    pot_path = os.path.join(locale_dir, "messages.pot")
    probs = Problems()
    entries, loose = extract(root, probs)
    pot = build_pot(entries)

    if a.web_json:
        table = web_table(entries, locale_dir, with_en=True, fallback=True)
        text = json.dumps(table, ensure_ascii=False, sort_keys=True, indent=1) + "\n"
        if a.out:
            with open(a.out, "w", encoding="utf-8") as fh:
                fh.write(text)
        else:
            sys.stdout.write(text)
        return 0

    if a.pending:
        return pending(entries, locale_dir, pot, pot_path)

    if a.check:
        if not os.path.exists(pot_path):
            probs.err("locale/messages.pot is missing (run tools/i18n_extract.py)")
        else:
            with open(pot_path, encoding="utf-8") as fh:
                if fh.read() != pot:
                    probs.err("locale/messages.pot is out of date with the code (run tools/i18n_extract.py --merge)")
        for code in LOCALES:
            path = os.path.join(locale_dir, f"{code}.po")
            if not os.path.exists(path):
                probs.err(f"locale/{code}.po is missing (run tools/i18n_extract.py --merge)")
                continue
            check_po(code, path, entries, probs, a.partial)
        check_web(root, entries, probs)
        if not a.no_code_scan:
            code_scan(root, loose, probs)
        for n in probs.notes:
            print("note:", n)
        for e in probs.errors:
            print("error:", e)
        print(f"i18n check: {len(entries)} strings, {len(probs.errors)} errors, {len(probs.notes)} notes")
        return 1 if probs.errors else 0

    if probs.errors:
        for e in probs.errors:
            print("error:", e)
        print("nothing written")
        return 1
    os.makedirs(locale_dir, exist_ok=True)
    _write_if_changed(pot_path, pot)
    print(f"locale/messages.pot: {len(entries)} strings")
    if a.web_embed and not a.merge:
        _embed_to_file(root, entries)
    if a.merge:
        for code in LOCALES:
            path = os.path.join(locale_dir, f"{code}.po")
            old = None
            if os.path.exists(path):
                with open(path, encoding="utf-8") as fh:
                    old = parse_po(fh.read(), path)
            _write_if_changed(path, merge(entries, code, old))
        print(f"merged {len(LOCALES)} locales")
        _embed_to_file(root, entries)
    return 0


# ---------------------------------------------------------------------------------------------------------
# --self-test: the extractor on a throwaway project (never the real locale/ folder).

def self_test() -> int:
    import tempfile
    fails: list[str] = []

    def ok(cond: bool, label: str) -> None:
        print(("  ok   " if cond else "  FAIL ") + label)
        if not cond:
            fails.append(label)

    def run(root: str, *args: str) -> tuple[int, str]:
        import contextlib
        import io
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = main(["--root", root, *args])
        return code, buf.getvalue()

    def write(path: str, text: str) -> None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def read(path: str) -> str:
        with open(path, encoding="utf-8") as fh:
            return fh.read()

    with tempfile.TemporaryDirectory() as root:
        gd = os.path.join(root, "scripts", "a.gd")
        write(gd, '''extends Node
# i18n: hub portal button, max 112px, lines 1
var a := Loc.t("hub.portal.random_maze", "RANDOM MAZE")
var b := Loc.n("wheel.hats_left", "{count} HAT TO WIN",
	"{count} HATS TO WIN", 3)  # i18n: {count} = hats still on the wheel
var c := Loc.t("hud.level", "LEVEL {level}/{total}\\n2ND LINE", {level = 1, "total": 2})
var d := Loc.t("hub.portal.random_maze", "RANDOM MAZE")  # i18n: max 100
var e := "NOT WRAPPED"
var f := "DEV ONLY"  # i18n: ignore
var g := "node_name"
''')
        code, out = run(root, "--merge")
        ok(code == 0, "extract + merge on a fresh project")
        pot = read(os.path.join(root, "locale", "messages.pot"))
        ok(pot.count("msgctxt") == 3, "three keys (a repeated key is one entry)")
        ok("#. budget: max 100px, lines 1" in pot, "budget = smallest over the call sites")
        ok("#. {count} = hats still on the wheel" in pot, "trailing hint on a multi-line call")
        ok('"LEVEL {level}/{total}\\n"' in pot, "escaped line break, multi-line PO string")
        es_path = os.path.join(root, "locale", "es.po")
        ar = read(os.path.join(root, "locale", "ar.po"))
        ok("msgstr[5]" in ar and "nplurals=6" in ar and "Language: ar" in ar, "Arabic: 6 plural forms")
        ok(len([f for f in os.listdir(os.path.join(root, "locale")) if f.endswith(".po")]) == len(LOCALES),
           "one .po per locale")
        code, out = run(root, "--check", "--partial")
        ok(code == 1 and "NOT WRAPPED" in out and "DEV ONLY" not in out and "node_name" not in out,
           "code scan flags unwrapped English only")
        code, out = run(root, "--check", "--partial", "--no-code-scan")
        ok(code == 0, "--partial: untranslated is only a note")
        code, out = run(root, "--check", "--no-code-scan")
        ok(code == 1 and "untranslated" in out, "--check: untranslated is an error")
        # Translate es, then change the code.
        es = read(es_path)
        es = es.replace('msgid "RANDOM MAZE"\nmsgstr ""', 'msgid "RANDOM MAZE"\nmsgstr "LABERINTO AL AZAR"')
        es = es.replace('msgstr[0] ""\nmsgstr[1] ""', 'msgstr[0] "QUEDA {count} SOMBRERO"\nmsgstr[1] "QUEDAN {count} SOMBREROS"')
        es = es.replace('#: scripts/a.gd\nmsgctxt "hud.level"', '# translator note\n#: scripts/a.gd\nmsgctxt "hud.level"')
        es = es.replace('"LEVEL {level}/{total}\\n"\n"2ND LINE"\nmsgstr ""',
                        '"LEVEL {level}/{total}\\n"\n"2ND LINE"\nmsgstr "NIVEL {level}/{totl}"')
        write(es_path, es)
        code, out = run(root, "--check", "--no-code-scan")
        ok(code == 1 and "placeholders" in out, "placeholder mismatch is an error")
        write(es_path, es.replace("{totl}", "{total}\\nOTRA"))
        code, out = run(root, "--check", "--partial", "--no-code-scan")
        ok(code == 0 and "es.po" not in out, "a complete, matching es passes" + ("" if code == 0 and "es.po" not in out else ": " + out))
        write(gd, read(gd).replace('"RANDOM MAZE")', '"RANDOM MAZES")').replace(
            'var c := Loc.t("hud.level"', 'var c := Loc.t("hud.level2"'))
        code, out = run(root, "--merge")
        ok(code == 0, "merge after a code change")
        es2 = read(es_path)
        ok("#, fuzzy" in es2 and '#| msgid "RANDOM MAZE"' in es2, "changed English text: old translation kept, fuzzy")
        ok("QUEDAN {count} SOMBREROS" in es2, "unchanged entries keep their translation")
        ok('#~ msgctxt "hud.level"' in es2 and "# translator note" in es2, "removed key: obsolete, comments kept")
        ok('msgctxt "hud.level2"' in es2, "new key added")
        write(gd, read(gd).replace("hud.level2", "hud.level").replace('"RANDOM MAZES")', '"RANDOM MAZE")'))
        run(root, "--merge")
        es3 = read(es_path)
        ok("NIVEL {level}/{total}" in es3 and "#~ msgctxt" not in es3, "a returning key revives its translation")
        code, out = run(root, "--merge")
        ok(read(es_path) == es3, "merge is idempotent")
        # English-only mode: English changed, nothing merged yet. The .pot (regenerated) is the only thing that must be current.
        gd_before = read(gd)
        write(gd, gd_before.replace('"RANDOM MAZE")', '"RANDOM MAZES (NEW)")'))
        code, out = run(root, "--check", "--partial", "--no-code-scan")
        ok(code == 1 and "messages.pot is out of date" in out, "--partial: the .pot must still be current")
        run(root)  # rewrites only messages.pot
        code, out = run(root, "--check", "--partial", "--no-code-scan")
        ok(code == 0 and "behind messages.pot" in out, "--partial: a .po behind the template is a note")
        code, out = run(root, "--check", "--no-code-scan")
        ok(code == 1 and "not in merged form" in out, "strict --check: a .po behind the template is an error")
        write(gd, gd_before)
        run(root, "--merge")
        # Content checks.
        def try_es(old: str, new: str) -> str:
            write(es_path, es3.replace(old, new))
            return run(root, "--check", "--partial", "--no-code-scan")[1]
        ok("NFC" in try_es("QUEDA {count}", "QUEDA\u0301 {count}"), "NFC check")
        ok("lowercase" in try_es("QUEDA {count}", "queda {count}"), "ALL CAPS check")
        ok("lines" in try_es("LABERINTO AL AZAR", "LABERINTO\\nAL AZAR"), "line budget check")
        ok("printf" in try_es("QUEDA {count}", "QUEDA %d {count}"), "printf check")
        write(es_path, es3)
        tr_path = os.path.join(root, "locale", "tr.po")
        tr = read(tr_path)
        write(tr_path, tr.replace('msgid "RANDOM MAZE"\nmsgstr ""', 'msgid "RANDOM MAZE"\nmsgstr "RASTGELE LABiRENT"'))
        ok("i / ı" in run(root, "--check", "--partial", "--no-code-scan")[1], "Turkish dotted / dotless i check")
        write(tr_path, tr.replace('msgid "RANDOM MAZE"\nmsgstr ""', 'msgid "RANDOM MAZE"\nmsgstr "RASTGELE LAB\u0130RENT"'))
        code, out = run(root, "--check", "--partial", "--no-code-scan")
        ok(code == 0, "Turkish İ passes" + ("" if code == 0 else ": " + out))
        write(tr_path, tr.replace("Language: tr", "Language: de"))
        ok("header Language" in run(root, "--check", "--partial", "--no-code-scan")[1], "header Language check")
        write(tr_path, tr)
        write(os.path.join(root, "scripts", "b.gd"), 'var x := Loc.t(key, "TEXT")\nvar y := Loc.t("a.b", "%d LEFT")\n'
              'var z := Loc.t("a.c", "{n} LEFT")\nvar w := Loc.t("hub.portal.random_maze", "OTHER")\n')
        code, out = run(root)
        ok(code == 1 and "plain string literals" in out and "printf" in out and "not in the args" in out
           and "already used" in out and "nothing written" in out, "bad call sites fail and write nothing")
        os.remove(os.path.join(root, "scripts", "b.gd"))
        write(os.path.join(root, "locale", "es.po"), es3.replace('msgstr "LABERINTO AL AZAR"', 'msgstr "LAB"'))
        code, out = run(root, "--web-json")
        ok(code == 0 and out.lstrip().startswith("{"), "--web-json writes a JSON table")
    print("SELF-TEST:", "PASS" if not fails else f"FAIL ({len(fails)})")
    return 1 if fails else 0


def _embed_to_file(root: str, entries: dict[str, Entry]) -> None:
    got = embed_web(root, entries)
    if got is not None and got[0] != got[1]:
        _write_if_changed(os.path.join(root, WEB_SHELL), got[1])
        print(f"{WEB_SHELL}: I18N_TABLE updated")


def _write_if_changed(path: str, text: str) -> None:
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            if fh.read() == text:
                return
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
