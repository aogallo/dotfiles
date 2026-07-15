# Implementation Plan: Neovim Keymap Reorganization

**Branch**: `001-keymap-reorganization` | **Date**: 2026-07-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-keymap-reorganization/spec.md`

## Summary

Reorganize repository-managed Neovim keymaps into an approved LazyVim-style semantic leader layout while preserving high-frequency native-style editing, navigation, LSP, insert-mode, and context-local plugin bindings. The implementation will touch only Neovim configuration files that currently define keymaps and discovery groups, with validation focused on duplicate detection, syntax/config loading, and manual which-key discovery.

## Technical Context

**Language/Version**: Lua for Neovim configuration; target runtime is the repository-managed Neovim setup.

**Primary Dependencies**: Neovim keymap API, existing `vim.pack` plugin configuration, `which-key.nvim`, `fzf-lua`, `gitsigns.nvim`, `diffview.nvim`, `snacks.nvim`, `markdown-preview.nvim`, and existing LSP configuration.

**Storage**: Repository-managed configuration files only; no persistent data storage.

**Testing**: Neovim headless/config load checks, Lua syntax checks where available, duplicate keymap inspection, and manual key discovery smoke test.

**Target Platform**: macOS dotfiles environment governed by the repository constitution; no architecture-specific behavior expected.

**Project Type**: Dotfiles configuration module for Neovim.

**Performance Goals**: No noticeable startup or interaction slowdown; keymap registration should remain simple direct configuration.

**Constraints**: Preserve approved native-style mappings; avoid duplicate mappings in the same mode; do not add dependencies; do not touch unrelated dotfiles modules.

**Scale/Scope**: Existing Neovim keymaps in `nvim/lua/config/keymaps.lua`, `nvim/lua/lsp.lua`, and relevant `nvim/plugin/*.lua` files.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. The change is limited to portable Neovim configuration and introduces no user-specific absolute paths, machine paths, or architecture-specific assumptions.
- **Idempotency**: Pass. Keymaps are registered during normal Neovim startup/plugin setup; the implementation must avoid duplicate active mappings for the same mode and shortcut.
- **Non-destructive safety**: Pass. No installer, file replacement, or user-owned external configuration is modified. Existing behavior removals are documented as mapping migrations.
- **Modularity**: Pass. Scope is restricted to the Neovim module and does not require tmux, Ghostty, shell, Git, or lazygit configuration changes.
- **Source of truth**: Pass. Shared configuration remains in repository-managed Neovim files; no generated local state or private overrides are introduced.
- **Dependencies**: Pass. No new dependency is planned; implementation reuses existing plugins and Neovim APIs.
- **Security**: Pass. No credentials, tokens, private identifiers, or secret-bearing configuration are involved.
- **Verification**: Pass. Plan includes syntax/config load validation, duplicate keymap checks, and manual smoke checks for discovery and preserved mappings.
- **Installer UX**: Not applicable. This feature does not change installation commands or installer output.
- **Recovery**: Pass. Recovery is a normal git revert of the affected Neovim config files.
- **Maintainability**: Pass. Implementation should be small, direct edits to existing keymap definitions and which-key groups; no abstraction is justified.
- **Documentation**: Pass. Spec, plan, research, data model, contract, and quickstart document the approved behavior and validation.
- **Branch/PR discipline**: Pass with workflow dependency. Implementation should continue on feature branch `001-keymap-reorganization` and later be submitted through the repository PR workflow.

## Project Structure

### Documentation (this feature)

```text
specs/001-keymap-reorganization/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── keymap-inventory.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── lua/
│   ├── config/
│   │   └── keymaps.lua
│   └── lsp.lua
└── plugin/
    ├── diffview.lua
    ├── editor.lua
    ├── fzf-lua.lua
    ├── gitsigns.lua
    └── markdown.lua
```

**Structure Decision**: Use the existing Neovim module structure. Keep general/global mappings in `nvim/lua/config/keymaps.lua`, LSP buffer-local mappings in `nvim/lua/lsp.lua`, and plugin-owned mappings next to the plugin configuration that creates them. Update `which-key.nvim` groups in `nvim/plugin/editor.lua` because that is the existing discovery-group source.

## Phase 0: Research Summary

See [research.md](./research.md). Key decisions: no new keymap abstraction, preserve native-style navigation/LSP mappings, add semantic which-key groups, and treat this as an internal configuration contract rather than an external API.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/keymap-inventory.md](./contracts/keymap-inventory.md), and [quickstart.md](./quickstart.md). The design defines the keymap entities, approved mapping migrations, preserved mappings, validation rules, and manual verification path.

## Post-Design Constitution Check

- **Portability**: Still passes; design contains no machine-specific paths or hardware assumptions.
- **Idempotency**: Still passes; duplicate mapping validation is an explicit acceptance check.
- **Non-destructive safety**: Still passes; changes are limited to repository files and reversible through git.
- **Modularity**: Still passes; all affected files are under `nvim/`.
- **Source of truth**: Still passes; no generated runtime state is introduced.
- **Dependencies**: Still passes; no new dependencies in design.
- **Security**: Still passes; no secrets touched.
- **Verification**: Still passes; quickstart defines config load, duplicate inspection, and smoke checks.
- **Installer UX**: Not applicable.
- **Recovery**: Still passes; quickstart documents rollback via reverting touched Neovim files.
- **Maintainability**: Still passes; no new abstraction or framework.
- **Documentation**: Still passes; design artifacts are complete for task generation.
- **Branch/PR discipline**: Still passes; implementation remains planned for feature branch and PR review.

## Complexity Tracking

No constitutional violations or added complexity require exceptions.
