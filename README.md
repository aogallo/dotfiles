# Developer Environment Configurations

## Contribution Workflow

Implementation commits must not go directly to `main`. Create a feature branch, commit the
work there with conventional commit messages, and submit it through a pull request linked to
the approved issue for the change. Before creating a pull request, verify whether the active
specification is related to the PR and ask whether that specification should be closed when
the PR completes the solution.

## Module README Standard

Every maintained module directory must include a `README.md`. Treat it as the module's operating
manual, not as decoration.

Each module README should cover:

- Purpose: what the module configures and why it exists.
- Source of truth: important files, scripts, manifests, and generated/local files.
- Prerequisites: required and optional tools, fonts, apps, services, or OS assumptions.
- Usage: how the module is activated, linked, validated, updated, and used day to day.
- Manual installation: steps that remain outside automation.
- Installer support: what the guided installer can safely validate, install, link, sync, or report.
- Validation: commands or checks that prove the module is healthy.
- Customization: local override files and private/work-specific boundaries.
- Recovery: rollback, unlink, backup restore, and interrupted-run guidance.
- Manual-only boundaries: risky or user-consent actions that must not be automated silently.

## Spec Artifact Navigation

Spec Kit artifacts should be easy to resume after days away from a change. In `tasks.md`, every
user-story phase must include a `Story Link` pointing to the matching heading in `spec.md`.
Setup, foundational, polish, and convergence phases stay unlinked unless they clearly belong to a
specific user story.

Use a visible legend near the top of `tasks.md`:

- `T###`: stable task ID.
- `[P]`: task can run in parallel because it has no dependency on incomplete work and touches
  different files.
- `[US#]`: task belongs to the linked user story phase.

## Dotfiles Installer

### Clean-machine bootstrap

On a new macOS machine, start with the shell bootstrap. It is intentionally small and
detection-first so it can run before Go is installed:

```sh
setup/bootstrap-dotfiles-installer.sh --dry-run
setup/bootstrap-dotfiles-installer.sh
```

The bootstrap checks Xcode Command Line Tools, Homebrew, and Go, then launches the guided
installer. If Xcode Command Line Tools are missing, the non-dry-run path initiates
`xcode-select --install`, stops with `prompt_required`, and asks you to complete the macOS
system prompt before rerunning the bootstrap.

Useful bootstrap modes:

```sh
setup/bootstrap-dotfiles-installer.sh --dry-run
setup/bootstrap-dotfiles-installer.sh --prefer-binary
setup/bootstrap-dotfiles-installer.sh --no-binary
PATH="/usr/bin:/bin:/usr/sbin:/sbin" setup/bootstrap-dotfiles-installer.sh --dry-run
```

`--prefer-binary` uses a compatible local prebuilt `dotfiles-installer` binary when one is
available, but Go is still required and will be installed with Homebrew when missing. `--no-binary`
always launches from source with `cd installer && go run ./cmd/dotfiles-installer`. Dry-run mode
never installs Homebrew or Go and never invokes `xcode-select --install`.

The bootstrap deliberately does not run broad setup or identity/configuration actions. It never
invokes `setup/macos.sh`, GitHub account setup, SSH key generation, Git identity changes, or the
Neovim/Ghostty config linkers. Use the guided installer and module-specific dry-run commands for
those reports and confirmations.

The guided installer lives in `installer/` as an isolated Go module. During development, run
commands from that directory:

```sh
cd installer && go run ./cmd/dotfiles-installer
cd installer && go test ./...
```

The TUI starts with `start installation`, `sync configs`, `Upgrade tools`, and `quit`. It uses
Neovim-style `j`/`k` navigation and defaults to dry-run, report, and confirmation gates before
any mutating action. Existing setup scripts remain the source of truth; the installer previews
and reports first, then delegates only approved commands such as:

```sh
setup/validate-nvim-deps.sh
setup/bootstrap-nvim-deps.sh --dry-run
setup/link-nvim-config.sh --dry-run
setup/validate-zsh-config.sh
setup/validate-ghostty-config.sh
setup/link-ghostty-config.sh --dry-run
```

Manual-only boundaries stay manual/report-only until a later spec designs safe automation:
keyboard VIA import, TPM keypress installation, macOS security approvals, GitHub SSH/account
setup from `setup/macos.sh`, and AWS CloudFormation language server bundle repair.

Rollback and recovery stay module-specific. Neovim and Ghostty link scripts refuse unmanaged
overwrites by default, can create backups only with explicit `--backup`, and remove only
repository-managed links. For troubleshooting, rerun the dry-run command first, inspect the final
installer report for skipped/failed/manual items, then use the relevant module README below.

## Keyboard

### Iris Keyboard

The shared VIA configuration for the Iris Rev. 5 keyboard lives in
`keyboard/iris_rev__5.json`. See `keyboard/README.md` for validation and rollback guidance.

#### Remapping each key

I use `Via Configurator App`, you can follow this [Via Usage Guide](https://www.usevia.app/)
Also review the Via documentation [Via web site](https://docs.keeb.io/via)

### Hombebrew

Install Hombebrew execute this command

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

For more information about Hombebrew you can visit this [web-site](https://brew.sh/)

## Font

I use the JetBrains Mono font

You can download [here](https://www.jetbrains.com/lp/mono/) the font. To install use the following instructions.

## iTerm2

Click [here](https://iterm2.com/) to read the documenation about `iterm2`

**NOTE**: change the key maps to `Natural Text Editing`

Go to Preferences -> Profile -> Keys -> Key Mappings

Click in `Presets` and choose `Natural Text Editing`

**Configure the font in iTerm2**

Go to Preferences -> Profile -> Text -> Font

Choose the `JetBrainsMono Nerd Font Mono` font and active the `Use ligatures` option.

## Ghosty

Other terminal option would be Ghosty, if you wnat to see images in neovim Ghosty is a good option. You can download it [here](https://ghostty.org/docs/install/binary#macos)

## NVIM

![neovim_logo](https://github.com/user-attachments/assets/61f55e5d-e434-4f5e-b986-b0ed7fe11a3c)


Install nvim by brew

```bash
brew install nvim
```

For more information about Neovim you can visit this [neovim](https://neovim.io/)

This repository's Neovim configuration is documented in `nvim/README.md`. Use that file for
validation, dependency checks, linking, local overrides, and rollback guidance.

## Tmux

### Tmux installation

To install tmux go to Installation section in this <a target="_blank" href="https://github.com/tmux/tmux#welcome-to-tmux">tmux repository</a>

This repository's tmux configuration is documented in `Tmux/README.md`. Use that file for
TPM setup, activation, reload, plugin behavior, validation, and rollback guidance.

## Create a symbolic link

See `nvim/README.md` for the safe Neovim linking workflow. It documents the dry-run path and
refuses to overwrite unmanaged local configuration by default.

## Zsh

The repository-managed zsh configuration lives in `zsh/`. See `zsh/README.md` for the current-machine inventory, local-only override boundaries, dependency validation, and future safe-linking expectations.

## Install Stylua formatter

This is the repository with all information about StyLua: [Stylua](https://github.com/JohnnyMorganz/StyLua)

To install Stylua with Homebew, run the following:

```bash
brew install stylua
```

[ripgrep](https://github.com/BurntSushi/ripgrep)

## Csharp language

Installing the lsp and formatter

```bash
dotnet tool install --global csharp-ls &&
dotnet tool install csharpier -g
```

## Images in Neovim

I use `snacks/image` so the following are the requirements:

- Install ImageMagick

### Mac OS X

```bash
brew install imagemagick
```

```bash
brew install ghostscript
```
