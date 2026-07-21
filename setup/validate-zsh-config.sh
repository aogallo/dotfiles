#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZSHRC="$ROOT_DIR/zsh/.zshrc"
MANIFEST="$ROOT_DIR/zsh/dependencies.tsv"

missing_required=0
missing_optional=0
checked=0

has_dependency() {
  local executable="$1"

  case "$executable" in
    *.sh|*.zsh)
      [[ -r "$HOME/.oh-my-zsh/$executable" ]] || \
        [[ -r "${HOMEBREW_PREFIX:-/opt/homebrew}/share/$executable" ]] || \
        [[ -r "/usr/local/share/$executable" ]]
      ;;
    oh-my-zsh.sh)
      [[ -r "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]
      ;;
    nvm.sh)
      [[ -r "$HOME/.nvm/nvm.sh" ]]
      ;;
    *)
      command -v "$executable" >/dev/null 2>&1
      ;;
  esac
}

printf 'Zsh configuration validation\n'
printf 'Config: %s\n' "$ZSHRC"
printf 'Manifest: %s\n\n' "$MANIFEST"

if [[ ! -f "$ZSHRC" ]]; then
  printf 'Missing zsh config: %s\n' "$ZSHRC" >&2
  exit 2
fi

if [[ ! -f "$MANIFEST" ]]; then
  printf 'Missing dependency manifest: %s\n' "$MANIFEST" >&2
  exit 2
fi

if zsh -n "$ZSHRC"; then
  printf 'ok       zsh syntax\n'
else
  printf 'failed   zsh syntax\n' >&2
  exit 1
fi

while IFS='|' read -r name executable required source install_hint used_by; do
  [[ -z "${name:-}" || "${name:0:1}" == '#' ]] && continue
  checked=$((checked + 1))

  if has_dependency "$executable"; then
    printf 'ok       %s (%s)\n' "$name" "$executable"
    continue
  fi

  if [[ "$required" == 'yes' ]]; then
    missing_required=$((missing_required + 1))
    printf 'missing  %s (%s) [required]\n' "$name" "$executable"
  else
    missing_optional=$((missing_optional + 1))
    printf 'optional %s (%s) [missing]\n' "$name" "$executable"
  fi

  printf '         source: %s\n' "$source"
  printf '         used by: %s\n' "$used_by"
  printf '         install: %s\n' "$install_hint"
done <"$MANIFEST"

if ZSHRC_PATH="$ZSHRC" ZSH_SKIP_OPTIONAL_INTEGRATIONS=1 zsh -fc 'source "$ZSHRC_PATH"; before="$PATH"; source "$ZSHRC_PATH"; [[ "$PATH" == "$before" ]]'; then
  printf 'ok       repeated source keeps PATH stable\n'
else
  printf 'failed   repeated source changed PATH\n' >&2
  exit 1
fi

if grep -R -n -E '([A-Za-z_]*(TOKEN|SECRET|PASSWORD|PRIVATE_KEY)[A-Za-z_]*=|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|/Users/allan|/home/alanbuscaglia)' "$ROOT_DIR/zsh" >/dev/null 2>&1; then
  printf 'failed   potential secret or private absolute path found under zsh/\n' >&2
  exit 1
fi

printf '\nSummary: %d dependencies checked, %d required missing, %d optional missing\n' \
  "$checked" "$missing_required" "$missing_optional"

if [[ "$missing_required" -gt 0 ]]; then
  exit 1
fi

exit 0
