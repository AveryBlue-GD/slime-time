#!/usr/bin/env python3
"""List a Godot 4 pack (.pck, or an .exe / .x86_64 with the pack embedded) and check a demo export's cut.

Used by tools/build_demo.ps1 / tools/build_demo.sh (docs/demo-plan.md "Shipping the demo"):

    python tools/pck_check.py PACK [--cut-list FILE --kind desktop|web] [--list OUT.txt]

PACK      a .pck file, or an executable with an embedded pack (Godot's trailer: u64 size + "GDPC").
--cut-list  the file `godot -s res://tools/demo_paths.gd -- --cut-list=FILE` writes (`desktop|web<TAB>res://path`).
--kind    which half of the cut list applies to this pack.
--list    write every packed path (with its size) to this file.

Fails (exit 1) if any cut path is in the pack in any form: the file itself, its .import / .remap / .uid sibling,
a compiled script (.gdc), its imported copy (.godot/imported/<file>-<hash>.*) or, for a .tscn / .tres,
its converted copy (.godot/exported/<n>/export-<hash>-<name>.scn / .res); or if its res:// path is written in
the pack's uid cache (.godot/uid_cache.bin) or script class cache (global_script_class_cache.cfg), which
would leak its name. Self-test: tools/test_pck_check.py (synthetic packs). Also fails if the pack
can't be read, or if a file every build needs (project.binary, level 1's data) is missing, which would
mean the parser or the export is broken rather than the cut being right.

The pack format (core/io/file_access_pack.cpp, Godot 4): "GDPC", u32 format version (2, 3 or 4 = Godot 4.7), u32 major,
minor, patch, u32 pack flags, u64 file base, [v3: u64 directory offset], 16 x u32 reserved; the directory
is u32 file count, then per file: u32 path length, path bytes (zero padded), u64 offset, u64 size,
16 bytes md5, u32 flags. Flag bit 0 of the pack = an encrypted directory (not readable here: say so).
"""
import argparse
import os
import struct
import sys

MAGIC = 0x43504447  # "GDPC"
DIR_ENCRYPTED = 1
REL_FILEBASE = 2


def read_pack(path):
    """Returns (version tuple, [(res path, size, flags, offset in data)], pack size, data) of the pack in `path`."""
    with open(path, "rb") as f:
        data = f.read()
    start = 0
    pack_size = len(data)
    if struct.unpack_from("<I", data, 0)[0] != MAGIC:
        # An embedded pack: the file ends with u64 pack size + "GDPC"; the pack starts size bytes earlier.
        if len(data) < 12 or struct.unpack_from("<I", data, len(data) - 4)[0] != MAGIC:
            raise ValueError("no Godot pack in %s" % path)
        size = struct.unpack_from("<Q", data, len(data) - 12)[0]
        start = len(data) - 12 - size
        pack_size = size
        if start < 0 or struct.unpack_from("<I", data, start)[0] != MAGIC:
            raise ValueError("bad embedded pack trailer in %s" % path)
    pos = start + 4
    fmt, major, minor, patch, flags = struct.unpack_from("<5I", data, pos)
    pos += 20
    if fmt not in (2, 3, 4):
        raise ValueError("unknown pack format %d (Godot %d.%d.%d)" % (fmt, major, minor, patch))
    file_base = struct.unpack_from("<Q", data, pos)[0] + (start if flags & REL_FILEBASE else 0)
    pos += 8
    if fmt >= 3:  # v3 (4.4+) and v4 (4.7): the directory sits after the files
        dir_offset = struct.unpack_from("<Q", data, pos)[0]
        pos = start + dir_offset
    else:
        pos += 16 * 4
    if flags & DIR_ENCRYPTED:
        raise ValueError("the pack's directory is encrypted (encrypt_directory): can't list it")
    count = struct.unpack_from("<I", data, pos)[0]
    pos += 4
    files = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, pos)[0]
        pos += 4
        name = data[pos:pos + length].rstrip(b"\0").decode("utf-8")
        pos += length
        ofs, size = struct.unpack_from("<QQ", data, pos)
        if file_base + ofs + size > len(data):
            raise ValueError("entry %s points past the end of the file (unknown layout?)" % name)
        pos += 16 + 16
        file_flags = struct.unpack_from("<I", data, pos)[0] if fmt >= 2 else 0
        pos += 4 if fmt >= 2 else 0
        if not name.startswith("res://"):
            name = "res://" + name
        files.append((name, size, file_flags, file_base + ofs))
    return (fmt, major, minor, patch), files, pack_size, data


def forbidden(cut_path, packed):
    """The packed paths that carry `cut_path` in some form."""
    hits = []
    base = cut_path[:-len(".import")] if cut_path.endswith(".import") else cut_path
    stem = base[:-3] if base.endswith(".gd") else None
    file = base.rsplit("/", 1)[-1]
    imported = "res://.godot/imported/" + file + "-"
    # A text scene / resource ships converted: .godot/exported/<n>/export-<md5>-<name>.scn / .res
    converted = "-" + file.rsplit(".", 1)[0] + "." if base.endswith((".tscn", ".tres")) else None
    for name in packed:
        leaf = name.rsplit("/", 1)[-1]
        if name in (base, base + ".import", base + ".remap", base + ".uid") or (stem and name == stem + ".gdc") \
                or name.startswith(imported) \
                or (converted and name.startswith("res://.godot/exported/") and leaf.startswith("export-")
                    and converted in leaf and leaf.endswith((".scn", ".res"))):
            hits.append(name)
    return hits


# The pack's index files that name other files by path: a cut path written there leaks its name (and, for the
# uid cache, makes a uid point at a file that isn't there).
INDEX_FILES = ("res://.godot/uid_cache.bin", "res://.godot/global_script_class_cache.cfg")


def index_mentions(cut_paths, files, data):
    """[(cut path, index file)] for every cut path whose res:// path is written in one of INDEX_FILES.
    `files` as read_pack returns them. An encrypted index file can't be searched: reported as (None, file)."""
    hits = []
    for name, size, flags, offset in files:
        if name not in INDEX_FILES:
            continue
        if flags & 1:
            hits.append((None, name))
            continue
        blob = data[offset:offset + size]
        for path in cut_paths:
            if not path.endswith(".import") and path.encode("utf-8") in blob:
                hits.append((path, name))
    return hits


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pack")
    ap.add_argument("--cut-list")
    ap.add_argument("--kind", choices=["desktop", "web"], default="desktop")
    ap.add_argument("--list")
    args = ap.parse_args()
    try:
        version, files, pack_size, data = read_pack(args.pack)
    except (ValueError, struct.error, OSError) as e:
        print("pck_check: FAIL %s" % e)
        return 1
    names = {entry[0] for entry in files}
    print("pck_check: %s: Godot %d.%d.%d pack format %d, %d files, %.1f MB pack (%.1f MB file)" % (
        os.path.basename(args.pack), version[1], version[2], version[3], version[0], len(files),
        pack_size / 1e6, os.path.getsize(args.pack) / 1e6))
    if args.list:
        with open(args.list, "w", encoding="utf-8", newline="\n") as out:
            for name, size, _flags, _offset in sorted(files):
                out.write("%10d  %s\n" % (size, name))
    ok = True
    for need in ("res://project.binary", "res://scripts/level_data/level_01.gd.remap"):
        if need not in names:
            print("pck_check: FAIL %s is missing (a broken export, or the parser misread the pack)" % need)
            ok = False
    if args.cut_list:
        cut = []
        with open(args.cut_list, encoding="utf-8") as f:
            for line in f:
                kind, _, path = line.rstrip("\n").partition("\t")
                if kind == args.kind and path:
                    cut.append(path)
        leaked = []
        for path in cut:
            leaked += [(path, hit) for hit in forbidden(path, names)]
        sources = sorted({p[:-len(".import")] if p.endswith(".import") else p for p in cut})
        if leaked:
            ok = False
            for path, hit in leaked:
                print("pck_check: FAIL cut file in the pack: %s (from %s)" % (hit, path))
        else:
            print("pck_check: ok, none of the %d cut files (%d paths with .import) is in the pack, in any form"
                  % (len(sources), len(cut)))
        mentions = index_mentions(cut, files, data)
        searched = [n for n in INDEX_FILES if n in names]
        if mentions:
            ok = False
            for path, index in mentions:
                if path is None:
                    print("pck_check: FAIL %s is encrypted: can't check it for cut paths" % index)
                else:
                    print("pck_check: FAIL a cut path is named in %s: %s" % (index, path))
        else:
            print("pck_check: ok, no cut path is named in %s" % (", ".join(n.rsplit("/", 1)[-1] for n in searched) or "(no index files)"))
    print("pck_check: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
