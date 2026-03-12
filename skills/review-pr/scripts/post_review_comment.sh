#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.
platform=
number=
body_file=
dry_run=false

usage() {
  cat <<'USAGE'
Usage: post_review_comment.sh --repo <path> --number <id> --body-file <file> [--platform <github|gitlab>] [--dry-run]

Post a change plan and patch guidance comment to a GitHub PR or GitLab MR.
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
    --body-file)
      body_file=$2
      shift 2
      ;;
    --dry-run)
      dry_run=true
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

repo=$(resolve_repo_root "$repo")
[[ -n "$number" ]] || die "--number is required"
[[ -n "$body_file" ]] || die "--body-file is required"
[[ -f "$body_file" ]] || die "body file not found: $body_file"

if [[ -z "$platform" ]]; then
  platform=$("$SCRIPT_DIR/detect_platform.sh" --repo "$repo")
fi

if [[ "$dry_run" == true ]]; then
  print_kv platform "$platform"
  print_kv repo_root "$repo"
  print_kv number "$number"
  print_kv body_file "$body_file"
  exit 0
fi

cd "$repo"

case "$platform" in
  github)
    require_cmd gh
    gh pr comment "$number" --body-file "$body_file"
    ;;
  gitlab)
    require_cmd glab
    glab mr note "$number" --message "$(cat "$body_file")"
    ;;
  *)
    die "unsupported platform: $platform"
    ;;
esac

print_kv platform "$platform"
print_kv number "$number"
print_kv body_file "$body_file"
