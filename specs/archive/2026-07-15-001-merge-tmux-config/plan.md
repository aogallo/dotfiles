# Implementation Plan: Merge Tmux Configuration

**Branch**: `feat/merge-tmux-config` | **Date**: 2026-07-14 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-merge-tmux-config/spec.md`

## Summary

Create `Tmux/tmux.conf` as the visible canonical tmux configuration for the repository. Merge non-theme behavior from `Tmux/.tmux.conf` and the current active `~/.tmux.conf`, exclude Catppuccin and Kanagawa configuration, and leave the result ready for a future installer to copy into the active tmux location without symbolic links.

## Technical Context

**Language/Version**: tmux configuration syntax; shell commands only for validation  
**Primary Dependencies**: tmux, tmux plugin manager, retained non-theme tmux plugins  
**Storage**: Repository-managed configuration file at `Tmux/tmux.conf`  
**Testing**: static text checks, tmux config parse/source smoke test, manual binding validation  
**Target Platform**: macOS dotfiles environment, portable across Apple Silicon and Intel Macs where practical  
**Project Type**: dotfiles configuration module  
**Performance Goals**: Config can be identified in under 30 seconds and loaded without theme-related errors  
**Constraints**: no themes, no symlink dependency, no secrets, no user-specific absolute paths in repository config  
**Scale/Scope**: one tmux module configuration file and related validation documentation

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. The repository file must not introduce user-specific absolute paths. The active user config is read as source input only.
- **Idempotency**: PASS. This phase creates a single canonical repository file. Future installer idempotency is out of scope but the file is copy-ready.
- **Non-destructive safety**: PASS. Implementation scope is repository-only and must not overwrite the active `~/.tmux.conf` unless the user later asks to apply it.
- **Modularity**: PASS. Scope is limited to the tmux module.
- **Source of truth**: PASS. `Tmux/tmux.conf` becomes the shared repository source of truth; local active config remains runtime state.
- **Dependencies**: PASS. tmux and retained plugins are declared in the config and validation guide.
- **Security**: PASS. No secrets or private identifiers are introduced.
- **Verification**: PASS. Plan includes static theme checks and tmux parse/source validation.
- **Installer UX**: PASS. Installer behavior is not implemented here; future installer requirements are documented.
- **Recovery**: PASS. Implementation leaves the active config untouched; rollback is reverting repository file changes.
- **Maintainability**: PASS. Uses one plain tmux config file and no new abstraction.
- **Documentation**: PASS. Plan, research, data model, and quickstart document the change.
- **Branch/PR discipline**: PASS. Work is on `feat/merge-tmux-config`; any commit should stay on the feature branch and proceed through PR.

## Project Structure

### Documentation (this feature)

```text
specs/001-merge-tmux-config/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── checklists/
```

### Source Code (repository root)

```text
Tmux/
├── .tmux.conf    # Existing hidden source file to retire during implementation
└── tmux.conf     # New visible canonical file to create during implementation
```

**Structure Decision**: Keep tmux configuration under the existing `Tmux/` module and make `Tmux/tmux.conf` the only canonical repository file for future installer copy workflows.

## Complexity Tracking

No constitutional violations require complexity exceptions.

## Phase 0 Research Summary

See [research.md](./research.md). All planning unknowns are resolved.

## Phase 1 Design Summary

See [data-model.md](./data-model.md) and [quickstart.md](./quickstart.md). No external interface contracts are required because this feature changes an internal dotfiles configuration module, not a public API or CLI contract.

## Post-Design Constitution Check

- **Portability**: PASS. Design uses repository-relative `Tmux/tmux.conf` and avoids machine-specific paths.
- **Idempotency**: PASS. Future copy operation has one unambiguous source file.
- **Non-destructive safety**: PASS. Active tmux config remains read-only source input during this feature.
- **Modularity**: PASS. Only the tmux module is affected.
- **Source of truth**: PASS. Hidden repository file is no longer the canonical destination.
- **Dependencies**: PASS. Retained plugins are behavior-oriented and theme plugins are excluded.
- **Security**: PASS. No sensitive material is introduced.
- **Verification**: PASS. Quickstart includes static and tmux load validation.
- **Installer UX**: PASS. Copy-not-symlink behavior is recorded for future installer work.
- **Recovery**: PASS. Rollback is repository-level revert; no runtime config replacement occurs now.
- **Maintainability**: PASS. Single config file, no helper abstraction added.
- **Documentation**: PASS. Planning artifacts describe intent and validation.
- **Branch/PR discipline**: PASS. Current work is on `feat/merge-tmux-config`; implementation and planning commits must not target `main` directly.
