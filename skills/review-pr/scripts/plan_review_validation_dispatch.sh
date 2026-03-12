#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

input_path=

usage() {
  cat <<'USAGE'
Usage: plan_review_validation_dispatch.sh [--input <path>]

Read clustered review issues and emit a bounded subagent dispatch plan.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      input_path=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_cmd jq

if [[ -n "$input_path" ]]; then
  input_json=$(cat "$input_path")
else
  input_json=$(cat)
fi

jq -cn --argjson payload "$input_json" '
  def cluster_items:
    $payload.issue_clusters.items // [];

  def planned_subagents($cluster_count):
    if $cluster_count <= 0 then 0
    elif $cluster_count <= 2 then 1
    elif $cluster_count <= 4 then 2
    elif $cluster_count <= 6 then 3
    else 4
    end;

  cluster_items as $clusters
  | ($clusters | length) as $cluster_count
  | planned_subagents($cluster_count) as $subagent_count
  | {
      issue_cluster_count: $cluster_count,
      subagent_count: $subagent_count,
      assignments: [
        range(0; $subagent_count)
        | . as $index
        | {
            subagent_id: ("validation-" + (($index + 1) | tostring)),
            cluster_ids: [
              range(0; $cluster_count)
              | select(. % $subagent_count == $index)
              | $clusters[.].cluster_id
            ]
          }
        | .cluster_count = (.cluster_ids | length)
      ]
    }
'
