#!/usr/bin/env bash
set -euo pipefail

EXPECTED="git-hooks"
CURRENT=$(git config --get core.hooksPath || echo "")

if [ "$CURRENT" = "$EXPECTED" ]; then
  echo "core.hooksPath already set to $EXPECTED — no change."
elif [ -n "$CURRENT" ] && [ "$CURRENT" != "$EXPECTED" ]; then
  echo "Warning: core.hooksPath is currently set to: $CURRENT"
  echo "Overwriting with: $EXPECTED"
  git config core.hooksPath "$EXPECTED"
else
  git config core.hooksPath "$EXPECTED"
  echo "core.hooksPath set to $EXPECTED"
fi

# Sanity-check that the wrappers exist and are executable
for hook in pre-commit pre-push; do
  if [ ! -x "git-hooks/$hook" ]; then
    echo "Warning: git-hooks/$hook missing or not executable. Run: chmod +x git-hooks/$hook"
  fi
done

echo "iOS pre-commit/pre-push hooks active."
