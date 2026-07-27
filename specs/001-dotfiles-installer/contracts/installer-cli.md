# Contract: Dotfiles Installer CLI/TUI

## Command

```sh
dotfiles-installer
```

During development the equivalent command is:

```sh
cd installer && go run ./cmd/dotfiles-installer
```

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
