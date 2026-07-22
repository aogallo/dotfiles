#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$ROOT_DIR/ghostty"
CONFIG="$MODULE_DIR/config.ghostty"
LOCAL_EXAMPLE="$MODULE_DIR/local.example.ghostty"
MANIFEST="$MODULE_DIR/dependencies.tsv"
README="$MODULE_DIR/README.md"
ACTIVE_CONFIG="$HOME/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
AUTO_STATE="$MODULE_DIR/auto"

missing_required=0
missing_optional=0
checked=0
failed=0

required_files=(
  "$CONFIG"
  "$LOCAL_EXAMPLE"
  "$MANIFEST"
  "$README"
)

has_dependency() {
  local name="$1"
  local executable="$2"

  case "$name" in
    Ghostty.app)
      [[ -d "$executable" ]] || [[ -d "$HOME/Applications/Ghostty.app" ]]
      ;;
    "IosevkaTerm NF")
      [[ -f "$HOME/Library/Fonts/IosevkaTermNerdFont-Regular.ttf" ]] || \
        [[ -f "$HOME/Library/Fonts/IosevkaTermNerdFont-Bold.ttf" ]] || \
        [[ -f "$HOME/Library/Fonts/IosevkaTermNF-Regular.ttf" ]] || \
        [[ -f "$HOME/Library/Fonts/Iosevka.ttc" ]] || \
        /usr/bin/osascript -e 'tell application "Font Book" to get name of every font family' 2>/dev/null | grep -F "Iosevka" >/dev/null 2>&1
      ;;
    *)
      command -v "$executable" >/dev/null 2>&1
      ;;
  esac
}

check_required_files() {
  local file

  for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
      printf 'ok       required file %s\n' "${file#$ROOT_DIR/}"
    else
      printf 'missing  required file %s\n' "${file#$ROOT_DIR/}" >&2
      failed=$((failed + 1))
    fi
  done
}

check_manifest() {
  local name executable required source install_hint used_by

  if [[ ! -f "$MANIFEST" ]]; then
    return
  fi

  while IFS=$'\t' read -r name executable required source install_hint used_by; do
    [[ -z "${name:-}" || "${name:0:1}" == '#' ]] && continue
    checked=$((checked + 1))

    if has_dependency "$name" "$executable"; then
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
}

check_hygiene() {
  if [[ -d "$AUTO_STATE" ]]; then
    printf 'failed   generated Ghostty auto state found in repository: %s\n' "${AUTO_STATE#$ROOT_DIR/}" >&2
    failed=$((failed + 1))
  else
    printf 'ok       no generated Ghostty auto state under ghostty/\n'
  fi

  if grep -R -n -E '([A-Za-z_]*(TOKEN|SECRET|PASSWORD|PRIVATE_KEY)[A-Za-z_]*=|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+)' "$MODULE_DIR" >/dev/null 2>&1; then
    printf 'failed   potential secret or private absolute path found under ghostty/\n' >&2
    failed=$((failed + 1))
  else
    printf 'ok       shared Ghostty files avoid secrets and private absolute paths\n'
  fi
}

check_config_syntax() {
  if [[ ! -f "$CONFIG" ]]; then
    return
  fi

  if grep -n -v -E '^([[:space:]]*#.*|[[:space:]]*$|[A-Za-z0-9._-]+[[:space:]]*=[[:space:]]*.*)$' "$CONFIG" >/dev/null 2>&1; then
    printf 'failed   managed config contains lines outside key = value Ghostty syntax\n' >&2
    failed=$((failed + 1))
  else
    printf 'ok       managed config uses key = value syntax\n'
  fi
}

smoke_check_ghostty() {
  local ghostty_cmd

  ghostty_cmd="$(command -v ghostty 2>/dev/null || true)"
  if [[ -z "$ghostty_cmd" ]]; then
    printf 'skip     Ghostty CLI smoke check unavailable\n'
    return
  fi

  if "$ghostty_cmd" +validate-config --help >/dev/null 2>&1; then
    if "$ghostty_cmd" +validate-config --config-file="$CONFIG" >/dev/null 2>&1; then
      printf 'ok       Ghostty CLI validated managed config\n'
    else
      printf 'failed   Ghostty CLI rejected managed config\n' >&2
      failed=$((failed + 1))
    fi
    return
  fi

  printf 'skip     Ghostty CLI found but no supported config validation command detected\n'
}

printf 'Ghostty configuration validation\n'
printf 'Managed config: %s\n' "$CONFIG"
printf 'Active config: %s\n' "$ACTIVE_CONFIG"
printf 'Manifest: %s\n\n' "$MANIFEST"

check_required_files
check_manifest
check_hygiene
check_config_syntax
smoke_check_ghostty

printf '\nSummary: %d dependencies checked, %d required missing, %d optional missing, %d validation failures\n' \
  "$checked" "$missing_required" "$missing_optional" "$failed"

if [[ "$missing_required" -gt 0 || "$failed" -gt 0 ]]; then
  exit 1
fi

exit 0
