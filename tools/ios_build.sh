#!/usr/bin/env bash
# Builds the full game for a personal iPhone install (free Apple ID) and puts it on the plugged-in iPhone.
#   ./tools/ios_build.sh [TEAM_ID]
# TEAM_ID (10 characters) defaults to the Personal Team Xcode signed in with (Xcode > Settings > Accounts).
# Needs Xcode, the phone plugged in, unlocked and in Developer Mode. Run it again every 7 days to renew the install
# (the save stays). Steps for the phone: docs/ios-personal-install.md
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM="${1:-}"
if [[ -z "$TEAM" ]]; then
	TEAM=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
		| grep -m1 -E '^\s*teamID = ' | sed -E 's/.*teamID = "?([A-Z0-9]+)"?;/\1/' || true)
fi
if [[ -z "$TEAM" ]]; then
	echo "No Apple ID team found: open Xcode > Settings > Accounts and sign in, then run this again." >&2
	exit 1
fi
echo "Team: $TEAM"

# The committed preset keeps its placeholder team; fill the real one for this build only.
mkdir -p build
cp export_presets.cfg build/export_presets.cfg.bak
trap 'mv build/export_presets.cfg.bak export_presets.cfg' EXIT
sed -i '' "s/^application\/app_store_team_id=\"ABCDE12345\"$/application\/app_store_team_id=\"$TEAM\"/" export_presets.cfg
# SKIP_DEMO=1: a test build whose save starts past the demo's levels (Progress.skip_demo_levels).
if [[ "${SKIP_DEMO:-}" == "1" ]]; then
	awk '/^name="iOS"$/ {ios = 1} ios && /^custom_features=""$/ {print "custom_features=\"skip_demo\""; ios = 0; next} {print}' \
		export_presets.cfg > build/export_presets.cfg.tmp && mv build/export_presets.cfg.tmp export_presets.cfg
fi

rm -rf build/ios
mkdir -p build/ios
./tools/godot.sh --path . --headless --export-debug "iOS" build/ios/DryTrying.ipa

xcodebuild -project build/ios/DryTrying.xcodeproj -scheme DryTrying -configuration Debug -destination generic/platform=iOS \
	-allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build/ios-derived -quiet build

DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && (/connected/ || /available/) {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')
if [[ -z "$DEVICE" ]]; then
	echo "Built, but no iPhone found: plug it in, unlock it, and run this again." >&2
	exit 1
fi
xcrun devicectl device install app --device "$DEVICE" build/ios-derived/Build/Products/Debug-iphoneos/DryTrying.app
echo "Installed on the iPhone. Open Dry Trying on the phone."
