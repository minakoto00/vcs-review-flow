#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.

usage() {
  cat <<'USAGE'
Usage: repo_policy.sh [--repo <path>]

Inspect AGENTS.md and CLAUDE.md, if present, and print the resolved worktree root policy.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo=$2
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

repo=$(resolve_repo_root "$repo")

extract_from_line() {
  local line=$1
  local token=
  local root_token=

  while IFS= read -r token; do
    [[ -n "$token" ]] || continue
    root_token=$token
    if [[ "$token" == ../*/* ]]; then
      root_token="../${token#../}"
      root_token="${root_token%%/*}"
    fi
    if [[ "$root_token" == *worktree* || "$root_token" == *worktrees* ]]; then
      printf '%s\n' "$(expand_path "$root_token" "$repo")"
      return 0
    fi
  done < <(printf '%s\n' "$line" | grep -oE '\.\./[^[:space:]`]+|\./[^[:space:]`]+|/[^[:space:]`]+' || true)

  while IFS= read -r token; do
    token=${token#\`}
    token=${token%\`}
    if [[ "$token" == *worktree* || "$token" == *worktrees* ]]; then
      printf '%s\n' "$(expand_path "$token" "$repo")"
      return 0
    fi
  done < <(printf '%s\n' "$line" | grep -oE '\`[^\`]+\`' || true)

  if [[ "$line" =~ ([A-Za-z0-9._-]+worktree[A-Za-z0-9._-]*)[[:space:]]+folder ]]; then
    printf '%s\n' "$(expand_path "../${BASH_REMATCH[1]}" "$repo")"
    return 0
  fi

  if [[ "$line" =~ \.[/]?worktrees ]]; then
    printf '%s\n' "$(expand_path .worktrees "$repo")"
    return 0
  fi

  if [[ "$line" =~ (^|[^.[:alnum:]_])worktrees([^[:alnum:]_]|$) ]]; then
    printf '%s\n' "$(expand_path worktrees "$repo")"
    return 0
  fi

  return 1
}

extract_policy() {
  local file=$1
  local match
  while IFS= read -r line; do
    match=$(extract_from_line "$line") || continue
    printf '%s\n' "$match"
    return 0
  done < <(grep -i 'worktree' "$file" || true)
  return 1
}

agents_file="$repo/AGENTS.md"
claude_file="$repo/CLAUDE.md"
agents_root=
claude_root=

if [[ -f "$agents_file" ]]; then
  agents_root=$(extract_policy "$agents_file" || true)
fi

if [[ -f "$claude_file" ]]; then
  claude_root=$(extract_policy "$claude_file" || true)
fi

if [[ -n "$agents_root" && -n "$claude_root" && "$agents_root" != "$claude_root" ]]; then
  die "conflicting worktree roots: AGENTS.md=$agents_root CLAUDE.md=$claude_root"
fi

policy_root=${agents_root:-$claude_root}
policy_source=default

if [[ -n "$agents_root" ]]; then
  policy_source=AGENTS.md
fi

if [[ -n "$claude_root" && -z "$agents_root" ]]; then
  policy_source=CLAUDE.md
fi

if [[ -n "$claude_root" && -n "$agents_root" ]]; then
  policy_source=AGENTS.md+CLAUDE.md
fi

if [[ -z "$policy_root" ]]; then
  policy_root=$(expand_path .worktrees "$repo")
fi

print_kv repo_root "$repo"
print_kv policy_worktree_root "$policy_root"
print_kv policy_source "$policy_source"
print_kv agents_file "$agents_file"
print_kv claude_file "$claude_file"
