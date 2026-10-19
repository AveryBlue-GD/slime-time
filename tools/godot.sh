#!/usr/bin/env bash
# macOS/Linux version of godot.ps1: runs Godot, passing all arguments through.
# Example: ./tools/godot.sh --path . --headless --quit
# Looks in $GODOT, then /Applications/Godot.app (the godotengine.org download or
# `brew install --cask godot`), then `godot` on PATH, then (Git Bash on Windows) the winget-installed
# console binary, as tools/godot.ps1 does.
set -e
winget_godot=""
if [ -n "${LOCALAPPDATA:-}" ]; then
    packages="$LOCALAPPDATA/Microsoft/WinGet/Packages"
    if command -v cygpath >/dev/null 2>&1; then packages="$(cygpath -u "$packages")"; fi
    winget_godot="$(ls -1 "$packages"/GodotEngine.GodotEngine*/Godot_v4*_console.exe 2>/dev/null | sort -r | head -n 1 || true)"
fi
for candidate in "${GODOT:-}" "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$(command -v godot || true)" "$winget_godot"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        exec "$candidate" "$@"
    fi
done
echo "Godot not found. Install Godot 4.7.2 into /Applications (Windows: winget install GodotEngine.GodotEngine), or set GODOT=/path/to/Godot." >&2
exit 1
