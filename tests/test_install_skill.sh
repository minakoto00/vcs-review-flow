#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/install-skill.sh"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

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

assert_not_contains() {
  local haystack=$1
  local needle=$2
  local message=$3

  if [[ "$haystack" == *"$needle"* ]]; then
    printf 'assertion failed: %s\nunexpected: %s\n' "$message" "$needle" >&2
    exit 1
  fi
}

test_dry_run_uses_review_pr_skill_dir() {
  local output

  output=$(bash "$SCRIPT" --agent codex --scope user-global --method symlink --dry-run)

  assert_contains "$output" "agent=codex" "dry-run preserves agent"
  assert_contains "$output" "scope=user-global" "dry-run preserves scope"
  assert_contains "$output" "method=symlink" "dry-run preserves method"
  assert_contains "$output" "source_dir=$ROOT_DIR/skills/review-pr" "dry-run uses the review-pr skill directory"
  assert_contains "$output" "target_path=$HOME/.agents/skills/review-pr" "dry-run installs under the review-pr name"
}

test_interactive_mode_returns_clean_stdout() {
  local stdout_file="$TMP_DIR/stdout.txt"
  local stderr_file="$TMP_DIR/stderr.txt"
  local stdout_content
  local stderr_content

  printf '\n\n\n' | bash "$SCRIPT" --dry-run >"$stdout_file" 2>"$stderr_file"

  stdout_content=$(cat "$stdout_file")
  stderr_content=$(cat "$stderr_file")

  assert_contains "$stdout_content" "agent=codex" "interactive mode returns the selected agent"
  assert_contains "$stdout_content" "scope=user-global" "interactive mode returns the selected scope"
  assert_contains "$stdout_content" "method=symlink" "interactive mode returns the selected method"
  assert_not_contains "$stdout_content" "Select target agent" "interactive menus stay off stdout"
  assert_not_contains "$stdout_content" "Select install scope" "interactive scope menus stay off stdout"
  assert_not_contains "$stdout_content" "Select install method" "interactive method menus stay off stdout"
  assert_contains "$stderr_content" "Select target agent" "interactive prompts are still shown to the user"
}

test_dry_run_uses_review_pr_skill_dir
test_interactive_mode_returns_clean_stdout

printf 'PASS\n'
