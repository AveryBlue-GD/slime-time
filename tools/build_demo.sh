#!/usr/bin/env bash
# Builds and VERIFIES the demo exports in one go (docs/demo-plan.md "Shipping the demo"; twin: build_demo.ps1).
#   ./tools/build_demo.sh [--all] [--no-smoke]
# 0. self-tests tools/pck_check.py (tools/test_pck_check.py: synthetic packs);
# 1. rewrites the demo presets in export_presets.cfg from their full twins + Demo.export_cut()
#    (tools/demo_paths.gd --write-presets; the full presets stay byte-identical);
# 2. exports "Windows Demo" -> build/demo/windows/DryTryingDemo.exe and "Web Demo" -> build/demo/web/index.html
#    (--all: also "Linux Demo", and "macOS Demo" on a Mac), release, headless;
# 3. lists every exported pack (tools/pck_check.py) and FAILS if any cut file is inside in any form
#    (the file, its .import / .remap / .uid, a .gdc, the imported or converted copy under .godot/, its path in
#    the pack's uid cache or class cache);
# 4. smoke-runs each desktop / web pack with the editor binary (--main-pack, never the exported exe itself):
#    tools/demo_smoke.gd plays the demo's levels to the chalice, the first demo maze, opens every menu,
#    on a throwaway save outside the game's user folder (build/demo/reports/demo_smoke_selftest.cfg, deleted
#    afterwards; the real save is checked unchanged); the web pack runs with --platform=web --expect=web, so
#    the web knobs (levels, no randomizer, no hat wheel) and the web cut list are what is checked;
#    FAILS on a failed check or any ERROR / SCRIPT ERROR line in its log.
# Reports (pack listings, cut list, smoke logs) go to build/demo/reports/ (NOT inside build/demo/web: that
# folder's files are the itch upload as they are). Needs Godot 4.7.2 + its export templates, python3.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="$root/tools/godot.sh"
all=0
smoke=1
for arg in "$@"; do
    case "$arg" in
        --all) all=1 ;;
        --no-smoke) smoke=0 ;;
        *) echo "usage: $0 [--all] [--no-smoke]" >&2; exit 2 ;;
    esac
done
py="$(command -v python3 || command -v python)"
# Godot (a Windows binary under Git Bash) needs C:/... paths for files outside the project.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
reports="$root/build/demo/reports"
mkdir -p "$reports"
status=0
fail() { echo "FAIL: $*"; status=1; }

# The player's real save (never written by any of this): its md5 before and after.
real_save=""
for candidate in "${APPDATA:-}/SlimeTime_R1/save.cfg" "$HOME/Library/Application Support/SlimeTime_R1/save.cfg" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/SlimeTime_R1/save.cfg"; do
    if [ -f "$candidate" ]; then real_save="$candidate"; break; fi
done
# (md5sum / md5, not python: the Microsoft Store python can't see the real %APPDATA%.)
md5_of() {
    [ -n "$real_save" ] || return 0
    if command -v md5sum >/dev/null 2>&1; then md5sum "$real_save" | cut -c1-32; else md5 -q "$real_save"; fi
}
save_before="$(md5_of)"

echo "== 0. pck_check self-test"
"$py" "$root/tools/test_pck_check.py" || fail "the tools/pck_check.py self-test"

echo "== 1. demo presets"
if out="$("$godot" --path "$root" --headless -s res://tools/demo_paths.gd -- --write-presets 2>&1)"; then
    echo "$out" | grep "demo presets"
else
    echo "$out" | tail -5; fail "the demo presets could not be written"
fi
rm -f "$reports/cut_list.txt"  # never check against a stale list
if ! "$godot" --path "$root" --headless -s res://tools/demo_paths.gd -- "--cut-list=$(native "$reports/cut_list.txt")" >/dev/null 2>&1 \
        || [ ! -s "$reports/cut_list.txt" ]; then
    rm -f "$reports/cut_list.txt"
    fail "the cut list could not be written"
fi

# name|output|pack file (relative to root)|cut kind
targets=("Windows Demo|build/demo/windows/DryTryingDemo.exe|build/demo/windows/DryTryingDemo.exe|desktop"
         "Web Demo|build/demo/web/index.html|build/demo/web/index.pck|web")
if [ "$all" = 1 ]; then
    targets+=("Linux Demo|build/demo/linux/DryTryingDemo.x86_64|build/demo/linux/DryTryingDemo.x86_64|desktop")
    # The macOS presets (ad-hoc signed) need Xcode's command line tools: build them on the Mac.
    case "$(uname -s)" in
        Darwin) targets+=("macOS Demo|build/demo/macos/DryTryingDemo.zip||desktop") ;;
        *) echo "(macOS Demo: skipped here, it exports on a Mac only - code signing needs Xcode's tools)" ;;
    esac
fi

echo "== 2. export"
for t in "${targets[@]}"; do
    IFS='|' read -r name out pack kind <<< "$t"
    dir="$root/$(dirname "$out")"
    rm -rf "$dir" && mkdir -p "$dir"
    log="$reports/export_$(echo "$name" | tr ' ' '_').log"
    if "$godot" --path "$root" --headless --export-release "$name" "$root/$out" > "$log" 2>&1 && [ -f "$root/$out" ]; then
        echo "exported $name -> $out ($(du -h "$root/$out" | cut -f1))"
    else
        fail "export of $name (see $log)"
    fi
done

echo "== 3. pack contents"
for t in "${targets[@]}"; do
    IFS='|' read -r name out pack kind <<< "$t"
    packfile="$root/$pack"
    if [ -z "$pack" ] && [ -f "$root/$out" ]; then  # the macOS zip: check the .pck inside the .app
        packfile="$reports/macos_demo.pck"
        "$py" -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
name = [n for n in z.namelist() if n.endswith(".pck")][0]
open(sys.argv[2], "wb").write(z.read(name))' "$root/$out" "$packfile" || { fail "$name: no .pck in the zip"; continue; }
    fi
    [ -f "$packfile" ] || continue
    listing="$reports/pack_$(echo "$name" | tr ' ' '_').txt"
    "$py" "$root/tools/pck_check.py" "$packfile" --cut-list "$reports/cut_list.txt" --kind "$kind" --list "$listing" \
        || fail "$name: the pack check"
done

if [ "$smoke" = 1 ]; then
    echo "== 4. smoke run of the exported packs (editor binary + --main-pack, throwaway save)"
    for t in "${targets[@]}"; do
        IFS='|' read -r name out pack kind <<< "$t"
        case "$name" in "Windows Demo"|"Web Demo") ;; *) continue ;; esac
        [ -f "$root/$pack" ] || continue
        log="$reports/smoke_$(echo "$name" | tr ' ' '_').log"
        save="$reports/demo_smoke_selftest.cfg"
        rm -f "$save" "$save.tmp"
        platform=""
        [ "$kind" = web ] && platform="--platform=web"
        (cd "$reports" && "$godot" --headless --fixed-fps 60 --quit-after 200000 --main-pack "$(native "$root/$pack")" \
            -s "$(native "$root/tools/demo_smoke.gd")" -- "--save-path=$(native "$save")" "--expect=$kind" $platform) > "$log" 2>&1
        code=$?
        if [ -e "$save" ] || [ -e "$save.tmp" ]; then
            echo "(the smoke run left its throwaway save behind: $save - deleted)"
            rm -f "$save" "$save.tmp"
        fi
        errors="$(grep -E "^(ERROR|SCRIPT ERROR|USER ERROR)" "$log" | grep -v "still in use at exit" || true)"
        checks="$(grep -c "^  ok" "$log")"
        if [ "$code" = 0 ] && grep -q "^RESULT: PASS" "$log" && [ -z "$errors" ]; then
            echo "$name: smoke PASS ($checks checks, $(grep -c "^WARNING" "$log") warnings; log $log)"
        else
            grep -E "FAIL|^(ERROR|SCRIPT ERROR|USER ERROR)" "$log" | head -20
            fail "$name: smoke run (exit $code; log $log)"
        fi
    done
fi

if [ -n "$real_save" ] && [ "$(md5_of)" != "$save_before" ]; then
    fail "the real save changed: $real_save"
fi

echo "== report"
cut_files="$(grep -c "^desktop	" "$reports/cut_list.txt" 2>/dev/null || true)"
echo "cut list: $cut_files paths for desktop ($(grep -v '\.import$' "$reports/cut_list.txt" | grep -c "^desktop	") files + their .import), see $reports/cut_list.txt"
for t in "${targets[@]}"; do
    IFS='|' read -r name out pack kind <<< "$t"
    [ -f "$root/$out" ] && echo "$name: $out $(du -h "$root/$out" | cut -f1)$( [ -n "$pack" ] && [ "$pack" != "$out" ] && [ -f "$root/$pack" ] && echo ", pack $(du -h "$root/$pack" | cut -f1)")"
done
if [ "$status" = 0 ]; then echo "DEMO BUILD: PASS"; else echo "DEMO BUILD: FAIL"; fi
exit "$status"
