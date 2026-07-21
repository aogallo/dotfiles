# Data Model: Configuration README Documentation

## Tmux Configuration

Represents the committed tmux configuration in `Tmux/tmux.conf`.

**Fields**:
- `path`: `Tmux/tmux.conf`
- `plugins`: TPM, tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, tmux-which-key, tmuxifier
- `behaviors`: terminal colors, mouse support, vi copy mode, pane splitting/navigation, reload, scratch popup

**Validation rules**:
- README must describe at least five user-facing behaviors from the config.
- README must identify TPM as required before plugin installation.

## Tmux README

Represents the new directory-level guide for Tmux configuration.

**Fields**:
- `purpose`: Clear statement that `Tmux/` is configuration.
- `quick_path`: Activation and validation steps.
- `dependencies`: TPM and tmux itself.
- `behaviors`: Key config features and shortcuts.
- `rollback`: How to recover from local activation.

**Validation rules**:
- Must stand alone without requiring the root README.
- Must warn users not to overwrite existing local config blindly.

## Neovim README

Represents the existing Neovim configuration guide.

**Fields**:
- `purpose`: Shared configuration framing.
- `quick_path`: Startup, formatting, health, dependencies, linking.
- `dependencies`: `nvim/dependencies.tsv` and setup scripts.
- `local_overrides`: Environment variables and ignored local values.
- `rollback`: Link removal or repository revert guidance where relevant.

**Validation rules**:
- Existing useful operational guidance must be preserved.
- Machine-specific values must remain outside committed Lua files.

## Repository User

Represents someone setting up or maintaining these dotfiles.

**Fields**:
- `intent`: Setup, validate, update, or maintain configuration.
- `risk`: Existing local config may already exist.

**Validation rules**:
- User can find setup and validation paths quickly.
- User can identify where future documentation updates belong.

## State Transitions

```text
Browse directory -> Read local README -> Activate safely -> Validate -> Maintain/update
        │                 │                 │             │
        └──── root README remains overview, not detailed source of truth ────┘
```
