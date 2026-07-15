# Quickstart: Validate Tokyonight Contrast Colors

This guide validates that the Tokyonight contrast changes improve readability for hidden dotfiles, current-file explorer rows, and comments without breaking Neovim startup.

## Prerequisites

- Neovim is installed.
- The feature implementation is present on the active branch.
- Run commands from the repository root.

## Automated Checks

1. Confirm formatting is valid:

   ```bash
   stylua --check nvim
   ```

2. Confirm Neovim starts and loads the colorscheme:

   ```bash
   nvim --headless -u nvim/init.lua '+colorscheme tokyonight' '+quitall'
   ```

3. Confirm the relevant config still lives in the expected module:

   ```bash
   grep -E 'tokyonight|Snacks|colorscheme' nvim/plugin/editor.lua
   ```

## Manual Readability Checks

1. Open Neovim with the repository config.
2. Open the explorer with `<leader>e`.
3. Press `H` to reveal hidden files.
4. Confirm dotfiles such as `.gitignore` are readable within 2 seconds and remain distinguishable from directories, normal files, selected rows, git status, and diagnostics.
5. Open a file from the explorer and confirm the row that represents the current file remains readable and easy to identify.
6. Move selection to a different row and confirm the selected row and current-file row remain distinguishable.
7. Open representative files with comments:
   - `nvim/plugin/editor.lua`
   - `setup/validate-nvim-deps.sh`
   - `README.md`
   - `Tmux/tmux.conf`
8. Confirm comments are readable without selecting text, moving the cursor onto them, or changing themes.
9. Run the same visual checks in Ghostty and record whether any terminal-level setting appears to reduce contrast after Neovim highlight changes.

## Expected Outcomes

- Neovim starts successfully.
- Tokyonight remains the active visual foundation.
- Hidden dotfiles revealed with `H` are visibly easier to read.
- The current-file explorer row is visibly easier to identify.
- Comments are visibly easier to read while remaining secondary to code.
- The selected row and current-file row remain distinguishable.
- Ghostty is either confirmed as acceptable with the Neovim-only change or documented as a separate follow-up.
- No machine-specific paths, secrets, or local-only overrides are introduced.

## Ghostty Follow-up Scope

This change intentionally does not add Ghostty configuration. The repository does not contain a versioned Ghostty config, and the targeted readability issues map to Neovim/Tokyonight/Snacks highlight groups. Treat Ghostty as a follow-up only if the manual checks above still show poor contrast after the Neovim-only highlight overrides are applied; likely terminal factors to inspect then are Ghostty theme, foreground/background palette, opacity, and font rendering.
