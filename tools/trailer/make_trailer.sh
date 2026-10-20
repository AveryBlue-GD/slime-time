#!/usr/bin/env bash
# macOS/Linux twin of make_trailer.ps1: renders the vertical trailer drafts (tools/trailer/trailer.json)
# into build/trailer/ (short_<ID>.mp4, short_<ID>_sheet.png, README.md). See docs/marketing/trailer.md.
# Usage: ./tools/trailer/make_trailer.sh [--drafts A,B] [--force] [--only-takes]
# Godot: $GODOT or the usual install (tools/godot.sh's lookup); ffmpeg: $FFMPEG or PATH. The movie
# writer records the game's audio into the file without playing it; the save is never touched.
set -e
root="$(cd "$(dirname "$0")/../.." && pwd)"
py="$(command -v python3 || command -v python)"
exec "$py" "$root/tools/trailer/trailer.py" "$@"
