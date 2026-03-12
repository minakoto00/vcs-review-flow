#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

input_path=

usage() {
  cat <<'USAGE'
Usage: cluster_review_issues.sh [--input <path>]

Read normalized review-comment JSON and group unresolved or outdated code-review comments into issue clusters.
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
  def review_comments:
    $payload.code_review_comments.items // [];

  def comment_state($comment):
    $comment.thread_state
    // (if ($comment.thread_resolved // false) then "resolved" else "unresolved" end);

  def cluster_key($comment):
    $comment.cluster_key
    // $comment.issue_key
    // (
      (($comment.path // "") + "::" + ($comment.body // ""))
      | gsub("[[:space:]]+"; " ")
    );

  def resolved_comments:
    review_comments
    | map(select(comment_state(.) == "resolved"));

  def active_comments:
    review_comments
    | map(select(comment_state(.) != "resolved"));

  def issue_clusters:
    active_comments
    | sort_by(cluster_key(.))
    | group_by(cluster_key(.))
    | map(
        . as $cluster_comments
        | {
            cluster_id: cluster_key($cluster_comments[0]),
            comment_count: ($cluster_comments | length),
            comment_ids: ($cluster_comments | map(.id | tostring)),
            thread_ids: ($cluster_comments | map(.thread_id // null) | unique),
            thread_states: ($cluster_comments | map(comment_state(.)) | unique | sort),
            paths: ($cluster_comments | map(.path // "") | unique | sort),
            comments: (
              $cluster_comments
              | map({
                  id: (.id | tostring),
                  thread_id: (.thread_id // null),
                  thread_state: comment_state(.),
                  path: (.path // ""),
                  body: (.body // "")
                })
            )
          }
      );

  {
    excluded_resolved_threads: {
      count: (resolved_comments | map(.thread_id // .id) | unique | length),
      comment_count: (resolved_comments | length),
      thread_ids: (resolved_comments | map(.thread_id // .id) | unique | sort)
    },
    active_review_comments: {
      count: (active_comments | length),
      state_counts: {
        unresolved: (active_comments | map(select(comment_state(.) == "unresolved")) | length),
        outdated: (active_comments | map(select(comment_state(.) == "outdated")) | length)
      }
    },
    issue_clusters: {
      count: (issue_clusters | length),
      items: issue_clusters
    }
  }
'
