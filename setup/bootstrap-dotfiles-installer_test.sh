#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/setup/bootstrap-dotfiles-installer.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap-test-XXXXXX")"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  [[ "$haystack" == *"$needle"* ]] || fail "$label: expected output to contain '$needle'"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  [[ "$haystack" != *"$needle"* ]] || fail "$label: output unexpectedly contained '$needle'"
}

make_fakebin() {
  local name="$1"
  local dir="$TEST_ROOT/$name"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

write_uname() {
  local dir="$1"
  cat >"$dir/uname" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -s) printf '%s\n' "${BOOTSTRAP_TEST_UNAME_S:-Darwin}" ;;
  -m) printf '%s\n' "${BOOTSTRAP_TEST_UNAME_M:-arm64}" ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$dir/uname"
}

write_xcode_select() {
  local dir="$1"
  cat >"$dir/xcode-select" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -p)
    if [[ "${BOOTSTRAP_TEST_CLT:-present}" == "present" ]]; then
      printf '/Library/Developer/CommandLineTools\n'
      exit 0
    fi
    exit 2
    ;;
  --install)
    printf 'xcode-select --install\n' >>"${BOOTSTRAP_TEST_LOG:?}"
    exit 0
    ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$dir/xcode-select"
}

write_brew() {
  local dir="$1"
  cat >"$dir/brew" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  shellenv)
    prefix="$(cd "$(dirname "$0")/.." && pwd)"
    printf 'export HOMEBREW_PREFIX=%q\n' "$prefix"
    printf 'export PATH=%q:$PATH\n' "$prefix/bin"
    ;;
  install)
    printf 'brew install %s\n' "$2" >>"${BOOTSTRAP_TEST_LOG:?}"
    if [[ "$2" == "go" && -n "${BOOTSTRAP_TEST_INSTALL_GO_BIN:-}" ]]; then
      cat >"$BOOTSTRAP_TEST_INSTALL_GO_BIN" <<'GOEOF'
#!/usr/bin/env bash
printf 'go %s\n' "$*" >>"${BOOTSTRAP_TEST_LOG:?}"
GOEOF
      chmod +x "$BOOTSTRAP_TEST_INSTALL_GO_BIN"
    fi
    ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$dir/brew"
}

write_go() {
  local dir="$1"
  cat >"$dir/go" <<'EOF'
#!/usr/bin/env bash
printf 'go %s\n' "$*" >>"${BOOTSTRAP_TEST_LOG:?}"
EOF
  chmod +x "$dir/go"
}

base_env() {
  local fakebin="$1"
  local log="$2"
  shift 2
  env \
    BOOTSTRAP_TEST_LOG="$log" \
    BOOTSTRAP_UNAME_S=Darwin \
    BOOTSTRAP_UNAME_M=arm64 \
    BOOTSTRAP_BREW_CANDIDATES="$fakebin/brew" \
    PATH="$fakebin:/usr/bin:/bin:/usr/sbin:/sbin" \
    "$@"
}

test_dry_run_default_and_minimal_path() {
  local fakebin log output minimal_output
  fakebin="$(make_fakebin dry-run)"
  log="$TEST_ROOT/dry-run.log"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_brew "$fakebin"
  write_go "$fakebin"

  output="$(base_env "$fakebin" "$log" "$SCRIPT" --dry-run)"
  assert_contains "$output" 'Mode: dry-run' 'dry-run mode'
  assert_contains "$output" 'xcode_clt' 'reports CLT'
  assert_contains "$output" 'homebrew' 'reports Homebrew'
  assert_contains "$output" 'go' 'reports Go'
  assert_contains "$output" 'launch' 'reports launch path'
  assert_not_contains "$output" 'setup/macos.sh' 'safety guard output'
  assert_not_contains "$output" 'link-nvim-config.sh' 'config linker guard output'
  [[ ! -s "$log" ]] || fail 'dry-run default should not execute fake commands'

  minimal_output="$(PATH="/usr/bin:/bin:/usr/sbin:/sbin" "$SCRIPT" --dry-run)"
  assert_contains "$minimal_output" 'Mode: dry-run' 'minimal PATH dry-run mode'
  assert_contains "$minimal_output" 'homebrew' 'minimal PATH reports Homebrew'
  assert_contains "$minimal_output" 'go' 'minimal PATH reports Go'
}

test_xcode_prompt_gate() {
  local fakebin log output status
  fakebin="$(make_fakebin xcode-missing)"
  log="$TEST_ROOT/xcode.log"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_brew "$fakebin"
  write_go "$fakebin"

  set +e
  output="$(BOOTSTRAP_TEST_CLT=missing base_env "$fakebin" "$log" "$SCRIPT" 2>&1)"
  status=$?
  set -e

  [[ "$status" -eq 75 ]] || fail "missing CLT should exit 75, got $status"
  assert_contains "$output" 'outcome: prompt_required' 'CLT prompt outcome'
  assert_contains "$output" 'Complete the Xcode Command Line Tools system prompt' 'CLT rerun guidance'
  assert_contains "$(<"$log")" 'xcode-select --install' 'CLT install initiated'
}

test_homebrew_and_go_prerequisites() {
  local fakebin log output prefer_output
  fakebin="$(make_fakebin missing-prereqs)"
  log="$TEST_ROOT/prereqs.log"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"

  output="$(base_env "$fakebin" "$log" "$SCRIPT" --dry-run)"
  assert_contains "$output" 'missing; would install Homebrew' 'dry-run plans Homebrew'
  assert_contains "$output" 'missing; would run brew install go' 'dry-run plans Go'

  prefer_output="$(base_env "$fakebin" "$log" "$SCRIPT" --dry-run --prefer-binary)"
  assert_contains "$prefer_output" 'missing; would run brew install go' 'Go required with prefer-binary'
}

test_homebrew_install_success_with_fake_installer() {
  local fakebin log install_script output
  fakebin="$(make_fakebin homebrew-install)"
  log="$TEST_ROOT/homebrew-install.log"
  install_script="$TEST_ROOT/install-homebrew.sh"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_go "$fakebin"

  cat >"$install_script" <<'EOF'
#!/usr/bin/env bash
cat >"${BOOTSTRAP_TEST_BREW_PATH:?}" <<'BREWEOF'
#!/usr/bin/env bash
case "$1" in
  shellenv)
    prefix="$(cd "$(dirname "$0")/.." && pwd)"
    printf 'export HOMEBREW_PREFIX=%q\n' "$prefix"
    printf 'export PATH=%q:$PATH\n' "$prefix/bin"
    ;;
  install)
    printf 'brew install %s\n' "$2" >>"${BOOTSTRAP_TEST_LOG:?}"
    ;;
esac
BREWEOF
chmod +x "${BOOTSTRAP_TEST_BREW_PATH:?}"
printf 'homebrew installer ran\n' >>"${BOOTSTRAP_TEST_LOG:?}"
EOF

  output="$(BOOTSTRAP_TEST_BREW_PATH="$fakebin/brew" BOOTSTRAP_HOMEBREW_INSTALL_URL="file://$install_script" base_env "$fakebin" "$log" "$SCRIPT" --no-binary)"
  assert_contains "$output" 'homebrew         installed' 'non-dry Homebrew install completes'
  assert_contains "$output" 'outcome: ready' 'non-dry Homebrew path reaches ready'
  assert_contains "$(<"$log")" 'homebrew installer ran' 'fake Homebrew installer executed'
  assert_contains "$(<"$log")" 'go run ./cmd/dotfiles-installer' 'source launch executed after Homebrew install'
}

test_go_install_success_with_fake_brew() {
  local fakebin log output
  fakebin="$(make_fakebin go-install)"
  log="$TEST_ROOT/go-install.log"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_brew "$fakebin"

  output="$(BOOTSTRAP_TEST_INSTALL_GO_BIN="$fakebin/go" base_env "$fakebin" "$log" "$SCRIPT" --no-binary)"
  assert_contains "$output" 'go               missing; installing with Homebrew' 'non-dry Go install starts'
  assert_contains "$output" 'outcome: ready' 'non-dry Go path reaches ready'
  assert_contains "$(<"$log")" 'brew install go' 'fake brew installs Go'
  assert_contains "$(<"$log")" 'go run ./cmd/dotfiles-installer' 'source launch runs after Go install'
}

test_binary_launch_paths() {
  local fakebin bindir log output disabled missing
  fakebin="$(make_fakebin binary-paths)"
  bindir="$TEST_ROOT/binaries"
  log="$TEST_ROOT/binary.log"
  mkdir -p "$bindir"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_brew "$fakebin"
  write_go "$fakebin"
  cat >"$bindir/dotfiles-installer-darwin-arm64" <<'EOF'
#!/usr/bin/env bash
printf 'binary launched\n' >>"${BOOTSTRAP_TEST_LOG:?}"
EOF
  chmod +x "$bindir/dotfiles-installer-darwin-arm64"

  output="$(BOOTSTRAP_BINARY_DIR="$bindir" base_env "$fakebin" "$log" "$SCRIPT" --dry-run --prefer-binary)"
  assert_contains "$output" 'prebuilt_binary' 'prefer-binary picks explicit binary'
  assert_contains "$output" "dry-run         $bindir/dotfiles-installer-darwin-arm64" 'binary execution is explicit argv'
  assert_not_contains "$output" 'sh -c' 'binary execution avoids shell interpolation'

  disabled="$(BOOTSTRAP_BINARY_DIR="$bindir" base_env "$fakebin" "$log" "$SCRIPT" --dry-run --no-binary)"
  assert_contains "$disabled" 'disabled by --no-binary' 'no-binary disables discovery'
  assert_contains "$disabled" 'go_run' 'no-binary uses source launch'

  missing="$(BOOTSTRAP_BINARY_DIR="$TEST_ROOT/no-such-dir" base_env "$fakebin" "$log" "$SCRIPT" --dry-run --prefer-binary)"
  assert_contains "$missing" 'release_binary' 'missing binary checks release fallback'
  assert_contains "$missing" 'missing, unavailable, or unverifiable; falling back to go run' 'missing binary fallback'
  assert_contains "$missing" 'go_run' 'missing binary uses go run'
}

test_release_binary_paths() {
  local fakebin releasedir log output mismatch mismatch_output missing_output checksum
  fakebin="$(make_fakebin release-binary)"
  releasedir="$TEST_ROOT/release-assets"
  log="$TEST_ROOT/release-binary.log"
  mkdir -p "$releasedir"
  : >"$log"
  write_uname "$fakebin"
  write_xcode_select "$fakebin"
  write_brew "$fakebin"
  write_go "$fakebin"

  cat >"$releasedir/dotfiles-installer-darwin-arm64" <<'EOF'
#!/usr/bin/env bash
printf 'release binary launched\n' >>"${BOOTSTRAP_TEST_LOG:?}"
EOF
  chmod +x "$releasedir/dotfiles-installer-darwin-arm64"
  checksum="$(cd "$releasedir" && shasum -a 256 dotfiles-installer-darwin-arm64)"
  printf '%s\n' "$checksum" >"$releasedir/checksums.txt"

  output="$(BOOTSTRAP_RELEASE_BASE_URL="file://$releasedir" base_env "$fakebin" "$log" "$SCRIPT" --prefer-binary)"
  assert_contains "$output" 'release_binary' 'release binary selected'
  assert_contains "$output" 'outcome: ready' 'release binary reaches ready'
  assert_contains "$(<"$log")" 'release binary launched' 'release binary executed'

  mismatch="$TEST_ROOT/release-mismatch"
  mkdir -p "$mismatch"
  cp "$releasedir/dotfiles-installer-darwin-arm64" "$mismatch/dotfiles-installer-darwin-arm64"
  printf '%s  %s\n' '0000000000000000000000000000000000000000000000000000000000000000' 'dotfiles-installer-darwin-arm64' >"$mismatch/checksums.txt"
  : >"$log"
  mismatch_output="$(BOOTSTRAP_RELEASE_BASE_URL="file://$mismatch" base_env "$fakebin" "$log" "$SCRIPT" --prefer-binary)"
  assert_contains "$mismatch_output" 'checksum verification failed' 'checksum mismatch reported'
  assert_contains "$mismatch_output" 'go_run' 'checksum mismatch falls back to source'
  assert_not_contains "$(<"$log")" 'release binary launched' 'checksum mismatch does not execute binary'

  missing_output="$(BOOTSTRAP_RELEASE_BASE_URL="file://$TEST_ROOT/no-release" base_env "$fakebin" "$log" "$SCRIPT" --dry-run --prefer-binary)"
  assert_contains "$missing_output" 'would download' 'dry-run release download is reported'
  assert_contains "$missing_output" 'go_run' 'dry-run release path still reports source fallback'
}

test_dry_run_default_and_minimal_path
test_xcode_prompt_gate
test_homebrew_and_go_prerequisites
test_homebrew_install_success_with_fake_installer
test_go_install_success_with_fake_brew
test_binary_launch_paths
test_release_binary_paths

printf 'ok - bootstrap-dotfiles-installer tests passed\n'
