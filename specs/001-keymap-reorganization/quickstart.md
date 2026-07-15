# Quickstart: Validate Neovim Keymap Reorganization

## Prerequisites

- Work on branch `001-keymap-reorganization` or a feature branch created from it.
- Use the repository-managed Neovim configuration under `nvim/`.
- Do not commit directly to `main`.

## Implementation Scope Check

Expected source files:

- `nvim/lua/config/keymaps.lua`
- `nvim/lua/lsp.lua`
- `nvim/plugin/editor.lua`
- `nvim/plugin/fzf-lua.lua`
- `nvim/plugin/gitsigns.lua`
- `nvim/plugin/diffview.lua`
- `nvim/plugin/markdown.lua`

No unrelated dotfiles module should change for this feature.

## Validation Scenario 1: Configuration Loads

Run a headless Neovim startup check with this repository configuration.

Expected outcome: Neovim exits successfully without keymap, plugin setup, or Lua errors.

## Validation Scenario 2: Duplicate Mapping Inspection

Inspect active normal and visual mappings after startup.

Expected outcome: No duplicate mappings exist for the same mode and final shortcut in the approved inventory, especially `<leader>bb`, `<leader>bn`, `<leader>bp`, `<leader>cf`, `<leader>cs`, `<leader>cL`, `<leader>fe`, `<leader>sd`, `<leader>sg`, `<leader>sb`, `<leader>sh`, `<leader>sr`, `<leader>up`, `<leader>gy`, `<leader>gO`, `<leader>gh`, and `<leader>gx*`.

## Validation Scenario 3: Which-Key Discovery

Open key discovery for `<leader>`.

Expected outcome: The following groups are visible and correctly labeled: buffers, code, files, git, packages, search, UI, and windows.

## Validation Scenario 4: Preserved Mapping Smoke Test

Exercise representative preserved mappings:

- `jk` exits insert mode.
- `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` navigate windows.
- `[e` and `]e` navigate diagnostics when diagnostics exist.
- `[g` and `]g` navigate git hunks in a changed file.
- `gd`, `gD`, `grr`, and `gy` remain available in LSP-attached buffers.

Expected outcome: Preserved mappings behave as before.

## Validation Scenario 5: Migrated Mapping Smoke Test

Exercise representative migrated mappings:

- `<leader>bb` opens buffer picker.
- `<leader>bn` and `<leader>bp` navigate buffers.
- `<leader>cf` formats the buffer.
- `<leader>cs` opens document symbols in an LSP-attached buffer.
- `<leader>sg` starts grep.
- `<leader>fe` opens the explorer.
- `<leader>up` toggles Markdown preview in Markdown files.
- `<leader>gy` yanks a git link and `<leader>gO` opens a git blame link where supported.

Expected outcome: Each migrated mapping invokes the same user-facing behavior as its previous shortcut.

## Rollback

If validation fails, revert only the Neovim keymap-related files changed by this feature. No installer rollback or external cleanup is required.
