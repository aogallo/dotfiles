# Quickstart: Validate Merged Tmux Configuration

This guide validates that `Tmux/tmux.conf` is a visible, copy-ready, non-theme tmux configuration.

## Prerequisites

- `tmux` is installed.
- The implementation has created `Tmux/tmux.conf`.
- The active user config is not modified as part of this validation.

## Validation Path

1. Confirm the canonical file is visible and non-hidden:

   ```bash
   test -f Tmux/tmux.conf
   ```

2. Confirm the old hidden repository file is no longer the canonical source:

   ```bash
   test ! -f Tmux/.tmux.conf
   ```

3. Confirm excluded themes are absent:

   ```bash
   ! grep -Ei 'catppuccin|kanagawa' Tmux/tmux.conf
   ```

4. Confirm the config can be parsed and sourced by tmux:

   ```bash
   tmux -f Tmux/tmux.conf start-server \; source-file Tmux/tmux.conf
   ```

5. Confirm expected workflow items are present by review:

   ```bash
   grep -E 'mouse|base-index|pane-base-index|vim-tmux-navigator|tmux-yank|tmux-resurrect|tmux-which-key|tmuxifier|allow-passthrough|display-popup' Tmux/tmux.conf
   ```

## Expected Outcomes

- `Tmux/tmux.conf` exists and is visible in normal file explorers.
- Catppuccin and Kanagawa do not appear in the canonical config.
- tmux accepts the config without theme-related missing dependency errors.
- The active `~/.tmux.conf` remains unchanged by this feature.
- Future installer work can copy `Tmux/tmux.conf` into the active tmux destination.
