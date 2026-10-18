#!/usr/bin/env bash
# Captures every screen / overlay / HUD state (the states of tests/test_i18n_screens.gd plus the story lines and stills of tests/capture_i18n.gd) in every locale,
# checks every visible text for missing glyphs, and builds contact sheets (docs/i18n/review/README.md).
# Usage: ./tools/i18n_capture.sh [--locales en,de,...|all] [--states slug,...|all] [--out DIR] [-j N] [--keep-backdrop] [--measure-boxes] [--no-sheets] [--gate]
# --gate (English-only mode on: only English is strict, other locales' findings are warnings, summarised and written to
# <out>/i18n_pending_warnings.json): exit 1 when the goo-ink check finds glyph ink on a goo band in any state of any locale, other than the
# accepted exceptions in tools/i18n_goo_ink_allow.txt (docs/i18n/review/README.md "Goo-ink gate"), or a locale
# captured fewer states than the suite builds.
# Exit 3 when the real save's md5 changed during the run (it must never be touched).
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
# The real save (project.godot: use_custom_user_dir, SlimeTime_R1): macOS, Linux ($XDG_DATA_HOME or ~/.local/share).
# Its md5 is compared before / after; a change fails the run. Absent on this machine: a note, nothing to compare.
save=""
for cand in "$HOME/Library/Application Support/SlimeTime_R1/save.cfg" "${XDG_DATA_HOME:-$HOME/.local/share}/SlimeTime_R1/save.cfg"; do
    [ -f "$cand" ] && { save="$cand"; break; }
done
md5of() { md5 -q "$1" 2>/dev/null || md5sum "$1" | cut -d' ' -f1; }
before=""; [ -n "$save" ] && before="$(md5of "$save")"
[ -z "$save" ] && echo "real save not found (macOS / Linux SlimeTime_R1 user dir): md5 check skipped"
start=$SECONDS
mkdir -p "$out/logs" "$out/json"
for l in ${locales//,/ }; do rm -rf "$out/$l"; rm -f "$out/json/missing_$l.json" "$out/json/states_$l.json"; done

printf '%s\n' ${locales//,/ } | xargs -P "$jobs" -I{} "$0" --one {} --out "$out" ${extra[@]+"${extra[@]}"}

python3 -I "$root/tools/i18n_contact_sheet.py" merge --out "$out" --locales "$locales"
[ "$sheets" = 1 ] && python3 -I "$root/tools/i18n_contact_sheet.py" sheets --out "$out" --locales "$locales"
status=0
# English-only mode (tests/i18n_mode.gd ENGLISH_ONLY): English stays strict, the other locales' gate findings are warnings.
english_only=0
grep -Eq '^const ENGLISH_ONLY *:= *true' "$root/tests/i18n_mode.gd" && english_only=1
python3 -I - "$out" "$root/tools/i18n_goo_ink_allow.txt" "$gate" "$states" "$english_only" ${locales//,/ } <<'PY' || status=1
import json, os, sys
out, allow_path, gate, states, english_only, locales = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5] == "1", sys.argv[6:]
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
    def strict(item):  # English always; every locale when the switch is off
        return not english_only or item.split()[0] == "en"
    fails = [u for u in unexpected if strict(u)] + [x for x in short if strict(x)]
    warns = {}
    for u in unexpected:
        if not strict(u):
            warns.setdefault(u.split()[0], {"goo_ink": [], "incomplete": ""})["goo_ink"].append(" ".join(u.split()[1:]))
    for x in short:
        if not strict(x):
            warns.setdefault(x.split()[0], {"goo_ink": [], "incomplete": ""})["incomplete"] = x.split()[1]
    for u in unexpected:
        if strict(u):
            print("  goo-ink gate: " + u)
    if [x for x in short if strict(x)]:
        print("  goo-ink gate: incomplete captures (rerun these locales): " + ", ".join(x for x in short if strict(x)))
    if english_only:
        json.dump({"english_only": True, "warnings": warns}, open(os.path.join(out, "i18n_pending_warnings.json"), "w"), indent=1, sort_keys=True)
        print("english-only mode: %d locale(s) with gate warnings (not failures) -> %s" % (len(warns), os.path.join(out, "i18n_pending_warnings.json")))
        for l, w in sorted(warns.items()):
            print("  warn %-6s %d goo-ink box(es)%s" % (l, len(w["goo_ink"]), ", incomplete capture " + w["incomplete"] if w["incomplete"] else ""))
    print("goo-ink gate: " + ("FAIL" if fails else "PASS"))
    sys.exit(1 if fails else 0)
PY
if [ -n "$save" ]; then
    after=""; [ -f "$save" ] && after="$(md5of "$save")"
    if [ "$before" = "$after" ]; then
        echo "real save md5 before/after: $before / $after (unchanged)"
    else
        echo "real save md5 before/after: $before / ${after:-gone} (CHANGED!) $save" >&2
        status=3
    fi
else
    for cand in "$HOME/Library/Application Support/SlimeTime_R1/save.cfg" "${XDG_DATA_HOME:-$HOME/.local/share}/SlimeTime_R1/save.cfg"; do
        [ -f "$cand" ] && { echo "real save created during the run: $cand (CHANGED!)" >&2; status=3; }
    done
fi
echo "total $((SECONDS - start))s -> $out"
exit $status
