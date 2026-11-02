#!/usr/bin/env bash
# Runs the bench/bench.gd scenarios and prints a table (and, with --json FILE, saves the raw results).
#
#   ./bench/run.sh                        # every scenario, 5 runs each, headless (CPU cost only)
#   ./bench/run.sh --display              # with a real renderer: on a Mac just run it (a window opens);
#                                         # on Linux CI/cloud it wraps itself in xvfb-run (software GL)
#   ./bench/run.sh --runs 3 level10 hub   # some scenarios, 3 runs each
#   ./bench/run.sh --json out.json        # also save every run's numbers
#
# Each scenario runs in its own process RUNS times; the table shows the MEDIAN of the runs for every metric
# (frame avg / p95 / p99, script ms, peak memory, startup). Run it on a quiet machine: other load shows up as noise.
# Godot: $GODOT, else tools/godot.sh's search (the project needs 4.7.2).
set -euo pipefail
cd "$(dirname "$0")/.."

RUNS=5
DISPLAY_MODE=0
JSON_OUT=""
SCENARIOS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--runs) RUNS="$2"; shift 2 ;;
		--display) DISPLAY_MODE=1; shift ;;
		--json) JSON_OUT="$2"; shift 2 ;;
		-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
		*) SCENARIOS+=("$1"); shift ;;
	esac
done
[[ ${#SCENARIOS[@]} -eq 0 ]] && SCENARIOS=(startup title hub level1 level10 random story skins)

if [[ -n "${GODOT:-}" ]]; then
	RUN=("$GODOT")
else
	RUN=(./tools/godot.sh)
fi
MODE_ARGS=(--headless)
WRAP=()
if [[ $DISPLAY_MODE -eq 1 ]]; then
	MODE_ARGS=()
	if [[ "$(uname)" == "Linux" && -z "${DISPLAY:-}" ]]; then
		WRAP=(xvfb-run -a -s "-screen 0 1280x720x24")
	fi
fi

RAW=$(mktemp)
trap 'rm -f "$RAW"' EXIT
for s in "${SCENARIOS[@]}"; do
	for ((r = 1; r <= RUNS; r++)); do
		extra=()
		case "$s" in hub|skins) extra=(--unlock-all) ;; esac  # all 8 hub stations / every skin
		line=$("${WRAP[@]}" "${RUN[@]}" --path . "${MODE_ARGS[@]}" --fixed-fps 60 --quit-after 100000 \
			-s res://bench/bench.gd -- --scenario="$s" "${extra[@]}" 2>/dev/null | grep '^BENCH ' | head -1 || true)
		if [[ -z "$line" ]]; then
			echo "bench: scenario $s run $r printed no BENCH line" >&2
			exit 1
		fi
		echo "${line#BENCH }" >> "$RAW"
		printf '.' >&2
	done
done
echo >&2

python3 - "$RAW" "${JSON_OUT:-}" "$DISPLAY_MODE" <<'PY'
import json, statistics, sys
raw, out, display = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
runs = [json.loads(l) for l in open(raw) if l.strip()]
by = {}
for r in runs:
    by.setdefault(r["scenario"], []).append(r)
def med(rs, k):
    vals = [r[k] for r in rs if k in r]
    return statistics.median(vals) if vals else None
cols = ["avg_ms", "p95_ms", "p99_ms", "max_ms", "script_ms", "load_ms", "mem_peak_mb", "nodes", "orphans"]
if display:
    cols += ["draw_calls", "render_objects"]
print("mode: " + ("display (real renderer)" if display else "headless (CPU only, dummy renderer)") + f", median of {len(next(iter(by.values())))} runs")
print("| scenario | " + " | ".join(cols) + " |")
print("|---" * (len(cols) + 1) + "|")
summary = {}
for s, rs in by.items():
    if s == "startup":
        summary[s] = {"startup_ms": med(rs, "startup_ms"), "mem_peak_mb": med(rs, "mem_peak_mb")}
        print(f"| startup | startup_ms {med(rs, 'startup_ms')} | mem_peak_mb {med(rs, 'mem_peak_mb')} |")
        continue
    summary[s] = {c: med(rs, c) for c in cols}
    print(f"| {s} | " + " | ".join(str(summary[s][c]) for c in cols) + " |")
if out:
    json.dump({"display": display, "summary": summary, "runs": runs}, open(out, "w"), indent=1)
PY
