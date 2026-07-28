#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
PREFER_BINARY=0
ALLOW_BINARY=1
BREW_INSTALL_URL="${BOOTSTRAP_HOMEBREW_INSTALL_URL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"
RELEASE_BASE_URL="${BOOTSTRAP_RELEASE_BASE_URL:-https://github.com/aogallo/dotfiles/releases/latest/download}"

usage() {
  cat <<'EOF'
Usage: setup/bootstrap-dotfiles-installer.sh [--dry-run] [--prefer-binary] [--no-binary]

Prepares a clean macOS machine for the guided dotfiles installer.

Options:
  --dry-run        Report prerequisite state and planned actions without installing or launching.
  --prefer-binary Prefer a compatible prebuilt or released dotfiles-installer binary when available.
  --no-binary     Skip prebuilt binary discovery and launch from source with go run.
  -h, --help      Show this help.

Outcomes:
  ready           Prerequisites are present and the installer launched, or would launch in dry-run.
  prompt_required Xcode Command Line Tools installation was initiated; complete the prompt and rerun.
  failed          A prerequisite install or launch failed; follow the printed next step.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --prefer-binary)
      PREFER_BINARY=1
      ALLOW_BINARY=1
      ;;
    --no-binary)
      ALLOW_BINARY=0
      PREFER_BINARY=0
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

status_line() {
  printf '%-16s %s\n' "$1" "$2"
}

fail() {
  printf 'failed: %s\n' "$1" >&2
  printf 'outcome: failed\n' >&2
  exit 1
}

safe_run() {
  case "${1:-}" in
    setup/macos.sh|*/setup/macos.sh|setup/link-nvim-config.sh|*/setup/link-nvim-config.sh|setup/link-ghostty-config.sh|*/setup/link-ghostty-config.sh|gh|ssh-keygen|git)
      fail "refusing forbidden bootstrap command: $*"
      ;;
  esac

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'dry-run         %s\n' "$*"
  else
    printf 'run             %s\n' "$*"
    "$@"
  fi
}

detect_platform() {
  local os arch
  os="${BOOTSTRAP_UNAME_S:-$(uname -s)}"
  arch="${BOOTSTRAP_UNAME_M:-$(uname -m)}"

  if [[ "$os" != "Darwin" ]]; then
    fail "unsupported platform '$os'; this bootstrap currently supports macOS only"
  fi

  case "$arch" in
    arm64)
      DETECTED_ARCH="arm64"
      ;;
    x86_64|amd64)
      DETECTED_ARCH="amd64"
      ;;
    *)
      fail "unsupported macOS architecture '$arch'"
      ;;
  esac
}

check_xcode_clt() {
  if command -v xcode-select >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
    status_line "xcode_clt" "present ($(xcode-select -p 2>/dev/null))"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    status_line "xcode_clt" "missing; would run xcode-select --install and stop for the macOS prompt"
    return 0
  fi

  status_line "xcode_clt" "missing; initiating macOS installation prompt"
  safe_run xcode-select --install || true
  printf 'outcome: prompt_required\n'
  printf 'Complete the Xcode Command Line Tools system prompt, then rerun:\n'
  printf '  setup/bootstrap-dotfiles-installer.sh\n'
  exit 75
}

brew_candidate_paths() {
  if [[ -n "${BOOTSTRAP_BREW_CANDIDATES:-}" ]]; then
    # shellcheck disable=SC2086 # intentional test-only word splitting for candidate paths
    printf '%s\n' $BOOTSTRAP_BREW_CANDIDATES
    return 0
  fi

  printf '%s\n' /opt/homebrew/bin/brew /usr/local/bin/brew
}

load_brew_shellenv() {
  local brew_path="$1"
  local prefix
  prefix="$(cd "$(dirname "$brew_path")/.." && pwd)"

  if [[ -x "$brew_path" ]]; then
    eval "$("$brew_path" shellenv)"
  else
    export PATH="$prefix/bin:$PATH"
    export HOMEBREW_PREFIX="$prefix"
  fi
}

find_brew() {
  local candidate
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  while IFS= read -r candidate; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    load_brew_shellenv "$candidate"
    command -v brew
    return 0
  done < <(brew_candidate_paths)

  return 1
}

ensure_homebrew() {
  local brew_path
  if brew_path="$(find_brew)"; then
    status_line "homebrew" "present ($brew_path)"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    status_line "homebrew" "missing; would install Homebrew"
    return 0
  fi

  status_line "homebrew" "missing; installing Homebrew"
  safe_run /bin/bash -c "$(curl -fsSL "$BREW_INSTALL_URL")"

  if ! brew_path="$(find_brew)"; then
    fail "Homebrew installation finished but brew was not found; open a new shell or add Homebrew to PATH, then rerun"
  fi

  status_line "homebrew" "installed ($brew_path)"
}

ensure_go() {
  if command -v go >/dev/null 2>&1; then
    status_line "go" "present ($(command -v go))"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    status_line "go" "missing; would run brew install go"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    fail "Go is missing and brew is unavailable; rerun after Homebrew is available"
  fi

  status_line "go" "missing; installing with Homebrew"
  safe_run brew install go
}

binary_candidates() {
  local dir
  if [[ -n "${BOOTSTRAP_BINARY_DIR:-}" ]]; then
    printf '%s\n' \
      "$BOOTSTRAP_BINARY_DIR/dotfiles-installer-darwin-$DETECTED_ARCH" \
      "$BOOTSTRAP_BINARY_DIR/dotfiles-installer-$DETECTED_ARCH" \
      "$BOOTSTRAP_BINARY_DIR/dotfiles-installer"
  fi

  for dir in "$ROOT_DIR/bin" "$ROOT_DIR/dist" "$ROOT_DIR/installer/bin"; do
    printf '%s\n' \
      "$dir/dotfiles-installer-darwin-$DETECTED_ARCH" \
      "$dir/dotfiles-installer-$DETECTED_ARCH" \
      "$dir/dotfiles-installer"
  done
}

find_binary() {
  local candidate
  [[ "$ALLOW_BINARY" -eq 1 && "$PREFER_BINARY" -eq 1 ]] || return 1

  while IFS= read -r candidate; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done < <(binary_candidates)

  return 1
}

release_asset_name() {
  printf 'dotfiles-installer-darwin-%s\n' "$DETECTED_ARCH"
}

download_release_binary() {
  local asset checksum_url asset_url tmpdir binary checksum_file
  DOWNLOADED_RELEASE_BINARY=""
  DOWNLOADED_RELEASE_DIR=""
  [[ "$ALLOW_BINARY" -eq 1 && "$PREFER_BINARY" -eq 1 ]] || return 1

  asset="$(release_asset_name)"
  asset_url="$RELEASE_BASE_URL/$asset"
  checksum_url="$RELEASE_BASE_URL/checksums.txt"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    status_line "release_binary" "would download $asset_url and verify checksums.txt"
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    status_line "release_binary" "curl missing; falling back to go run"
    return 1
  fi

  if ! command -v shasum >/dev/null 2>&1; then
    status_line "release_binary" "shasum missing; falling back to go run"
    return 1
  fi

  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-installer-release-XXXXXX")"
  binary="$tmpdir/$asset"
  checksum_file="$tmpdir/checksums.txt"

  if ! curl -fsSL "$asset_url" -o "$binary" || ! curl -fsSL "$checksum_url" -o "$checksum_file"; then
    rm -rf "$tmpdir"
    status_line "release_binary" "missing or unavailable; falling back to go run"
    return 1
  fi

  if ! (cd "$tmpdir" && shasum -a 256 -c checksums.txt --ignore-missing >/dev/null 2>&1); then
    rm -rf "$tmpdir"
    status_line "release_binary" "checksum verification failed; falling back to go run"
    return 1
  fi

  chmod +x "$binary"
  DOWNLOADED_RELEASE_BINARY="$binary"
  DOWNLOADED_RELEASE_DIR="$tmpdir"
}

launch_installer() {
  local binary status

  if binary="$(find_binary)"; then
    status_line "launch" "prebuilt_binary ($binary)"
    safe_run "$binary"
    printf 'outcome: ready\n'
    return 0
  fi

  if download_release_binary; then
    binary="$DOWNLOADED_RELEASE_BINARY"
    status_line "launch" "release_binary ($binary)"
    if safe_run "$binary"; then
      rm -rf "$DOWNLOADED_RELEASE_DIR"
    else
      status=$?
      rm -rf "$DOWNLOADED_RELEASE_DIR"
      return "$status"
    fi
    printf 'outcome: ready\n'
    return 0
  fi

  if [[ "$PREFER_BINARY" -eq 1 && "$ALLOW_BINARY" -eq 1 ]]; then
    status_line "binary" "missing, unavailable, or unverifiable; falling back to go run"
  elif [[ "$ALLOW_BINARY" -eq 0 ]]; then
    status_line "binary" "disabled by --no-binary"
  fi

  status_line "launch" "go_run (cd installer && go run ./cmd/dotfiles-installer)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf 'dry-run         cd %s/installer && go run ./cmd/dotfiles-installer\n' "$ROOT_DIR"
  else
    (cd "$ROOT_DIR/installer" && safe_run go run ./cmd/dotfiles-installer)
  fi

  printf 'outcome: ready\n'
}

printf 'Dotfiles installer bootstrap\n'
printf 'Mode: %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && printf dry-run || printf apply)"
printf 'Repository: %s\n' "$ROOT_DIR"

detect_platform
printf 'Platform: macos\n'
printf 'Architecture: %s\n\n' "$DETECTED_ARCH"

check_xcode_clt
ensure_homebrew
ensure_go
launch_installer
