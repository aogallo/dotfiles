# Implementation Plan: Markdown Notes Formatting

**Branch**: `001-markdown-notes-formatting` | **Date**: 2026-07-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-markdown-notes-formatting/spec.md`

## Summary

Prevent Markdown save errors when Neovim is opened inside an Obsidian-style notes vault with no project formatter configuration. The implementation will keep Prettier for Markdown files when a portable project/config signal exists, and otherwise use a safe no-project fallback so notes can be saved without formatter failures. Documentation will recommend keeping notes folders lightweight: Markdown content plus optional vault-local settings, with formatter/project tooling only when intentionally desired.

## Technical Context

**Language/Version**: Lua for Neovim configuration; Markdown for documentation and Spec Kit artifacts.

**Primary Dependencies**: `stevearc/conform.nvim`, existing `prettier` formatter, existing trim fallback formatters, Neovim Lua APIs (`vim.fs`, buffer/filetype options), existing `nvim/plugin/conform.lua`.

**Storage**: Markdown files in user notes folders or software project directories; no repository-managed runtime storage.

**Testing**: `stylua --check nvim`, `nvim --headless -u nvim/init.lua '+quitall'`, `setup/validate-nvim-deps.sh`, and headless/temp-directory Markdown formatting smoke tests from [quickstart.md](./quickstart.md).

**Target Platform**: Neovim on supported macOS dotfiles machines, portable across Apple Silicon and Intel where the existing Neovim setup is supported.

**Project Type**: Dotfiles-managed Neovim configuration.

**Performance Goals**: Saving a Markdown note in a notes-only folder completes with zero formatter error notifications; configured project Markdown formatting still applies within one save cycle.

**Constraints**: No user-specific notes path checks; no requirement to add `package.json` or Prettier config to every notes folder; no changes to unrelated filetype formatters; preserve global autoformat controls.

**Scale/Scope**: Single-user editor sessions across notes vaults and software projects using the shared Neovim configuration.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. Detection must use project-local config signals, not absolute notes paths.
- **Idempotency**: Pass. Formatting decisions are declarative and must not register duplicate handlers.
- **Non-destructive safety**: Pass. Notes save without toolchain errors; no note files or vault settings are created by the config itself.
- **Modularity**: Pass. Scope stays in Neovim formatting config and documentation.
- **Source of truth**: Pass. Shared behavior lives in repository-managed Neovim files; vault contents remain user-owned.
- **Dependencies**: Pass. Uses existing Conform/Prettier dependency model; no new dependency required.
- **Security**: Pass. No credentials, private paths, or vault names are committed.
- **Verification**: Pass. Quickstart includes notes-only and project-configured Markdown smoke tests.
- **Installer UX**: Pass. No installer changes are planned.
- **Recovery**: Pass. Rollback is reverting the Neovim formatting/doc changes.
- **Maintainability**: Pass. Prefer a small Conform decision helper over broad formatter rewrites.
- **Documentation**: Pass. Notes-folder recommendation and rollback guidance are part of the design.
- **Branch/PR discipline**: Pass. Implementation must occur on a feature branch and PR creation must ask whether this spec should close.

## Project Structure

### Documentation (this feature)

```text
specs/001-markdown-notes-formatting/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── markdown-formatting.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── plugin/
│   └── conform.lua        # Markdown formatter selection and fallback behavior
├── README.md              # Notes-folder recommendation and validation docs
└── dependencies.tsv       # Existing formatter dependency inventory; update only if dependency meaning changes

specs/001-markdown-notes-formatting/
└── *.md                   # Planning and validation artifacts
```

**Structure Decision**: Keep implementation in `nvim/plugin/conform.lua` because this is a formatter-selection problem. Update `nvim/README.md` only for user-facing notes-folder guidance and rollback/validation notes. Do not add a new module unless the helper becomes too large for the plugin config.

## Phase 0: Research Summary

See [research.md](./research.md). All technical unknowns are resolved with no open clarification markers.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/markdown-formatting.md](./contracts/markdown-formatting.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Portability**: Pass. Plan uses config-file/root signals rather than fixed vault paths.
- **Idempotency**: Pass. No autocmd or handler duplication is introduced.
- **Non-destructive safety**: Pass. Notes-only folders are not modified to satisfy formatting.
- **Modularity**: Pass. Only Neovim formatting/docs are affected.
- **Source of truth**: Pass. Repo config controls editor behavior; notes remain user content.
- **Dependencies**: Pass. No new dependency after design.
- **Security**: Pass. No private path or secret data involved.
- **Verification**: Pass. Quickstart covers headless validation and context-specific smoke tests.
- **Installer UX**: Pass. No installer changes.
- **Recovery**: Pass. Rollback is a normal config/doc revert.
- **Maintainability**: Pass. Conform-native dynamic selection avoids custom formatter infrastructure.
- **Documentation**: Pass. Recommended notes folder model is documented.
- **Branch/PR discipline**: Pass. Active spec closure remains a PR gate.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.
