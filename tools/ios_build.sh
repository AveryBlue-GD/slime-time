#!/usr/bin/env bash
# Builds the full game for a personal iPhone install (free Apple ID) and puts it on the plugged-in iPhone.
#   ./tools/ios_build.sh [TEAM_ID]
#   SKIP_DEMO=1 ./tools/ios_build.sh   the full game with the save past the demo's levels (test build)
#   DEMO_END=1 ./tools/ios_build.sh    the demo ("iOS Demo": its own app, Dry Trying Demo, beside the full
#                                      game) starting on its last level, so one chalice opens the end screen
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
PRESET="iOS" OUT="build/ios" APP="DryTrying" DERIVED="build/ios-derived"
# DEMO_END=1: the demo preset plus the test feature demo_end_test (Progress.DEMO_END_TEST_FEATURE).
if [[ "${DEMO_END:-}" == "1" ]]; then
	PRESET="iOS Demo" OUT="build/demo/ios" APP="DryTryingDemo" DERIVED="build/demo/ios-derived"
	awk '/^name="iOS Demo"$/ {ios = 1} ios && /^custom_features="demo"$/ {print "custom_features=\"demo,demo_end_test\""; ios = 0; next} {print}' \
		export_presets.cfg > build/export_presets.cfg.tmp && mv build/export_presets.cfg.tmp export_presets.cfg
fi

rm -rf "$OUT"
mkdir -p "$OUT"
./tools/godot.sh --path . --headless --export-debug "$PRESET" "$OUT/$APP.ipa"
if [[ "$APP" != "DryTrying" ]]; then
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Dry Trying Demo" "$OUT/$APP/$APP-Info.plist"
fi

xcodebuild -project "$OUT/$APP.xcodeproj" -scheme "$APP" -configuration Debug -destination generic/platform=iOS \
	-allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath "$DERIVED" -quiet build

DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && (/connected/ || /available/) {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')
if [[ -z "$DEVICE" ]]; then
	echo "Built, but no iPhone found: plug it in, unlock it, and run this again." >&2
	exit 1
fi
xcrun devicectl device install app --device "$DEVICE" "$DERIVED/Build/Products/Debug-iphoneos/$APP.app"
echo "Installed on the iPhone. Open $( [[ "$APP" == "DryTrying" ]] && echo "Dry Trying" || echo "Dry Trying Demo") on the phone."
