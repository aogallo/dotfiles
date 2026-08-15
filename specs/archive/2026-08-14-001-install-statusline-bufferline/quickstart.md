# Quickstart: Validate Statusline and Bufferline Upgrade

## Prerequisites

- Neovim available on the machine.
- Repository checked out locally.
- Existing Neovim dependencies available as described in `nvim/README.md`.

## Static Validation

Run from the repository root:

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
```

Expected outcome:

- Lua formatting passes.
- Neovim starts without configuration errors.

## Package Sync Validation

After implementation, start Neovim and sync package state:

```vim
:packupdate ++lockfile
```

Expected outcome:

- New plugin entries are installed and written to `nvim/nvim-pack-lock.json`.
- Restarting Neovim does not reinstall the same plugins repeatedly.

## Manual UI Validation

1. Open Neovim with the repository config.
2. Open three different files from the repository.
3. Confirm the bufferline appears and clearly marks the active buffer.
4. Use the existing buffer mappings:

| Mapping | Expected Behavior |
|---------|-------------------|
| `<S-h>` | Move to the next buffer |
| `<S-l>` | Move to the previous buffer |
| `<leader>bb` | Show/select buffers |
| `<leader>bx` | Close the current buffer |
| `<leader>bo` | Close other buffers |

5. Confirm the statusline shows mode, file identity, diagnostics when present, filetype, and cursor position.
6. Confirm the old custom statusline is not visible or loaded.

Expected outcome:

- The active file is identifiable within 2 seconds.
- Buffer close and navigation actions update the UI correctly.
- No duplicate statusline or duplicate buffer UI appears.

## Regression Checks

Run from the repository root:

```sh
nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+quitall'
nvim --headless -u nvim/init.lua '+command PackClean' '+quitall'
```

Expected outcome:

- Existing LSP health checks still run.
- Existing package cleanup command remains available.
