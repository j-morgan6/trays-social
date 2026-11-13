#!/usr/bin/env bash
# Gives an unsigned TraysSocial archive an ad-hoc signature that carries the
# app's entitlements, so `xcodebuild -exportArchive` can sign it for
# distribution with Apple's cloud-managed certificate and keep them.
# Ad-hoc signing (identity "-") needs no certificate, so CI never creates one.
#
# Usage: scripts/adhoc-sign-archive.sh <path/to/App.xcarchive>
set -euo pipefail

archive="${1:?usage: adhoc-sign-archive.sh <archive>}"
app="$archive/Products/Applications/TraysSocial.app"
entitlements="ios/TraysSocial/TraysSocial/TraysSocial.entitlements"

if [ ! -d "$app" ]; then
  echo "::error::No app bundle at $app"
  exit 1
fi

# The file is applied as-is, so a build-setting reference such as
# $(AppIdentifierPrefix) would reach the signature unexpanded.
if grep -q '\$(' "$entitlements"; then
  echo "::error::$entitlements contains a \$(...) build setting; expand it before ad-hoc signing"
  exit 1
fi

# Only the app itself is signed here. An extension or embedded framework would
# need its own entitlements and signature, so fail loudly rather than ship one
# without them.
for nested in PlugIns Extensions Frameworks Watch; do
  if [ -e "$app/$nested" ]; then
    echo "::error::$app/$nested exists; extend scripts/adhoc-sign-archive.sh to sign nested bundles"
    exit 1
  fi
done

codesign --force --sign - --entitlements "$entitlements" "$app"
echo "Ad-hoc signed $app with $entitlements"
