# Implementation Plan: Installer V2 UI and Install Flow

**Branch**: `002-installer-v2-ui` | **Date**: 2026-07-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-installer-v2-ui/spec.md`

## Summary

Upgrade the existing Go/Bubble Tea installer from a linear text menu into a full-screen, color-coded, progress-aware terminal experience. The implementation keeps the existing installer package, approved-command boundary, and setup scripts as the source of truth while adding viewport-aware rendering, user-facing status terminology, automatic backup confirmation behavior, asynchronous step execution, and release-launch guidance.

## Technical Context

**Language/Version**: Go 1.22

**Primary Dependencies**: `github.com/charmbracelet/bubbletea v1.2.4`, existing indirect `lipgloss` dependency for styling; evaluate adding `github.com/charmbracelet/bubbles` only if custom progress/spinner rendering becomes larger than a small local component.

**Storage**: Local filesystem only; repository-managed config paths, user home config targets, backup paths, and release artifacts.

**Testing**: `go test ./...` inside `installer/`; existing unit tests for installer planning, reports, runner boundaries, TUI views, and updates.

**Target Platform**: macOS on Apple Silicon and Intel; terminal-first execution.

**Project Type**: CLI/TUI application inside an isolated Go module.

**Performance Goals**: Initial UI appears within 1 second after process start; progress or waiting state updates within 2 seconds during long-running steps; 80x24 terminal remains usable.

**Constraints**: No shell interpolation for command execution; no secrets in UI/logs/reports; mutating steps stay confirmation-gated; repeated runs must remain idempotent; full-screen rendering must have readable fallback.

**Scale/Scope**: Six existing modules, three top-level flows, current approved setup-script command set, one active install session at a time.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Use repository root discovery and existing module metadata; release docs cover Apple Silicon/Intel assets.
- **Idempotency**: PASS. Preserve planning/report model and add duplicate backup prevention in backup contract.
- **Non-destructive safety**: PASS. Keep preview-before-mutation and explicit confirmation gates; backups remain automatic only after install confirmation.
- **Modularity**: PASS. Changes stay inside installer module plus release/docs; existing dotfile modules remain optional.
- **Source of truth**: PASS. Existing setup scripts and dependency manifests remain authoritative for behavior.
- **Dependencies**: PASS. Bubble Tea already exists; Bubbles is optional and must be justified if added.
- **Security**: PASS. Existing shell-free runner boundary remains; reports must redact/avoid secrets.
- **Verification**: PASS. Plan includes unit, rendering, runner, repeated-run, failure, and release-launch validation.
- **Installer UX**: PASS. Feature directly improves progress output, actionable errors, exit codes, and final summary.
- **Recovery**: PASS. Backup records and final report continue to provide restore guidance.
- **Maintainability**: PASS. Prefer small local UI state/rendering additions over a new app or framework switch.
- **Documentation**: PASS. Update installer README and release-facing launch instructions.
- **Module README**: PASS. No module behavior changes require per-module README updates unless implementation changes module support boundaries.
- **Spec navigation**: PASS. Tasks must link user-story phases back to `spec.md` headings.
- **Branch/PR discipline**: PASS. Active branch is `002-installer-v2-ui`; PR must verify active spec relationship and ask about closure.

## Project Structure

### Documentation (this feature)

```text
specs/002-installer-v2-ui/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── release-launch-contract.md
│   ├── runner-progress-contract.md
│   └── tui-state-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
installer/
├── README.md
├── cmd/dotfiles-installer/main.go
├── internal/installer/
│   ├── action.go
│   ├── plan.go
│   ├── report.go
│   └── *_test.go
├── internal/runner/
│   ├── runner.go
│   └── runner_test.go
└── internal/tui/
    ├── model.go
    ├── update.go
    ├── view.go
    └── *_test.go

setup/
└── bootstrap-dotfiles-installer.sh

.github/workflows/
└── release-installer.yml
```

**Structure Decision**: Continue with the existing isolated Go installer module. Add UI state, progress messages, responsive rendering, and release guidance in place rather than creating a second application or moving setup-script behavior into Go.

## Complexity Tracking

No constitutional violations require exceptions.

## Phase 0: Research Summary

See [research.md](./research.md). Key outcomes: keep Bubble Tea, use alternate screen and `WindowSizeMsg`, execute steps asynchronously via messages, keep emojis supplemental, and preserve shell-free runner boundaries.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [quickstart.md](./quickstart.md), and contracts in [contracts/](./contracts/).

## Post-Design Constitution Check

- **Portability**: PASS. Contracts require terminal fallback and explicit non-terminal launch guidance.
- **Idempotency**: PASS. Data model includes stable step identity and backup uniqueness rules.
- **Non-destructive safety**: PASS. Confirmation and backup contracts preserve preview-first behavior.
- **Modularity**: PASS. Contracts operate over existing `Module`, `Plan`, `Action`, and `Report` entities.
- **Source of truth**: PASS. No contract duplicates setup-script internals; scripts remain authoritative.
- **Dependencies**: PASS. Optional Bubbles dependency remains research-gated, not mandatory.
- **Security**: PASS. Runner/report contracts retain no-shell execution and no secret exposure.
- **Verification**: PASS. Quickstart defines unit, TUI, repeated-run, failure, and release artifact validation.
- **Installer UX**: PASS. UI state and runner-progress contracts directly cover visible progress and final reporting.
- **Recovery**: PASS. Data model and quickstart cover backup records and interrupted/failed installs.
- **Maintainability**: PASS. Changes are localized to current packages.
- **Documentation**: PASS. Quickstart includes README and release-instruction validation.
- **Module README**: PASS. No module README change required unless tasks alter module automation boundaries.
- **Spec navigation**: PASS. Tasks must link back to four user stories.
- **Branch/PR discipline**: PASS. No direct-main workflow required.
