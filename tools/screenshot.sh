#!/usr/bin/env bash
# macOS/Linux version of screenshot.ps1: runs the game for a number of frames and saves the last
# frame to .screens/latest.png.
# Usage: ./tools/screenshot.sh [--frames 30] [--scene res://scenes/main.tscn] [--level 5] [extra game flags...]
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
frames=30
scene=""
game_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --frames) frames="$2"; shift ;;
        --scene) scene="$2"; shift ;;
        --level) game_args+=("--level=$2"); shift ;;
        *) game_args+=("$1") ;;
    esac
    shift
done
out="$root/.screens"
rm -rf "$out"
mkdir -p "$out"
args=(--path "$root" --write-movie "$out/frame.png" --fixed-fps 60 --quit-after "$frames")
[ -n "$scene" ] && args+=("$scene")
"$root/tools/godot.sh" "${args[@]}" -- "${game_args[@]}"
last="$(ls "$out"/frame*.png 2>/dev/null | sort | tail -n 1)"
if [ -z "$last" ]; then echo "No frames were written." >&2; exit 1; fi
cp "$last" "$out/latest.png"
rm -f "$out"/frame*.png
echo "Saved $out/latest.png"
