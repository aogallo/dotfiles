# Quickstart: Dotfiles Installer TUI Validation

This guide validates the planned installer behavior end-to-end without requiring implementation
details to live in the design artifacts.

## Prerequisites

- macOS development machine or test sandbox.
- Repository checked out at the project root.
- Go 1.22+ once implementation begins.
- Existing setup scripts remain executable from `setup/`.

## Baseline Checks

From the repository root:

```sh
test -f specs/001-dotfiles-installer/spec.md
test -f specs/001-dotfiles-installer/plan.md
test -f specs/001-dotfiles-installer/research.md
test -f specs/001-dotfiles-installer/data-model.md
test -f specs/001-dotfiles-installer/contracts/installer-cli.md
```

## Scenario 1: Main Menu Safety

Run the US1 automated validation:

```sh
cd installer && go test ./internal/tui ./cmd/dotfiles-installer
```

Expected outcome:
- TUI model, update, and view tests pass.
- The installer command package compiles.

Run the installer once implementation exists:

```sh
cd installer && go run ./cmd/dotfiles-installer
```

Expected outcome:
- The main menu shows `start installation`, `sync configs`, `Upgrade tools`, and `quit`.
- `j` and `k` move focus through the menu.
- `q` exits from the main menu without changing files.
- No setup script runs until the user selects and confirms an action.

## Scenario 2: Dry-Run Install Planning

Run the installer and choose `start installation`.

Expected outcome:
- The installer inventories Neovim, zsh, Ghostty, tmux, keyboard, and macOS setup sources.
- Neovim and Ghostty show safe linker preview actions.
- Zsh shows validation/report-only behavior because no zsh linker exists yet.
- Tmux, keyboard, and unsafe macOS items show manual guidance instead of apply actions.
- The plan separates required, optional, Mason-backed, AWS, and manual-only items.

Reference: [data-model.md](./data-model.md) for Action Plan and Module states.

## Scenario 3: Existing Config Conflict

Prepare a sandbox where `~/.config/nvim` or Ghostty's active config path contains an unmanaged
file or symlink.

Run the relevant flow and inspect the plan.

Expected outcome:
- The installer reports the target as unmanaged.
- Apply is blocked unless explicit backup behavior is selected.
- Existing link scripts remain the source of truth for conflict and backup behavior.
- The final report includes the conflict or backup path.

## Scenario 4: Safe Rerun

Run the same dry-run and confirmed apply/sync flow twice in a sandbox.

Validated US3 sandbox command sequence:

```sh
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-us3-XXXXXX")"
HOME="$SANDBOX/home"
mkdir -p "$HOME"
HOME="$HOME" setup/link-nvim-config.sh --dry-run
HOME="$HOME" setup/link-nvim-config.sh --apply
HOME="$HOME" setup/link-nvim-config.sh --dry-run
HOME="$HOME" setup/link-ghostty-config.sh --dry-run
HOME="$HOME" setup/link-ghostty-config.sh --apply
HOME="$HOME" setup/link-ghostty-config.sh --dry-run
cd installer && go test ./internal/installer -run 'TestBuild(SyncPlanRepeatedRunsConvergeWithoutBackupLoops|UpgradeReportNormalizesToolCategories)'
```

Expected outcome:
- The second run reports already-managed or unchanged state.
- No duplicate symlinks are created.
- No backup loop is created for already-managed targets.
- Skipped and unchanged results are clearly visible in the final report.

## Scenario 5: Upgrade Tools Report

Choose `Upgrade tools`.

Expected outcome:
- Supported tool upgrades are shown separately from optional and manual items.
- Mason-backed and external AWS tooling are reported with guidance unless a safe automated path
  already exists.
- Failures are visible and actionable.

## Regression Commands

Once implementation exists, run:

```sh
cd installer && go test ./...
setup/validate-nvim-deps.sh
setup/bootstrap-nvim-deps.sh --dry-run
setup/link-nvim-config.sh --dry-run
setup/validate-zsh-config.sh
setup/validate-ghostty-config.sh
setup/link-ghostty-config.sh --dry-run
```

Expected outcome:
- Go tests pass.
- Existing validators either pass or report documented missing optional dependencies.
- Dry-run scripts do not change local files.
