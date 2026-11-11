#!/usr/bin/env bash
#
# test-regen-xcodeproj.sh — checks scripts/regen-xcodeproj.sh without Xcode.
#
# A stub `xcodegen` goes first on PATH. It copies the temp spec the regen
# script hands it and logs its arguments, and never writes the .xcodeproj,
# so no tracked file changes. The checks:
#
#   - With no argument the spec and stdout are exactly what the script
#     produced before it took an argument. Local archives and the CI Beta
#     upload depend on that default.
#   - With a suffix the build number is "<commit count>.<suffix>", quoted so
#     YAML keeps it a string (unquoted, 395.10 would parse as the float 395.1).
#   - A bad suffix or a second argument exits non-zero, prints usage, never
#     runs xcodegen and leaves no temp spec behind.
#
# Run from anywhere: bash scripts/test-regen-xcodeproj.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGEN="$REPO_ROOT/scripts/regen-xcodeproj.sh"
PROJECT_DIR="$REPO_ROOT/ios/TraysSocial"
SPEC="$PROJECT_DIR/project.yml"
TEMP_SPEC="$PROJECT_DIR/.regen-spec.tmp.yml"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUB_DIR="$WORK/bin"
mkdir -p "$STUB_DIR"
cat > "$STUB_DIR/xcodegen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$CAPTURE_DIR/args.log"
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--spec" ]; then
    cp "$2" "$CAPTURE_DIR/spec.yml"
    shift
  fi
  shift
done
STUB
chmod +x "$STUB_DIR/xcodegen"

COUNT="$(cd "$REPO_ROOT" && git rev-list --count HEAD)"
FAILURES=0

fail() {
  echo "FAIL: $*" >&2
  FAILURES=$((FAILURES + 1))
}

# Runs the regen script with the stub on PATH and the given arguments.
# Leaves stdout, stderr, the exit status and anything the stub captured in
# a fresh $CAPTURE_DIR.
run_regen() {
  CAPTURE_DIR="$WORK/run-$RANDOM-$RANDOM"
  mkdir -p "$CAPTURE_DIR"
  set +e
  CAPTURE_DIR="$CAPTURE_DIR" PATH="$STUB_DIR:$PATH" \
    "$REGEN" "$@" > "$CAPTURE_DIR/stdout" 2> "$CAPTURE_DIR/stderr"
  STATUS=$?
  set -e
}

# The substitution the script performed before it took an argument, applied
# to project.yml, with $1 as the replacement value.
legacy_spec() {
  sed "s/^\(        CURRENT_PROJECT_VERSION:\) [0-9][0-9]*/\1 $1/" "$SPEC"
}

# Sanity: exactly one line for the substitution to hit, so a spec that came
# out unchanged would be a real failure rather than a vacuous pass.
matches="$(grep -c '^        CURRENT_PROJECT_VERSION: [0-9][0-9]*' "$SPEC" || true)"
if [ "$matches" != "1" ]; then
  fail "project.yml has $matches CURRENT_PROJECT_VERSION lines at the expected indent, expected 1"
fi

# --- No argument: byte-identical to the old behaviour -----------------------
run_regen
if [ "$STATUS" -ne 0 ]; then
  fail "no argument: exit $STATUS ($(cat "$CAPTURE_DIR/stderr"))"
elif ! cmp -s "$CAPTURE_DIR/spec.yml" <(legacy_spec "$COUNT"); then
  fail "no argument: the spec differs from the legacy substitution"
  diff <(legacy_spec "$COUNT") "$CAPTURE_DIR/spec.yml" >&2 || true
else
  expected_stdout="Setting CURRENT_PROJECT_VERSION to $COUNT (git commit count)
Regenerated TraysSocial.xcodeproj with build $COUNT."
  if [ "$(cat "$CAPTURE_DIR/stdout")" != "$expected_stdout" ]; then
    fail "no argument: stdout changed"
    diff <(printf '%s\n' "$expected_stdout") "$CAPTURE_DIR/stdout" >&2 || true
  fi
  if ! grep -qx "        CURRENT_PROJECT_VERSION: $COUNT" "$CAPTURE_DIR/spec.yml"; then
    fail "no argument: the spec does not carry the plain commit count $COUNT"
  fi
fi

# --- A suffix: "<count>.<suffix>", quoted -----------------------------------
for suffix in 1 10; do
  run_regen "$suffix"
  expected="\"$COUNT.$suffix\""
  if [ "$STATUS" -ne 0 ]; then
    fail "suffix $suffix: exit $STATUS ($(cat "$CAPTURE_DIR/stderr"))"
  elif ! cmp -s "$CAPTURE_DIR/spec.yml" <(legacy_spec "$expected"); then
    fail "suffix $suffix: the spec is not project.yml with CURRENT_PROJECT_VERSION $expected"
    diff <(legacy_spec "$expected") "$CAPTURE_DIR/spec.yml" >&2 || true
  fi
done

# --- Rejected arguments --------------------------------------------------
for bad in 0 01 abc 1.2 -1 ""; do
  run_regen "$bad"
  if [ "$STATUS" -eq 0 ]; then
    fail "suffix '$bad' was accepted"
  fi
  if ! grep -q '^Usage:' "$CAPTURE_DIR/stderr"; then
    fail "suffix '$bad': no usage on stderr"
  fi
  if [ -e "$CAPTURE_DIR/args.log" ]; then
    fail "suffix '$bad': xcodegen ran"
  fi
done

run_regen 1 2
if [ "$STATUS" -eq 0 ]; then
  fail "two arguments were accepted"
fi
if [ -e "$CAPTURE_DIR/args.log" ]; then
  fail "two arguments: xcodegen ran"
fi

if [ -e "$TEMP_SPEC" ]; then
  fail "the temp spec $TEMP_SPEC was left behind"
fi

if [ "$FAILURES" -ne 0 ]; then
  echo "$FAILURES check(s) failed." >&2
  exit 1
fi
echo "regen-xcodeproj.sh: all checks passed (commit count $COUNT)."
