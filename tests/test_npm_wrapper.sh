#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/bin/skills.js"

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3

  if [[ "$expected" != "$actual" ]]; then
    printf 'assertion failed: %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_contains() {
  local haystack=$1
  local needle=$2
  local message=$3

  if [[ "$haystack" != *"$needle"* ]]; then
    printf 'assertion failed: %s\nmissing: %s\n' "$message" "$needle" >&2
    exit 1
  fi
}

test_wrapper_dry_run_targets_skills_cli_install() {
  local output

  output=$(node "$SCRIPT" install review-pr --dry-run)

  assert_contains "$output" "npx" "wrapper emits an npx command"
  assert_contains "$output" "skills add minakoto00/vcs-review-flow --skill review-pr" "wrapper targets the canonical skills install command"
}

test_wrapper_rejects_unknown_skill() {
  local output
  local status=0

  output=$(node "$SCRIPT" install unknown-skill --dry-run 2>&1) || status=$?

  assert_eq "1" "$status" "wrapper exits non-zero for unsupported skills"
  assert_contains "$output" "unsupported skill" "wrapper explains unsupported skill names"
}

test_wrapper_dry_run_targets_skills_cli_install
test_wrapper_rejects_unknown_skill

printf 'PASS\n'
