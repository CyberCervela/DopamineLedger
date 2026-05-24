# Makefile — Dopamine Ledger round 2.
#
# All build / test / install / screenshot verbs go through here. Do not
# invent ad-hoc xcodebuild invocations — round 1 ended up with a dozen
# half-working variants. Centralizing here means fixing a build flag
# once fixes it everywhere.
#
# Every target exports DEVELOPER_DIR so xcrun and xcodebuild find Xcode
# even when xcode-select still points at CLT. See TOOLING.md.

SHELL := /bin/bash

# --- Configurable ------------------------------------------------------
PROJECT       := DopamineLedger.xcodeproj
SCHEME        := DopamineLedger
DESTINATION   := platform=iOS Simulator,name=iPhone 17 Pro Max
SIMULATOR     := iPhone 17 Pro Max
BUNDLE_ID     := com.cibercervela.DopamineLedger
SCREENSHOT    := $(CURDIR)/screenshot.png
DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

export DEVELOPER_DIR

# --- Phony targets -----------------------------------------------------
.PHONY: help generate build test install screenshot clean fmt verify-pbxproj

help:
	@echo "Targets:"
	@echo "  make generate         Regenerate project.pbxproj from project.yml (xcodegen)"
	@echo "  make build            Build for the simulator destination"
	@echo "  make test             Run the unit-test target"
	@echo "  make install          Boot simulator, build, install the .app"
	@echo "  make screenshot       install + take a PNG (path: $(SCREENSHOT))"
	@echo "  make verify-pbxproj   Confirm project.yml and project.pbxproj are in sync"
	@echo "  make clean            xcodebuild clean"

# Regenerate the Xcode project from project.yml.
# Requires `brew install xcodegen` (one-time).
generate:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found. Install with: brew install xcodegen"; exit 1; \
	}
	xcodegen generate

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		build

test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)'

# Boot the simulator (idempotent), build, install the .app.
install: build
	@bash scripts/install-and-screenshot.sh install-only

screenshot:
	@bash scripts/install-and-screenshot.sh screenshot "$(SCREENSHOT)"
	@echo "Screenshot saved to: $(SCREENSHOT)"

# Run xcodegen in --use-cache mode and diff. Fast sanity check that
# project.pbxproj wasn't hand-edited.
verify-pbxproj:
	@xcodegen generate --quiet
	@git diff --quiet -- $(PROJECT)/project.pbxproj && \
		echo "project.pbxproj is in sync with project.yml" || \
		(echo "project.pbxproj drift detected. Commit the regenerated version."; exit 1)

clean:
	xcodebuild clean \
		-project $(PROJECT) \
		-scheme $(SCHEME)
