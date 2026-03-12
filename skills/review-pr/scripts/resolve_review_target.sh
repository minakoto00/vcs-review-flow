#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.
platform=
number=
mode=
json_output=false

usage() {
  cat <<'USAGE'
Usage: resolve_review_target.sh --repo <path> (--latest | --number <id>) [--platform <github|gitlab>] [--json]

Resolve the latest open MR/PR or a specific MR/PR number and print normalized metadata.
Default output is shell-safe key=value lines.
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
      mode=number
      shift 2
      ;;
    --latest)
      mode=latest
      shift
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

repo=$(resolve_repo_root "$repo")
require_cmd jq

if [[ -z "$mode" ]]; then
  die "choose exactly one of --latest or --number"
fi

if [[ -z "$platform" ]]; then
  platform=$("$SCRIPT_DIR/detect_platform.sh" --repo "$repo")
fi

remote_url=$(origin_url "$repo")
repository=$(repository_slug_from_remote "$remote_url")

select_latest_number() {
  local field=$1
  jq -r --arg field "$field" 'sort_by(.updatedAt // .updated_at) | last | .[$field] // empty'
}

emit_kv() {
  local number_value=$1
  local title=$2
  local source_branch=$3
  local target_branch=$4
  local author=$5
  local head_sha=$6
  local updated_at=$7
  local web_url=$8

  print_kv platform "$platform"
  print_kv repository "$repository"
  print_kv number "$number_value"
  print_kv title "$title"
  print_kv source_branch "$source_branch"
  print_kv target_branch "$target_branch"
  print_kv author "$author"
  print_kv head_sha "$head_sha"
  print_kv updated_at "$updated_at"
  print_kv web_url "$web_url"
}

cd "$repo"

case "$platform" in
  github)
    require_cmd gh

    if [[ "$mode" == latest ]]; then
      prs=$(gh pr list --state open --limit 100 --json number,updatedAt)
      number=$(printf '%s' "$prs" | select_latest_number number)
    fi

    [[ -n "$number" ]] || die "no open GitHub pull requests found"

    view=$(gh pr view "$number" --json number,title,headRefName,baseRefName,author,headRefOid,updatedAt,url)
    number_value=$(printf '%s' "$view" | jq -r '.number')
    title=$(printf '%s' "$view" | jq -r '.title')
    source_branch=$(printf '%s' "$view" | jq -r '.headRefName')
    target_branch=$(printf '%s' "$view" | jq -r '.baseRefName')
    author=$(printf '%s' "$view" | jq -r '.author.login // .author.name // "unknown"')
    head_sha=$(printf '%s' "$view" | jq -r '.headRefOid')
    updated_at=$(printf '%s' "$view" | jq -r '.updatedAt')
    web_url=$(printf '%s' "$view" | jq -r '.url')
    ;;
  gitlab)
    require_cmd glab

    if [[ "$mode" == latest ]]; then
      mrs=$(glab mr list --state opened --per-page 100 --output json)
      number=$(printf '%s' "$mrs" | select_latest_number iid)
    fi

    [[ -n "$number" ]] || die "no open GitLab merge requests found"

    view=$(glab mr view "$number" --output json)
    number_value=$(printf '%s' "$view" | jq -r '.iid')
    title=$(printf '%s' "$view" | jq -r '.title')
    source_branch=$(printf '%s' "$view" | jq -r '.source_branch')
    target_branch=$(printf '%s' "$view" | jq -r '.target_branch')
    author=$(printf '%s' "$view" | jq -r '.author.username // .author.name // "unknown"')
    head_sha=$(printf '%s' "$view" | jq -r '.sha')
    updated_at=$(printf '%s' "$view" | jq -r '.updated_at')
    web_url=$(printf '%s' "$view" | jq -r '.web_url')
    ;;
  *)
    die "unsupported platform: $platform"
    ;;
esac

if [[ "$json_output" == true ]]; then
  jq -cn \
    --arg platform "$platform" \
    --arg repository "$repository" \
    --arg number "$number_value" \
    --arg title "$title" \
    --arg source_branch "$source_branch" \
    --arg target_branch "$target_branch" \
    --arg author "$author" \
    --arg head_sha "$head_sha" \
    --arg updated_at "$updated_at" \
    --arg web_url "$web_url" \
    '{platform:$platform,repository:$repository,number:$number,title:$title,source_branch:$source_branch,target_branch:$target_branch,author:$author,head_sha:$head_sha,updated_at:$updated_at,web_url:$web_url}'
else
  emit_kv "$number_value" "$title" "$source_branch" "$target_branch" "$author" "$head_sha" "$updated_at" "$web_url"
fi
