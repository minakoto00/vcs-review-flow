#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/skills/review-pr/scripts/cluster_review_issues.sh"
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

fixture_file="$TMP_DIR/review-comments.json"
cat >"$fixture_file" <<'JSON'
{
  "code_review_comments": {
    "count": 10,
    "items": [
      {
        "id": "c1",
        "thread_id": "t-resolved",
        "thread_state": "resolved",
        "thread_resolved": true,
        "path": "src/app.ts",
        "body": "This is already resolved.",
        "cluster_key": "resolved-thread"
      },
      {
        "id": "c2",
        "thread_id": "t-rename-1",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "src/app.ts",
        "body": "Rename this helper.",
        "cluster_key": "rename-helper"
      },
      {
        "id": "c3",
        "thread_id": "t-rename-2",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "src/utils.ts",
        "body": "The helper name is still misleading.",
        "cluster_key": "rename-helper"
      },
      {
        "id": "c4",
        "thread_id": "t-logging",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "src/logger.ts",
        "body": "Trim this log noise.",
        "cluster_key": "log-noise"
      },
      {
        "id": "c5",
        "thread_id": "t-null",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "src/parser.ts",
        "body": "Guard null input here.",
        "cluster_key": "null-guard"
      },
      {
        "id": "c6",
        "thread_id": "t-docs",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "README.md",
        "body": "Document this flag.",
        "cluster_key": "docs-flag"
      },
      {
        "id": "c7",
        "thread_id": "t-outdated",
        "thread_state": "outdated",
        "thread_resolved": false,
        "thread_outdated": true,
        "path": "src/legacy.ts",
        "body": "This older thread still needs checking.",
        "cluster_key": "legacy-check"
      },
      {
        "id": "c8",
        "thread_id": "t-test",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "tests/app.test.ts",
        "body": "Cover the retry path.",
        "cluster_key": "retry-test"
      },
      {
        "id": "c9",
        "thread_id": "t-config",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "config/app.yml",
        "body": "Move this flag to config.",
        "cluster_key": "config-flag"
      },
      {
        "id": "c10",
        "thread_id": "t-error",
        "thread_state": "unresolved",
        "thread_resolved": false,
        "path": "src/errors.ts",
        "body": "Use a typed error here.",
        "cluster_key": "typed-error"
      }
    ]
  }
}
JSON

output=$(bash "$SCRIPT" --input "$fixture_file")

assert_eq "1" "$(printf '%s' "$output" | jq -r '.excluded_resolved_threads.count')" "resolved threads are excluded"
assert_eq "9" "$(printf '%s' "$output" | jq -r '.active_review_comments.count')" "only unresolved and outdated comments remain"
assert_eq "8" "$(printf '%s' "$output" | jq -r '.active_review_comments.state_counts.unresolved')" "unresolved comment count"
assert_eq "1" "$(printf '%s' "$output" | jq -r '.active_review_comments.state_counts.outdated')" "outdated comment count"
assert_eq "8" "$(printf '%s' "$output" | jq -r '.issue_clusters.count')" "10 comments collapse into 8 issue clusters after resolved exclusion"
assert_eq "2" "$(printf '%s' "$output" | jq -r '.issue_clusters.items[] | select(.cluster_id == "rename-helper") | .comment_count')" "rename helper cluster groups two comments"
assert_eq "unresolved" "$(printf '%s' "$output" | jq -r '.issue_clusters.items[] | select(.cluster_id == "rename-helper") | .thread_states[0]')" "rename helper cluster preserves unresolved state"
assert_eq "outdated" "$(printf '%s' "$output" | jq -r '.issue_clusters.items[] | select(.cluster_id == "legacy-check") | .thread_states[0]')" "outdated threads remain in clustering input"

printf 'PASS\n'
