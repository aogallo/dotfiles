# Tmux Configuration

This directory contains the shared tmux configuration for the dotfiles repository. The
committed source of truth is `tmux.conf`; local machine activation should be done by copying
or linking that file into the active tmux config location.

## Quick Path

1. Install tmux and TPM, the tmux plugin manager:

   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

2. Preview your existing local config before replacing or linking anything:

   ```sh
   test -e ~/.tmux.conf && ls -l ~/.tmux.conf
   ```

3. Activate this config by copying or linking `Tmux/tmux.conf` to `~/.tmux.conf`.

4. Reload tmux after activation:

   ```sh
   tmux source-file ~/.tmux.conf
   ```

5. Install plugins from inside tmux with TPM:

   ```text
   prefix + I
   ```

## What This Config Does

| Area | Behavior |
|------|----------|
| Plugins | Uses TPM with sensible defaults, clipboard yank, Vim/tmux navigation, resurrect, tmux which-key, and tmuxifier. |
| Terminal color | Uses `tmux-256color` and true-color overrides. |
| Mouse and indexing | Enables mouse support and starts windows/panes at index 1. |
| Copy mode | Uses vi copy mode and sends `y` to `pbcopy` on macOS. |
| Pane workflow | Uses `prefix + v` for horizontal splits and `prefix + d` for vertical splits in the current path. |
| Navigation | Uses repeatable `prefix + h/j/k/l` pane movement and arrow-key resizing. |
| Reload | Uses `prefix + r` to reload `~/.tmux.conf` and show a confirmation message. |
| Scratch session | Uses `M-g` to toggle a `scratch` popup session from the current pane path. |

## Safe Maintenance

- Do not overwrite an existing `~/.tmux.conf` without reviewing or backing it up first.
- Keep shared behavior in `Tmux/tmux.conf`; keep machine-specific changes in your local tmux config or another ignored local file.
- After changing plugins, reload tmux and use TPM's install/update bindings from inside tmux.

## Validation

Use these checks after activation:

```sh
tmux source-file ~/.tmux.conf
tmux list-keys | grep 'source-file ~/.tmux.conf'
```

Inside tmux, confirm `prefix + r` reloads the config and `M-g` opens or hides the scratch popup.

## Rollback

If activation causes problems, restore your previous `~/.tmux.conf` backup or remove the symlink/copy you created. Repository rollback is a normal git revert of documentation or `Tmux/tmux.conf` changes.
