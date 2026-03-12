#!/usr/bin/env bash
set -euo pipefail

script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warn: %s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

resolve_repo_root() {
  local repo_arg="${1:-.}"
  git -C "$repo_arg" rev-parse --show-toplevel 2>/dev/null || die "not a git repository: $repo_arg"
}

origin_url() {
  local repo_root=$1
  git -C "$repo_root" remote get-url origin 2>/dev/null || die "repository has no origin remote: $repo_root"
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

print_kv() {
  local key=$1
  local value=${2-}
  printf '%s=%q\n' "$key" "$value"
}

normalize_path() {
  local raw=$1
  python3 - "$raw" <<'PY'
import os
import sys
print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

expand_path() {
  local raw=$1
  local repo_root=$2

  if [[ -z "$raw" ]]; then
    die "cannot expand empty path"
  fi

  if [[ "$raw" == ~* ]]; then
    raw="${raw/#\~/$HOME}"
  fi

  case "$raw" in
    /*)
      normalize_path "$raw"
      ;;
    ./*|../*)
      normalize_path "$repo_root/$raw"
      ;;
    *)
      normalize_path "$raw"
      ;;
  esac
}

sanitize_branch_name() {
  local branch=$1
  branch=${branch//\//-}
  branch=${branch//:/-}
  branch=${branch// /-}
  printf '%s' "$branch"
}

repository_slug_from_remote() {
  local remote_url=$1
  local slug

  slug=$(printf '%s' "$remote_url" | sed -E 's#^[a-z]+://[^/]+/##; s#^git@[^:]+:##; s#\.git$##')
  if [[ -z "$slug" || "$slug" == "$remote_url" ]]; then
    die "unable to derive repository slug from remote: $remote_url"
  fi

  printf '%s' "$slug"
}

load_kv_output() {
  local output=$1
  eval "$output"
}
