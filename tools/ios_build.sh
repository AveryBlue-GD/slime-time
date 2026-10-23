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

# (the build stamp's commit, below: + = uncommitted changes; read before this script edits anything)
COMMIT="$(git rev-parse --short HEAD)"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
	COMMIT="$COMMIT+"
fi
# The committed preset keeps its placeholder team; fill the real one for this build only.
mkdir -p build
cp export_presets.cfg build/export_presets.cfg.bak
cp project.godot build/project.godot.bak
trap 'mv build/export_presets.cfg.bak export_presets.cfg; mv build/project.godot.bak project.godot' EXIT
sed -i '' "s/^application\/app_store_team_id=\"ABCDE12345\"$/application\/app_store_team_id=\"$TEAM\"/" export_presets.cfg
# The build stamp (owner, 2026-10-23: tell builds apart on the phone): commit (+ = uncommitted changes), time and which
# app, as this build's application/config/version (the title screen shows it, top left; nothing in other builds); the
# bundle version is the build time (xcrun devicectl device info apps lists it).
APP_TAG="FULL"
[[ "${SKIP_DEMO:-}" == "1" ]] && APP_TAG="FULL SKIP"
[[ "${DEMO_END:-}" == "1" ]] && APP_TAG="DEMO END"
STAMP="$COMMIT $(date +%m-%d) $(date +%H:%M) $APP_TAG"
BUILD_NO="$(date +%Y%m%d).$(date +%H%M)"
awk -v stamp="$STAMP" '{print} /^\[application\]$/ {print ""; print "config/version=\"" stamp "\""}' project.godot > build/project.godot.tmp \
	&& mv build/project.godot.tmp project.godot
sed -i '' "s/^application\/version=\"1\"$/application\/version=\"$BUILD_NO\"/" export_presets.cfg
echo "Build: $STAMP (bundle version $BUILD_NO)"
# SKIP_DEMO=1: a test build whose save starts past the demo's levels (Progress.skip_demo_levels).
if [[ "${SKIP_DEMO:-}" == "1" ]]; then
	awk '/^name="iOS"$/ {ios = 1} ios && /^custom_features=""$/ {print "custom_features=\"skip_demo\""; ios = 0; next} {print}' \
		export_presets.cfg > build/export_presets.cfg.tmp && mv build/export_presets.cfg.tmp export_presets.cfg
fi

rm -rf build/ios
mkdir -p build/ios
./tools/godot.sh --path . --headless --export-debug "iOS" build/ios/DryTrying.ipa

rm -rf build/ios-derived/Build/Products  # (never an old app: the install below is this build)
xcodebuild -project build/ios/DryTrying.xcodeproj -scheme DryTrying -configuration Debug -destination generic/platform=iOS \
	-allowProvisioningUpdates -allowProvisioningDeviceRegistration -derivedDataPath build/ios-derived -quiet build

DEVICE=$(xcrun devicectl list devices 2>/dev/null | awk '/physical/ && (/connected/ || /available/) {for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) {print $i; exit}}')
if [[ -z "$DEVICE" ]]; then
	echo "Built, but no iPhone found: plug it in, unlock it, and run this again." >&2
	exit 1
fi
xcrun devicectl device install app --device "$DEVICE" build/ios-derived/Build/Products/Debug-iphoneos/DryTrying.app
echo "Installed on the iPhone. Open Dry Trying on the phone."
