#!/usr/bin/env bash
# Re-renders every marketing asset from the current game, always to the same file names (docs/marketing/README.md):
#   build/music/      hub_A/B/C.wav, trailer_1/2.wav (+ .ogg)              tools/make_music.py
#   build/trailer/    short_A/B/C.mp4, short_<ID>_music.mp4, short_<ID>_sheet.png, and with --zh the Chinese
#                     cuts short_<ID>_zh.mp4 / _zh_music.mp4 / _zh_sheet.png  tools/trailer/trailer.py
#   build/promo/steam/  the Steam capsules (base + demo/), library hero and logo, screenshot_1..6.png
#                                                                           tools/promo/make_steam_art.sh
# Usage: ./tools/marketing/refresh.sh [--only music|shorts|steam] [--zh] [--force]
#   --force   re-render the trailer takes even if their flags didn't change (after gameplay / art changes)
# Needs Godot 4.7.2 (tools/godot.sh's lookup, or $GODOT) and ffmpeg on PATH (brew install ffmpeg). Godot windows
# open and close by themselves; leave them alone until it finishes. The real save is never touched.
# The itch images are separate (tools/promo/make_promo.sh), and like everything here only re-rendered when asked.
set -e
root="$(cd "$(dirname "$0")/../.." && pwd)"
only=""; zh=0; force=()
while [ $# -gt 0 ]; do
    case "$1" in
        --only) only="$2"; shift ;;
        --zh) zh=1 ;;
        --force) force=(--force) ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
py="$(command -v python3 || command -v python)"
command -v ffmpeg >/dev/null || [ -n "$FFMPEG" ] || [ "$only" = steam ] || [ "$only" = music ] \
    || { echo "ffmpeg not found: brew install ffmpeg" >&2; exit 1; }

if [ -z "$only" ] || [ "$only" = music ]; then
    echo "== music -> build/music/"
    "$py" "$root/tools/make_music.py"
fi
if [ -z "$only" ] || [ "$only" = shorts ]; then
    echo "== Shorts -> build/trailer/"
    "$py" "$root/tools/trailer/trailer.py" "${force[@]}"
    if [ "$zh" = 1 ]; then
        "$py" "$root/tools/trailer/trailer.py" --lang zh
    fi
fi
if [ -z "$only" ] || [ "$only" = steam ]; then
    echo "== Steam art -> build/promo/steam/"
    "$root/tools/promo/make_steam_art.sh"
fi
echo "done"
