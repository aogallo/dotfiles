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

The installer is written in Go, so a completely clean machine needs Go before it can run.

1. Install Apple command line tools:

   ```sh
   xcode-select --install
   ```

2. Install Go using one of these paths:

   ```sh
   # Option A: official installer from https://go.dev/dl/
   go version
   ```

   ```sh
   # Option B: Homebrew, if brew is already installed
   brew install go
   go version
   ```

3. Clone the repository:

   ```sh
   git clone https://github.com/aogallo/dotfiles.git
   cd dotfiles
   ```

4. Start the installer:

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
