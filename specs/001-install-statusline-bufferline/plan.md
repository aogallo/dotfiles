# Implementation Plan: Statusline and Bufferline Upgrade

**Branch**: `main`  
**Spec**: `specs/001-install-statusline-bufferline/spec.md`  
**Plan**: `specs/001-install-statusline-bufferline/plan.md`  
**Created**: 2026-08-14

## Summary

Replace the custom Neovim statusline with lualine.nvim and add bufferline.nvim as the primary visible buffer list. Keep the existing `vim-pack` plugin pattern, preserve the `<leader>b` buffer domain, and remove redundant status/buffer UI rather than layering plugins over custom code.

## Technical Context

**Language/Runtime**: Lua configuration loaded by Neovim  
**Plugin Manager**: Native `vim.pack` through `nvim/lua/vim-pack.lua`  
**Primary Dependencies**: `nvim-lualine/lualine.nvim`, `akinsho/bufferline.nvim`, existing `nvim-tree/nvim-web-devicons`  
**Current Status UI**: Custom `nvim/lua/statusline.lua`, loaded from `nvim/init.lua`  
**Current Buffer UX**: `<leader>bn`, `<leader>bp`, `<leader>bx`, `<leader>bo`, `<leader>bb`; which-key group `<leader>b`  
**Validation**: `stylua --check nvim`, headless Neovim startup, manual UI buffer workflow

## Constitution Check

No `.specify/memory/constitution.md` exists in this repository. Apply existing repository conventions instead:

- Keep Neovim configuration portable and committed under `nvim/`.
- Use `vim-pack` declarations for plugins.
- Keep keymaps grouped by workflow domain.
- Validate startup and formatting before considering the change complete.

**Gate Status**: PASS. No governance violations found.

## Project Structure

```text
nvim/
├── init.lua
├── lua/
│   ├── statusline.lua
│   ├── vim-pack.lua
│   └── config/
│       ├── keymaps.lua
│       └── options.lua
├── plugin/
│   └── editor.lua
└── nvim-pack-lock.json
```

## Technical Approach

1. Add lualine.nvim and bufferline.nvim to the eager editor plugin list because both affect baseline UI after startup.
2. Configure lualine with global statusline behavior to match the current `laststatus = 3` intent and show mode, branch, filename, diagnostics, filetype, encoding, and position.
3. Configure bufferline in buffer mode with diagnostics enabled, icons supported by existing devicons, and auto-toggle behavior so a single-buffer session stays clean.
4. Remove the custom statusline load from `init.lua` and delete `nvim/lua/statusline.lua` if no remaining references exist.
5. Preserve existing `<leader>b` keymaps. Add only bufferline-specific actions if they materially improve workflows and fit the same domain.
6. Update the lockfile by running the repository's package sync command after plugin installation.

## Phase 0: Research

Completed in `research.md`.

## Phase 1: Design & Contracts

Generated artifacts:

- `data-model.md`
- `contracts/ui-contract.md`
- `quickstart.md`

## Post-Design Constitution Check

**Gate Status**: PASS.

- The design follows existing plugin declaration patterns.
- No new keymap namespace is introduced.
- Redundant custom statusline code is planned for removal.
- Validation commands are documented.

## Implementation Risks

- lualine defaults may not preserve every custom detail from `statusline.lua`; the implementation should prioritize the spec's observable outcomes over one-to-one visual parity.
- `:bdelete` can unload windows unexpectedly in some workflows; keep existing behavior unless manual validation proves a safer replacement is needed.
- The lockfile must be updated after `vim.pack` installs the new plugins.
