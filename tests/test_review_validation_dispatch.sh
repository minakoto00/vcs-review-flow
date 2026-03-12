#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT_DIR/skills/review-pr/scripts/plan_review_validation_dispatch.sh"
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

write_fixture() {
  local path=$1
  local count=$2

  jq -cn --argjson count "$count" '
    {
      issue_clusters: {
        count: $count,
        items: [
          range(0; $count)
          | {
              cluster_id: ("cluster-" + ((. + 1) | tostring))
            }
        ]
      }
    }
  ' >"$path"
}

assert_balanced_distribution() {
  local output=$1
  local min_count
  local max_count

  min_count=$(printf '%s' "$output" | jq -r '.assignments | map(.cluster_count) | min')
  max_count=$(printf '%s' "$output" | jq -r '.assignments | map(.cluster_count) | max')

  if (( max_count - min_count > 1 )); then
    printf 'assertion failed: assignments are not balanced\nmin: %s\nmax: %s\n' "$min_count" "$max_count" >&2
    exit 1
  fi
}

run_case() {
  local cluster_count=$1
  local expected_subagents=$2
  local fixture="$TMP_DIR/$cluster_count.json"
  local output

  write_fixture "$fixture" "$cluster_count"
  output=$(bash "$SCRIPT" --input "$fixture")

  assert_eq "$cluster_count" "$(printf '%s' "$output" | jq -r '.issue_cluster_count')" "cluster count is preserved for $cluster_count clusters"
  assert_eq "$expected_subagents" "$(printf '%s' "$output" | jq -r '.subagent_count')" "subagent count for $cluster_count clusters"
  assert_eq "$cluster_count" "$(printf '%s' "$output" | jq -r '[.assignments[].cluster_count] | add')" "all clusters are assigned for $cluster_count clusters"
  assert_balanced_distribution "$output"
}

run_case 2 1
run_case 4 2
run_case 6 3
run_case 9 4

printf 'PASS\n'
