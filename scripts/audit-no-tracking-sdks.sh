#!/usr/bin/env bash
# Enforces the privacy policy claim that Trays uses no third-party
# tracking SDKs. Exits non-zero if any tracking SDK is detected, so
# the pre-push hook blocks the push.
#
# Adding a tracking SDK requires updating:
#   - priv/legal/privacy.md
#   - docs/app-store-privacy-checklist.md
#   - App Store Connect Nutrition Labels
#   - this script's allowlist (after review)
#
# Patterns are anchored (import statements, package declarations, hex
# lockfile entries) rather than bare substrings so common English
# words like "Branch" or "Adjust" don't trigger false positives.

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# iOS tracking SDK names. Detected via `import <Pkg>` in .swift files
# and as package-name strings in project.yml / Package.swift /
# Package.resolved / *.pbxproj.
IOS_PATTERNS=(
  Firebase
  FirebaseAnalytics
  Amplitude
  Mixpanel
  Segment
  Sentry
  Bugsnag
  Crashlytics
  Adjust
  AppsFlyer
  Branch
  OneSignal
)

# Backend Hex package names. Anchored to {:hex, :<pkg>, in mix.lock.
BACKEND_PATTERNS=(
  sentry
  appsignal
  new_relic_agent
  posthog
  mixpanel
  segment
  amplitude
  bugsnag
)

EXIT=0

echo "Auditing iOS sources for import statements..."
for pat in "${IOS_PATTERNS[@]}"; do
  # `import <Pkg>` in any .swift file
  if command grep -rq -E "^import[[:space:]]+${pat}([[:space:]]|$)" \
       --include="*.swift" ios/TraysSocial/TraysSocial 2>/dev/null; then
    echo "  [FAIL] iOS source imports ${pat} — tracking SDK invalidates privacy policy claim"
    EXIT=1
  fi
done

echo "Auditing iOS package declarations..."
PROJECT_FILES=(
  ios/TraysSocial/project.yml
  ios/TraysSocial/TraysSocial.xcodeproj/project.pbxproj
)
for pat in "${IOS_PATTERNS[@]}"; do
  for file in "${PROJECT_FILES[@]}"; do
    [ -f "$file" ] || continue
    # Match package names quoted (e.g., name = "Sentry") or in pbxproj product/repo paths
    if command grep -qE "[\"/]${pat}[\".]" "$file" 2>/dev/null; then
      echo "  [FAIL] iOS project file ${file} references ${pat} — tracking SDK invalidates privacy policy claim"
      EXIT=1
    fi
  done
done

echo "Auditing backend mix.lock..."
for pat in "${BACKEND_PATTERNS[@]}"; do
  # mix.lock entries look like:  "<pkg>": {:hex, :<pkg>, "1.2.3", ...}
  if command grep -qE "\\{:hex, :${pat}," mix.lock 2>/dev/null; then
    echo "  [FAIL] mix.lock contains :${pat} — tracking SDK invalidates privacy policy claim"
    EXIT=1
  fi
done

if [ "$EXIT" -eq 0 ]; then
  echo "[OK] No tracking SDKs found. Privacy policy 'no third-party tracking' claim is intact."
fi

exit "$EXIT"
