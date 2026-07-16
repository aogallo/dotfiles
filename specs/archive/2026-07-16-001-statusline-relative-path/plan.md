# Implementation Plan: Statusline Relative File Path

**Branch**: `pending-feature-branch` | **Date**: 2026-07-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-statusline-relative-path/spec.md`

## Summary

Update the Neovim statusline so the active file is shown relative to the directory where
the editor session was opened, while preserving the current minimal layout. The design also
adds compact editing-state hints for modified and read-only/non-editable buffers, plus sane
labels for unnamed and special buffers.

## Technical Context

**Language/Version**: Lua for Neovim configuration; current repo targets local Neovim setup.

**Primary Dependencies**: Neovim built-in statusline, buffer, path, and option APIs; existing
`nvim-web-devicons` integration remains unchanged for file type display.

**Storage**: N/A; no persisted data model or migration.

**Testing**: Manual Neovim smoke tests plus `stylua --check nvim/lua/statusline.lua` using
the existing `nvim/stylua.toml` configuration.

**Target Platform**: macOS dotfiles Neovim configuration.

**Project Type**: Personal dotfiles configuration module.

**Performance Goals**: Statusline rendering remains effectively instant during buffer
switching and cursor movement; no noticeable redraw lag in normal editing.

**Constraints**: Keep the statusline minimal, avoid user-specific absolute path output for
files inside the starting directory, and do not add new plugins or persistent state.

**Scale/Scope**: One statusline module: `nvim/lua/statusline.lua`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. The design must derive paths from the editor session and active
  buffer rather than hard-code user-specific absolute paths.
- **Idempotency**: PASS. This is a render-only configuration change; repeated statusline
  rendering must not mutate files, options, or local state.
- **Non-destructive safety**: PASS. No installer or replacement behavior is introduced.
- **Modularity**: PASS. Scope is limited to the Neovim statusline module.
- **Source of truth**: PASS. Shared configuration remains in `nvim/lua/statusline.lua`; no
  generated, local, private, or secret files are involved.
- **Dependencies**: PASS. No new dependency is planned; existing optional icon behavior
  remains unchanged.
- **Security**: PASS. No secrets, tokens, or private machine data are introduced.
- **Verification**: PASS. Plan includes formatting/static checks and manual Neovim smoke
  tests for normal, unnamed, special, modified, read-only, and outside-directory buffers.
- **Installer UX**: PASS. Not applicable to installer behavior; no setup command output is
  changed.
- **Recovery**: PASS. Change is isolated to one configuration file and can be reverted by
  restoring the previous file component behavior.
- **Maintainability**: PASS. Prefer one small helper inside the existing statusline module;
  avoid new abstractions unless the implementation becomes hard to read.
- **Documentation**: PASS. The spec, plan, research, data model, contract, and quickstart
  document behavior and validation.
- **Branch/PR discipline**: WARNING. Current branch is `main`; before implementation commits
  or PR creation, work must move to a feature branch. PR creation must verify this active
  spec is related and ask whether it should be closed when the PR completes the solution.

No MUST-level gate is blocked for planning. Implementation must not be committed directly on
`main`.

## Project Structure

### Documentation (this feature)

```text
specs/001-statusline-relative-path/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── statusline-display.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
nvim/
├── lua/
│   └── statusline.lua
└── stylua.toml
```

**Structure Decision**: Implement the feature in the existing statusline module. Do not add a
new module unless the single-file implementation becomes less readable than the extraction.

## Complexity Tracking

No constitutional violations require a complexity exception.

## Phase 0: Research

Research decisions are captured in [research.md](./research.md).

## Phase 1: Design

Design artifacts are captured in:

- [data-model.md](./data-model.md)
- [contracts/statusline-display.md](./contracts/statusline-display.md)
- [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

- **Portability**: PASS. The selected approach uses the editor starting directory and active
  buffer path, not machine-specific path constants.
- **Idempotency**: PASS. Render behavior is pure display logic for the active buffer state.
- **Non-destructive safety**: PASS. No file write, delete, link, or installer operation is
  introduced.
- **Modularity**: PASS. Only `nvim/lua/statusline.lua` is expected to change.
- **Source of truth**: PASS. No generated or local override files are introduced.
- **Dependencies**: PASS. No new runtime dependency is required.
- **Security**: PASS. The statusline may display a relative file path only; no secrets are
  introduced or persisted.
- **Verification**: PASS. Quickstart defines formatting and smoke-test scenarios.
- **Installer UX**: PASS. Not applicable.
- **Recovery**: PASS. Revert the small statusline file change if behavior is unwanted.
- **Maintainability**: PASS. Design keeps logic in one existing module and favors built-in
  path/buffer state.
- **Documentation**: PASS. Plan artifacts cover decisions and validation.
- **Branch/PR discipline**: PASS for design. Implementation remains gated on using a feature
  branch and performing active spec closure review before PR creation.
