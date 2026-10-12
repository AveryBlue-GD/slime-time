#!/usr/bin/env bash
# Runs every tests/test_*.gd suite headless and reports which failed.
# Usage: ./tools/test_all.sh
root="$(cd "$(dirname "$0")/.." && pwd)"
failed=0
total=0
for test in "$root"/tests/test_*.gd; do
    name="$(basename "$test" .gd)"
    total=$((total + 1))
    output="$("$root/tools/godot.sh" --path "$root" --headless --fixed-fps 60 --quit-after 300000 -s "res://tests/$name.gd" 2>&1)"
    if ! echo "$output" | grep -q "RESULT: PASS"; then
        failed=$((failed + 1))
        echo "$name FAILED:"
        echo "$output" | grep -E "FAIL|SCRIPT ERROR|Parse" | head -n 8
    fi
done
echo "suites: $total failed: $failed"
[ "$failed" -eq 0 ]
