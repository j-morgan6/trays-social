#!/usr/bin/env bash
set -euo pipefail

# Verify required tools exist
for tool in swiftformat swiftlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Run: brew bundle"
    exit 1
  fi
done

FIX=0
for arg in "$@"; do
  case "$arg" in
    --fix) FIX=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

TARGET="ios/TraysSocial/TraysSocial"

if [ "$FIX" -eq 1 ]; then
  swiftformat "$TARGET"
  swiftlint --fix "$TARGET" || true
  swiftformat "$TARGET"
fi

# Strict report mode — surfaces what CI would fail on.
swiftlint --strict "$TARGET"
