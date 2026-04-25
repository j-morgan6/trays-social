#!/usr/bin/env bash
set -euo pipefail

# Verify required tools exist
for tool in swiftformat swiftlint; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool. Run: brew bundle"
    exit 1
  fi
done

# Collect staged iOS Swift files (Bash 3.2 compatible — macOS ships 3.2, no mapfile)
FILES=()
while IFS= read -r line; do
  [ -n "$line" ] && FILES+=("$line")
done < <(git diff --cached --name-only --diff-filter=ACMR | grep -E '^ios/.+\.swift$' || true)

if [ ${#FILES[@]} -eq 0 ]; then
  exit 0
fi

# Refuse to run if any of these files have *unstaged* changes alongside staged ones.
UNSTAGED=()
while IFS= read -r line; do
  [ -n "$line" ] && UNSTAGED+=("$line")
done < <(git diff --name-only -- "${FILES[@]}")

if [ ${#UNSTAGED[@]} -gt 0 ]; then
  echo "Refusing to auto-format files that have both staged and unstaged changes:"
  printf '  - %s\n' "${UNSTAGED[@]}"
  echo ""
  echo "Either stash the unstaged changes (git stash -k), commit the file fully, or run"
  echo "scripts/lint-ios.sh manually and re-stage."
  exit 1
fi

# Auto-fix loop: SwiftFormat -> SwiftLint --fix -> SwiftFormat (normalizes whitespace from lint fixes)
swiftformat "${FILES[@]}"
swiftlint --fix --quiet "${FILES[@]}" || true
swiftformat "${FILES[@]}"

# Re-stage the (now fixed) files
git add "${FILES[@]}"

# Report pass: non-strict so warnings don't block commits
if ! swiftlint --quiet "${FILES[@]}"; then
  echo ""
  echo "SwiftLint reported errors. Fix them and re-stage, or run scripts/lint-ios.sh to reproduce."
  exit 1
fi
