# Implementation Plan: Dotfiles Installer TUI

**Branch**: `001-dotfiles-installer` | **Date**: 2026-07-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-dotfiles-installer/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Build a Bubble Tea terminal installer for this dotfiles repository that presents guided
install, sync, upgrade, and quit flows while preserving the safety guarantees already encoded
in existing setup scripts and module documentation. The implementation should introduce a Go
CLI/TUI as a planner and executor: inventory repository modules, classify actions, preview
changes by default, delegate mutating work to safe existing link/bootstrap scripts, and produce
a final normalized report.

## Technical Context

**Language/Version**: Go 1.22+ for the new installer CLI/TUI; existing setup surfaces remain
Bash, TSV manifests, and module documentation.

**Primary Dependencies**: Bubble Tea for the terminal UI; Bubbles/Lip Gloss may be added only
where they reduce TUI boilerplate for menus, key help, and presentation. Existing shell scripts
remain runtime integration points.

**Storage**: Repository files and local filesystem state only. No database. Backups remain under
existing script-owned paths such as `$HOME/.dotfiles_backup`.

**Testing**: `cd installer && go test ./...` for model transitions, action planning, report normalization, and
script-runner boundaries; existing shell validators for module smoke checks.

**Target Platform**: macOS first, with Apple Silicon and Intel Homebrew path discovery where
practical. Linux behavior is not a Phase 1 target unless existing scripts already support it.

**Project Type**: CLI/TUI application inside a dotfiles repository.

**Performance Goals**: Main menu renders immediately after startup inventory; long-running
validation or install commands stream or surface progress without blocking the Bubble Tea event
loop. A typical dry-run inventory should complete in under 30 seconds on an already-configured
machine.

**Constraints**: Default to dry-run/report mode; never overwrite unmanaged targets without
explicit backup confirmation; never automate manual-only items; preserve idempotency and
recoverability of existing scripts.

**Scale/Scope**: One repository owner/operator, six initial module areas (Neovim, zsh, Ghostty,
tmux, keyboard, macOS setup), and four top-level user actions.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Document how the plan satisfies each applicable dotfiles constitution gate:

- **Portability**: PASS. The installer will derive the repository root from its executable or
  working directory, use `$HOME`, `$XDG_*`, `$HOMEBREW_PREFIX`, `PATH`, and script-provided path
  discovery instead of user-specific absolute paths, and preserve local override separation.
- **Idempotency**: PASS. Plans are state-driven, existing managed links are detected before
  apply, and repeated install/sync/upgrade runs must converge without duplicate links or backup
  loops.
- **Non-destructive safety**: PASS. Mutating actions require confirmation; unmanaged Neovim and
  Ghostty targets continue to be protected by existing linkers and explicit `--backup` behavior.
- **Modularity**: PASS. Modules remain independently validated and actionable; missing optional
  tools in one module do not block unrelated modules.
- **Source of truth**: PASS. Existing setup scripts, `dependencies.tsv` manifests, and module
  READMEs remain authoritative. The TUI presents and orchestrates them rather than duplicating
  their safety rules.
- **Dependencies**: PASS. Go module dependencies will be declared in `installer/go.mod`; runtime tool
  dependencies continue to come from module manifests and validators.
- **Security**: PASS. The installer must not collect, store, print, or commit secrets. Git/SSH,
  macOS security approvals, and private local overrides remain manual or externally confirmed.
- **Verification**: PASS. Required validation includes `cd installer && go test ./...`, model transition tests,
  script-runner tests with fakes, repeated dry-run/apply scenario checks, and module smoke
  checks.
- **Installer UX**: PASS. The TUI contract requires visible progress, skipped/failed/manual
  status separation, actionable messages, exit behavior, and a final summary.
- **Recovery**: PASS. Backups and removal stay delegated to existing safe linkers where they
  exist; manual-only modules document recovery guidance instead of pretending rollback can be
  automated.
- **Maintainability**: PASS. The new code is limited to a small CLI/TUI, planner, runner, and
  report model. Existing shell scripts are reused instead of reimplemented.
- **Documentation**: PASS. Phase 1 includes quickstart validation and contracts; implementation
  tasks must update user docs for install, sync, upgrade, rollback, and troubleshooting.
- **Branch/PR discipline**: PASS WITH PROCESS NOTE. `setup-plan.sh` reported branch
  `001-dotfiles-installer`, but the working tree is currently on `main`. No implementation
  commits should be made until work is moved to the feature branch; the PR must link GitHub issue
  #37 and ask whether the completed spec should be closed.

Plans with unresolved MUST-level violations cannot proceed unless the violation is
explicitly documented as a constitutional exception with rationale and risk.

## Project Structure

### Documentation (this feature)

```text
specs/001-dotfiles-installer/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
installer/
├── go.mod
├── go.sum
├── cmd/
│   └── dotfiles-installer/
│       └── main.go
└── internal/
    ├── installer/
    │   ├── action.go
    │   ├── module.go
    │   ├── plan.go
    │   └── report.go
    ├── runner/
    │   └── runner.go
    └── tui/
        ├── model.go
        ├── update.go
        └── view.go

setup/
├── bootstrap-nvim-deps.sh
├── link-ghostty-config.sh
├── link-nvim-config.sh
├── validate-ghostty-config.sh
├── validate-nvim-deps.sh
└── validate-zsh-config.sh

nvim/dependencies.tsv
zsh/dependencies.tsv
ghostty/dependencies.tsv
```

**Structure Decision**: Keep the installer as an isolated Go module under `installer/`, with the
CLI entrypoint under `installer/cmd/dotfiles-installer` and implementation packages under
`installer/internal/`. Continue using root `setup/` scripts and module manifests as integration
boundaries; do not move existing dotfiles module files as part of this feature.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
