#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

repo=.
remote_url=

usage() {
  cat <<'USAGE'
Usage: detect_platform.sh [--repo <path>] [--remote-url <url>]

Detect the remote VCS platform from a repository or explicit remote URL.
Prints one of: github, gitlab
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      repo=$2
      shift 2
      ;;
    --remote-url)
      remote_url=$2
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

if [[ -z "$remote_url" ]]; then
  repo=$(resolve_repo_root "$repo")
  remote_url=$(origin_url "$repo")
fi

case "$remote_url" in
  *github.com* )
    printf 'github\n'
    ;;
  *gitlab* )
    printf 'gitlab\n'
    ;;
  * )
    die "unsupported remote platform: $remote_url"
    ;;
esac
