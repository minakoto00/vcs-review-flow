#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=./skills/review-pr/scripts/common.sh
source "$SCRIPT_DIR/skills/review-pr/scripts/common.sh"

agent=
scope=
method=
project_root=
conflict_strategy=
dry_run=false

usage() {
  cat <<'USAGE'
Usage: install-skill.sh [--agent codex|claude] [--scope user-global|project-local] [--method symlink|copy] [--project-root <path>] [--conflict replace|backup|cancel] [--dry-run]

Interactive installer for the review-pr skill.
USAGE
}

prompt_with_default() {
  local prompt=$1
  local default_value=$2
  local value
  printf '%s [%s]: ' "$prompt" "$default_value" >&2
  read -r value
  printf '%s' "${value:-$default_value}"
}

choose_option() {
  local prompt=$1
  local default_value=$2
  shift 2
  local options=("$@")
  local answer
  while true; do
    printf '%s\n' "$prompt" >&2
    local index=1
    for option in "${options[@]}"; do
      if [[ "$option" == "$default_value" ]]; then
        printf '  %s. %s (default)\n' "$index" "$option" >&2
      else
        printf '  %s. %s\n' "$index" "$option" >&2
      fi
      index=$((index + 1))
    done
    printf '> ' >&2
    read -r answer
    answer=${answer:-$default_value}
    if [[ "$answer" == "$default_value" ]]; then
      printf '%s\n' "$default_value"
      return 0
    fi
    if [[ "$answer" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#options[@]} )); then
      printf '%s\n' "${options[answer-1]}"
      return 0
    fi
    for option in "${options[@]}"; do
      if [[ "$answer" == "$option" ]]; then
        printf '%s\n' "$option"
        return 0
      fi
    done
    printf 'Invalid choice. Try again.\n' >&2
  done
}

determine_target_root() {
  case "$agent:$scope" in
    codex:user-global)
      printf '%s/.agents/skills\n' "$HOME"
      ;;
    codex:project-local)
      printf '%s/.agents/skills\n' "$project_root"
      ;;
    claude:user-global)
      printf '%s/.claude/skills\n' "$HOME"
      ;;
    claude:project-local)
      printf '%s/.claude/skills\n' "$project_root"
      ;;
    *)
      die "unsupported install target: $agent:$scope"
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      agent=$2
      shift 2
      ;;
    --scope)
      scope=$2
      shift 2
      ;;
    --method)
      method=$2
      shift 2
      ;;
    --project-root)
      project_root=$2
      shift 2
      ;;
    --conflict)
      conflict_strategy=$2
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

if [[ -z "$agent" ]]; then
  agent=$(choose_option "Select target agent" codex codex claude)
fi

if [[ -z "$scope" ]]; then
  scope=$(choose_option "Select install scope" user-global user-global project-local)
fi

if [[ -z "$method" ]]; then
  method=$(choose_option "Select install method" symlink symlink copy)
fi

if [[ "$scope" == project-local ]]; then
  default_root=$(pwd)
  if [[ -z "$project_root" ]]; then
    project_root=$(prompt_with_default "Project root" "$default_root")
  fi
  project_root=$(normalize_path "$project_root")
fi

case "$agent" in
  codex|claude) ;;
  *) die "agent must be codex or claude" ;;
esac

case "$scope" in
  user-global|project-local) ;;
  *) die "scope must be user-global or project-local" ;;
esac

case "$method" in
  symlink|copy) ;;
  *) die "method must be symlink or copy" ;;
esac

source_dir=$(normalize_path "$SCRIPT_DIR/skills/review-pr")
skill_name=review-pr
target_root=$(determine_target_root)
target_path="$target_root/$skill_name"

if [[ "$dry_run" == true ]]; then
  print_kv agent "$agent"
  print_kv scope "$scope"
  print_kv method "$method"
  print_kv source_dir "$source_dir"
  print_kv target_root "$target_root"
  print_kv target_path "$target_path"
  print_kv project_root "$project_root"
  exit 0
fi

mkdir -p "$target_root"

if [[ -e "$target_path" || -L "$target_path" ]]; then
  if [[ -z "$conflict_strategy" ]]; then
    conflict_strategy=$(choose_option "Existing installation found. Choose conflict action" cancel cancel replace backup)
  fi

  case "$conflict_strategy" in
    cancel)
      printf 'Installation cancelled.\n'
      exit 0
      ;;
    replace)
      rm -rf "$target_path"
      ;;
    backup)
      mv "$target_path" "$target_path.bak.$(date +%Y%m%d%H%M%S)"
      ;;
    *)
      die "conflict strategy must be replace, backup, or cancel"
      ;;
  esac
fi

case "$method" in
  symlink)
    ln -s "$source_dir" "$target_path"
    ;;
  copy)
    cp -R "$source_dir" "$target_path"
    ;;
esac

print_kv agent "$agent"
print_kv scope "$scope"
print_kv method "$method"
print_kv target_path "$target_path"
