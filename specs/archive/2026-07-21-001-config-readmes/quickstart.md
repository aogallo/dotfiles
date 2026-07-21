# Quickstart: Configuration README Documentation

## Prerequisites

- Run from the repository root.
- Do not change local `~/.tmux.conf` or `~/.config/nvim` during documentation validation unless explicitly testing activation.

## Documentation Review

### Scenario 1: Tmux README Standalone Use

1. Open `Tmux/README.md` without reading the root README.
2. Confirm the first section says this is shared tmux configuration.
3. Confirm the quick path explains TPM, local activation, reload, and validation.
4. Confirm at least five configured behaviors are documented from `Tmux/tmux.conf`.

**Expected**: A reader can understand and validate the Tmux configuration in under 2 minutes.

### Scenario 2: Neovim README Configuration Framing

1. Open `nvim/README.md`.
2. Confirm the opening describes shared editor configuration.
3. Confirm validation, dependency checks, linking, notifications, Obsidian notes, and local overrides remain discoverable.

**Expected**: A reader can find Neovim validation and local override guidance in under 3 minutes.

### Scenario 3: Root README No Contradiction

1. Compare `README.md` with `Tmux/README.md` and `nvim/README.md`.
2. Identify any stale or contradictory setup instructions.
3. If contradictions exist, update root README to point to directory-level docs.

**Expected**: Root README remains an overview and does not conflict with tool-specific docs.

## Safe Command Checks

These commands are safe review aids and should not overwrite user configuration:

```sh
test -f Tmux/tmux.conf
test -f Tmux/README.md
test -f nvim/README.md
setup/validate-nvim-deps.sh
nvim --headless -u nvim/init.lua '+quitall'
```

## Rollback

Rollback is a normal repository revert of documentation changes. If a user manually copied or linked `Tmux/tmux.conf` during local testing, they should restore their previous local tmux config from their own backup.
