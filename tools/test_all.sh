#!/usr/bin/env bash
# Runs every tests/test_*.gd suite headless (in parallel) and reports which failed.
# Usage: ./tools/test_all.sh [-j N] [suite_name ...]
#   -j N, or JOBS=N  parallel jobs (default: 3/4 of the CPU cores, at least 2; -j 1 = one at a time like before)
#   suite names      run only those suites (test_coins ...); default = all of them
#   TIMES=1          print every job's wall time, slowest first
#   KEEP_LOGS=dir    keep each job's full output in dir/<job>.log
# The few long suites are split into SHARDS (same suite script, different arguments) so that none of them is the
# critical path; a sharded suite counts once in "suites: N". Every suite uses a per-process throwaway save
# (tests/suite_base.gd throwaway_save), so jobs and even two test_all.sh runs side by side cannot disturb each other.
root="$(cd "$(dirname "$0")/.." && pwd)"

# A Mac that sleeps freezes the run (a run that looked like 27 minutes of wall time was mostly sleep): stay awake meanwhile.
if [ -z "$TEST_ALL_AWAKE" ] && command -v caffeinate >/dev/null 2>&1; then
    TEST_ALL_AWAKE=1 exec caffeinate -i "$0" "$@"
fi

jobs_n="${JOBS:-0}"
wanted=()
while [ $# -gt 0 ]; do
    case "$1" in
        -j) jobs_n="$2"; shift 2 ;;
        -j*) jobs_n="${1#-j}"; shift ;;
        *) wanted+=("$(basename "${1%.gd}")"); shift ;;
    esac
done
if ! [ "$jobs_n" -gt 0 ] 2>/dev/null; then
    cores="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
    jobs_n=$((cores * 3 / 4))
    [ "$jobs_n" -lt 2 ] && jobs_n=2
fi

# Sharded suites: "suite|job label|arguments after --". Longest first (they start first).
SHARDS=(
    "test_nav_fuzz|test_nav_fuzz#scripted|--nav-only=scripted --nav-no-web-child"
    "test_nav_fuzz|test_nav_fuzz#web-ring|--web-ui --nav-child --nav-only=walks --nav-steps=600 --nav-area-steps=500 --nav-seed=1239"
    "test_nav_fuzz|test_nav_fuzz#walks-0-8|--nav-only=walks --nav-walk=0-8"
    "test_nav_fuzz|test_nav_fuzz#walks-9-17|--nav-only=walks --nav-walk=9-17"
    "test_maze_golden|test_maze_golden#0|--shard=0"
    "test_maze_golden|test_maze_golden#1|--shard=1"
    "test_maze_golden|test_maze_golden#2|--shard=2"
    "test_maze_golden|test_maze_golden#3|--shard=3"
)
# Unsharded but slow: scheduled right after the shards.
SLOW=(test_attempt_restarts test_descent_runs test_save_robust test_autoplay test_spawn_picker)

work="$(mktemp -d "${TMPDIR:-/tmp}/slime_test_all.XXXXXX")"
trap 'rm -rf "$work"' EXIT

wants() { # is suite $1 selected?
    [ ${#wanted[@]} -eq 0 ] && return 0
    local w
    for w in "${wanted[@]}"; do [ "$w" = "$1" ] && return 0; done
    return 1
}
sharded_suites=" test_nav_fuzz test_maze_golden "

jobfile="$work/jobs.txt"
: > "$jobfile"
suites=()
for test in "$root"/tests/test_*.gd; do suites+=("$(basename "$test" .gd)"); done
for entry in "${SHARDS[@]}"; do
    IFS='|' read -r suite label args <<< "$entry"
    wants "$suite" && echo "$suite|$label|$args" >> "$jobfile"
done
for suite in "${SLOW[@]}"; do wants "$suite" && echo "$suite|$suite|" >> "$jobfile"; done
total=0
for suite in "${suites[@]}"; do
    wants "$suite" || continue
    total=$((total + 1))
    case "$sharded_suites" in *" $suite "*) continue ;; esac
    case " ${SLOW[*]} " in *" $suite "*) continue ;; esac
    echo "$suite|$suite|" >> "$jobfile"
done
if [ "$total" -eq 0 ]; then
    echo "no such suite: ${wanted[*]}"
    exit 1
fi

run_job() { # "suite|label|args": runs one headless job, leaves <label>.log and <label>.result in $work
    local suite label args r
    IFS='|' read -r suite label args <<< "$1"
    local file="${label//#/_}"
    local start=$SECONDS
    # shellcheck disable=SC2086
    "$root/tools/godot.sh" --path "$root" --headless --fixed-fps 60 --quit-after 300000 -s "res://tests/$suite.gd" ${args:+--} $args > "$work/$file.log" 2>&1
    if grep -q "RESULT: PASS" "$work/$file.log"; then r=PASS; else r=FAIL; fi
    echo "$r $((SECONDS - start)) $label" > "$work/$file.result"
}
export -f run_job
export root work

started=$SECONDS
tr '\n' '\0' < "$jobfile" | xargs -0 -n 1 -P "$jobs_n" bash -c 'run_job "$0"'

failed_jobs=0
failed_names=""
for entry in "$work"/*.result; do
    read -r r secs label < "$entry"
    [ "$r" = PASS ] && continue
    failed_jobs=$((failed_jobs + 1))
    failed_names="$failed_names ${label%%#*}"
    echo "$label FAILED:"
    grep -E "FAIL|SCRIPT ERROR|Parse" "$work/$(basename "$entry" .result).log" | head -n 8
done
failed=$(echo $failed_names | tr ' ' '\n' | sort -u | grep -c .)
if [ -n "$TIMES" ]; then
    echo "--- job wall times, slowest first (jobs: $jobs_n)"
    cat "$work"/*.result | sort -k2 -n -r | head -n 20
fi
if [ -n "$KEEP_LOGS" ]; then
    mkdir -p "$KEEP_LOGS"
    cp "$work"/*.log "$work"/*.result "$KEEP_LOGS"/
fi
echo "suites: $total failed: $failed ($jobs_n jobs, $((SECONDS - started)) s)"
[ "$failed_jobs" -eq 0 ]
