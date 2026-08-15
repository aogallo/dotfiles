# Research: Statusline and Bufferline Upgrade

## Decision: Use `vim-pack` for both plugins

**Rationale**: The repository already centralizes plugin installation through `nvim/lua/vim-pack.lua`, where GitHub `src` values are converted to full URLs and configured through `setup()` automatically.

**Alternatives considered**: Add a new plugin manager or ad hoc package loading. Rejected because it would fight the repo's established dependency pattern.

## Decision: Replace the custom statusline with lualine

**Rationale**: `nvim/lua/statusline.lua` currently owns mode, branch, file, diagnostics, filetype, encoding, and position rendering. lualine provides first-class components for those same areas, so keeping both would duplicate UI and maintenance.

**Alternatives considered**: Keep the custom statusline and only add bufferline. Rejected because the user's request explicitly asks to remove what the new plugins improve.

## Decision: Configure lualine as the global statusline

**Rationale**: `nvim/lua/config/options.lua` already sets `laststatus = 3`, which expresses one global statusline. lualine supports a `globalstatus` option, matching the current user experience direction.

**Alternatives considered**: Per-window statuslines. Rejected because it would be a behavior shift and add visual noise.

## Decision: Use bufferline in `buffers` mode with auto-toggle

**Rationale**: The requested workflow is buffer visibility and navigation, not tabpage management. bufferline supports `mode = "buffers"` and `auto_toggle_bufferline`, which keeps single-buffer sessions clean.

**Alternatives considered**: Tabpage mode or always-visible bufferline. Rejected because the spec requires avoiding confusing empty controls for single-buffer sessions.

## Decision: Keep buffer keymaps under `<leader>b`

**Rationale**: Existing mappings already define the buffer domain: `<leader>bn`, `<leader>bp`, `<leader>bx`, `<leader>bo`, and `<leader>bb`. The which-key setup also registers `<leader>b` as `buffers`.

**Alternatives considered**: Add plugin-specific prefixes or move buffer operations under UI. Rejected because the user explicitly asked to keep the established workflow grouping.

## Decision: Skip external contracts except for a UI behavior contract

**Rationale**: This dotfiles change exposes no API, CLI, database schema, or service contract. The relevant contract is the observable editor behavior users can validate.

**Alternatives considered**: No contracts. Rejected because Phase 1 benefits from a lightweight UI contract for manual validation.
