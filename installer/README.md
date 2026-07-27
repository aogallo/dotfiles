# Dotfiles Installer

This directory contains the Bubble Tea installer for this dotfiles repository. It is an isolated Go module so installer dependencies stay separate from the dotfiles themselves.

## Quick Start

From the repository root:

```sh
cd installer
go run ./cmd/dotfiles-installer
```

Run tests with:

```sh
cd installer
go test ./...
```

## Clean macOS Setup

On a clean macOS machine, run the repository bootstrap from the repository root. It prepares the
minimum prerequisites before launching this Go installer:

```sh
setup/bootstrap-dotfiles-installer.sh --dry-run
setup/bootstrap-dotfiles-installer.sh
```

The bootstrap checks or installs:

- Xcode Command Line Tools
- Homebrew
- Go

If Xcode Command Line Tools are missing, macOS may require a system prompt. In that case the
bootstrap starts `xcode-select --install`, exits with `prompt_required`, and tells you to rerun it
after completing the prompt.

Useful modes:

```sh
setup/bootstrap-dotfiles-installer.sh --prefer-binary
setup/bootstrap-dotfiles-installer.sh --no-binary
PATH="/usr/bin:/bin:/usr/sbin:/sbin" setup/bootstrap-dotfiles-installer.sh --dry-run
```

`--prefer-binary` uses a compatible prebuilt installer binary when available, but Go is still
installed when missing because it is required for development and Neovim tooling. `--no-binary`
forces source execution with `go run` after prerequisites are ready.

Manual Go installation is not the preferred first-run path anymore. Use it only for recovery if
the bootstrap cannot complete on the current machine.

After prerequisites are ready, this direct command also works:

```sh
cd installer
go run ./cmd/dotfiles-installer
```

## What It Does

The installer presents a terminal menu with:

- `start installation`
- `sync configs`
- `Upgrade tools`
- `quit`

It inventories repository modules, builds an action plan, shows safe previews, requires confirmation before mutating actions, and delegates work to approved setup scripts.

## Safety Boundaries

The installer does not replace every setup script. Existing scripts remain the source of truth for module behavior.

Automated execution is limited to approved commands such as:

```sh
setup/validate-nvim-deps.sh
setup/bootstrap-nvim-deps.sh --dry-run
setup/bootstrap-nvim-deps.sh --install
setup/link-nvim-config.sh --dry-run
setup/link-nvim-config.sh --apply
setup/link-nvim-config.sh --apply --backup
setup/validate-zsh-config.sh
setup/validate-ghostty-config.sh
setup/link-ghostty-config.sh --dry-run
setup/link-ghostty-config.sh --apply
setup/link-ghostty-config.sh --apply --backup
setup/link-ghostty-config.sh --remove
```

Manual-only items stay manual until a later spec designs safe automation:

- Keyboard VIA import
- TPM plugin installation keypresses
- macOS security approvals
- GitHub SSH/account setup from `setup/macos.sh`
- AWS CloudFormation language server bundle repair

## Development Notes

Keep Go commands inside this directory:

```sh
go test ./...
go run ./cmd/dotfiles-installer
```

The `internal/` directory is intentional. In Go, packages under `internal/` are private to the parent module and cannot be imported by unrelated external modules.
