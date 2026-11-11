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
#
# Usage: scripts/regen-xcodeproj.sh [suffix]
#
# With no argument the build number is the plain commit count N. This is
# what local dev builds and the CI Beta upload use, and it must not change.
# A manual fallback upload passes 2 (N.2) so it cannot collide with CI's N
# or N.1; docs/ios-release.md section 7.
#
# With a suffix (a positive integer with no leading zero) the build number
# is "N.<suffix>". The CI Release upload passes 1, so a Release build of a
# commit (N.1) never collides with the Beta build of the same commit (N),
# and still sorts between it and the next commit's Beta (N+1). The value
# is quoted in the temp spec so YAML keeps it a string: unquoted, 395.10
# would parse as the float 395.1. Zero and leading zeros are refused
# because App Store Connect compares each component as a number, so 395.0
# would equal 395 and 395.01 would equal 395.1.
#
# A suffixed build number is not an integer, so InfoPlistTests
# (test_buildNumberDidNotRegress) fails against it. Run the tests after a
# plain regen, never after a suffixed one.
#
# scripts/test-regen-xcodeproj.sh checks all of this without Xcode.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/TraysSocial"
SPEC="$PROJECT_DIR/project.yml"
# The temp spec MUST live inside PROJECT_DIR: xcodegen resolves a target's
# relative `sources` against the spec file's own directory, so a spec in
# /tmp makes it look for sources in /tmp and fail validation.
TEMP_SPEC="$PROJECT_DIR/.regen-spec.tmp.yml"

usage() {
  echo "Usage: scripts/regen-xcodeproj.sh [suffix]" >&2
  echo "  suffix: a positive integer with no leading zero; the build number becomes <commit count>.<suffix>" >&2
  exit 2
}

# Validated before anything else runs, so a bad argument never reaches
# xcodegen and never writes a temp spec.
if [ "$#" -gt 1 ]; then
  usage
fi
SUFFIX_GIVEN=0
if [ "$#" -eq 1 ]; then
  SUFFIX_GIVEN=1
  SUFFIX="$1"
  if ! [[ "$SUFFIX" =~ ^[1-9][0-9]*$ ]]; then
    usage
  fi
fi

trap 'rm -f "$TEMP_SPEC"' EXIT

if [ ! -f "$SPEC" ]; then
  echo "Error: $SPEC not found." >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Error: xcodegen not found. brew install xcodegen." >&2
  exit 1
fi

COMMIT_COUNT=$(cd "$REPO_ROOT" && git rev-list --count HEAD)
if [ "$SUFFIX_GIVEN" -eq 1 ]; then
  BUILD_NUMBER="$COMMIT_COUNT.$SUFFIX"
  SPEC_VALUE="\"$BUILD_NUMBER\""
  echo "Setting CURRENT_PROJECT_VERSION to $BUILD_NUMBER (git commit count, suffix $SUFFIX)"
else
  BUILD_NUMBER="$COMMIT_COUNT"
  SPEC_VALUE="$BUILD_NUMBER"
  echo "Setting CURRENT_PROJECT_VERSION to $BUILD_NUMBER (git commit count)"
fi

# Substitute on a copy. Source project.yml never changes.
sed "s/^\(        CURRENT_PROJECT_VERSION:\) [0-9][0-9]*/\1 $SPEC_VALUE/" \
  "$SPEC" > "$TEMP_SPEC"

xcodegen generate --spec "$TEMP_SPEC" --project "$PROJECT_DIR"

echo "Regenerated TraysSocial.xcodeproj with build $BUILD_NUMBER."
