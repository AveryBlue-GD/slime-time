#!/usr/bin/env bash
# Captures every screen / overlay / HUD state (the 53 of tests/test_i18n_screens.gd) in every locale,
# checks every visible text for missing glyphs, and builds contact sheets (docs/i18n/review/README.md).
# Usage: ./tools/i18n_capture.sh [--locales en,de,...|all] [--states slug,...|all] [--out DIR] [-j N] [--keep-backdrop] [--measure-boxes] [--no-sheets]
# Output (default build/i18n-shots/, git-ignored): <locale>/<state>.png, sheets/, missing_glyphs.json, logs/.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
all_locales="en,es,pt_BR,fr,de,it,ru,pl,tr,ja,ko,zh_CN,zh_TW,th,vi,id,ar,hi,pseudo"
locales="all"; states="all"; out="$root/build/i18n-shots"; jobs=6; extra=(); sheets=1
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
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
if [ -n "$one" ]; then  # worker (one locale, one Godot process); started by the xargs below
    t=$SECONDS
    "$root/tools/godot.sh" --path "$root" --fixed-fps 60 --quit-after 300000 -s res://tests/capture_i18n.gd \
        -- --locale="$one" --out="$out" ${extra[@]+"${extra[@]}"} >"$out/logs/$one.log" 2>&1 || true
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
python3 -I - "$out" ${locales//,/ } <<'PY'
import json, os, sys
out, locales = sys.argv[1], sys.argv[2:]
bad = []
for l in locales:
    path = os.path.join(out, "json", "goo_ink_%s.json" % l)
    hits = json.load(open(path)) if os.path.exists(path) else []
    on, zone = sum(h["on_goo"] for h in hits), sum(h["zone"] for h in hits)
    if hits:
        bad.append("%s %d/%d" % (l, on, zone))
print("goo-ink check (glyph ink px on goo / in band rows): " + (", ".join(bad) if bad else "0 in every locale"))
PY
after=""; [ -f "$save" ] && after="$(md5 -q "$save" 2>/dev/null || md5sum "$save" | cut -d' ' -f1)"
echo "real save md5 before/after: ${before:-none} / ${after:-none} $([ "$before" = "$after" ] && echo '(unchanged)' || echo '(CHANGED!)')"
echo "total $((SECONDS - start))s -> $out"
