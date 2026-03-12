#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.
remote=origin
source_branch=
head_sha=
dry_run=false

usage() {
  cat <<'USAGE'
Usage: worktree_sync.sh --repo <path> --source-branch <branch> [--head-sha <sha>] [--remote <name>] [--dry-run]

Reuse or create a worktree for the source branch, using AGENTS.md / CLAUDE.md policy when present.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo=$2
      shift 2
      ;;
    --source-branch)
      source_branch=$2
      shift 2
      ;;
    --head-sha)
      head_sha=$2
      shift 2
      ;;
    --remote)
      remote=$2
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

[[ -n "$source_branch" ]] || die "--source-branch is required"
repo=$(resolve_repo_root "$repo")

policy_output=$("$SCRIPT_DIR/repo_policy.sh" --repo "$repo")
load_kv_output "$policy_output"

worktree_name=$(sanitize_branch_name "$source_branch")
worktree_path="$policy_worktree_root/$worktree_name"
action=reused

worktree_exists=false
if git -C "$repo" worktree list --porcelain | grep -F "worktree $worktree_path" >/dev/null 2>&1; then
  worktree_exists=true
elif [[ -d "$worktree_path" && -e "$worktree_path/.git" ]]; then
  worktree_exists=true
fi

if [[ "$worktree_exists" == true ]]; then
  if [[ -n "$(git -C "$worktree_path" status --porcelain)" ]]; then
    die "existing worktree has uncommitted changes: $worktree_path"
  fi
else
  action=created
fi

if [[ "$dry_run" == true ]]; then
  print_kv repo_root "$repo"
  print_kv worktree_path "$worktree_path"
  print_kv worktree_action "$action"
  print_kv source_branch "$source_branch"
  print_kv remote "$remote"
  print_kv head_sha "$head_sha"
  exit 0
fi

mkdir -p "$policy_worktree_root"

git -C "$repo" fetch "$remote" "$source_branch"

git -C "$repo" rev-parse --verify "$remote/$source_branch" >/dev/null 2>&1 || die "remote branch not found: $remote/$source_branch"

if [[ "$worktree_exists" == true ]]; then
  git -C "$worktree_path" checkout "$source_branch"
  git -C "$worktree_path" pull --ff-only "$remote" "$source_branch"
else
  if git -C "$repo" show-ref --verify --quiet "refs/heads/$source_branch"; then
    git -C "$repo" worktree add "$worktree_path" "$source_branch"
  else
    git -C "$repo" worktree add -b "$source_branch" "$worktree_path" "$remote/$source_branch"
  fi
fi

if [[ -n "$head_sha" ]]; then
  git -C "$worktree_path" fetch "$remote" "$source_branch"
  git -C "$worktree_path" cat-file -e "$head_sha^{commit}" >/dev/null 2>&1 || die "head sha not available after fetch: $head_sha"
  git -C "$worktree_path" reset --hard "$head_sha"
else
  git -C "$worktree_path" reset --hard "$remote/$source_branch"
fi

print_kv repo_root "$repo"
print_kv worktree_path "$worktree_path"
print_kv worktree_action "$action"
print_kv source_branch "$source_branch"
print_kv current_head "$(git -C "$worktree_path" rev-parse HEAD)"
