#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${1:-$ROOT_DIR/nvim/dependencies.tsv}"
MASON_BIN="${MASON:-$HOME/.local/share/nvim/mason}/bin"
CFN_LSP_SERVER="${CFN_LSP_SERVER:-$HOME/.local/share/cfn-lsp/cfn-lsp-server-standalone.js}"

if [[ ! -f "$MANIFEST" ]]; then
  printf 'Missing dependency manifest: %s\n' "$MANIFEST" >&2
  exit 2
fi

found=0
missing_required=0
missing_optional=0

has_executable() {
  local executable="$1"
  if [[ "$executable" == 'cfn-lsp-server-standalone.js' ]]; then
    [[ -f "$CFN_LSP_SERVER" && -r "$CFN_LSP_SERVER" ]]
    return
  fi

  command -v "$executable" >/dev/null 2>&1 || [[ -x "$MASON_BIN/$executable" ]]
}

printf 'Neovim dependency validation\n'
printf 'Manifest: %s\n' "$MANIFEST"
printf 'Mason bin: %s\n\n' "$MASON_BIN"

while IFS='|' read -r name executable required source install_hint used_by; do
  [[ -z "${name:-}" || "${name:0:1}" == '#' ]] && continue

  found=$((found + 1))
  if has_executable "$executable"; then
    printf 'ok       %s (%s)\n' "$name" "$executable"
    continue
  fi

  if [[ "$required" == 'yes' ]]; then
    missing_required=$((missing_required + 1))
    printf 'missing  %s (%s) [required]\n' "$name" "$executable"
  else
    missing_optional=$((missing_optional + 1))
    printf 'optional %s (%s) [missing, non-blocking]\n' "$name" "$executable"
  fi

  printf '         source: %s\n' "$source"
  printf '         used by: %s\n' "$used_by"
  printf '         install: %s\n' "$install_hint"
  if [[ "$name" == AWS* || "$executable" == cfn-lint || "$executable" == sam ]]; then
    printf '         note: AWS template tooling is optional; generic YAML and baseline Neovim validation continue without it.\n'
  fi
done <"$MANIFEST"

printf '\nSummary: %d checked, %d required missing, %d optional missing\n' \
  "$found" "$missing_required" "$missing_optional"

if [[ "$missing_required" -gt 0 ]]; then
  exit 1
fi

exit 0
