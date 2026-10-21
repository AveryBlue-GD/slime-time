#!/usr/bin/env bash
# Renders the Steam store art from the real game: the capsule set (base app and demo app) and six 1920x1080
# screenshots (6x the game's 320x180), with fixed file names (docs/marketing/README.md).
# Usage: ./tools/promo/make_steam_art.sh [--out-dir DIR] [--only capsules|screenshots]   (default: build/promo/steam)
# Opens a game window per image (it closes itself); leave them alone until the script finishes. Debug flags only,
# so the real save is never written. Promo rules (docs/marketing/brief.md): each level in its own skin (Lime 1,
# Mint 2, Lemon 3, Ocean 4, Grape 5, Crimson 6, Frost 7, Inkky 8, Bubblegum 9, Ember 10); the RAINBOW and STOPWATCH
# skins only as the skins screen's locked silhouettes; no HEAT. Steam's capsule rules allow only the art and the
# game's name on capsules (no taglines), and no text at all on the library hero.
set -e
root="$(cd "$(dirname "$0")/../.." && pwd)"
out_dir="$root/build/promo/steam"
only=""
while [ $# -gt 0 ]; do
    case "$1" in
        --out-dir) out_dir="$2"; shift ;;
        --only) only="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
mkdir -p "$out_dir/demo"
godot="$root/tools/godot.sh"

render() {  # file level skin frame size zoom logo_scale [more capsule flags...]
    local file="$1" level="$2" skin="$3" frame="$4" size="$5" zoom="$6" logo="$7"
    shift 7
    rm -f "$out_dir/$file"
    # (--quit-after: a window that stalls can't hang the script; the image is saved at frame $frame)
    "$godot" --path "$root" --fixed-fps 60 --quit-after "$((frame + 600))" res://tools/promo/capsule.tscn -- --unlock-all "--skin=$skin" \
        --upgrades=0,0,3 "--cover-level=$level" "--frame=$frame" "--size=$size" "--zoom=$zoom" "--logo-scale=$logo" \
        "--out=$out_dir/$file" --promo "$@" >/dev/null 2>&1
    [ -f "$out_dir/$file" ] || { echo "FAILED: $file" >&2; exit 1; }
    echo "wrote $file"
}

if [ "$only" != "screenshots" ]; then
    # Base app capsules, then the demo app's (the same art with the DEMO sticker).
    for kind in base demo; do
        dir=""; extra=()
        if [ "$kind" = demo ]; then dir="demo/"; extra=(--demo); fi
        render "${dir}header_capsule_920x430.png" 7 frost 1300 920,430 2 2 "${extra[@]}"
        render "${dir}small_capsule_462x174.png" 1 lime 700 462,174 2 1 --logo-y=40 "${extra[@]}"
        render "${dir}main_capsule_1232x706.png" 4 ocean 900 1232,706 4 3 "${extra[@]}"
        render "${dir}vertical_capsule_748x896.png" 9 bubblegum 1000 748,896 4 2 --logo-y=24 "${extra[@]}"
        render "${dir}library_capsule_600x900.png" 2 mint 500 600,900 3 2 --logo-y=40 "${extra[@]}"
    done
    render library_hero_3840x1240.png 10 ember 1100 3840,1240 8 0
    render library_logo_1280.png 1 lime 5 1280,360 1 4 --logo-only
fi

if [ "$only" != "capsules" ]; then
    # Gameplay with the HUD, each level in its own skin (6x = 1920x1080).
    render screenshot_1_dark_dungeon.png 1 lime 700 1920,1080 6 0 --hud
    render screenshot_2_sunken_shrine.png 4 ocean 900 1920,1080 6 0 --hud
    render screenshot_3_creepy_catacombs.png 6 crimson 1000 1920,1080 6 0 --hud
    render screenshot_4_frozen_fortress.png 7 frost 1300 1920,1080 6 0 --hud
    render screenshot_5_volcanic_vault.png 10 ember 1100 1920,1080 6 0 --hud
    # The skins screen: RAINBOW and STOPWATCH stay locked silhouettes (--promo).
    "$root/tools/screenshot.sh" --frames 40 --scene res://scenes/skins.tscn --unlock-all --promo --skin=bubblegum >/dev/null
    python3 "$root/tools/upscale_png.py" "$root/.screens/latest.png" "$out_dir/screenshot_6_skins.png" 6 >/dev/null
    echo "wrote screenshot_6_skins.png"
fi
echo "Steam art in $out_dir"
