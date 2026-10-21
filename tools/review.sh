#!/usr/bin/env bash
# Walks through everything to check on the Mac, one step at a time (press Enter for the next step).
# Usage: cd ~/slime-time && ./tools/review.sh [step number to start from]
# Opens windows, players and Finder folders; nothing is changed and the real save is never touched.
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root" || exit 1
start="${1:-1}"
n=0

step() {  # title, then the commands run by the caller when step() returns 0
    n=$((n + 1))
    [ "$n" -lt "$start" ] && return 1
    echo
    echo "== $n. $1"
    return 0
}
wait_enter() { read -r -p "   Press Enter for the next step (Ctrl+C stops)... " _; }
need() { [ -e "$1" ] || { echo "   (missing: $1 - run ./tools/marketing/refresh.sh --zh first)"; return 1; }; }

if step "Demo end screen: teaser cards + NOW TRY THE RANDOMIZER IN THE HUB (close the game window when done)"; then
    ./tools/play.sh --dev --demo --scene res://scenes/demo_end.tscn >/dev/null 2>&1
    wait_enter
fi
if step "Normal play: dev mode, play a level or two (close the window when done)"; then
    ./tools/play.sh --dev >/dev/null 2>&1
    wait_enter
fi
if step "Steam art: capsules, library hero + logo, 6 screenshots (Rainbow / Stopwatch only as silhouettes in screenshot 6)"; then
    need build/promo/steam && open build/promo/steam && open build/promo/steam/demo
    wait_enter
fi
if step "Shorts (English): A, B, C with music"; then
    for f in build/trailer/short_A_music.mp4 build/trailer/short_B_music.mp4 build/trailer/short_C_music.mp4; do
        need "$f" && open "$f"
    done
    wait_enter
fi
if step "Shorts (Chinese captions): A, B, C with music"; then
    for f in build/trailer/short_A_zh_music.mp4 build/trailer/short_B_zh_music.mp4 build/trailer/short_C_zh_music.mp4; do
        need "$f" && open "$f"
    done
    wait_enter
fi
if step "Music mockups: hub loops and trailer tracks"; then
    need build/music && open build/music
    wait_enter
fi
if step "Web demo in the browser (it stops when you press Enter)"; then
    if need build/demo/web/index.html; then
        python3 -m http.server -d build/demo/web 8000 >/dev/null 2>&1 &
        server=$!
        sleep 1
        open http://localhost:8000
        wait_enter
        kill "$server" 2>/dev/null
    fi
fi
if step "Docs: Steam setup, web size, marketing index"; then
    open docs/steam-setup.md docs/web-size.md docs/marketing/README.md
    wait_enter
fi
if step "All automatic tests (about 4 minutes; the last line should say failed: 0)"; then
    ./tools/test_all.sh
    echo "   (a speed check like test_descent can fail when the Mac is busy: rerun it alone with ./tools/test_all.sh -j 1 <name>)"
fi
echo
echo "Done. Tell me in the thread what looked wrong, if anything."
