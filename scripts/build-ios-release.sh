#!/usr/bin/env bash
set -euo pipefail

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Missing required tool: xcodebuild. Install Xcode."
  exit 1
fi

xcodebuild \
  -project ios/TraysSocial/TraysSocial.xcodeproj \
  -scheme TraysSocial \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -quiet \
  build
