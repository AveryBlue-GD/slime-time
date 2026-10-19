#!/usr/bin/env python3
"""Self-test of tools/pck_check.py (the demo build's pack reader; docs/demo-plan.md section 8).

    python tools/test_pck_check.py        (tools/build_demo.sh / .ps1 run it first; prints RESULT: PASS)

Writes tiny synthetic Godot packs (formats 2, 3 and 4, standalone and embedded after a fake executable,
with and without a relative file base) into a temp folder and checks that read_pack lists them exactly,
that forbidden() catches every form of a cut file (the file, .import / .remap / .uid, .gdc, the imported
and the converted copy) and nothing else, that index_mentions() finds a cut path in the uid cache and the
class cache, and that the command line passes a clean pack and fails a leaking, encrypted or broken one.
"""
import contextlib
import io
import os
import struct
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pck_check  # noqa: E402

failures = 0


def check(ok, label):
    global failures
    print(("  ok   " if ok else "  FAIL ") + label)
    if not ok:
        failures += 1


def make_pack(files, fmt=4, rel_filebase=True, encrypted_dir=False, res_prefix=False):
    """A Godot pack with `files` ({res path: bytes}) laid out as file_access_pack.cpp reads it."""
    flags = (2 if rel_filebase else 0) | (1 if encrypted_dir else 0)
    header_size = 4 + 20 + 8 + (8 if fmt >= 3 else 0) + 16 * 4
    blobs = b""
    entries = []
    for name, content in files.items():
        entries.append((name, len(blobs), len(content)))
        blobs += content
    directory = struct.pack("<I", len(entries))
    for name, ofs, size in entries:
        stored = (name if res_prefix else name[len("res://"):]).encode("utf-8")
        stored += b"\0" * (4 - len(stored) % 4)
        directory += struct.pack("<I", len(stored)) + stored + struct.pack("<QQ", ofs, size) + b"\0" * 16 \
            + struct.pack("<I", 0)
    file_base = header_size if fmt >= 3 else header_size + len(directory)
    out = struct.pack("<I5IQ", pck_check.MAGIC, fmt, 4, 7, 2, flags, file_base)
    if fmt >= 3:
        out += struct.pack("<Q", header_size + len(blobs))  # the directory after the files
        out += b"\0" * 64
        out += blobs + directory
    else:
        out += b"\0" * 64
        out += directory + blobs
    return out


def embed(pack, stub=b"MZ fake executable " * 50):
    return stub + pack + struct.pack("<Q", len(pack)) + struct.pack("<I", pck_check.MAGIC)


BASE = {
    "res://project.binary": b"ECFG",
    "res://scripts/level_data/level_01.gd.remap": b"[remap]",
    "res://scripts/level_data/level_01.gdc": b"GDSC",
    "res://.godot/uid_cache.bin": b"\x01\x00res://scripts/level_data/level_01.gd\x00",
    "res://.godot/global_script_class_cache.cfg": b'list=[{"path": "res://scripts/demo.gd"}]',
}
CUT = ["res://scripts/level_data/level_04.gd", "res://assets/sprites/themes/sunken_walls.png",
       "res://assets/sprites/themes/sunken_walls.png.import", "res://scenes/victory.tscn", "res://locale/de.po"]


def run_cli(args):
    old = sys.argv
    sys.argv = ["pck_check.py"] + args
    out = io.StringIO()
    try:
        with contextlib.redirect_stdout(out):
            code = pck_check.main()
    finally:
        sys.argv = old
    return code, out.getvalue()


def main():
    tmp = tempfile.mkdtemp(prefix="pck_check_test_")
    cut_list = os.path.join(tmp, "cut.txt")
    with open(cut_list, "w", encoding="utf-8", newline="\n") as f:
        for path in CUT:
            f.write("desktop\t%s\n" % path)

    # read_pack: every format, standalone and embedded, relative or absolute file base, with or without res://.
    for fmt in (2, 3, 4):
        for embedded in (False, True):
            for rel in (True, False):
                if embedded and not rel:
                    continue  # an embedded pack always has a relative file base (Godot 4.x exports)
                for prefix in (False, True):
                    raw = make_pack(BASE, fmt, rel_filebase=rel, res_prefix=prefix)
                    path = os.path.join(tmp, "p.bin")
                    with open(path, "wb") as f:
                        f.write(embed(raw) if embedded else raw)
                    version, files, size, data = pck_check.read_pack(path)
                    names = sorted(f[0] for f in files)
                    contents = {f[0]: data[f[3]:f[3] + f[1]] for f in files}
                    check(version[0] == fmt and names == sorted(BASE) and contents == BASE and size == len(raw),
                          "read_pack: format %d, %s, %s file base, %s paths" % (
                              fmt, "embedded" if embedded else "standalone", "relative" if rel else "absolute",
                              "res://" if prefix else "bare"))

    # forbidden(): every shipped form of a cut file, and nothing near-miss.
    packed = [
        "res://scripts/level_data/level_04.gd", "res://scripts/level_data/level_04.gd.remap",
        "res://scripts/level_data/level_04.gdc", "res://scripts/level_data/level_04.gd.uid",
        "res://assets/sprites/themes/sunken_walls.png.import",
        "res://.godot/imported/sunken_walls.png-0123abcd.ctex",
        "res://scenes/victory.tscn.remap", "res://.godot/exported/133200997/export-0047ee4f-victory.scn",
        # near misses (must not be flagged)
        "res://scripts/level_data/level_01.gdc", "res://.godot/imported/sunken_walls_b.png-99.ctex",
        "res://.godot/exported/1/export-00-victory_lap.scn", "res://scenes/victory2.tscn.remap",
    ]
    got = sorted(set(h for c in CUT for h in pck_check.forbidden(c, packed)))
    check(got == sorted(packed[:8]), "forbidden: the 8 forms are caught, the 4 near misses are not (%s)" % got)
    check(pck_check.forbidden("res://locale/de.po", packed) == [], "forbidden: an absent cut file finds nothing")

    # index_mentions(): a cut path named in the uid cache / class cache.
    leaky = dict(BASE)
    leaky["res://.godot/uid_cache.bin"] += b"\x02\x00res://scripts/level_data/level_04.gd\x00"
    leaky["res://.godot/global_script_class_cache.cfg"] += b'{"path": "res://scenes/victory.tscn"}'
    path = os.path.join(tmp, "leaky.pck")
    with open(path, "wb") as f:
        f.write(make_pack(leaky))
    _, files, _, data = pck_check.read_pack(path)
    hits = sorted(pck_check.index_mentions(CUT, files, data))
    check(hits == [("res://scenes/victory.tscn", "res://.godot/global_script_class_cache.cfg"),
                   ("res://scripts/level_data/level_04.gd", "res://.godot/uid_cache.bin")],
          "index_mentions: cut paths named in the uid cache and the class cache (%s)" % hits)

    # The command line: a clean pack passes; a leaking file, a leaking index, an encrypted directory, a pack
    # without project.binary and a file without a pack fail.
    clean = os.path.join(tmp, "clean.exe")
    with open(clean, "wb") as f:
        f.write(embed(make_pack(BASE)))
    code, out = run_cli([clean, "--cut-list", cut_list, "--kind", "desktop"])
    check(code == 0 and "PASS" in out, "cli: a clean embedded pack passes")
    code, out = run_cli([clean, "--cut-list", cut_list, "--kind", "web"])
    check(code == 0, "cli: --kind picks its half of the cut list")
    cases = {
        "a cut file": dict(BASE, **{"res://.godot/imported/sunken_walls.png-ff.ctex": b"GST2"}),
        "a cut path in the uid cache": leaky,
        "no project.binary": {k: v for k, v in BASE.items() if k != "res://project.binary"},
    }
    for label, files in cases.items():
        path = os.path.join(tmp, "case.pck")
        with open(path, "wb") as f:
            f.write(make_pack(files))
        code, out = run_cli([path, "--cut-list", cut_list])
        check(code == 1 and "FAIL" in out, "cli: fails on %s" % label)
    path = os.path.join(tmp, "enc.pck")
    with open(path, "wb") as f:
        f.write(make_pack(BASE, encrypted_dir=True))
    code, out = run_cli([path])
    check(code == 1 and "encrypted" in out, "cli: an encrypted directory is reported, not misread")
    path = os.path.join(tmp, "none.bin")
    with open(path, "wb") as f:
        f.write(b"not a pack at all" * 10)
    code, out = run_cli([path])
    check(code == 1 and "no Godot pack" in out, "cli: a file without a pack fails")

    for name in os.listdir(tmp):
        os.remove(os.path.join(tmp, name))
    os.rmdir(tmp)
    print("RESULT: " + ("PASS" if failures == 0 else "FAIL (%d)" % failures))
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
