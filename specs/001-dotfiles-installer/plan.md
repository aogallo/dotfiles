# Implementation Plan: Dotfiles Installer TUI

**Branch**: `001-dotfiles-installer` | **Date**: 2026-07-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-dotfiles-installer/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Build a clean-machine bootstrap path plus a Bubble Tea terminal installer for this dotfiles
repository. A minimal shell bootstrap prepares the prerequisites needed to launch the installer
on macOS, including Xcode Command Line Tools initiation, Homebrew installation when missing, and
Go installation as a required development dependency. The Go CLI/TUI then presents guided
install, sync, upgrade, and quit flows while preserving the safety guarantees already encoded in
existing setup scripts and module documentation.

## Technical Context

**Language/Version**: macOS Bash for the first-run bootstrap; Go 1.22+ for the installer CLI/TUI;
existing setup surfaces remain Bash, TSV manifests, and module documentation.

**Primary Dependencies**: macOS system shell tools for bootstrap; Xcode Command Line Tools for
compiler/Git prerequisites; Homebrew for managed developer tooling; Go as a managed required
development dependency; Bubble Tea for the terminal UI. Existing shell scripts remain runtime
integration points.

**Storage**: Repository files and local filesystem state only. No database. Backups remain under
existing script-owned paths such as `$HOME/.dotfiles_backup`.

**Testing**: `setup/bootstrap-dotfiles-installer.sh --dry-run` for first-run prerequisite planning;
`PATH="/usr/bin:/bin:/usr/sbin:/sbin" setup/bootstrap-dotfiles-installer.sh --dry-run` for clean
PATH simulation; `cd installer && go test ./...` for model transitions, action planning, report
normalization, and script-runner boundaries; existing shell validators for module smoke checks.

**Target Platform**: macOS first, with Apple Silicon and Intel Homebrew path discovery where
practical. Linux behavior is not a Phase 1 target unless existing scripts already support it.

**Project Type**: CLI/TUI application inside a dotfiles repository.

**Performance Goals**: Bootstrap prerequisite detection should complete in under 10 seconds when
Xcode CLT, Homebrew, and Go are already installed. Main menu renders immediately after startup
inventory; long-running validation or install commands stream or surface progress without
blocking the Bubble Tea event loop. A typical dry-run inventory should complete in under 30
seconds on an already-configured machine.

**Constraints**: Bootstrap must be detection-first and rerunnable; `xcode-select --install` may
require a macOS system prompt and must stop with rerun guidance when manual completion is needed;
prebuilt binaries are optional convenience, not a substitute for installing Go. Default installer
flows to dry-run/report mode; never overwrite unmanaged targets without explicit backup
confirmation; never automate manual-only items; preserve idempotency and recoverability of
existing scripts.

**Scale/Scope**: One repository owner/operator, six initial module areas (Neovim, zsh, Ghostty,
tmux, keyboard, macOS setup), and four top-level user actions.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Document how the plan satisfies each applicable dotfiles constitution gate:

- **Portability**: PASS. The bootstrap and installer will derive the repository root from their
  script/executable location or working directory, use `$HOME`, `$XDG_*`, `$HOMEBREW_PREFIX`,
  `PATH`, and Homebrew shellenv discovery instead of user-specific absolute paths, and preserve
  local override separation.
- **Idempotency**: PASS. Bootstrap checks Xcode CLT, Homebrew, and Go before attempting install;
  plans are state-driven, existing managed links are detected before apply, and repeated
  install/sync/upgrade runs must converge without duplicate links or backup loops.
- **Non-destructive safety**: PASS. Bootstrap installs only prerequisites required to launch and
  operate the installer; mutating dotfiles actions require confirmation; unmanaged Neovim and
  Ghostty targets continue to be protected by existing linkers and explicit `--backup` behavior.
- **Modularity**: PASS. Modules remain independently validated and actionable; missing optional
  tools in one module do not block unrelated modules.
- **Source of truth**: PASS. Existing setup scripts, `dependencies.tsv` manifests, and module
  READMEs remain authoritative. The TUI presents and orchestrates them rather than duplicating
  their safety rules.
- **Dependencies**: PASS. Bootstrap makes Xcode CLT/Homebrew/Go prerequisites explicit and
  testable; Go module dependencies will be declared in `installer/go.mod`; runtime tool
  dependencies continue to come from module manifests and validators.
- **Security**: PASS. The bootstrap and installer must not collect, store, print, or commit
  secrets. Git/SSH account setup, macOS security approvals, and private local overrides remain
  manual or externally confirmed.
- **Verification**: PASS. Required validation includes `cd installer && go test ./...`, model transition tests,
  script-runner tests with fakes, repeated dry-run/apply scenario checks, and module smoke
  checks.
- **Installer UX**: PASS. The TUI contract requires visible progress, skipped/failed/manual
  status separation, actionable messages, exit behavior, and a final summary.
- **Recovery**: PASS. Bootstrap stops safely when Xcode CLT requires manual completion and tells
  the user to rerun; backups and removal stay delegated to existing safe linkers where they exist;
  manual-only modules document recovery guidance instead of pretending rollback can be automated.
- **Maintainability**: PASS. The new code is limited to a small bootstrap script, CLI/TUI,
  planner, runner, and report model. Existing shell scripts are reused instead of reimplemented;
  `setup/macos.sh` remains historical/manual guidance rather than a one-click bootstrap.
- **Documentation**: PASS. Phase 1 includes quickstart validation and contracts; implementation
  tasks must update user docs for install, sync, upgrade, rollback, and troubleshooting.
- **Branch/PR discipline**: PASS WITH PROCESS NOTE. `setup-plan.sh` reported branch
  `001-dotfiles-installer`, while the active Git branch for the opened PR is
  `feat/dotfiles-installer`. The PR must keep linking GitHub issue #37 and ask whether the
  completed spec should be closed.

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
├── bootstrap-dotfiles-installer.sh
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

**Structure Decision**: Add `setup/bootstrap-dotfiles-installer.sh` as the clean-machine shell
entrypoint. Keep the installer as an isolated Go module under `installer/`, with the CLI entrypoint
under `installer/cmd/dotfiles-installer` and implementation packages under `installer/internal/`.
Continue using root `setup/` scripts and module manifests as integration boundaries; do not move
existing dotfiles module files as part of this feature.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | N/A | N/A |
