#!/usr/bin/env bash
# install-and-screenshot.sh
#
# One-shot visual-verify helper for the Dopamine Ledger round 2 rebuild.
# Used by `make install` and `make screenshot`.
#
# Two modes:
#   ./install-and-screenshot.sh install-only
#       Boots the simulator, installs the .app, launches it. No screenshot.
#   ./install-and-screenshot.sh screenshot [output.png]
#       install-only, then takes a PNG of the simulator screen.
#
# Why this is a shell script and not Swift:
#   `xcrun simctl` is the only sane way to drive the simulator from
#   outside Xcode, and it lives in shell-land. Keeping it here means
#   one place to set DEVELOPER_DIR, one place to find the .app bundle.
#
# Inherits DEVELOPER_DIR from the Makefile, but sets it defensively
# so direct invocation also works.

set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

MODE="${1:-screenshot}"
OUT="${2:-screenshot.png}"

SCHEME="DopamineLedger"
PROJECT="DopamineLedger.xcodeproj"
SIM_NAME="iPhone 17 Pro Max"
BUNDLE_ID="com.cibercervela.DopamineLedger"

# ---------------------------------------------------------------------
# 1. Find or boot the simulator
# ---------------------------------------------------------------------
DEVICE_UDID="$(
    xcrun simctl list devices available --json \
    | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data["devices"].items():
    for d in devices:
        if d["name"] == "'"$SIM_NAME"'" and d["isAvailable"]:
            print(d["udid"]); sys.exit(0)
sys.exit(1)
'
)" || { echo "Simulator not found: $SIM_NAME"; exit 1; }

STATE="$(xcrun simctl list devices --json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == '$DEVICE_UDID':
            print(d['state']); sys.exit(0)
")"

if [ "$STATE" != "Booted" ]; then
    echo "Booting simulator..."
    xcrun simctl boot "$DEVICE_UDID"
fi

open -a Simulator

# ---------------------------------------------------------------------
# 2. Locate the freshly built .app bundle
# ---------------------------------------------------------------------
APP_PATH="$(
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,name=$SIM_NAME" \
        -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/[[:space:]]BUILT_PRODUCTS_DIR/ {print $2; exit}'
)/$SCHEME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found at $APP_PATH — did you run 'make build' first?"
    exit 1
fi

# ---------------------------------------------------------------------
# 3. Install and launch
# ---------------------------------------------------------------------
echo "Installing $APP_PATH ..."
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null

# Tiny pause so the launch transition finishes before screenshotting.
sleep 1.5

# ---------------------------------------------------------------------
# 4. (Optional) screenshot
# ---------------------------------------------------------------------
if [ "$MODE" = "screenshot" ]; then
    xcrun simctl io "$DEVICE_UDID" screenshot "$OUT"
    echo "Wrote $OUT"
fi
