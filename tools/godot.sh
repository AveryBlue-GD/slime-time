#!/usr/bin/env bash
# macOS/Linux version of godot.ps1: runs Godot, passing all arguments through.
# Example: ./tools/godot.sh --path . --headless --quit
# Looks in $GODOT, then /Applications/Godot.app (the godotengine.org download or
# `brew install --cask godot`), then `godot` on PATH.
set -e
for candidate in "$GODOT" "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        exec "$candidate" "$@"
    fi
done
echo "Godot not found. Install Godot 4.7.2 into /Applications (or set GODOT=/path/to/Godot)." >&2
exit 1
