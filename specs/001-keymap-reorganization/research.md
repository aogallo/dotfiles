# Phase 0 Research: Neovim Keymap Reorganization

## Decision: Keep Existing File Ownership for Keymaps

**Rationale**: General editing mappings already live in `nvim/lua/config/keymaps.lua`, buffer-local LSP mappings in `nvim/lua/lsp.lua`, and plugin actions next to plugin setup in `nvim/plugin/*.lua`. Keeping that layout avoids a new abstraction and preserves locality between a plugin and its keymaps.

**Alternatives considered**: Move all keymaps into a single registry file. Rejected because it would separate plugin actions from plugin setup, add coordination overhead, and make lazy/plugin-local conditions less obvious.

## Decision: Use Semantic Leader Groups for Discoverable Actions

**Rationale**: The approved proposal follows a LazyVim-style mental model where the first key after `<leader>` names the domain. This improves recall and which-key discovery for actions that are not natural Vim motions.

**Alternatives considered**: Preserve current prefixes exactly. Rejected because current mappings mix buffers/search/files/code and leave some actions as single-letter leader orphans.

## Decision: Preserve Native-Style Motion and LSP Navigation Bindings

**Rationale**: Mappings such as `gd`, `gD`, `grr`, `gy`, `[e`, `]e`, `[g`, and `]g` are direct navigation commands and already match common Vim/LSP previous-next conventions. Forcing them into leader groups would reduce speed without improving clarity.

**Alternatives considered**: Move all LSP and git actions under `<leader>c` and `<leader>g`. Rejected because direct navigation is faster and more idiomatic as motion-style bindings.

## Decision: Add Search and UI Groups

**Rationale**: The current discovery groups include buffers, code, files, git, and packages, but several mappings are search workflows or UI/display toggles. Adding `<leader>s` and `<leader>u` makes grep, current-buffer search, resume, highlights, and preview/toggle actions easier to find.

**Alternatives considered**: Keep all picker actions under `<leader>f`. Rejected because file pickers and search pickers are different user intents even if they share the same plugin.

## Decision: Keep Implementation Dependency-Free

**Rationale**: The feature is a configuration cleanup. Existing Neovim APIs and plugins are enough; adding a keymap registry helper or new plugin would violate the simplicity gate without concrete benefit.

**Alternatives considered**: Add a custom helper module for grouped mappings. Rejected until there is repeated complexity that justifies extraction.

## Decision: Treat Contracts as an Internal Keymap Inventory Contract

**Rationale**: This dotfiles project exposes no public API for keymaps. The useful contract is the implementation-facing inventory of approved moved and preserved mappings.

**Alternatives considered**: Create API or command contracts. Rejected because there are no external service endpoints, CLI schemas, or library interfaces introduced by this change.
