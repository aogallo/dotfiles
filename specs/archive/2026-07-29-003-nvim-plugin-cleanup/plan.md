# Implementation Plan: Neovim Plugin Cleanup UI

**Branch**: `003-nvim-plugin-cleanup` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-nvim-plugin-cleanup/spec.md`

## Summary

Replace the current opaque `:PackClean` experience with a safe, discoverable Neovim plugin cleanup workflow. The approach is to build a reusable cleanup module that derives candidates from `vim.pack.get()`, lockfile metadata, and validated managed plugin paths; present candidates in a floating Snacks picker/review UI; require explicit selection/confirmation before destructive cleanup; call `vim.pack.del()` for managed inactive plugins where possible; update stale lockfile metadata only after confirmation; and report removed, skipped, blocked, and not-found results.

Issue #27 currently lacks `status:approved`, so implementation/PR flow must treat approval as a blocker before opening the final PR.

## Technical Context

**Language/Version**: Lua configuration for Neovim using built-in `vim.pack` APIs and repository `vim-pack` helper conventions.

**Primary Dependencies**: Existing Neovim `vim.pack`, existing `folke/snacks.nvim` picker/notifier, existing custom `notifications` module, existing `nvim/nvim-pack-lock.json`.

**Storage**: Local Neovim package directories managed by `vim.pack`, repository lockfile `nvim/nvim-pack-lock.json`, runtime-only cleanup selection state, and spec validation fixtures if needed.

**Testing**: `stylua --check nvim`, headless Neovim startup, command existence checks, unit-like Lua validation helpers where practical, manual/interactive cleanup UI validation, and dry-run/simulated candidate scenarios for disk-only, lockfile-only, active, missing, and unsafe-path cases.

**Target Platform**: Portable macOS Neovim dotfiles for Apple Silicon and Intel Macs.

**Project Type**: Dotfiles configuration module.

**Performance Goals**: Cleanup candidate discovery should complete fast enough for interactive use in normal plugin counts; repeated cleanup runs should produce stable state with no duplicate removals.

**Constraints**: Never delete outside allowed Neovim package roots; never delete active plugins; do not require the user to know disk directory names; do not add another plugin manager; do not hard-code user-specific runtime paths in committed config or docs.

**Scale/Scope**: One Neovim package cleanup workflow affecting `PackClean`, helper modules, documentation, and validation guidance.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Plan uses Neovim runtime path discovery and avoids committed absolute local paths.
- **Idempotency**: PASS. Cleanup must be safe to run repeatedly and report no duplicate removals after convergence.
- **Non-destructive safety**: PASS with strict requirement. Deletion is confirmation-gated and path-boundary validated.
- **Modularity**: PASS. Scope is limited to Neovim plugin cleanup.
- **Source of truth**: PASS. Active config, local runtime state, and committed lockfile are explicitly separated.
- **Dependencies**: PASS. Uses existing Snacks and vim.pack; no new plugin manager.
- **Security**: PASS. No secrets or private config are introduced.
- **Verification**: PASS with task obligation. Validation covers active, orphan, missing, lockfile-only, and unsafe-path cases.
- **Installer UX**: NOT APPLICABLE. Installer flow is not changed.
- **Recovery**: PASS. Cleanup is review/confirmation-based; rollback docs explain reinstalling/restoring lockfile entries if needed.
- **Maintainability**: PASS. Separate detection/execution/reporting module avoids embedding destructive behavior directly in UI code.
- **Documentation**: PASS with task obligation. Update `nvim/README.md`.
- **Module README**: PASS with task obligation. Existing Neovim module README must document usage and recovery.
- **Spec navigation**: PASS with `/speckit.tasks` obligation.
- **Branch/PR discipline**: PASS with blocker. Issue #27 approval is required before final PR.

No constitutional exceptions are required.

## Project Structure

### Documentation (this feature)

```text
specs/003-nvim-plugin-cleanup/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cleanup-behavior.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── README.md
├── nvim-pack-lock.json
├── lua/
│   ├── config/
│   │   └── autocmds.lua
│   ├── notifications.lua
│   ├── pack-clean.lua
│   └── vim-pack.lua
└── plugin/
    └── editor.lua
```

**Structure Decision**: Move cleanup logic out of `nvim/lua/config/autocmds.lua` into a dedicated module such as `nvim/lua/pack-clean.lua`, keeping `autocmds.lua` responsible only for registering commands. Use existing `Snacks` if available for picker-style review, and fall back to a simpler review/report path if Snacks is unavailable. Preserve `PackClean` as the user-facing command name but improve or redirect its behavior rather than leaving competing cleanup commands.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.

## Phase 0: Research Output

Research is captured in [research.md](./research.md). The selected approach is a dedicated cleanup module using `vim.pack.get()` and `vim.pack.del()` for managed plugins, Snacks picker for visual review when available, strict path-boundary validation, and explicit lockfile metadata cleanup only after confirmation.

## Phase 1: Design Output

- Data model: [data-model.md](./data-model.md)
- Cleanup behavior contract: [contracts/cleanup-behavior.md](./contracts/cleanup-behavior.md)
- Validation guide: [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

- **Portability**: PASS. Design discovers runtime roots and documents local paths generically.
- **Idempotency**: PASS. Repeated-run behavior is contractually validated.
- **Non-destructive safety**: PASS. Unsafe path blocking and active plugin exclusion are explicit.
- **Modularity**: PASS. Logic is isolated in a Neovim package cleanup module.
- **Source of truth**: PASS. Lockfile changes are explicit and reviewable.
- **Dependencies**: PASS. Existing Snacks is optional UI enhancement; no new plugin manager.
- **Security**: PASS. No secrets involved.
- **Verification**: PASS. Quickstart includes required failure-path validation.
- **Installer UX**: NOT APPLICABLE.
- **Recovery**: PASS. Rollback/reinstall instructions are included.
- **Maintainability**: PASS. UI, detection, execution, and reporting are separable.
- **Documentation**: PASS with implementation obligation.
- **Module README**: PASS with implementation obligation.
- **Spec navigation**: PASS with `/speckit.tasks` obligation.
- **Branch/PR discipline**: PASS with issue #27 approval blocker.

No unresolved NEEDS CLARIFICATION markers remain.
