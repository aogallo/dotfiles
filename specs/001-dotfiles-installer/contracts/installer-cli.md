# Contract: Dotfiles Installer CLI/TUI

## Command

```sh
dotfiles-installer
```

During development the equivalent command is:

```sh
cd installer && go run ./cmd/dotfiles-installer
```

## Bootstrap Command

Clean-machine setup starts from a shell bootstrap that can run before Go is available:

```sh
setup/bootstrap-dotfiles-installer.sh [--dry-run] [--prefer-binary] [--no-binary]
```

### Options

- `--dry-run`: report prerequisite state and planned actions without installing or launching.
- `--prefer-binary`: use a compatible prebuilt `dotfiles-installer` binary when available, then
  fall back to source execution if needed.
- `--no-binary`: skip prebuilt binary discovery and launch with `go run` after Go is available.

### Required Bootstrap Behavior

- Detect macOS and fail clearly on unsupported platforms.
- Check Xcode Command Line Tools with `xcode-select -p` before attempting install.
- Run `xcode-select --install` when CLT are missing, then stop with rerun instructions if macOS
  requires manual prompt completion.
- Install Homebrew only when `brew` is missing.
- Load Homebrew shellenv for Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) installs.
- Install Go only when `go` is missing; Go remains required even when a prebuilt binary is used.
- Prefer a compatible prebuilt binary only when explicitly available and allowed.
- Fall back to `cd installer && go run ./cmd/dotfiles-installer` when no compatible binary is used.
- Avoid GitHub account setup, SSH key generation, Git identity changes, config linking, or any
  unmanaged dotfiles overwrite.
- Be safe to rerun after partial completion.

### Bootstrap Outcomes

- `ready`: prerequisites are present and the guided installer was launched or would launch in dry-run.
- `prompt_required`: Xcode CLT installation was initiated and the user must complete the macOS
  system prompt before rerunning bootstrap.
- `failed`: a prerequisite install or launch failed and the output includes an actionable next step.

## Main Menu

The initial screen must expose exactly these top-level actions:

- `start installation`
- `sync configs`
- `Upgrade tools`
- `quit`

## Required Key Bindings

- `j`: move focus down on menu/list screens
- `k`: move focus up on menu/list screens
- `enter`: select focused item
- `q`: exit from the main menu or return/back out from safe sub-screens without applying
  unconfirmed changes
- `ctrl+c`: exit immediately without applying further changes

## Flow Contract

### `start installation`

Must inventory repository setup sources, build an Action Plan, show dry-run/report-only results,
and require confirmation before running mutating steps.

Supported initial modules:
- Neovim
- zsh
- Ghostty
- tmux
- keyboard
- macOS setup

### `sync configs`

Must inspect repository-managed config targets and report each target as managed, unmanaged,
missing, backed-up, removed, skipped, or failed. It must not replace unmanaged files without
explicit backup confirmation.

### `Upgrade tools`

Must report changed, skipped, failed, optional, and manual items. It must separate Mason-backed,
AWS/external, optional, and manual-only entries.

### `quit`

Must exit with code `0` when no required action failed.

## Action Classification

Every planned step must be classified as one of:

- `automatic`: safe read-only or validation step that may run without confirmation
- `confirmation_required`: mutating step that requires explicit user confirmation
- `dry_run_report_only`: preview step that must not change local files
- `manual_only`: guidance that must not execute as an installer command

## Script Integration Boundary

The installer may invoke existing setup scripts only through documented flags, including:

- `setup/validate-nvim-deps.sh`
- `setup/bootstrap-nvim-deps.sh --dry-run`
- `setup/bootstrap-nvim-deps.sh --install`
- `setup/link-nvim-config.sh --dry-run`
- `setup/link-nvim-config.sh --apply`
- `setup/link-nvim-config.sh --apply --backup`
- `setup/validate-zsh-config.sh`
- `setup/validate-ghostty-config.sh`
- `setup/link-ghostty-config.sh --dry-run`
- `setup/link-ghostty-config.sh --apply`
- `setup/link-ghostty-config.sh --apply --backup`
- `setup/link-ghostty-config.sh --remove`

The installer must not invoke `setup/macos.sh` as a single automatic action.

## Report Contract

The final report must include:

- Selected flow
- Per-module results
- Counts for changed, unchanged, skipped, failed, backup, and manual items
- Backup paths when created
- Manual next steps for report-only or manual-only work
- Non-zero exit status when required validation or confirmed apply work fails

## Manual-Only Boundaries

These items must remain manual/report-only until a later spec designs safe automation:

- Keyboard VIA import
- TPM plugin installation keypresses
- macOS security approvals
- GitHub SSH/account setup from `setup/macos.sh`
- AWS CloudFormation language server bundle repair or quarantine handling
