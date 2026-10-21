#!/bin/bash
# Claude Code cloud sessions only: installs headless Godot 4.7.2 (Linux) and imports the project,
# so ./tools/godot.sh and ./tools/test_all.sh work. Local sessions are left alone.
set -euo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
    exit 0
fi

version="4.7.2"
dir="$HOME/.local/godot-$version"
bin="$dir/godot"
if [ ! -x "$bin" ]; then
    mkdir -p "$dir"
    zip="$dir/godot.zip"
    url="https://github.com/godotengine/godot/releases/download/$version-stable/Godot_v$version-stable_linux.x86_64.zip"
    # the proxy can drop a long download mid-way: resume it a few times
    for i in 1 2 3 4 5 6; do
        curl -sSL -C - -o "$zip" "$url" && break
        sleep $((i * 2))
    done
    unzip -o -q "$zip" -d "$dir"
    mv "$dir/Godot_v$version-stable_linux.x86_64" "$bin"
    chmod +x "$bin"
    rm -f "$zip"
fi
echo "export GODOT=\"$bin\"" >> "$CLAUDE_ENV_FILE"

# first import (fills .godot/); later sessions reuse it
cd "$CLAUDE_PROJECT_DIR"
if [ ! -d .godot/imported ]; then
    "$bin" --path . --headless --import > /dev/null 2>&1 || true
fi
