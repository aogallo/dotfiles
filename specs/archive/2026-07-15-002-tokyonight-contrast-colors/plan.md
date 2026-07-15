# Implementation Plan: Tokyonight Contrast Colors

**Branch**: `feat/tokyonight-contrast-colors` | **Date**: 2026-07-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-tokyonight-contrast-colors/spec.md`

## Summary

Improve readability in the existing Neovim Tokyonight setup without replacing the theme. The implementation should keep Tokyonight `moon`, add targeted highlight overrides for comments, low-contrast explorer/picker file entries, and current-file explorer rows, then evaluate whether Ghostty terminal settings need a documented follow-up.

## Technical Context

**Language/Version**: Lua configuration for Neovim 0.12-era dotfiles  
**Primary Dependencies**: `folke/tokyonight.nvim`, `folke/snacks.nvim`, existing `vim-pack` plugin loader  
**Storage**: Repository-managed Neovim configuration under `nvim/`  
**Testing**: Neovim headless startup, Lua formatting check, runtime highlight inspection, manual explorer/current-row/comment readability validation  
**Target Platform**: macOS dotfiles environment  
**Project Type**: Neovim configuration module  
**Performance Goals**: No measurable startup slowdown; color overrides apply during colorscheme setup  
**Constraints**: Preserve Tokyonight identity, avoid machine-specific values, do not introduce secrets/local overrides, keep changes scoped to Neovim theme/explorer readability unless Ghostty investigation proves a separate terminal follow-up is needed  
**Scale/Scope**: One theme configuration file plus validation artifacts

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Color overrides are repository Lua config with no absolute paths.
- **Idempotency**: PASS. Colorscheme setup applies deterministic highlight overrides on each Neovim startup.
- **Non-destructive safety**: PASS. Change affects shared Neovim config only and does not touch user-owned runtime files.
- **Modularity**: PASS. Scope is limited to the Neovim module, with Ghostty treated as investigation/follow-up unless evidence requires otherwise.
- **Source of truth**: PASS. Shared visual behavior remains in `nvim/plugin/editor.lua`.
- **Dependencies**: PASS. Uses existing plugins already declared in the config.
- **Security**: PASS. No credentials or private identifiers involved.
- **Verification**: PASS. Plan includes startup, formatting, and manual UI validation.
- **Installer UX**: PASS. No installer behavior changes.
- **Recovery**: PASS. Rollback is removing the targeted highlight overrides.
- **Maintainability**: PASS. Minimal config change, no new framework.
- **Documentation**: PASS. Spec and validation guide document the behavior.
- **Branch/PR discipline**: PASS. Work is on `feat/tokyonight-contrast-colors` and must proceed through PR.

## Project Structure

### Documentation (this feature)

```text
specs/002-tokyonight-contrast-colors/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── checklists/
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── plugin/
│   └── editor.lua       # Tokyonight and Snacks explorer config live here
└── lua/
    └── vim-pack.lua     # Existing plugin loader; no change planned
```

**Structure Decision**: Keep theme and explorer readability configuration in the existing `nvim/plugin/editor.lua` plugin configuration boundary.

## Complexity Tracking

No constitutional violations require complexity exceptions.

## Phase 0 Research Summary

See [research.md](./research.md). All planning unknowns are resolved.

## Phase 1 Design Summary

See [data-model.md](./data-model.md) and [quickstart.md](./quickstart.md). No external contracts are needed because this feature changes internal visual configuration and may only document Ghostty follow-up guidance.

## Post-Design Constitution Check

- **Portability**: PASS. Design uses shared Lua config only.
- **Idempotency**: PASS. Highlight overrides are deterministic and re-applied on startup/colorscheme load.
- **Non-destructive safety**: PASS. No user runtime files are edited.
- **Modularity**: PASS. Only Neovim theme/explorer UI behavior is planned; Ghostty is checked as rendering context and not changed by default.
- **Source of truth**: PASS. The shared color behavior is reviewable in the repository.
- **Dependencies**: PASS. No new plugin dependency is required.
- **Security**: PASS. No sensitive data involved.
- **Verification**: PASS. Quickstart defines automated and manual checks.
- **Installer UX**: PASS. No installer surface changes.
- **Recovery**: PASS. Revert the config change to roll back.
- **Maintainability**: PASS. Small, targeted highlight override strategy.
- **Documentation**: PASS. Plan, research, data model, and quickstart are present.
- **Branch/PR discipline**: PASS. Continue on feature branch and PR.
