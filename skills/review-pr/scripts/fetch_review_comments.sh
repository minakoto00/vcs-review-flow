#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.
platform=
number=
json_output=false

usage() {
  cat <<'USAGE'
Usage: fetch_review_comments.sh --repo <path> --number <id> [--platform <github|gitlab>] [--json]

Fetch MR/PR comments and normalize them into code-review comments and discussion comments.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo=$2
      shift 2
      ;;
    --platform)
      platform=$2
      shift 2
      ;;
    --number)
      number=$2
      shift 2
      ;;
    --json)
      json_output=true
      shift
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

[[ -n "$number" ]] || die "--number is required"

repo=$(resolve_repo_root "$repo")
require_cmd jq

if [[ -z "$platform" ]]; then
  platform=$("$SCRIPT_DIR/detect_platform.sh" --repo "$repo")
fi

remote_url=$(origin_url "$repo")
repository=$(repository_slug_from_remote "$remote_url")

normalize_github_comments() {
  local review_comments=$1
  local discussion_comments=$2
  local review_threads=$3

  jq -cn \
    --arg platform "$platform" \
    --arg repository "$repository" \
    --arg number "$number" \
    --argjson review_comments "$review_comments" \
    --argjson discussion_comments "$discussion_comments" \
    --argjson review_threads "$review_threads" \
    '
      def github_thread_lookup:
        (
          $review_threads.data.repository.pullRequest.reviewThreads.nodes // []
        )
        | map(
            . as $thread
            | ($thread.comments.nodes // [])[]
            | {
                key: (.databaseId | tostring),
                value: {
                  thread_id: ($thread.id // null),
                  thread_state: (
                    if ($thread.isResolved // false) then "resolved"
                    elif ($thread.isOutdated // false) then "outdated"
                    else "unresolved"
                    end
                  ),
                  thread_resolved: ($thread.isResolved // false),
                  thread_outdated: ($thread.isOutdated // false)
                }
              }
          )
        | from_entries;

      github_thread_lookup as $thread_lookup
      | (
          $review_comments
          | map(
              (.id | tostring) as $comment_id
              | {
                  id: $comment_id,
                  author: (.user.login // .user.name // "unknown"),
                  body: (.body // ""),
                  path: (.path // ""),
                  start_line: (if .start_line == null then null else (.start_line | tostring) end),
                  line: (if .line == null then "" else (.line | tostring) end),
                  side: (.side // null),
                  start_side: (.start_side // null),
                  subject_type: (.subject_type // null),
                  original_line: (if .original_line == null then null else (.original_line | tostring) end),
                  original_start_line: (if .original_start_line == null then null else (.original_start_line | tostring) end),
                  original_position: (if .original_position == null then null else (.original_position | tostring) end),
                  commit_id: (.commit_id // null),
                  original_commit_id: (.original_commit_id // null),
                  diff_hunk: (.diff_hunk // null),
                  url: (.html_url // ""),
                  created_at: (.created_at // "")
                }
              + ($thread_lookup[$comment_id] // {})
            )
        ) as $all_review
      | ($all_review | map(select((.thread_state // "unresolved") != "resolved"))) as $active
      | ($all_review | map(select((.thread_state // "unresolved") == "resolved"))) as $resolved
      | {
          platform: $platform,
          repository: $repository,
          number: $number,
          code_review_comments: {
            count: ($active | length),
            items: $active
          },
          excluded_resolved_comments: {
            count: ($resolved | length),
            items: $resolved
          },
          discussion_comments: {
            count: ($discussion_comments | length),
            items: ($discussion_comments | map({
              id: (.id | tostring),
              author: (.user.login // .user.name // "unknown"),
              body: (.body // ""),
              url: (.html_url // ""),
              created_at: (.created_at // "")
            }))
          }
        }
    '
}

normalize_gitlab_comments() {
  local discussions=$1

  jq -cn \
    --arg platform "$platform" \
    --arg repository "$repository" \
    --arg number "$number" \
    --argjson discussions "$discussions" \
    '
      def active_notes:
        [
          $discussions[]
          | .notes[]?
          | select((.system // false) | not)
        ];

      def review_notes:
        [
          active_notes[]
          | . as $note
          | $discussions[]
          | select(any(.notes[]?; (.id // null) == ($note.id // null)))
          | . as $discussion
          | $note
          | select(
              (.position // null) != null
              or (.line_code // null) != null
            )
          | . + {
              thread_id: ($discussion.id // null),
              thread_resolved: ($discussion.resolved // false),
              thread_state: (
                if ($discussion.resolved // false) then "resolved"
                else "unresolved"
                end
              ),
              resolved_by: ($discussion.resolved_by // null),
              resolved_at: ($discussion.resolved_at // null)
            }
        ];

      def discussion_notes:
        [
          active_notes[]
          | select(
              (.position // null) == null
              and (.line_code // null) == null
            )
        ];

      def normalize_review_note:
        {
          id: (.id | tostring),
          author: (.author.username // .author.name // "unknown"),
          body: (.body // ""),
          path: (.position.new_path // .position.old_path // ""),
          line: (
            if (.position.new_line // null) != null then (.position.new_line | tostring)
            elif (.position.old_line // null) != null then (.position.old_line | tostring)
            else ""
            end
          ),
          new_path: (.position.new_path // null),
          old_path: (.position.old_path // null),
          new_line: (if (.position.new_line // null) != null then (.position.new_line | tostring) else null end),
          old_line: (if (.position.old_line // null) != null then (.position.old_line | tostring) else null end),
          base_sha: (.position.base_sha // null),
          start_sha: (.position.start_sha // null),
          head_sha: (.position.head_sha // null),
          position_type: (.position.position_type // null),
          line_range: (.position.line_range // null),
          position: (.position // null),
          thread_id: (.thread_id // null),
          thread_state: (.thread_state // "unresolved"),
          thread_resolved: (.thread_resolved // false),
          resolved_by: (.resolved_by // null),
          resolved_at: (.resolved_at // null),
          url: (.url // .web_url // ""),
          created_at: (.created_at // "")
        };

      (review_notes | map(normalize_review_note)) as $all_review
      | ($all_review | map(select(.thread_state != "resolved"))) as $active
      | ($all_review | map(select(.thread_state == "resolved"))) as $resolved
      | {
          platform: $platform,
          repository: $repository,
          number: $number,
          code_review_comments: {
            count: ($active | length),
            items: $active
          },
          excluded_resolved_comments: {
            count: ($resolved | length),
            items: $resolved
          },
          discussion_comments: {
            count: (discussion_notes | length),
            items: (discussion_notes | map({
              id: (.id | tostring),
              author: (.author.username // .author.name // "unknown"),
              body: (.body // ""),
              url: (.url // .web_url // ""),
              created_at: (.created_at // "")
            }))
          }
        }
    '
}

emit_kv() {
  local json=$1
  print_kv platform "$(printf '%s' "$json" | jq -r '.platform')"
  print_kv repository "$(printf '%s' "$json" | jq -r '.repository')"
  print_kv number "$(printf '%s' "$json" | jq -r '.number')"
  print_kv code_review_comment_count "$(printf '%s' "$json" | jq -r '.code_review_comments.count')"
  print_kv excluded_resolved_comment_count "$(printf '%s' "$json" | jq -r '.excluded_resolved_comments.count')"
  print_kv discussion_comment_count "$(printf '%s' "$json" | jq -r '.discussion_comments.count')"
}

cd "$repo"

case "$platform" in
  github)
    require_cmd gh
    review_comments=$(gh api "repos/$repository/pulls/$number/comments")
    discussion_comments=$(gh api "repos/$repository/issues/$number/comments")
    owner=${repository%%/*}
    repo_name=${repository#*/}
    review_threads=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $number: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $number) {
            reviewThreads(first: 100) {
              nodes {
                id
                isResolved
                isOutdated
                comments(first: 100) {
                  nodes {
                    databaseId
                  }
                }
              }
            }
          }
        }
      }
    ' -F owner="$owner" -F repo="$repo_name" -F number="$number")
    normalized=$(normalize_github_comments "$review_comments" "$discussion_comments" "$review_threads")
    ;;
  gitlab)
    require_cmd glab
    encoded_repository=$(jq -nr --arg value "$repository" '$value | @uri')
    discussions=$(glab api "projects/$encoded_repository/merge_requests/$number/discussions" --paginate)
    normalized=$(normalize_gitlab_comments "$discussions")
    ;;
  *)
    die "unsupported platform: $platform"
    ;;
esac

if [[ "$json_output" == true ]]; then
  printf '%s\n' "$normalized"
else
  emit_kv "$normalized"
fi
