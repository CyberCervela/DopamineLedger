#!/usr/bin/env bash
# qa/tap.sh — QA-pass helper: tap the booted Simulator at device-point coords.
# Usage: tap.sh <device_pt_x> <device_pt_y> <device_pt_width> <device_pt_height>
# Maps logical device points to screen coordinates of the frontmost Simulator
# window and clicks there via System Events. NOT committed to the app bundle —
# QA tooling only.
set -euo pipefail
DX="$1"; DY="$2"; DW="${3:-440}"; DH="${4:-956}"

osascript <<EOF
tell application "Simulator" to activate
delay 0.3
tell application "System Events"
    tell process "Simulator"
        set w to front window
        set {wx, wy} to position of w
        set {ww, wh} to size of w
        -- Simulator draws the device screen edge-to-edge below the title bar.
        set titleBar to 28
        set contentH to wh - titleBar
        set sx to wx + ($DX / $DW) * ww
        set sy to wy + titleBar + ($DY / $DH) * contentH
        click at {sx, sy}
    end tell
end tell
EOF
sleep 0.8
