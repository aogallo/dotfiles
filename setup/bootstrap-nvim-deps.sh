#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT_DIR/nvim/dependencies.tsv"
MASON_BIN="${MASON:-$HOME/.local/share/nvim/mason}/bin"
DRY_RUN=1
INCLUDE_OPTIONAL=0

usage() {
  cat <<'EOF'
Usage: setup/bootstrap-nvim-deps.sh [--dry-run] [--install] [--include-optional]

Reads nvim/dependencies.tsv and installs missing Neovim tools only when --install is set.
Default mode is --dry-run. Mason-backed tools are reported with instructions; they are not
installed by this shell script yet.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --install)
      DRY_RUN=0
      ;;
    --include-optional)
      INCLUDE_OPTIONAL=1
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

if [[ ! -f "$MANIFEST" ]]; then
  printf 'Missing dependency manifest: %s\n' "$MANIFEST" >&2
  exit 2
fi

has_executable() {
  local executable="$1"
  command -v "$executable" >/dev/null 2>&1 || [[ -x "$MASON_BIN/$executable" ]]
}

run_or_print() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'dry-run  %s\n' "$*"
  else
    printf 'run      %s\n' "$*"
    "$@"
  fi
}

install_dependency() {
  local name="$1"
  local executable="$2"
  local source="$3"
  local install_hint="$4"

  case "$source" in
    homebrew)
      run_or_print brew install "$executable"
      ;;
    pnpm)
      case "$executable" in
        tsgo)
          run_or_print pnpm install -g @typescript/native-preview
          ;;
        *)
          printf 'manual   %s: %s\n' "$name" "$install_hint"
          ;;
      esac
      ;;
    npm)
      case "$executable" in
        bash-language-server)
          run_or_print pnpm add -g bash-language-server
          ;;
        stylelint-lsp)
          run_or_print npm install -g stylelint-lsp
          ;;
        *)
          printf 'manual   %s: %s\n' "$name" "$install_hint"
          ;;
      esac
      ;;
    go)
      case "$executable" in
        gopls)
          run_or_print go install golang.org/x/tools/gopls@latest
          ;;
        *)
          printf 'manual   %s: %s\n' "$name" "$install_hint"
          ;;
      esac
      ;;
    mason/*|mason)
      printf 'manual   %s: install via Mason (%s)\n' "$name" "$install_hint"
      ;;
    curl|external|plugin|*)
      printf 'manual   %s: %s\n' "$name" "$install_hint"
      ;;
  esac
}

printf 'Neovim dependency bootstrap\n'
printf 'Mode: %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf dry-run || printf install)"
printf 'Include optional: %s\n' "$([[ "$INCLUDE_OPTIONAL" -eq 1 ]] && printf yes || printf no)"
printf 'Manifest: %s\n\n' "$MANIFEST"

checked=0
already_present=0
planned=0
skipped_optional=0
manual=0
failed=0

while IFS='|' read -r name executable required source install_hint used_by; do
  [[ -z "${name:-}" || "${name:0:1}" == '#' ]] && continue
  checked=$((checked + 1))

  if has_executable "$executable"; then
    already_present=$((already_present + 1))
    printf 'ok       %s (%s)\n' "$name" "$executable"
    continue
  fi

  if [[ "$required" != 'yes' && "$INCLUDE_OPTIONAL" -ne 1 ]]; then
    skipped_optional=$((skipped_optional + 1))
    printf 'skip     %s (%s) [optional]\n' "$name" "$executable"
    continue
  fi

  planned=$((planned + 1))
  before_status=0
  has_executable "$executable" || before_status=$?
  install_dependency "$name" "$executable" "$source" "$install_hint" || failed=$((failed + 1))

  if [[ "$DRY_RUN" -eq 0 && "$before_status" -ne 0 ]]; then
    if ! has_executable "$executable"; then
      manual=$((manual + 1))
    fi
  fi
done <"$MANIFEST"

printf '\nSummary: %d checked, %d present, %d planned, %d optional skipped, %d manual/unresolved, %d failed\n' \
  "$checked" "$already_present" "$planned" "$skipped_optional" "$manual" "$failed"

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

exit 0
