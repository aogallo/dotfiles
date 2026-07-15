#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/nvim"
TARGET="$HOME/.config/nvim"
BACKUP_DIR="$HOME/.dotfiles_backup"
OBSIDIAN_NOTES_DIR_DEFAULT="${OBSIDIAN_NOTES_DIR:-$HOME/dev/notes}"
DRY_RUN=1
BACKUP=0
REMOVE=0

usage() {
  cat <<'EOF'
Usage: setup/link-nvim-config.sh [--dry-run] [--apply] [--backup] [--remove]

Safely manages the ~/.config/nvim symlink for this repository.

Default mode is --dry-run. Use --apply to create or remove links.
Use --backup with --apply to move an existing conflicting target before linking.
Use --remove with --apply to remove only the symlink managed by this repository.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --apply)
      DRY_RUN=0
      ;;
    --backup)
      BACKUP=1
      ;;
    --remove)
      REMOVE=1
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

backup_target() {
  local timestamp backup_path
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_path="$BACKUP_DIR/nvim-$timestamp"

  print_action mkdir -p "$BACKUP_DIR"
  print_action mv "$TARGET" "$backup_path"

  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$TARGET" "$backup_path"
  fi

  printf 'backup   %s\n' "$backup_path"
}

if [[ ! -d "$SOURCE" ]]; then
  printf 'Missing source directory: %s\n' "$SOURCE" >&2
  exit 2
fi

printf 'Neovim config linker\n'
printf 'Mode: %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf dry-run || printf apply)"
printf 'Source: %s\n' "$SOURCE"
printf 'Target: %s\n\n' "$TARGET"

if [[ "$REMOVE" -eq 1 ]]; then
  if is_managed_link; then
    print_action rm "$TARGET"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      rm "$TARGET"
    fi
    printf 'Summary: managed Neovim symlink removed\n'
    exit 0
  fi

  if [[ -e "$TARGET" || -L "$TARGET" ]]; then
    printf 'Refusing to remove unmanaged target: %s\n' "$TARGET" >&2
    exit 1
  fi

  printf 'Summary: nothing to remove\n'
  exit 0
fi

if is_managed_link; then
  printf 'ok       target already links to source\n'
  print_action mkdir -p "$OBSIDIAN_NOTES_DIR_DEFAULT"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$OBSIDIAN_NOTES_DIR_DEFAULT"
  fi
  printf 'Summary: no changes needed\n'
  printf 'Summary: Obsidian notes directory %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf planned || printf ready)"
  exit 0
fi

if [[ -e "$TARGET" || -L "$TARGET" ]]; then
  printf 'conflict target exists and is not managed by this repository: %s\n' "$TARGET" >&2

  if [[ "$BACKUP" -ne 1 ]]; then
    printf 'hint     rerun with --backup to move it to %s before linking\n' "$BACKUP_DIR" >&2
    printf 'Summary: no changes made\n'
    exit 1
  fi

  backup_target
fi

print_action mkdir -p "$(dirname "$TARGET")"
print_action ln -s "$SOURCE" "$TARGET"
print_action mkdir -p "$OBSIDIAN_NOTES_DIR_DEFAULT"

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$(dirname "$TARGET")"
  ln -s "$SOURCE" "$TARGET"
  mkdir -p "$OBSIDIAN_NOTES_DIR_DEFAULT"
fi

printf 'Summary: Neovim config link %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf planned || printf created)"
printf 'Summary: Obsidian notes directory %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf planned || printf ready)"
