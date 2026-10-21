#!/usr/bin/env bash
# Builds the Xcode project for a personal iPhone install (full game, free Apple ID).
#   ./tools/ios_build.sh [TEAM_ID]
# TEAM_ID (10 characters, Xcode > Settings > Accounts) is optional: without it the project uses a placeholder and you
# pick your Personal Team in Xcode's Signing & Capabilities tab. Opens build/ios/DryTrying.xcodeproj when done.
# Steps for the phone: docs/ios-personal-install.md
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${1:-}"
if [[ -n "$TEAM" ]]; then
	# Only for this build: the committed preset keeps its placeholder.
	cp export_presets.cfg build/export_presets.cfg.bak 2>/dev/null || { mkdir -p build; cp export_presets.cfg build/export_presets.cfg.bak; }
	trap 'mv build/export_presets.cfg.bak export_presets.cfg' EXIT
	sed -i '' "s/^application\/app_store_team_id=\"ABCDE12345\"$/application\/app_store_team_id=\"$TEAM\"/" export_presets.cfg
fi

rm -rf build/ios
mkdir -p build/ios
./tools/godot.sh --path . --headless --export-debug "iOS" build/ios/DryTrying.ipa
echo "Xcode project: build/ios/DryTrying.xcodeproj"
open build/ios/DryTrying.xcodeproj 2>/dev/null || true
