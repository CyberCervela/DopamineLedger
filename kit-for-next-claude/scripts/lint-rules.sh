#!/usr/bin/env bash
#
# lint-rules.sh — mechanical enforcement of HARD_RULES.md (Dopamine Ledger)
#
# Run before every "READY TO TEST" handoff. Each check is a grep that
# SHOULD return nothing; a match means a hard rule has eroded.
#
# Usage:  bash kit-for-next-claude/scripts/lint-rules.sh [SRC_DIR]
#         (SRC_DIR defaults to the Swift source root, "DopamineLedger")
# Exit:   0 = clean, 1 = at least one rule violated.
#
# NOTE: this repo has a few KNOWN, tracked leaks (see HARD_RULES.md and
# BACKLOG.md → tech debt). The lint reports them on purpose — that's the
# rule made mechanical. The job is "no NEW violations," and clean the
# tracked ones when PixelArt work resumes.

set -uo pipefail

SRC="${1:-DopamineLedger}"
VIEWS="$SRC/Views"
fail=0

report() {
  local desc="$1" hits="$2"
  if [[ -n "$hits" ]]; then
    echo "✗ RULE VIOLATION: $desc"
    echo "$hits" | sed 's/^/    /'
    echo
    fail=1
  else
    echo "✓ $desc"
  fi
}

echo "Running hard-rule lint over: $SRC"
echo

# --- 1. No secret-shaped literals in source (HARD_RULES #1) -----------------
secret_hits=$(grep -rInE \
  "(api[_-]?key|secret|password|token)[\"' ]*[:=][\"' ]*[A-Za-z0-9_\-]{16,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|AIza[0-9A-Za-z_\-]{30,}" \
  "$SRC" --include='*.swift' --include='*.py' --include='*.sh' \
  2>/dev/null || true)
report "No secret-shaped literals in source" "$secret_hits"

# --- 2. No leftover XXX/HACK/--no-verify markers (HARD_RULES #4) -------------
marker_hits=$(grep -rIn "XXX\|HACK\|--no-verify" "$SRC" \
  --include='*.swift' 2>/dev/null || true)
report "No XXX/HACK/--no-verify markers in Swift" "$marker_hits"

# --- 3. No Image(systemName:) outside the resolver (HARD_RULES #6) ----------
#     The resolver and the two theme impls that delegate to it are allowed.
icon_hits=$(grep -rIn "Image(systemName:" "$SRC" --include='*.swift' 2>/dev/null \
  | grep -v -e "IconResolver.swift" -e "/Theme.swift" -e "NeuTheme.swift" \
  || true)
report "No raw Image(systemName:) outside IconResolver/Theme" "$icon_hits"

# --- 4. No Label(systemImage:) literals (HARD_RULES #6) ---------------------
label_hits=$(grep -rIn "systemImage:" "$SRC" --include='*.swift' 2>/dev/null || true)
report "No raw systemImage: labels (route icons through theme)" "$label_hits"

# --- 5. No raw color literals in view code (HARD_RULES #5) ------------------
#     Themes legitimately define Color(red:...); views must not.
if [[ -d "$VIEWS" ]]; then
  color_hits=$(grep -rInE "Color\((red:|hex:)" "$VIEWS" --include='*.swift' 2>/dev/null || true)
  report "No raw color literals in Views/ (use theme.colors)" "$color_hits"
else
  echo "• skipped Views/ color check ($VIEWS not found)"
fi

echo
if [[ "$fail" -eq 0 ]]; then
  echo "All hard-rule checks passed."
else
  echo "Hard-rule lint reported violations above."
  echo "If they are the KNOWN tracked leaks (HARD_RULES.md), that's expected."
  echo "If any are NEW, fix them before handoff."
fi
exit "$fail"
