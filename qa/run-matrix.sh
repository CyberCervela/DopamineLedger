#!/usr/bin/env bash
# qa/run-matrix.sh — drives the QAScreenshotWalk harness through one cell of the
# resubmission visual matrix: <device> x <theme> x <appearance> x <language>.
# QA tooling only; not part of the app.
#
# Usage: run-matrix.sh "<sim name>" <devtag> <theme:neu|system> <scheme tag> \
#                      <appearance:light|dark> [language] [extra TEST_RUNNER env]
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

SIM="$1"; DEVTAG="$2"; THEME="$3"; SCHEMETAG="$4"; APPEARANCE="$5"; LANG_CODE="${6:-en}"
BUNDLE=com.cibercervela.DopamineLedger
REPO="$(cd "$(dirname "$0")/.." && pwd)"

UDID="$(xcrun simctl list devices available --json | python3 -c "
import json,sys
for r,ds in json.load(sys.stdin)['devices'].items():
    for d in ds:
        if d['name'] == '''$SIM''' and d['isAvailable']: print(d['udid']); sys.exit()
sys.exit(1)")"

xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl ui "$UDID" appearance "$APPEARANCE"
# Theme + in-app language are plain UserDefaults — set them before launch so the
# harness photographs the right configuration without driving the pickers.
xcrun simctl spawn "$UDID" defaults write "$BUNDLE" themeId -string "$THEME" 2>/dev/null || true
xcrun simctl spawn "$UDID" defaults write "$BUNDLE" languageCode -string "$LANG_CODE" 2>/dev/null || true

env TEST_RUNNER_DL_QA_DIR="$REPO/qa/resubmission" \
    TEST_RUNNER_DL_QA_DEVICE="$DEVTAG" \
    TEST_RUNNER_DL_QA_THEME="$THEME" \
    TEST_RUNNER_DL_QA_SCHEME="$SCHEMETAG" \
    ${7:+TEST_RUNNER_$7} \
xcodebuild test \
  -project "$REPO/DopamineLedger.xcodeproj" -scheme DopamineLedgerUITests \
  -destination "id=$UDID" \
  -only-testing:DopamineLedgerUITests/QAScreenshotWalk/test01CoreScreens \
  2>&1 | grep -E "Test Case.*(passed|failed)" | tail -2
