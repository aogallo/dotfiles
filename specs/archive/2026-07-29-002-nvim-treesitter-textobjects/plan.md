# Implementation Plan: Neovim Treesitter Textobjects

**Branch**: `002-nvim-treesitter-textobjects` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-nvim-treesitter-textobjects/spec.md`

## Summary

Add semantic Treesitter textobjects and structural selection behavior to the existing Neovim module without copying Lazy.nvim-oriented examples or breaking the current `nvim-treesitter` main-branch setup. The approach is to add `nvim-treesitter/nvim-treesitter-textobjects`, configure it through its current direct `setup` API, define explicit keymaps for select/move/swap behavior, preserve native punctuation textobjects such as `ca(` and `va(`, and document where semantic textobjects are complementary rather than replacements.

## Technical Context

**Language/Version**: Lua configuration for Neovim using repository-managed `vim-pack` helpers and current `nvim-treesitter` main branch APIs.

**Primary Dependencies**: Existing `nvim-treesitter/nvim-treesitter`, existing `nvim-treesitter/nvim-treesitter-context`, candidate `nvim-treesitter/nvim-treesitter-textobjects`, existing custom `vim-pack` plugin helper.

**Storage**: Repository-managed Neovim Lua config, plugin lockfile `nvim/nvim-pack-lock.json`, and optional validation fixtures under the spec directory.

**Testing**: `stylua --check nvim`, Neovim headless startup, Treesitter health check, parser install/update command smoke checks, and interactive/manual validation against Go and Lua or JavaScript/TypeScript fixtures.

**Target Platform**: Portable macOS Neovim dotfiles for Apple Silicon and Intel Macs.

**Project Type**: Dotfiles configuration module.

**Performance Goals**: Textobject selection and movement should feel immediate during normal editing; no startup errors or repeated handler/mapping side effects.

**Constraints**: Do not switch plugin managers, do not copy deprecated `nvim-treesitter.configs` module examples blindly, preserve current parser install/update commands, preserve runtime path handling, avoid keymap conflicts, and coordinate delivery through the Neovim integration branch/final PR flow.

**Scale/Scope**: One Neovim Treesitter configuration enhancement, plus docs, plugin lock update, and validation fixtures/artifacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Plan uses repository-relative Lua config and standard Neovim runtime/plugin paths; no user-specific absolute paths.
- **Idempotency**: PASS. Mappings and commands must be registered once through normal startup config; repeated starts must not duplicate commands or autocmds.
- **Non-destructive safety**: PASS. Existing user files are not overwritten; native textobjects are preserved.
- **Modularity**: PASS. Scope is limited to the Neovim Treesitter module.
- **Source of truth**: PASS. Shared config remains in `nvim/plugin/treesitter.lua`; plugin revisions remain in `nvim/nvim-pack-lock.json`.
- **Dependencies**: PASS with task obligation. Add `nvim-treesitter-textobjects` through `vim-pack` and lock it.
- **Security**: PASS. No secrets or private paths are introduced.
- **Verification**: PASS with task obligation. Include syntax/static/headless/manual validation.
- **Installer UX**: NOT APPLICABLE. Installer flow is not changed.
- **Recovery**: PASS. Rollback is removing/disabling the textobjects plugin/config and lockfile entry.
- **Maintainability**: PASS. Use the plugin's current direct API and minimal explicit mappings instead of custom structural editing code.
- **Documentation**: PASS with task obligation. Update `nvim/README.md` with mappings, validation, troubleshooting, and rollback.
- **Module README**: PASS with task obligation. Existing `nvim/README.md` must be updated.
- **Spec navigation**: PASS with `/speckit.tasks` obligation.
- **Branch/PR discipline**: PASS with task obligation. Link approved issue #48 and coordinate through the integration branch/final PR.

No constitutional exceptions are required.

## Project Structure

### Documentation (this feature)

```text
specs/002-nvim-treesitter-textobjects/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── mapping-behavior.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── README.md
├── nvim-pack-lock.json
├── lua/
│   └── config/
│       └── autocmds.lua
└── plugin/
    └── treesitter.lua

specs/002-nvim-treesitter-textobjects/
└── fixtures/
    ├── sample.go
    └── sample.lua or sample.ts
```

**Structure Decision**: Keep implementation in `nvim/plugin/treesitter.lua` because that file owns parser install/update and context plugin setup. Do not move the Treesitter folding autocommand unless implementation reveals a direct conflict. Add validation fixtures under the spec directory so they remain tied to the feature's requirements and can be archived with the spec.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.

## Phase 0: Research Output

Research is captured in [research.md](./research.md). The selected approach is `nvim-treesitter-textobjects` with its current direct setup API plus explicit keymaps; native punctuation textobjects remain unchanged and documented as complementary.

## Phase 1: Design Output

- Data model: [data-model.md](./data-model.md)
- Mapping behavior contract: [contracts/mapping-behavior.md](./contracts/mapping-behavior.md)
- Validation guide: [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

- **Portability**: PASS. Design uses repository paths and Neovim-standard runtime behavior only.
- **Idempotency**: PASS. Mapping contract includes duplicate/conflict validation.
- **Non-destructive safety**: PASS. Native textobjects are explicitly preserved.
- **Modularity**: PASS. Only Neovim Treesitter module is affected.
- **Source of truth**: PASS. Plugin/config/fixtures are committed; runtime parser installs stay runtime state.
- **Dependencies**: PASS. Dependency and lockfile updates are explicit implementation obligations.
- **Security**: PASS. No sensitive data involved.
- **Verification**: PASS. Quickstart includes headless, health, command, fixture, and manual mapping checks.
- **Installer UX**: NOT APPLICABLE.
- **Recovery**: PASS. Quickstart documents rollback.
- **Maintainability**: PASS. Avoids custom structural editing implementation.
- **Documentation**: PASS with implementation obligation.
- **Module README**: PASS with implementation obligation.
- **Spec navigation**: PASS with `/speckit.tasks` obligation.
- **Branch/PR discipline**: PASS with final PR obligation.

No unresolved NEEDS CLARIFICATION markers remain.
