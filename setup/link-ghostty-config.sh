#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/ghostty/config.ghostty"
TARGET="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
BACKUP_DIR="$HOME/.dotfiles_backup/ghostty"
DRY_RUN=1
APPLY=0
BACKUP=0
REMOVE=0
changed=0
skipped=0
failed=0
backup_paths=()

usage() {
  cat <<'EOF'
Usage: setup/link-ghostty-config.sh [--dry-run] [--apply] [--backup] [--remove]

Safely manages Ghostty's active config. Default mode is --dry-run.
Use --apply to activate the repository-managed config.
Use --apply --backup to protect and replace an unmanaged active config.
Use --remove to remove only a Ghostty config managed by this repository.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --apply)
      APPLY=1
      DRY_RUN=0
      ;;
    --backup)
      BACKUP=1
      ;;
    --remove)
      REMOVE=1
      DRY_RUN=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$REMOVE" -eq 1 && "$APPLY" -eq 1 ]]; then
  printf 'Use either --apply or --remove, not both.\n' >&2
  exit 2
fi

print_action() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'dry-run  %s\n' "$*"
  else
    printf 'run      %s\n' "$*"
  fi
}

is_managed_link() {
  [[ -L "$TARGET" && "$(readlink "$TARGET")" == "$SOURCE" ]]
}

target_state() {
  if is_managed_link; then
    printf 'repo-managed'
  elif [[ -e "$TARGET" || -L "$TARGET" ]]; then
    printf 'unmanaged'
  else
    printf 'missing'
  fi
}

record_skip() {
  skipped=$((skipped + 1))
  printf 'skip     %s\n' "$*"
}

record_failure() {
  failed=$((failed + 1))
  printf 'failed   %s\n' "$*" >&2
}

backup_target() {
  local timestamp backup_path

  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="$BACKUP_DIR/config.ghostty-$timestamp"

  print_action mkdir -p "$BACKUP_DIR"
  print_action mv "$TARGET" "$backup_path"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$TARGET" "$backup_path"
  fi

  backup_paths+=("$backup_path")
  changed=$((changed + 1))
  printf 'backup   %s\n' "$backup_path"
}

print_summary() {
  local path

  printf '\nSummary: %d changed, %d skipped, %d failed\n' "$changed" "$skipped" "$failed"
  if [[ "${#backup_paths[@]}" -gt 0 ]]; then
    for path in "${backup_paths[@]}"; do
      printf 'Summary: backup %s\n' "$path"
    done
  fi
}

if [[ ! -f "$SOURCE" ]]; then
  printf 'Missing source config: %s\n' "$SOURCE" >&2
  exit 2
fi

printf 'Ghostty config linker\n'
printf 'Mode: %s\n' "$([[ "$REMOVE" -eq 1 ]] && printf remove || ([[ "$DRY_RUN" -eq 1 ]] && printf dry-run || printf apply))"
printf 'Source: %s\n' "$SOURCE"
printf 'Target: %s\n' "$TARGET"
printf 'State: %s\n\n' "$(target_state)"

if [[ "$REMOVE" -eq 1 ]]; then
  if is_managed_link; then
    print_action rm "$TARGET"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rm "$TARGET"
    fi
    changed=$((changed + 1))
    print_summary
    exit 0
  fi

  if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    record_failure "refusing to remove unmanaged active config: $TARGET"
    print_summary
    exit 1
  fi

  record_skip 'nothing to remove'
  print_summary
  exit 0
fi

if is_managed_link; then
  record_skip 'active config already links to repository source'
  print_summary
  exit 0
fi

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  printf 'conflict target exists and is not managed by this repository: %s\n' "$TARGET" >&2

  if [[ "$BACKUP" -ne 1 ]]; then
    if [[ "$APPLY" -eq 1 ]]; then
      record_failure "rerun with --apply --backup to move it to $BACKUP_DIR before linking"
      print_summary
      exit 1
    fi

    record_skip "backup required before apply; rerun with --apply --backup"
    print_summary
    exit 0
  fi

  backup_target
fi

if [[ "$APPLY" -ne 1 ]]; then
  print_action mkdir -p "$(dirname "$TARGET")"
  print_action ln -s "$SOURCE" "$TARGET"
  record_skip 'dry-run only; no files changed'
  print_summary
  exit 0
fi

print_action mkdir -p "$(dirname "$TARGET")"
print_action ln -s "$SOURCE" "$TARGET"

mkdir -p "$(dirname "$TARGET")"
ln -s "$SOURCE" "$TARGET"
changed=$((changed + 1))

print_summary
exit 0
