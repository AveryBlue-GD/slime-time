#!/usr/bin/env bash
# macOS/Linux version of play.ps1: opens the game for playtesting.
# Usage: ./tools/play.sh [--dev | --story] [--scene res://tests/demo_record_run.tscn] [extra game flags...]
#   --dev     everything unlocked, nothing saved (the --unlock-all debug flag)
#   --story   the whole story beaten on normal AND hard, all 165 coins found (none spent), nothing saved
#             and the real save never read (the --story-complete debug flag); for testing the postgame
#   --scene   start in a specific scene instead of the title
#   anything else is passed to the game as a debug flag (see scripts/progress.gd), e.g. --skin=ocean
root="$(cd "$(dirname "$0")/.." && pwd)"
scene=""
game_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --dev) game_args+=("--unlock-all") ;;
        --story) game_args+=("--story-complete") ;;
        --scene) scene="$2"; shift ;;
        *) game_args+=("$1") ;;
    esac
    shift
done
args=(--path "$root")
[ -n "$scene" ] && args+=("$scene")
exec "$root/tools/godot.sh" "${args[@]}" -- "${game_args[@]}"
