#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
SKILL_DIR="$ROOT_DIR/skills/review-pr"
SCRIPT="$SKILL_DIR/scripts/fetch_review_comments.sh"
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

make_fake_bin() {
  local fake_bin=$1
  mkdir -p "$fake_bin"

  cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == "-C" ]]; then
  repo=$2
  shift 2
else
  repo=$(pwd)
fi

case "${1-} ${2-} ${3-}" in
  "rev-parse --show-toplevel " )
    printf '%s\n' "$repo"
    ;;
  "remote get-url origin" )
    printf 'git@github.com:acme/widgets.git\n'
    ;;
  * )
    printf 'unexpected git invocation: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_bin/git"

  cat >"$fake_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" != "api" ]]; then
  printf 'unexpected gh invocation: %s\n' "$*" >&2
  exit 1
fi

endpoint=${2-}
case "$endpoint" in
  graphql)
    cat <<'JSON'
{
  "data": {
    "repository": {
      "pullRequest": {
        "reviewThreads": {
          "nodes": [
            {
              "id": "PRRT_kwDOAA1",
              "isResolved": true,
              "isOutdated": false,
              "comments": {
                "nodes": [
                  {"databaseId": 101}
                ]
              }
            },
            {
              "id": "PRRT_kwDOAA2",
              "isResolved": false,
              "isOutdated": false,
              "comments": {
                "nodes": [
                  {"databaseId": 102}
                ]
              }
            },
            {
              "id": "PRRT_kwDOAA3",
              "isResolved": false,
              "isOutdated": true,
              "comments": {
                "nodes": [
                  {"databaseId": 103}
                ]
              }
            }
          ]
        }
      }
    }
  }
}
JSON
    ;;
  repos/acme/widgets/pulls/77/comments)
    cat <<'JSON'
[
  {
    "id": 101,
    "user": {"login": "reviewer"},
    "body": "Rename this helper",
    "path": "src/app.ts",
    "start_line": 40,
    "line": 42,
    "side": "RIGHT",
    "start_side": "RIGHT",
    "original_line": 41,
    "original_start_line": 39,
    "original_position": 7,
    "subject_type": "line",
    "commit_id": "headsha123",
    "original_commit_id": "basesha456",
    "diff_hunk": "@@ -39,4 +39,6 @@ export function run() {",
    "html_url": "https://github.com/acme/widgets/pull/77#discussion_r101",
    "created_at": "2026-03-11T08:00:00Z"
  },
  {
    "id": 102,
    "user": {"login": "reviewer"},
    "body": "Split this branch.",
    "path": "src/app.ts",
    "line": 52,
    "side": "RIGHT",
    "commit_id": "headsha123",
    "original_commit_id": "basesha456",
    "html_url": "https://github.com/acme/widgets/pull/77#discussion_r102",
    "created_at": "2026-03-11T08:15:00Z"
  },
  {
    "id": 103,
    "user": {"login": "reviewer"},
    "body": "This older thread may still matter.",
    "path": "src/legacy.ts",
    "line": 8,
    "side": "RIGHT",
    "commit_id": "headsha123",
    "original_commit_id": "basesha456",
    "html_url": "https://github.com/acme/widgets/pull/77#discussion_r103",
    "created_at": "2026-03-11T08:30:00Z"
  }
]
JSON
    ;;
  repos/acme/widgets/issues/77/comments)
    cat <<'JSON'
[
  {
    "id": 202,
    "user": {"login": "maintainer"},
    "body": "Please update the release notes too.",
    "html_url": "https://github.com/acme/widgets/pull/77#issuecomment-202",
    "created_at": "2026-03-11T09:00:00Z"
  }
]
JSON
    ;;
  *)
    printf 'unexpected gh endpoint: %s\n' "$endpoint" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_bin/gh"

  cat >"$fake_bin/glab" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" != "api" ]]; then
  printf 'unexpected glab invocation: %s\n' "$*" >&2
  exit 1
fi

endpoint=${2-}
case "$endpoint" in
  projects/acme%2Fwidgets/merge_requests/55/discussions)
    cat <<'JSON'
[
  {
    "id": "review-thread",
    "individual_note": false,
    "resolved": true,
    "resolved_at": "2026-03-11T10:30:00Z",
    "resolved_by": {
      "username": "lead-reviewer"
    },
    "notes": [
      {
        "id": 301,
        "system": false,
        "body": "Please rename this variable.",
        "created_at": "2026-03-11T10:00:00Z",
        "author": {"username": "gitlab-reviewer"},
        "position": {
          "base_sha": "base123",
          "start_sha": "start456",
          "head_sha": "head789",
          "position_type": "text",
          "new_path": "src/service.kt",
          "old_path": "src/service.kt",
          "new_line": 18,
          "old_line": 17,
          "line_range": {
            "start": {
              "line_code": "abc_17_18",
              "new_line": 17,
              "type": "new"
            },
            "end": {
              "line_code": "abc_17_18",
              "new_line": 18,
              "type": "new"
            }
          }
        },
        "resolvable": true,
        "url": "https://gitlab.example.com/acme/widgets/-/merge_requests/55#note_301"
      }
    ]
  },
  {
    "id": "discussion-thread",
    "individual_note": false,
    "resolved": false,
    "resolved_at": null,
    "resolved_by": null,
    "notes": [
      {
        "id": 302,
        "system": false,
        "body": "Can we summarize this change in the MR description?",
        "created_at": "2026-03-11T11:00:00Z",
        "author": {"username": "gitlab-maintainer"},
        "resolvable": false,
        "url": "https://gitlab.example.com/acme/widgets/-/merge_requests/55#note_302"
      }
    ]
  }
]
JSON
    ;;
  *)
    printf 'unexpected glab endpoint: %s\n' "$endpoint" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fake_bin/glab"
}

test_github_json_split() {
  local fake_bin="$TMP_DIR/fake-bin"
  make_fake_bin "$fake_bin"

  local output
  output=$(PATH="$fake_bin:$PATH" bash "$SCRIPT" --repo "$ROOT_DIR" --platform github --number 77 --json)

  assert_eq "3" "$(printf '%s' "$output" | jq -r '.code_review_comments.count')" "github code review comment count"
  assert_eq "1" "$(printf '%s' "$output" | jq -r '.discussion_comments.count')" "github discussion comment count"
  assert_eq "src/app.ts" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].path')" "github review comment path"
  assert_eq "40" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].start_line')" "github review comment start line"
  assert_eq "RIGHT" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].side')" "github review comment side"
  assert_eq "RIGHT" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].start_side')" "github review comment start side"
  assert_eq "41" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].original_line')" "github review comment original line"
  assert_eq "39" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].original_start_line')" "github review comment original start line"
  assert_eq "7" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].original_position')" "github review comment original position"
  assert_eq "line" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].subject_type')" "github review comment subject type"
  assert_eq "headsha123" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].commit_id')" "github review comment commit id"
  assert_eq "basesha456" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].original_commit_id')" "github review comment original commit id"
  assert_eq "@@ -39,4 +39,6 @@ export function run() {" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].diff_hunk')" "github review comment diff hunk"
  assert_eq "PRRT_kwDOAA1" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_id')" "github resolved thread id"
  assert_eq "resolved" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_state')" "github resolved thread state"
  assert_eq "true" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_resolved')" "github resolved thread flag"
  assert_eq "PRRT_kwDOAA2" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[1].thread_id')" "github unresolved thread id"
  assert_eq "unresolved" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[1].thread_state')" "github unresolved thread state"
  assert_eq "false" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[1].thread_resolved')" "github unresolved thread flag"
  assert_eq "PRRT_kwDOAA3" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[2].thread_id')" "github outdated thread id"
  assert_eq "outdated" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[2].thread_state')" "github outdated thread state"
  assert_eq "true" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[2].thread_outdated')" "github outdated thread flag"
  assert_eq "maintainer" "$(printf '%s' "$output" | jq -r '.discussion_comments.items[0].author')" "github discussion author"
}

test_gitlab_json_split() {
  local fake_bin="$TMP_DIR/fake-bin"
  make_fake_bin "$fake_bin"

  local output
  output=$(PATH="$fake_bin:$PATH" bash "$SCRIPT" --repo "$ROOT_DIR" --platform gitlab --number 55 --json)

  assert_eq "1" "$(printf '%s' "$output" | jq -r '.code_review_comments.count')" "gitlab code review comment count"
  assert_eq "1" "$(printf '%s' "$output" | jq -r '.discussion_comments.count')" "gitlab discussion comment count"
  assert_eq "src/service.kt" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].path')" "gitlab review comment path"
  assert_eq "18" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].new_line')" "gitlab review comment new line"
  assert_eq "17" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].old_line')" "gitlab review comment old line"
  assert_eq "base123" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].base_sha')" "gitlab review comment base sha"
  assert_eq "start456" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].start_sha')" "gitlab review comment start sha"
  assert_eq "head789" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].head_sha')" "gitlab review comment head sha"
  assert_eq "text" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].position_type')" "gitlab review comment position type"
  assert_eq "17" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].line_range.start.new_line')" "gitlab review comment line range start"
  assert_eq "18" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].line_range.end.new_line')" "gitlab review comment line range end"
  assert_eq "review-thread" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_id')" "gitlab review thread id"
  assert_eq "resolved" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_state')" "gitlab review thread state"
  assert_eq "true" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].thread_resolved')" "gitlab review thread resolved flag"
  assert_eq "lead-reviewer" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].resolved_by.username')" "gitlab resolved by username"
  assert_eq "2026-03-11T10:30:00Z" "$(printf '%s' "$output" | jq -r '.code_review_comments.items[0].resolved_at')" "gitlab resolved at"
  assert_eq "gitlab-maintainer" "$(printf '%s' "$output" | jq -r '.discussion_comments.items[0].author')" "gitlab discussion author"
}

test_docs_cover_two_step_scope_flow() {
  grep -q 'fetch_review_comments.sh' "$SKILL_DIR/SKILL.md"
  grep -q 'code-review comments' "$SKILL_DIR/SKILL.md"
  grep -q 'discussion comments' "$SKILL_DIR/SKILL.md"
  grep -qi 'only the approved comment categories' "$SKILL_DIR/SKILL.md"
  grep -qi 'resolved code-review feedback is excluded from review scope by default' "$SKILL_DIR/SKILL.md"
  grep -qi 'outdated code-review feedback' "$SKILL_DIR/SKILL.md"
  grep -qi 'search only within changed files for same-pattern candidates' "$SKILL_DIR/SKILL.md"
  grep -qi 'report same-pattern candidates separately from the original issue clusters' "$SKILL_DIR/SKILL.md"
  grep -qi 'subagents in parallel' "$SKILL_DIR/SKILL.md"
  grep -qi 'verification report' "$SKILL_DIR/SKILL.md"
  grep -qi 'before planning fixes' "$SKILL_DIR/SKILL.md"
  grep -qi 'ask the user whether to include code-review comments in scope' "$ROOT_DIR/README.md"
  grep -qi 'only the approved comment categories' "$ROOT_DIR/README.md"
  grep -qi 'resolved code-review feedback is excluded by default' "$ROOT_DIR/README.md"
  grep -qi 'outdated threads are validated separately from unresolved threads' "$ROOT_DIR/README.md"
  grep -qi 'search only within changed files for same-pattern candidates' "$ROOT_DIR/README.md"
  grep -qi 'same-pattern candidates separately from the original issues' "$ROOT_DIR/README.md"
  grep -qi 'verification report' "$ROOT_DIR/README.md"
  grep -qi 'even when tests do not yet cover them' "$ROOT_DIR/README.md"
  grep -qi 'ask the user whether to include discussion comments in scope' "$SKILL_DIR/docs/examples.md"
  grep -qi 'subagents in parallel' "$SKILL_DIR/docs/examples.md"
  grep -qi 'resolved code-review feedback is excluded by default' "$SKILL_DIR/docs/examples.md"
  grep -qi 'outdated threads are validated separately from unresolved threads' "$SKILL_DIR/docs/examples.md"
  grep -qi 'search only within changed files for same-pattern candidates' "$SKILL_DIR/docs/examples.md"
  grep -qi 'same-pattern candidates are reported separately from the original issues' "$SKILL_DIR/docs/examples.md"
  grep -qi 'confirm the verification report' "$SKILL_DIR/docs/examples.md"
  ! rg -n '/Users/brainco' "$ROOT_DIR/README.md" >/dev/null
}

test_github_json_split
test_gitlab_json_split
test_docs_cover_two_step_scope_flow

printf 'PASS\n'
