#!/usr/bin/env bash
# macOS / Linux twin of make_promo.ps1: renders the itch.io cover (630x500) and screenshots (1280x720) from the
# real game, with the same file names, scenes, frames and flags.
# Usage: ./tools/promo/make_promo.sh [--out-dir <folder>]   (default: ~/Desktop/SlimeTime-itch-images)
# Uses debug flags (--unlock-all, --skin=..., --upgrades=...), so the real save file is never written. On the Mac
# the windows open normally (no right-monitor / no-focus trick); leave them alone until the script finishes.
# Don't re-render as part of normal changes: only when the owner asks (CLAUDE.md).
set -e
root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$HOME/Desktop/SlimeTime-itch-images"
while [ $# -gt 0 ]; do
    case "$1" in
        --out-dir) out_dir="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
shot="$root/tools/screenshot.sh"
upscale="$root/tools/upscale_png.py"
mkdir -p "$out_dir"
rm -f "$out_dir"/screenshot-*.png

capture() {  # name scene frames [game flags...]
    local name="$1" scene="$2" frames="$3"
    shift 3
    "$shot" --frames "$frames" --scene "$scene" "$@" >/dev/null
    python3 "$upscale" "$root/.screens/latest.png" "$out_dir/$name" 4 >/dev/null
    echo "wrote $name"
}

# Every shot puts each level's own skin on it (the one its first run equips: Lime 1, Mint 2, Lemon 3, Ocean 4,
# Grape 5, Crimson 6, Frost 7, Inkky 8, Bubblegum 9, Ember 10). The rainbow is the only exception, and only with
# every coin found (--all-coins), as the game requires.

# The cover renders itself at 315x250 (its own SubViewport) and saves the PNG directly: the Frozen Fortress, a
# Frost slime well into the maze with its light maxed out.
raw="$(mktemp -d)/slimetime_cover_raw.png"
"$root/tools/godot.sh" --path "$root" --fixed-fps 60 res://tools/promo/cover.tscn -- --unlock-all --skin=frost \
    --upgrades=0,0,3 --cover-level=7 --cover-frame=1300 "--out=$raw" >/dev/null
python3 "$upscale" "$raw" "$out_dir/cover.png" 2 >/dev/null
rm -f "$raw"
echo "wrote cover.png"

capture screenshot-1-title.png res://scenes/title.tscn 40 --unlock-all --skin=lime
capture screenshot-2-sunken-shrine.png res://tests/demo.tscn 900 --unlock-all --skin=ocean --level=4 --upgrades=0,0,2 --coins=14
capture screenshot-3-charged-leap.png res://tools/promo/jump_shot.tscn 360 --unlock-all --skin=mint --coins=6  # level 2, the Mossy Mines
capture screenshot-4-volcanic-vault.png res://tests/demo.tscn 1100 --unlock-all --skin=ember --level=10 --upgrades=0,0,2 --coins=37
capture screenshot-5-crystal-rainbow.png res://tests/demo.tscn 1000 --unlock-all --skin=rainbow --level=9 --upgrades=0,0,2 --all-coins
capture screenshot-6-new-record.png res://tests/demo_record_run.tscn 1150 --unlock-all --skin=lemon --coins=9  # level 3, the Sandstone Sanctum; the win lands at about frame 1084 (banner at once, buttons 0.6 s later)
capture screenshot-7-upgrades.png res://scenes/upgrades.tscn 40 --skin=mint --upgrades=4,1,2 --coins=12
capture screenshot-8-skins.png res://scenes/skins.tscn 40 --unlock-all --skin=bubblegum
