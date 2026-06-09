#!/usr/bin/env bash
#
# regen-xcodeproj.sh — single source of truth for regenerating
# ios/TraysSocial/TraysSocial.xcodeproj.
#
# Why this exists: project.yml hardcodes CURRENT_PROJECT_VERSION,
# which means every plain `xcodegen generate` resets the TestFlight
# build number to whatever's in source (was 12 for a long time). On
# trunk-based dev, that meant every regen during the day silently
# undid the manual bump Joseph had to make before archiving.
#
# Fix: derive the build number from `git rev-list --count HEAD` — a
# strictly monotonic integer that increments on every commit. Each
# archive picks up the current commit count, so TestFlight always
# sees a fresh, ordered build number with no manual touching.
#
# Implementation: copy project.yml to a temp spec, substitute the
# build number, then run xcodegen against the temp. Source project.yml
# stays clean; only the generated .xcodeproj reflects the bumped
# value.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/TraysSocial"
SPEC="$PROJECT_DIR/project.yml"
# The temp spec MUST live inside PROJECT_DIR: xcodegen resolves a target's
# relative `sources` against the spec file's own directory, so a spec in
# /tmp makes it look for sources in /tmp and fail validation.
TEMP_SPEC="$PROJECT_DIR/.regen-spec.tmp.yml"

trap 'rm -f "$TEMP_SPEC"' EXIT

if [ ! -f "$SPEC" ]; then
  echo "Error: $SPEC not found." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not found. brew install xcodegen." >&2
  exit 1
fi

BUILD_NUMBER=$(cd "$REPO_ROOT" && git rev-list --count HEAD)
echo "Setting CURRENT_PROJECT_VERSION to $BUILD_NUMBER (git commit count)"

# Substitute on a copy. Source project.yml never changes.
sed "s/^\(        CURRENT_PROJECT_VERSION:\) [0-9][0-9]*/\1 $BUILD_NUMBER/" \
  "$SPEC" > "$TEMP_SPEC"

xcodegen generate --spec "$TEMP_SPEC" --project "$PROJECT_DIR"

echo "Regenerated TraysSocial.xcodeproj with build $BUILD_NUMBER."
