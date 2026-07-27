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

`--prefer-binary` first uses a compatible local prebuilt installer binary when available. If none
is available, it tries the latest GitHub Release asset for the detected macOS architecture and
verifies it with `checksums.txt` before execution. Go is still installed when missing because it is
required for development and Neovim tooling. `--no-binary` forces source execution with `go run`
after prerequisites are ready.

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

## Release Playbook

`v1.0.0` is the first stable release of the merged installer from PR #49. It intentionally excludes
the next installer UX/UI redesign; that work should ship in a later version unless the release spec
changes first.

### Manual release

Run these checks from a clean checkout of the intended default-branch commit:

```sh
git status --short
git tag --list 'v1.0.0'
gh release view v1.0.0
(cd installer && go test ./...)
setup/bootstrap-dotfiles-installer_test.sh
bash -n setup/bootstrap-dotfiles-installer.sh setup/bootstrap-dotfiles-installer_test.sh
git diff --check
```

Build assets and checksums:

```sh
mkdir -p dist
(cd installer && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o ../dist/dotfiles-installer-darwin-arm64 ./cmd/dotfiles-installer)
(cd installer && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o ../dist/dotfiles-installer-darwin-amd64 ./cmd/dotfiles-installer)
(cd dist && shasum -a 256 dotfiles-installer-darwin-* > checksums.txt && shasum -a 256 -c checksums.txt)
```

Publish only after the checks pass:

```sh
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0 dist/* --verify-tag --title "Dotfiles Installer v1.0.0" --generate-notes
```

After publishing, confirm the release contains:

- `dotfiles-installer-darwin-arm64`
- `dotfiles-installer-darwin-amd64`
- `checksums.txt`

### Automated release

The GitHub Actions workflow at `.github/workflows/release-installer.yml` runs when a `v*` tag is
pushed. It validates the installer and bootstrap, builds both macOS binaries, generates
`checksums.txt`, verifies the checksums, and publishes the GitHub Release with generated notes.

`--prefer-binary` consumes release assets from GitHub Releases by default. For validation or
recovery, override the base asset URL with `BOOTSTRAP_RELEASE_BASE_URL`; use `--no-binary` to skip
release and local binary discovery entirely.

## Development Notes

Keep Go commands inside this directory:

```sh
go test ./...
go run ./cmd/dotfiles-installer
```

The `internal/` directory is intentional. In Go, packages under `internal/` are private to the parent module and cannot be imported by unrelated external modules.
