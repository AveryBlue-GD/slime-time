#!/usr/bin/env bash
# Captures every screen / overlay / HUD state (the 53 of tests/test_i18n_screens.gd) in every locale,
# checks every visible text for missing glyphs, and builds contact sheets (docs/i18n/review/README.md).
# Usage: ./tools/i18n_capture.sh [--locales en,de,...|all] [--states slug,...|all] [--out DIR] [-j N] [--keep-backdrop] [--measure-boxes] [--no-sheets] [--gate]
# --gate: exit 1 when the goo-ink check finds glyph ink on a goo band in any state of any locale, other than the
# accepted exceptions in tools/i18n_goo_ink_allow.txt (docs/i18n/review/README.md "Goo-ink gate"), or a locale
# captured fewer states than the suite builds.
# Output (default build/i18n-shots/, git-ignored): <locale>/<state>.png, sheets/, missing_glyphs.json, logs/.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
all_locales="en,es,pt_BR,fr,de,it,ru,pl,tr,ja,ko,zh_CN,zh_TW,th,vi,id,ar,hi,pseudo"
locales="all"; states="all"; out="$root/build/i18n-shots"; jobs=6; extra=(); sheets=1; gate=0
one=""
while [ $# -gt 0 ]; do
    case "$1" in
        --one) one="$2"; shift ;;
        --locales) locales="$2"; shift ;;
        --states) states="$2"; shift ;;
        --out) out="$2"; shift ;;
        -j) jobs="$2"; shift ;;
        --keep-backdrop) extra+=(--keep-backdrop) ;;
        --measure-boxes) extra+=(--measure-boxes) ;;
        --states=*) extra+=("$1") ;;
        --no-sheets) sheets=0 ;;
        --gate) gate=1 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ -n "$one" ]; then  # worker (one locale, one Godot process); started by the xargs below
    t=$SECONDS
    for try in 1 2; do  # (a run that dies before its summary, rare and not reproducible, is run once more)
        "$root/tools/godot.sh" --path "$root" --fixed-fps 60 --quit-after 300000 -s res://tests/capture_i18n.gd \
            -- --locale="$one" --out="$out" ${extra[@]+"${extra[@]}"} >"$out/logs/$one.log" 2>&1 || true
        grep -q "^RESULT:" "$out/logs/$one.log" && break
        echo "  $one: run $try ended early, retrying"
    done
    echo "  $one: $((SECONDS - t))s, $(ls "$out/$one"/*.png 2>/dev/null | wc -l | tr -d ' ') shots"
    exit 0
fi
[ "$locales" = "all" ] && locales="$all_locales"
[ "$states" != "all" ] && extra+=("--states=$states")
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
case "$out" in *"/.screens"*) echo "refusing to write into .screens/ (screenshot.sh clears it)" >&2; exit 2 ;; esac
save="$HOME/Library/Application Support/SlimeTime_R1/save.cfg"
before=""; [ -f "$save" ] && before="$(md5 -q "$save" 2>/dev/null || md5sum "$save" | cut -d' ' -f1)"
start=$SECONDS
mkdir -p "$out/logs" "$out/json"
for l in ${locales//,/ }; do rm -rf "$out/$l"; rm -f "$out/json/missing_$l.json" "$out/json/states_$l.json"; done

printf '%s\n' ${locales//,/ } | xargs -P "$jobs" -I{} "$0" --one {} --out "$out" ${extra[@]+"${extra[@]}"}

python3 -I "$root/tools/i18n_contact_sheet.py" merge --out "$out" --locales "$locales"
[ "$sheets" = 1 ] && python3 -I "$root/tools/i18n_contact_sheet.py" sheets --out "$out" --locales "$locales"
status=0
python3 -I - "$out" "$root/tools/i18n_goo_ink_allow.txt" "$gate" "$states" ${locales//,/ } <<'PY' || status=1
import json, os, sys
out, allow_path, gate, states, locales = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5:]
allow = set()
if os.path.exists(allow_path):
    for line in open(allow_path, encoding="utf-8"):
        line = line.split("#", 1)[0].split()
        if len(line) >= 3:
            allow.add(tuple(line[:3]))  # locale state-slug box
bad, unexpected, short = [], [], []
for l in locales:
    path = os.path.join(out, "json", "goo_ink_%s.json" % l)
    hits = json.load(open(path)) if os.path.exists(path) else []
    on, zone = sum(h["on_goo"] for h in hits), sum(h["zone"] for h in hits)
    if hits:
        bad.append("%s %d/%d" % (l, on, zone))
    unexpected += ["%s %s %s" % (l, h["slug"], h["box"]) for h in hits if (l, h["slug"], h["box"]) not in allow]
    names = os.path.join(out, "json", "states_%s.json" % l)
    built = len(json.load(open(names))) if os.path.exists(names) else 0
    shots = len([f for f in os.listdir(os.path.join(out, l)) if f.endswith(".png")]) if os.path.isdir(os.path.join(out, l)) else 0
    if states == "all" and (built == 0 or shots < built):
        short.append("%s %d/%d" % (l, shots, built))
print("goo-ink check (glyph ink px on goo / in band rows): " + (", ".join(bad) if bad else "0 in every locale"))
if gate:
    for u in unexpected:
        print("  goo-ink gate: " + u)
    if short:
        print("  goo-ink gate: incomplete captures (rerun these locales): " + ", ".join(short))
    print("goo-ink gate: " + ("FAIL" if unexpected or short else "PASS"))
    sys.exit(1 if unexpected or short else 0)
PY
after=""; [ -f "$save" ] && after="$(md5 -q "$save" 2>/dev/null || md5sum "$save" | cut -d' ' -f1)"
echo "real save md5 before/after: ${before:-none} / ${after:-none} $([ "$before" = "$after" ] && echo '(unchanged)' || echo '(CHANGED!)')"
echo "total $((SECONDS - start))s -> $out"
exit $status
