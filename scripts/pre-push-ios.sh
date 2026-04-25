#!/usr/bin/env bash
set -euo pipefail

# Verify required tools exist
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Missing required tool: xcodebuild. Install Xcode."
  exit 1
fi

ZERO_SHA="0000000000000000000000000000000000000000"
NEEDS_BUILD=0
PROJECT_YML_CHANGED=0

# Git's pre-push contract: one line per ref being pushed on stdin.
while read -r LOCAL_REF LOCAL_SHA REMOTE_REF REMOTE_SHA; do
  [ "$LOCAL_SHA" = "$ZERO_SHA" ] && continue

  if [ "$REMOTE_SHA" = "$ZERO_SHA" ]; then
    # New branch on remote — no remote SHA to diff against. Compare against the
    # merge-base with the local default branch so we see what this branch
    # introduces, not just the working-tree-vs-HEAD diff (which is empty).
    DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@' || echo "")
    if [ -z "$DEFAULT_BRANCH" ]; then
      if git rev-parse --verify main >/dev/null 2>&1; then
        DEFAULT_BRANCH=main
      elif git rev-parse --verify master >/dev/null 2>&1; then
        DEFAULT_BRANCH=master
      fi
    fi
    BASE=""
    if [ -n "$DEFAULT_BRANCH" ]; then
      BASE=$(git merge-base "$LOCAL_SHA" "$DEFAULT_BRANCH" 2>/dev/null || echo "")
    fi
    if [ -n "$BASE" ] && [ "$BASE" != "$LOCAL_SHA" ]; then
      RANGE="${BASE}..${LOCAL_SHA}"
    else
      # No usable base — fall back to "always build" safety
      NEEDS_BUILD=1
      continue
    fi
  else
    RANGE="${REMOTE_SHA}..${LOCAL_SHA}"
  fi

  CHANGED=$(git diff --name-only "$RANGE" -- ios/ || true)
  if echo "$CHANGED" | grep -qE '\.swift$|/Info\.plist$'; then
    NEEDS_BUILD=1
  fi
  if echo "$CHANGED" | grep -q '/project\.yml$'; then
    PROJECT_YML_CHANGED=1
    NEEDS_BUILD=1
  fi
done

if [ "$NEEDS_BUILD" -eq 0 ]; then
  exit 0
fi

if [ "$PROJECT_YML_CHANGED" -eq 1 ]; then
  echo "Note: project.yml changed in this push. Confirm you ran 'xcodegen generate'"
  echo "from ios/TraysSocial/ and committed the regenerated .xcodeproj before pushing."
fi

echo "Running iOS Release build..."
xcodebuild \
  -project ios/TraysSocial/TraysSocial.xcodeproj \
  -scheme TraysSocial \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -quiet \
  build
